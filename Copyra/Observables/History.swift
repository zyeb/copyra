// swiftlint:disable file_length
import AppKit.NSRunningApplication
import Defaults
import Foundation
import Logging
import Observation
import Sauce
import Settings
import SwiftData

@Observable
class History: ItemsContainer { // swiftlint:disable:this type_body_length
  static let shared = History()
  let logger = Logger(label: "com.copyra.Copyra")

  var items: [HistoryItemDecorator] = []
  var pasteStack: PasteStack?

  var pinnedItems: [HistoryItemDecorator] { items.filter(\.isPinned) }
  var unpinnedItems: [HistoryItemDecorator] { items.filter(\.isUnpinned) }

  var totalCount: Int {
    return max(storageItemCount, all.count)
  }

  var largeHistoryMode: Bool {
    return totalCount > Defaults[.largeHistoryThreshold]
  }

  var shouldUseVirtualizedHistoryList: Bool {
    return largeHistoryMode && searchQuery.isEmpty
  }

  @MainActor var pagedUnpinnedTotalCount: Int { paginationManager.totalCount }
  @MainActor var pagedWindowStartIndex: Int { paginationManager.windowStartIndex }
  @MainActor var pagedWindowEndIndex: Int { paginationManager.windowEndIndex }
  @MainActor var hasMorePagedItemsBefore: Bool { paginationManager.hasMoreItemsBefore }
  @MainActor var hasMorePagedItemsAfter: Bool { paginationManager.hasMoreItemsAfter }

  var searchQuery: String = "" {
    didSet {
      throttler.throttle { [weak self] in
        guard let self else { return }

        if self.shouldUseVirtualizedHistoryList {
          Task { @MainActor [weak self] in
            guard let self else { return }
            self.composeLargeModeItems()
            self.updateUnpinnedShortcuts()
            AppState.shared.navigator.select(item: self.unpinnedItems.first)
            AppState.shared.popup.needsResize = true
          }
          return
        }

        if self.largeHistoryMode {
          let query = self.searchQuery
          Task { [weak self] in
            guard let self else { return }
            let results = await self.searchInLargeHistory(query: query)
            await MainActor.run { [weak self] in
              guard let self else { return }
              guard self.searchQuery == query else { return }
              self.updateItems(results)
              AppState.shared.navigator.highlightFirst()
              AppState.shared.popup.needsResize = true
            }
          }
          return
        }

        self.updateItems(self.search.search(string: self.searchQuery, within: self.all))

        if self.searchQuery.isEmpty {
          AppState.shared.navigator.select(item: self.unpinnedItems.first)
        } else {
          AppState.shared.navigator.highlightFirst()
        }

        AppState.shared.popup.needsResize = true
      }
    }
  }

  var pressedShortcutItem: HistoryItemDecorator? {
    guard let event = NSApp.currentEvent else {
      return nil
    }

    let modifierFlags = event.modifierFlags
      .intersection(.deviceIndependentFlagsMask)
      .subtracting(.capsLock)

    guard HistoryItemAction(modifierFlags) != .unknown else {
      return nil
    }

    let key = Sauce.shared.key(for: Int(event.keyCode))
    return items.first { $0.shortcuts.contains(where: { $0.key == key }) }
  }

  private let search = Search()
  private let sorter = Sorter()
  private let throttler = Throttler(minimumDelay: 0.2)
  private let largeModeRefreshThrottler = Throttler(minimumDelay: 0.25)

  @ObservationIgnored
  private var sessionLog: [Int: HistoryItem] = [:]

  // The distinction between `all` and `items` is the following:
  // - `all` stores all history items, even the ones that are currently hidden by a search
  // - `items` stores only visible history items, updated during a search
  @ObservationIgnored
  var all: [HistoryItemDecorator] = []

  @ObservationIgnored
  @MainActor private lazy var paginationManager = PaginationManager()

  @ObservationIgnored
  private var pinnedLargeModeItems: [HistoryItemDecorator] = []

  @ObservationIgnored
  private var storageItemCount = 0

  init() {
    Task {
      for await _ in Defaults.updates(.pasteByDefault, initial: false) {
        updateShortcuts()
      }
    }

    Task {
      for await _ in Defaults.updates(.sortBy, initial: false) {
        try? await load()
      }
    }

    Task {
      for await _ in Defaults.updates(.pinTo, initial: false) {
        try? await load()
      }
    }

    Task {
      for await _ in Defaults.updates(.showSpecialSymbols, initial: false) {
        for item in items {
          await updateTitle(item: item, title: item.item.generateTitle())
        }
      }
    }

    Task {
      for await _ in Defaults.updates(.imageMaxHeight, initial: false) {
        for item in items {
          await item.cleanupImages()
        }
      }
    }

    Task {
      for await _ in Defaults.updates(.largeHistoryThreshold, initial: false) {
        await MainActor.run {
          self.refreshForCurrentMode()
        }
      }
    }

    Task {
      for await _ in Defaults.updates(.largeHistoryPageSize, initial: false) {
        await MainActor.run {
          self.refreshForCurrentMode()
        }
      }
    }

    Task {
      for await _ in Defaults.updates(.largeHistoryMaxLoadedPages, initial: false) {
        await MainActor.run {
          self.refreshForCurrentMode()
        }
      }
    }
  }

  @MainActor
  func load() async throws {
    storageItemCount = (try? Storage.shared.context.fetchCount(FetchDescriptor<HistoryItem>())) ?? 0

    if largeHistoryMode {
      try loadLargeHistoryWindow()
    } else {
      try loadFullHistory()
    }

    updateShortcuts()
    // Ensure that panel size is proper *after* loading items.
    Task {
      AppState.shared.popup.needsResize = true
    }
  }

  @MainActor
  func loadMoreItems() async {
    guard shouldUseVirtualizedHistoryList else { return }

    do {
      try paginationManager.loadNextWindow(sortBy: Defaults[.sortBy])
      composeLargeModeItems()
      updateUnpinnedShortcuts()
      AppState.shared.popup.needsResize = true
    } catch {
      logger.error("Failed to load next page: \(error.localizedDescription)")
    }
  }

  @MainActor
  func loadPreviousItems() async {
    guard shouldUseVirtualizedHistoryList else { return }

    do {
      try paginationManager.loadPreviousWindow(sortBy: Defaults[.sortBy])
      composeLargeModeItems()
      updateUnpinnedShortcuts()
      AppState.shared.popup.needsResize = true
    } catch {
      logger.error("Failed to load previous page: \(error.localizedDescription)")
    }
  }

  @MainActor
  func jumpToFirst() async {
    guard shouldUseVirtualizedHistoryList else { return }

    do {
      try paginationManager.jumpToFirst(sortBy: Defaults[.sortBy])
      composeLargeModeItems()
      updateUnpinnedShortcuts()
      AppState.shared.popup.needsResize = true
    } catch {
      logger.error("Failed to jump to first: \(error.localizedDescription)")
    }
  }

  @MainActor
  func jumpToLast() async {
    guard shouldUseVirtualizedHistoryList else { return }

    do {
      try paginationManager.jumpToLast(sortBy: Defaults[.sortBy])
      composeLargeModeItems()
      updateUnpinnedShortcuts()
      AppState.shared.popup.needsResize = true
    } catch {
      logger.error("Failed to jump to last: \(error.localizedDescription)")
    }
  }

  @MainActor
  private func loadFullHistory() throws {
    let descriptor = FetchDescriptor<HistoryItem>()
    let results = try Storage.shared.context.fetch(descriptor)
    pinnedLargeModeItems = []
    all = sorter.sort(results).map { HistoryItemDecorator($0) }
    items = all

    limitHistorySize(to: Defaults[.size])
    storageItemCount = (try? Storage.shared.context.fetchCount(FetchDescriptor<HistoryItem>())) ?? all.count
  }

  @MainActor
  private func loadLargeHistoryWindow() throws {
    var pinnedDescriptor = FetchDescriptor<HistoryItem>(
      predicate: #Predicate { $0.pin != nil },
      sortBy: [PaginationManager.sortDescriptor(for: Defaults[.sortBy])]
    )
    pinnedDescriptor.fetchLimit = 64
    let pinnedResults = try Storage.shared.context.fetch(pinnedDescriptor)
    pinnedLargeModeItems = sorter.sort(pinnedResults).map { HistoryItemDecorator($0) }

    try paginationManager.load(sortBy: Defaults[.sortBy])
    composeLargeModeItems()
  }

  @MainActor
  private func composeLargeModeItems() {
    let unpinnedWindow = paginationManager.allLoadedItems

    if Defaults[.pinTo] == .bottom {
      all = unpinnedWindow + pinnedLargeModeItems
    } else {
      all = pinnedLargeModeItems + unpinnedWindow
    }

    items = all
  }

  @MainActor
  private func fetchLargeSearchPinnedItems() -> [HistoryItemDecorator] {
    var descriptor = FetchDescriptor<HistoryItem>(
      predicate: #Predicate { $0.pin != nil },
      sortBy: [PaginationManager.sortDescriptor(for: Defaults[.sortBy])]
    )
    descriptor.fetchLimit = 64

    let results = (try? Storage.shared.context.fetch(descriptor)) ?? []
    return sorter.sort(results).map { HistoryItemDecorator($0) }
  }

  @MainActor
  private func fetchLargeSearchUnpinnedItems(offset: Int, limit: Int) -> [HistoryItemDecorator] {
    var descriptor = FetchDescriptor<HistoryItem>(
      predicate: #Predicate { $0.pin == nil },
      sortBy: [PaginationManager.sortDescriptor(for: Defaults[.sortBy])]
    )
    descriptor.fetchOffset = offset
    descriptor.fetchLimit = limit

    let results = (try? Storage.shared.context.fetch(descriptor)) ?? []
    return results.map { HistoryItemDecorator($0) }
  }

  @MainActor
  private func fetchLargeExactSearchMatches(query: String, pinned: Bool, limit: Int) -> [HistoryItemDecorator] {
    var descriptor = FetchDescriptor<HistoryItem>(
      predicate: pinned
        ? #Predicate { $0.pin != nil && $0.title.localizedStandardContains(query) }
        : #Predicate { $0.pin == nil && $0.title.localizedStandardContains(query) },
      sortBy: [PaginationManager.sortDescriptor(for: Defaults[.sortBy])]
    )
    descriptor.fetchLimit = limit

    let results = (try? Storage.shared.context.fetch(descriptor)) ?? []
    return results.map { HistoryItemDecorator($0) }
  }

  private func searchInLargeHistory(query: String) async -> [Search.SearchResult] {
    let itemCount = await MainActor.run { totalCount }
    let effectiveMode = search.effectiveMode(for: itemCount)
    let candidateLimit = max(10_000, Defaults[.largeHistoryThreshold] * 2)
    let batchSize = max(5_000, Defaults[.largeHistoryPageSize] * 25)
    let resultsLimit = max(400, Defaults[.largeHistoryPageSize] * 4)

    if effectiveMode == .exact {
      let (pinnedCandidates, unpinnedCandidates) = await MainActor.run {
        (
          fetchLargeExactSearchMatches(query: query, pinned: true, limit: 64),
          fetchLargeExactSearchMatches(query: query, pinned: false, limit: resultsLimit)
        )
      }

      let pinnedMatches = search.search(
        string: query,
        within: pinnedCandidates
      )
      let unpinnedMatches = search.search(
        string: query,
        within: unpinnedCandidates
      )

      if Defaults[.pinTo] == .bottom {
        return unpinnedMatches + pinnedMatches
      }

      return pinnedMatches + unpinnedMatches
    }

    let pinnedMatches = await MainActor.run {
      search.search(string: query, within: fetchLargeSearchPinnedItems())
    }

    let unpinnedCount = await MainActor.run {
      paginationManager.totalCount > 0
        ? paginationManager.totalCount
        : ((try? Storage.shared.context.fetchCount(
          FetchDescriptor<HistoryItem>(predicate: #Predicate { $0.pin == nil })
        )) ?? 0)
    }

    var unpinnedMatches: [Search.SearchResult] = []
    var offset = 0

    while offset < unpinnedCount, unpinnedMatches.count < resultsLimit {
      let limit = offset == 0 ? min(candidateLimit, unpinnedCount) : batchSize
      guard limit > 0 else { break }
      let batchOffset = offset

      let candidates = await MainActor.run {
        fetchLargeSearchUnpinnedItems(offset: batchOffset, limit: limit)
      }

      let matches: [Search.SearchResult] = autoreleasepool {
        return search.search(string: query, within: candidates)
      }

      unpinnedMatches.append(contentsOf: matches)
      offset += limit
      await Task.yield()
    }

    if Defaults[.pinTo] == .bottom {
      return unpinnedMatches + pinnedMatches
    }

    return pinnedMatches + unpinnedMatches
  }

  @MainActor
  private func refreshForCurrentMode() {
    storageItemCount = (try? Storage.shared.context.fetchCount(FetchDescriptor<HistoryItem>())) ?? storageItemCount

    if largeHistoryMode {
      try? paginationManager.reload(sortBy: Defaults[.sortBy])
      let pinnedDescriptor = FetchDescriptor<HistoryItem>(predicate: #Predicate { $0.pin != nil })
      let pinnedResults = (try? Storage.shared.context.fetch(pinnedDescriptor)) ?? []
      pinnedLargeModeItems = sorter.sort(pinnedResults).map { HistoryItemDecorator($0) }
      composeLargeModeItems()

      if !searchQuery.isEmpty {
        let query = searchQuery
        Task { [self] in
          let results = await searchInLargeHistory(query: query)
          await MainActor.run {
            guard searchQuery == query else { return }
            updateItems(results)
          }
        }
      }
    } else {
      try? loadFullHistory()

      if !searchQuery.isEmpty {
        updateItems(search.search(string: searchQuery, within: all))
      }
    }

    updateUnpinnedShortcuts()
    AppState.shared.popup.needsResize = true
  }

  @MainActor
  private func limitHistorySize(to maxSize: Int) {
    guard maxSize > 0 else {
      return
    }

    guard !largeHistoryMode else {
      return
    }

    let unpinned = all.filter(\.isUnpinned)
    guard unpinned.count > maxSize else {
      return
    }

    unpinned[maxSize...].forEach(delete)
  }

  @MainActor
  func insertIntoStorage(_ item: HistoryItem) throws {
    logger.info("Inserting item with id '\(item.title)'")
    Storage.shared.context.insert(item)
    Storage.shared.context.processPendingChanges()
    try? Storage.shared.context.save()
  }

  @discardableResult
  @MainActor
  func add(_ item: HistoryItem) -> HistoryItemDecorator {
    if #available(macOS 15.0, *) {
      try? History.shared.insertIntoStorage(item)
    } else {
      // On macOS 14 the history item needs to be inserted into storage directly after creating it.
      // It was already inserted after creation in Clipboard.swift
    }

    var removedItemIndex: Int?
    if let existingHistoryItem = findSimilarItem(item) {
      if isModified(item) == nil {
        item.contents = existingHistoryItem.contents
      }
      item.firstCopiedAt = existingHistoryItem.firstCopiedAt
      item.numberOfCopies += existingHistoryItem.numberOfCopies
      item.pin = existingHistoryItem.pin
      item.title = existingHistoryItem.title
      if !item.fromCopyra {
        item.application = existingHistoryItem.application
      }
      logger.info("Removing duplicate item '\(item.title)'")
      Storage.shared.context.delete(existingHistoryItem)
      removedItemIndex = all.firstIndex(where: { $0.item == existingHistoryItem })
      if let removedItemIndex {
        all.remove(at: removedItemIndex)
      }
    } else {
      Task {
        Notifier.notify(body: item.title, sound: .write)
      }
    }

    // Remove exceeding items. Do this after the item is added to avoid removing something
    // if a duplicate was found as then the size already stayed the same.
    if !largeHistoryMode {
      limitHistorySize(to: Defaults[.size] - 1)
    }

    sessionLog[Clipboard.shared.changeCount] = item

    var itemDecorator: HistoryItemDecorator
    if let pin = item.pin {
      itemDecorator = HistoryItemDecorator(item, shortcuts: KeyShortcut.create(character: pin))
      // Keep pins in the same place.
      if let removedItemIndex {
        all.insert(itemDecorator, at: removedItemIndex)
      }
    } else {
      itemDecorator = HistoryItemDecorator(item)

      if !largeHistoryMode {
        let sortedItems = sorter.sort(all.map(\.item) + [item])
        if let index = sortedItems.firstIndex(of: item) {
          all.insert(itemDecorator, at: index)
        }

        items = all
        updateUnpinnedShortcuts()
        AppState.shared.popup.needsResize = true
      }
    }

    if largeHistoryMode {
      if removedItemIndex == nil {
        storageItemCount += 1
      }
      if itemDecorator.isPinned {
        pinnedLargeModeItems.removeAll(where: { $0.item == itemDecorator.item })
        pinnedLargeModeItems.insert(itemDecorator, at: 0)
      }

      if searchQuery.isEmpty {
        composeLargeModeItems()
        updateUnpinnedShortcuts()
        AppState.shared.popup.needsResize = true
      }

      scheduleLargeModeRefresh()
    } else {
      storageItemCount = all.count
    }

    return itemDecorator
  }

  @MainActor
  private func withLogging(_ msg: String, _ block: () throws -> Void) rethrows {
    func dataCounts() -> String {
      let historyItemCount = try? Storage.shared.context.fetchCount(FetchDescriptor<HistoryItem>())
      let historyContentCount = try? Storage.shared.context.fetchCount(FetchDescriptor<HistoryItemContent>())
      return "HistoryItem=\(historyItemCount ?? 0) HistoryItemContent=\(historyContentCount ?? 0)"
    }

    logger.info("\(msg) Before: \(dataCounts())")
    try? block()
    logger.info("\(msg) After: \(dataCounts())")
  }

  @MainActor
  func clear() {
    withLogging("Clearing history") {
      all.forEach { item in
        if item.isUnpinned {
          cleanup(item)
        }
      }
      all.removeAll(where: \.isUnpinned)
      sessionLog.removeValues { $0.pin == nil }
      items = all

      try? Storage.shared.context.transaction {
        try? Storage.shared.context.delete(
          model: HistoryItem.self,
          where: #Predicate { $0.pin == nil }
        )
        try? Storage.shared.context.delete(
          model: HistoryItemContent.self,
          where: #Predicate { $0.item?.pin == nil }
        )
      }
      Storage.shared.context.processPendingChanges()
      try? Storage.shared.context.save()
    }

    storageItemCount = (try? Storage.shared.context.fetchCount(FetchDescriptor<HistoryItem>())) ?? 0

    if largeHistoryMode {
      refreshForCurrentMode()
    }

    Clipboard.shared.clear()
    AppState.shared.popup.close()
    Task {
      AppState.shared.popup.needsResize = true
    }
  }

  @MainActor
  func clearAll() {
    withLogging("Clearing all history") {
      all.forEach { item in
        cleanup(item)
      }
      all.removeAll()
      sessionLog.removeAll()
      items = all

      try? Storage.shared.context.delete(model: HistoryItem.self)
      Storage.shared.context.processPendingChanges()
      try? Storage.shared.context.save()
    }

    storageItemCount = 0
    pinnedLargeModeItems = []

    if largeHistoryMode {
      refreshForCurrentMode()
    }

    Clipboard.shared.clear()
    AppState.shared.popup.close()
    Task {
      AppState.shared.popup.needsResize = true
    }
  }

  @MainActor
  func delete(_ item: HistoryItemDecorator?) {
    guard let item else { return }

    cleanup(item)
    withLogging("Removing history item") {
      Storage.shared.context.delete(item.item)
      Storage.shared.context.processPendingChanges()
      try? Storage.shared.context.save()
    }

    sessionLog.removeValues { $0 == item.item }

    if largeHistoryMode {
      all.removeAll { $0 == item }
      items.removeAll { $0 == item }
      pinnedLargeModeItems.removeAll { $0 == item }
      storageItemCount = max(0, storageItemCount - 1)

      updateUnpinnedShortcuts()
      Task {
        AppState.shared.popup.needsResize = true
      }
      scheduleLargeModeRefresh()
    } else {
      all.removeAll { $0 == item }
      items.removeAll { $0 == item }
      storageItemCount = all.count

      updateUnpinnedShortcuts()
      Task {
        AppState.shared.popup.needsResize = true
      }
    }
  }

  @MainActor
  private func cleanup(_ item: HistoryItemDecorator) {
    item.cleanupImages()
  }

  private func currentModifierFlags() -> NSEvent.ModifierFlags {
    return NSApp.currentEvent?.modifierFlags
      .intersection(.deviceIndependentFlagsMask)
      .subtracting([.capsLock, .numericPad, .function]) ?? []
  }

  @MainActor
  func select(_ item: HistoryItemDecorator?) {
    guard let item else {
      return
    }

    let modifierFlags = currentModifierFlags()

    if modifierFlags.isEmpty {
      AppState.shared.popup.close()
      Clipboard.shared.copy(item.item, removeFormatting: Defaults[.removeFormattingByDefault])
      if Defaults[.pasteByDefault] {
        Clipboard.shared.paste()
      }
    } else {
      switch HistoryItemAction(modifierFlags) {
      case .copy:
        AppState.shared.popup.close()
        Clipboard.shared.copy(item.item)
      case .paste:
        AppState.shared.popup.close()
        Clipboard.shared.copy(item.item)
        Clipboard.shared.paste()
      case .pasteWithoutFormatting:
        AppState.shared.popup.close()
        Clipboard.shared.copy(item.item, removeFormatting: true)
        Clipboard.shared.paste()
      case .unknown:
        return
      }
    }

    Task {
      searchQuery = ""
    }
  }

  @MainActor
  func startPasteStack(selection: inout Selection<HistoryItemDecorator>) {
    guard AppState.shared.multiSelectionEnabled else { return }
    guard let item = selection.first else { return }
    PasteStack.initializeIfNeeded()

    let modifierFlags = currentModifierFlags()

    let stack = PasteStack(items: selection.items, modifierFlags: modifierFlags)
    pasteStack = stack

    logger.info("Initialising PasteStack with \(stack.items.count) items")
    logger.info("Copying \(item.item.title) from PasteStack")

    if modifierFlags.isEmpty {
      AppState.shared.popup.close()
      Clipboard.shared.copy(item.item, removeFormatting: Defaults[.removeFormattingByDefault])
    } else {
      switch HistoryItemAction(modifierFlags) {
      case .copy:
        AppState.shared.popup.close()
        Clipboard.shared.copy(item.item)
      case .paste:
        AppState.shared.popup.close()
        Clipboard.shared.copy(item.item)
      case .pasteWithoutFormatting:
        AppState.shared.popup.close()
        Clipboard.shared.copy(item.item, removeFormatting: true)
        Clipboard.shared.paste()
      case .unknown:
        return
      }
    }

    Task {
      searchQuery = ""
    }
  }

  func handlePasteStack() {
    guard let stack = pasteStack else {
      return
    }

    guard let pasted = stack.items.first else {
      pasteStack = nil
      logger.info("PasteStack is empty")
      return
    }

    logger.info("PasteStack pasted \(pasted.item.title)")

    stack.items.removeFirst()

    guard let item = stack.items.first else {
      pasteStack = nil
      logger.info("PasteStack is empty")
      return
    }

    logger.info("Copying \(item.item.title) from PasteStack. \(stack.items.count) items remaining in stack.")

    Task {
      if stack.modifierFlags.isEmpty {
        await Clipboard.shared.copy(item.item, removeFormatting: Defaults[.removeFormattingByDefault])
      } else {
        switch HistoryItemAction(stack.modifierFlags) {
        case .copy:
          await Clipboard.shared.copy(item.item)
        case .paste:
          await Clipboard.shared.copy(item.item)
        case .pasteWithoutFormatting:
          await Clipboard.shared.copy(item.item, removeFormatting: true)
        case .unknown:
          return
        }
      }
    }
  }

  func interruptPasteStack() {
    guard pasteStack != nil else {
      return
    }
    logger.info("Interrupting PasteStack")
    pasteStack = nil
  }

  @MainActor
  func togglePin(_ item: HistoryItemDecorator?) {
    guard let item else { return }

    item.togglePin()

    if largeHistoryMode {
      searchQuery = ""
      pinnedLargeModeItems.removeAll { $0 == item }
      if item.isPinned {
        pinnedLargeModeItems.insert(item, at: 0)
      }
      composeLargeModeItems()
      updateUnpinnedShortcuts()
      scheduleLargeModeRefresh()
      if item.isUnpinned {
        AppState.shared.navigator.scrollTarget = item.id
      }
      return
    }

    let sortedItems = sorter.sort(all.map(\.item))
    if let currentIndex = all.firstIndex(of: item),
       let newIndex = sortedItems.firstIndex(of: item.item) {
      all.remove(at: currentIndex)
      all.insert(item, at: newIndex)
    }

    items = all

    searchQuery = ""
    updateUnpinnedShortcuts()
    if item.isUnpinned {
      AppState.shared.navigator.scrollTarget = item.id
    }
  }

  @MainActor
  private func findSimilarItem(_ item: HistoryItem) -> HistoryItem? {
    if let duplicate = all.first(where: { $0.item.supersedes(item) }) {
      return duplicate.item
    }

    if largeHistoryMode, !item.title.isEmpty {
      let title = item.title
      var descriptor = FetchDescriptor<HistoryItem>(
        predicate: #Predicate { $0.title == title }
      )
      descriptor.fetchLimit = 64
      if let candidates = try? Storage.shared.context.fetch(descriptor),
         let duplicate = candidates.first(where: { $0 != item && $0.supersedes(item) }) {
        return duplicate
      }
    }

    return isModified(item)
  }

  private func isModified(_ item: HistoryItem) -> HistoryItem? {
    if let modified = item.modified, sessionLog.keys.contains(modified) {
      return sessionLog[modified]
    }

    return nil
  }

  private func updateItems(_ newItems: [Search.SearchResult]) {
    items = newItems.map { result in
      let item = result.object
      item.highlight(searchQuery, result.ranges)

      return item
    }

    updateUnpinnedShortcuts()
  }

  private func updateShortcuts() {
    for item in pinnedItems {
      if let pin = item.item.pin {
        item.shortcuts = KeyShortcut.create(character: pin)
      }
    }

    updateUnpinnedShortcuts()
  }

  @MainActor
  private func updateTitle(item: HistoryItemDecorator, title: String) {
    item.title = title
    item.item.title = title
  }

  private func updateUnpinnedShortcuts() {
    let visibleUnpinnedItems = unpinnedItems.filter(\.isVisible)
    for item in visibleUnpinnedItems {
      item.shortcuts = []
    }

    var index = 1
    for item in visibleUnpinnedItems.prefix(9) {
      item.shortcuts = KeyShortcut.create(character: String(index))
      index += 1
    }
  }

  @MainActor
  private func scheduleLargeModeRefresh() {
    largeModeRefreshThrottler.throttle { [weak self] in
      Task { @MainActor in
        self?.refreshForCurrentMode()
      }
    }
  }
}

@MainActor
@Observable
private class PaginationManager {
  private enum Direction {
    case forward
    case backward
  }

  private var loadedPages: [Int: [HistoryItemDecorator]] = [:]
  private(set) var currentPageIndex: Int = 0
  private(set) var totalCount: Int = 0
  private(set) var isLoading: Bool = false

  private var pageSize: Int {
    max(80, Defaults[.largeHistoryPageSize])
  }

  private var maxLoadedPages: Int {
    min(max(2, Defaults[.largeHistoryMaxLoadedPages]), 5)
  }

  private var loadedPageIndices: [Int] {
    loadedPages.keys.sorted()
  }

  var windowStartIndex: Int {
    guard let first = loadedPageIndices.first else {
      return 0
    }
    return first * pageSize
  }

  var windowEndIndex: Int {
    return windowStartIndex + allLoadedItems.count
  }

  var hasMoreItemsAfter: Bool {
    guard totalPageCount > 0, let highest = loadedPageIndices.last else {
      return false
    }
    return highest < (totalPageCount - 1)
  }

  var hasMoreItemsBefore: Bool {
    guard totalPageCount > 0, let lowest = loadedPageIndices.first else {
      return false
    }
    return lowest > 0
  }

  var allLoadedItems: [HistoryItemDecorator] {
    return loadedPageIndices.flatMap { loadedPages[$0] ?? [] }
  }

  func load(sortBy: Sorter.By) throws {
    isLoading = true
    defer { isLoading = false }

    currentPageIndex = 0
    loadedPages.removeAll()

    let countDescriptor = FetchDescriptor<HistoryItem>(predicate: #Predicate { $0.pin == nil })
    totalCount = (try? Storage.shared.context.fetchCount(countDescriptor)) ?? 0

    guard totalCount > 0 else {
      return
    }

    try loadPageIfNeeded(at: 0, sortBy: sortBy)
    try preloadFromCurrent(sortBy: sortBy, preferred: .forward)
    trimWindow(keeping: currentPageIndex, preferred: .forward)
  }

  func reload(sortBy: Sorter.By) throws {
    isLoading = true
    defer { isLoading = false }

    let countDescriptor = FetchDescriptor<HistoryItem>(predicate: #Predicate { $0.pin == nil })
    totalCount = (try? Storage.shared.context.fetchCount(countDescriptor)) ?? 0

    guard totalCount > 0 else {
      currentPageIndex = 0
      loadedPages.removeAll()
      return
    }

    currentPageIndex = min(currentPageIndex, totalPageCount - 1)
    loadedPages.removeAll()
    try loadPageIfNeeded(at: currentPageIndex, sortBy: sortBy)

    var step = 1
    while loadedPages.count < maxLoadedPages {
      var loadedAny = false

      let previousIndex = currentPageIndex - step
      if previousIndex >= 0 {
        try loadPageIfNeeded(at: previousIndex, sortBy: sortBy)
        loadedAny = true
      }

      if loadedPages.count >= maxLoadedPages {
        break
      }

      let nextIndex = currentPageIndex + step
      if nextIndex < totalPageCount {
        try loadPageIfNeeded(at: nextIndex, sortBy: sortBy)
        loadedAny = true
      }

      if !loadedAny {
        break
      }
      step += 1
    }

    trimWindow(keeping: currentPageIndex, preferred: .forward)
  }

  func loadNextWindow(sortBy: Sorter.By) throws {
    guard !isLoading, currentPageIndex < (totalPageCount - 1) else { return }

    isLoading = true
    defer { isLoading = false }

    currentPageIndex += 1
    try loadPageIfNeeded(at: currentPageIndex, sortBy: sortBy)
    try preloadFromCurrent(sortBy: sortBy, preferred: .forward)
    trimWindow(keeping: currentPageIndex, preferred: .forward)
  }

  func loadPreviousWindow(sortBy: Sorter.By) throws {
    guard !isLoading, currentPageIndex > 0 else { return }

    isLoading = true
    defer { isLoading = false }

    currentPageIndex -= 1
    try loadPageIfNeeded(at: currentPageIndex, sortBy: sortBy)
    try preloadFromCurrent(sortBy: sortBy, preferred: .backward)
    trimWindow(keeping: currentPageIndex, preferred: .backward)
  }

  func jumpToFirst(sortBy: Sorter.By) throws {
    guard currentPageIndex > 0 else { return }
    try load(sortBy: sortBy)
  }

  func jumpToLast(sortBy: Sorter.By) throws {
    guard totalCount > 0 else { return }

    isLoading = true
    defer { isLoading = false }

    currentPageIndex = max(0, totalPageCount - 1)
    loadedPages.removeAll()
    try loadPageIfNeeded(at: currentPageIndex, sortBy: sortBy)
    try preloadFromCurrent(sortBy: sortBy, preferred: .backward)
    trimWindow(keeping: currentPageIndex, preferred: .backward)
  }

  static func sortDescriptor(for mode: Sorter.By) -> SortDescriptor<HistoryItem> {
    switch mode {
    case .lastCopiedAt:
      return SortDescriptor(\.lastCopiedAt, order: .reverse)
    case .firstCopiedAt:
      return SortDescriptor(\.firstCopiedAt, order: .reverse)
    case .numberOfCopies:
      return SortDescriptor(\.numberOfCopies, order: .reverse)
    }
  }

  private var totalPageCount: Int {
    guard totalCount > 0 else { return 0 }
    return (totalCount + pageSize - 1) / pageSize
  }

  private func loadPageIfNeeded(at index: Int, sortBy: Sorter.By) throws {
    guard index >= 0, index < totalPageCount else {
      return
    }

    if loadedPages[index] != nil {
      return
    }

    loadedPages[index] = try fetchPage(at: index, sortBy: sortBy)
  }

  private func preloadFromCurrent(sortBy: Sorter.By, preferred: Direction) throws {
    guard totalPageCount > 0 else {
      return
    }

    var step = 1
    while loadedPages.count < maxLoadedPages {
      var loadedAny = false

      if preferred == .forward {
        let nextIndex = currentPageIndex + step
        if nextIndex < totalPageCount {
          try loadPageIfNeeded(at: nextIndex, sortBy: sortBy)
          loadedAny = true
        }

        if loadedPages.count < maxLoadedPages {
          let previousIndex = currentPageIndex - step
          if previousIndex >= 0 {
            try loadPageIfNeeded(at: previousIndex, sortBy: sortBy)
            loadedAny = true
          }
        }
      } else {
        let previousIndex = currentPageIndex - step
        if previousIndex >= 0 {
          try loadPageIfNeeded(at: previousIndex, sortBy: sortBy)
          loadedAny = true
        }

        if loadedPages.count < maxLoadedPages {
          let nextIndex = currentPageIndex + step
          if nextIndex < totalPageCount {
            try loadPageIfNeeded(at: nextIndex, sortBy: sortBy)
            loadedAny = true
          }
        }
      }

      if !loadedAny {
        break
      }
      step += 1
    }
  }

  private func trimWindow(keeping current: Int, preferred: Direction) {
    while loadedPages.count > maxLoadedPages {
      let sorted = loadedPageIndices
      let candidate: Int?

      if preferred == .forward {
        candidate = sorted.first(where: { $0 != current })
      } else {
        candidate = sorted.last(where: { $0 != current })
      }

      guard let indexToRemove = candidate else {
        break
      }

      loadedPages.removeValue(forKey: indexToRemove)
    }
  }

  private func fetchPage(at pageIndex: Int, sortBy: Sorter.By) throws -> [HistoryItemDecorator] {
    var descriptor = FetchDescriptor<HistoryItem>(
      predicate: #Predicate { $0.pin == nil },
      sortBy: [Self.sortDescriptor(for: sortBy)]
    )
    descriptor.fetchLimit = pageSize
    descriptor.fetchOffset = pageIndex * pageSize

    let results = try Storage.shared.context.fetch(descriptor)
    return results.map { HistoryItemDecorator($0) }
  }
}

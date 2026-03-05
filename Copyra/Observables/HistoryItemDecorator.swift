import AppKit.NSWorkspace
import Defaults
import Foundation
import Observation
import Sauce

@Observable
class HistoryItemDecorator: Identifiable, Hashable, HasVisibility {
  static func == (lhs: HistoryItemDecorator, rhs: HistoryItemDecorator) -> Bool {
    return lhs.id == rhs.id
  }

  static var previewImageSize: NSSize { NSScreen.forPopup?.visibleFrame.size ?? NSSize(width: 2048, height: 1536) }
  static var thumbnailImageSize: NSSize { NSSize(width: 340, height: Defaults[.imageMaxHeight]) }
  private static let thumbnailCache = NSCache<NSString, NSImage>()

  let id = UUID()

  var title: String = ""
  var attributedTitle: AttributedString?

  var isVisible: Bool = true
  var selectionIndex: Int = -1
  var isSelected: Bool {
    return selectionIndex != -1
  }
  var shortcuts: [KeyShortcut] = []

  var application: String? {
    if item.universalClipboard {
      return "iCloud"
    }

    guard let bundle = item.application,
      let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle)
    else {
      return nil
    }

    return url.deletingPathExtension().lastPathComponent
  }

  var hasImage: Bool { item.hasImageContent }

  var previewImageGenerationTask: Task<(), Never>?
  var thumbnailImageGenerationTask: Task<(), Never>?
  var previewImage: NSImage?
  var thumbnailImage: NSImage?
  var applicationImage: ApplicationImage

  // 10k characters seems to be more than enough on large displays
  var text: String { item.previewableText.shortened(to: 10_000) }

  var isPinned: Bool { item.pin != nil }
  var isUnpinned: Bool { item.pin == nil }

  func hash(into hasher: inout Hasher) {
    // We need to hash title and attributedTitle, so SwiftUI knows it needs to update the view if they chage
    hasher.combine(id)
    hasher.combine(title)
    hasher.combine(attributedTitle)
  }

  private(set) var item: HistoryItem

  init(_ item: HistoryItem, shortcuts: [KeyShortcut] = []) {
    self.item = item
    self.shortcuts = shortcuts
    self.title = item.title
    self.applicationImage = ApplicationImageCache.shared.getImage(item: item)

    synchronizeItemPin()
    synchronizeItemTitle()
  }

  @MainActor
  func ensureThumbnailImage() {
    guard item.hasImageContent else {
      return
    }

    updateThumbnailCacheLimits()

    if let cached = Self.thumbnailCache.object(forKey: thumbnailCacheKey) {
      thumbnailImage = cached
      return
    }

    guard thumbnailImage == nil else {
      return
    }
    guard thumbnailImageGenerationTask == nil else {
      return
    }
    let inlineData = item.embeddedImageData
    let remoteURL = item.universalClipboardImageURL
    thumbnailImageGenerationTask = Task { [weak self] in
      await self?.generateThumbnailImage(inlineData: inlineData, remoteURL: remoteURL)
    }
  }

  @MainActor
  func ensurePreviewImage() {
    guard item.hasImageContent else {
      return
    }
    guard previewImage == nil else {
      return
    }
    guard previewImageGenerationTask == nil else {
      return
    }
    let inlineData = item.embeddedImageData
    let remoteURL = item.universalClipboardImageURL
    previewImageGenerationTask = Task { [weak self] in
      await self?.generatePreviewImage(inlineData: inlineData, remoteURL: remoteURL)
    }
  }

  @MainActor
  func asyncGetPreviewImage() async -> NSImage? {
    if let image = previewImage {
      return image
    }
    ensurePreviewImage()
    _ = await previewImageGenerationTask?.result
    return previewImage
  }

  @MainActor
  func cleanupImages() {
    thumbnailImageGenerationTask?.cancel()
    previewImageGenerationTask?.cancel()
    thumbnailImageGenerationTask = nil
    previewImageGenerationTask = nil
    thumbnailImage?.recache()
    previewImage?.recache()
    thumbnailImage = nil
    previewImage = nil
  }

  private func generateThumbnailImage(inlineData: Data?, remoteURL: URL?) async {
    let targetSize = HistoryItemDecorator.thumbnailImageSize
    guard let resized = await Self.buildResizedImage(inlineData: inlineData, remoteURL: remoteURL, targetSize: targetSize),
          !Task.isCancelled else {
      await MainActor.run {
        self.thumbnailImageGenerationTask = nil
      }
      return
    }

    await MainActor.run {
      self.thumbnailImage = resized
      let cost = Int(resized.size.width * resized.size.height * 4)
      Self.thumbnailCache.setObject(resized, forKey: self.thumbnailCacheKey, cost: cost)
      self.thumbnailImageGenerationTask = nil
    }
  }

  private func generatePreviewImage(inlineData: Data?, remoteURL: URL?) async {
    let targetSize = HistoryItemDecorator.previewImageSize
    guard let resized = await Self.buildResizedImage(inlineData: inlineData, remoteURL: remoteURL, targetSize: targetSize),
          !Task.isCancelled else {
      await MainActor.run {
        self.previewImageGenerationTask = nil
      }
      return
    }

    await MainActor.run {
      self.previewImage = resized
      self.previewImageGenerationTask = nil
    }
  }

  @MainActor
  func sizeImages() {
    guard item.hasImageContent else {
      return
    }

    updateThumbnailCacheLimits()

    if previewImage == nil || thumbnailImage == nil {
      guard let image = item.image else {
        ensurePreviewImage()
        ensureThumbnailImage()
        return
      }

      if previewImage == nil {
        previewImage = image.resized(to: HistoryItemDecorator.previewImageSize)
      }

      if thumbnailImage == nil {
        let resizedThumbnail = image.resized(to: HistoryItemDecorator.thumbnailImageSize)
        thumbnailImage = resizedThumbnail
        let cost = Int(resizedThumbnail.size.width * resizedThumbnail.size.height * 4)
        Self.thumbnailCache.setObject(resizedThumbnail, forKey: thumbnailCacheKey, cost: cost)
      }
      return
    }

    ensurePreviewImage()
    ensureThumbnailImage()
  }

  @MainActor
  private func updateThumbnailCacheLimits() {
    Self.thumbnailCache.countLimit = Defaults[.thumbnailCacheCountLimit]
    Self.thumbnailCache.totalCostLimit = Defaults[.thumbnailCacheTotalCostLimit]
  }

  private static func buildResizedImage(
    inlineData: Data?,
    remoteURL: URL?,
    targetSize: NSSize
  ) async -> NSImage? {
    await withCheckedContinuation { continuation in
      DispatchQueue.global(qos: .userInitiated).async {
        let data = inlineData ?? (remoteURL.flatMap { try? Data(contentsOf: $0) })
        guard let data,
              let image = NSImage(data: data) else {
          continuation.resume(returning: nil)
          return
        }

        continuation.resume(returning: image.resized(to: targetSize))
      }
    }
  }

  func highlight(_ query: String, _ ranges: [Range<String.Index>]) {
    guard !query.isEmpty, !title.isEmpty else {
      attributedTitle = nil
      return
    }

    var attributedString = AttributedString(title.shortened(to: 500))
    for range in ranges {
      if let lowerBound = AttributedString.Index(range.lowerBound, within: attributedString),
         let upperBound = AttributedString.Index(range.upperBound, within: attributedString) {
        switch Defaults[.highlightMatch] {
        case .bold:
          attributedString[lowerBound..<upperBound].font = .bold(.body)()
        case .italic:
          attributedString[lowerBound..<upperBound].font = .italic(.body)()
        case .underline:
          attributedString[lowerBound..<upperBound].underlineStyle = .single
        default:
          attributedString[lowerBound..<upperBound].backgroundColor = .findHighlightColor
          attributedString[lowerBound..<upperBound].foregroundColor = .black
        }
      }
    }

    attributedTitle = attributedString
  }

  @MainActor
  func togglePin() {
    if item.pin != nil {
      item.pin = nil
    } else {
      let pin = HistoryItem.randomAvailablePin
      item.pin = pin
    }
  }

  private func synchronizeItemPin() {
    _ = withObservationTracking {
      item.pin
    } onChange: { [weak self] in
      guard let self else { return }
      if let pin = self.item.pin {
        self.shortcuts = KeyShortcut.create(character: pin)
      }
      self.synchronizeItemPin()
    }
  }

  private func synchronizeItemTitle() {
    _ = withObservationTracking {
      item.title
    } onChange: { [weak self] in
      guard let self else { return }
      self.title = self.item.title
      self.synchronizeItemTitle()
    }
  }

  private var thumbnailCacheKey: NSString {
    let key = "\(item.firstCopiedAt.timeIntervalSince1970)-\(item.lastCopiedAt.timeIntervalSince1970)-\(item.title)"
    return NSString(string: key)
  }
}

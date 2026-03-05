import XCTest
import Defaults
@testable import Copyra

class SearchTests: XCTestCase {
  let savedSearchMode = Defaults[.searchMode]
  var items: [Search.Searchable]!

  override func tearDown() {
    super.tearDown()
    Defaults[.searchMode] = savedSearchMode
  }

  @MainActor
  func testSimpleSearch() { // swiftlint:disable:this function_body_length
    Defaults[.searchMode] = Search.Mode.exact
    items = [
      HistoryItemDecorator(historyItemWithTitle("foo bar baz")),
      HistoryItemDecorator(historyItemWithTitle("foo bar zaz")),
      HistoryItemDecorator(historyItemWithTitle("xxx yyy zzz"))
    ]

    XCTAssertEqual(search(""), [
      Search.SearchResult(score: nil, object: items[0], ranges: []),
      Search.SearchResult(score: nil, object: items[1], ranges: []),
      Search.SearchResult(score: nil, object: items[2], ranges: [])
    ])
    XCTAssertEqual(search("z"), [
      Search.SearchResult(
        score: nil,
        object: items[0],
        ranges: [range(from: 10, to: 10, in: items[0])]
      ),
      Search.SearchResult(
        score: nil,
        object: items[1],
        ranges: [range(from: 8, to: 8, in: items[1])]
      ),
      Search.SearchResult(
        score: nil,
        object: items[2],
        ranges: [range(from: 8, to: 8, in: items[2])]
      )
    ])
    XCTAssertEqual(search("foo"), [
      Search.SearchResult(
        score: nil,
        object: items[0],
        ranges: [range(from: 0, to: 2, in: items[0])]
      ),
      Search.SearchResult(
        score: nil,
        object: items[1],
        ranges: [range(from: 0, to: 2, in: items[1])]
      )
    ])
    XCTAssertEqual(search("za"), [
      Search.SearchResult(
        score: nil,
        object: items[1],
        ranges: [range(from: 8, to: 9, in: items[1])]
      )
    ])
    XCTAssertEqual(search("yyy"), [
      Search.SearchResult(
        score: nil,
        object: items[2],
        ranges: [range(from: 4, to: 6, in: items[2])]
      )
    ])
    XCTAssertEqual(search("fbb"), [])
    XCTAssertEqual(search("m"), [])
  }

  @MainActor
  func testFuzzySearch() { // swiftlint:disable:this function_body_length
    Defaults[.searchMode] = Search.Mode.fuzzy
    items = [
      HistoryItemDecorator(historyItemWithTitle("foo bar baz")),
      HistoryItemDecorator(historyItemWithTitle("foo bar zaz")),
      HistoryItemDecorator(historyItemWithTitle("xxx yyy zzz"))
    ]

    XCTAssertEqual(search(""), [
      Search.SearchResult(score: nil, object: items[0], ranges: []),
      Search.SearchResult(score: nil, object: items[1], ranges: []),
      Search.SearchResult(score: nil, object: items[2], ranges: [])
    ])
    XCTAssertEqual(search("z"), [
      Search.SearchResult(
        score: 0.08,
        object: items[1],
        ranges: [range(from: 8, to: 8, in: items[1]), range(from: 10, to: 10, in: items[1])]
      ),
      Search.SearchResult(
        score: 0.08,
        object: items[2],
        ranges: [range(from: 8, to: 10, in: items[2])]
      ),
      Search.SearchResult(
        score: 0.1,
        object: items[0],
        ranges: [range(from: 10, to: 10, in: items[0])]
      )
    ])
    XCTAssertEqual(search("foo"), [
      Search.SearchResult(
        score: 0.0,
        object: items[0],
        ranges: [range(from: 0, to: 2, in: items[0])]
      ),
      Search.SearchResult(
        score: 0.0,
        object: items[1],
        ranges: [range(from: 0, to: 2, in: items[1])]
      )
    ])
    XCTAssertEqual(search("za"), [
      Search.SearchResult(
        score: 0.08,
        object: items[1],
        ranges: [range(from: 5, to: 5, in: items[1]), range(from: 8, to: 9, in: items[1])]
      ),
      Search.SearchResult(
        score: 0.54,
        object: items[0],
        ranges: [range(from: 5, to: 5, in: items[0]), range(from: 9, to: 10, in: items[0])]
      ),
      Search.SearchResult(
        score: 0.58,
        object: items[2],
        ranges: [range(from: 8, to: 10, in: items[2])]
      )
    ])
    XCTAssertEqual(search("yyy"), [
      Search.SearchResult(
        score: 0.04,
        object: items[2],
        ranges: [range(from: 4, to: 6, in: items[2])]
      )
    ])
    XCTAssertEqual(search("fbb"), [
      Search.SearchResult(
        score: 0.6666666666666666,
        object: items[0],
        ranges: [
          range(from: 0, to: 0, in: items[0]),
          range(from: 4, to: 4, in: items[0]),
          range(from: 8, to: 8, in: items[0])
        ]
      ),
      Search.SearchResult(
        score: 0.6666666666666666,
        object: items[1],
        ranges: [range(from: 0, to: 0, in: items[1]), range(from: 4, to: 4, in: items[1])])
    ])
    XCTAssertEqual(search("m"), [])
  }

  @MainActor
  func testRegexpSearch() { // swiftlint:disable:this function_body_length
    Defaults[.searchMode] = Search.Mode.regexp
    items = [
      HistoryItemDecorator(historyItemWithTitle("foo bar baz")),
      HistoryItemDecorator(historyItemWithTitle("foo bar zaz")),
      HistoryItemDecorator(historyItemWithTitle("xxx yyy zzz"))
    ]

    XCTAssertEqual(search(""), [
      Search.SearchResult(score: nil, object: items[0], ranges: []),
      Search.SearchResult(score: nil, object: items[1], ranges: []),
      Search.SearchResult(score: nil, object: items[2], ranges: [])
    ])
    XCTAssertEqual(search("z+"), [
      Search.SearchResult(
        score: nil,
        object: items[0],
        ranges: [range(from: 10, to: 10, in: items[0])]
      ),
      Search.SearchResult(
        score: nil,
        object: items[1],
        ranges: [range(from: 8, to: 8, in: items[1])]
      ),
      Search.SearchResult(
        score: nil,
        object: items[2],
        ranges: [range(from: 8, to: 10, in: items[2])]
      )
    ])
    XCTAssertEqual(search("z*"), [
      Search.SearchResult(
        score: nil,
        object: items[0],
        ranges: [range(from: 0, to: -1, in: items[0])]
      ),
      Search.SearchResult(
        score: nil,
        object: items[1],
        ranges: [range(from: 0, to: -1, in: items[1])]
      ),
      Search.SearchResult(
        score: nil,
        object: items[2],
        ranges: [range(from: 0, to: -1, in: items[2])]
      )
    ])
    XCTAssertEqual(search("^foo"), [
      Search.SearchResult(
        score: nil,
        object: items[0], ranges: [range(from: 0, to: 2, in: items[0])]
      ),
      Search.SearchResult(
        score: nil,
        object: items[1], ranges: [range(from: 0, to: 2, in: items[1])]
      )
    ])
    XCTAssertEqual(search(" za"), [
      Search.SearchResult(
        score: nil,
        object: items[1],
        ranges: [range(from: 7, to: 9, in: items[1])]
      )
    ])
    XCTAssertEqual(search("[y]+"), [
      Search.SearchResult(
        score: nil,
        object: items[2],
        ranges: [range(from: 4, to: 6, in: items[2])]
      )
    ])
    XCTAssertEqual(search("fbb"), [])
    XCTAssertEqual(search("m"), [])
  }

  func testEffectiveModeForLargeHistory() {
    let sut = Search()
    let threshold = Defaults[.largeHistoryThreshold]

    XCTAssertEqual(
      sut.effectiveMode(for: threshold + 1, preferred: .fuzzy),
      .exact
    )
    XCTAssertEqual(
      sut.effectiveMode(for: threshold + 1, preferred: .mixed),
      .exact
    )
    XCTAssertEqual(
      sut.effectiveMode(for: threshold + 1, preferred: .regexp),
      .exact
    )
    XCTAssertEqual(
      sut.effectiveMode(for: threshold, preferred: .fuzzy),
      .fuzzy
    )
  }

  func testIntentHistoryIndexValidation() throws {
    XCTAssertEqual(try IntentHistoryIndex.resolve(number: 1, itemCount: 3), 0)
    XCTAssertEqual(try IntentHistoryIndex.resolve(number: 3, itemCount: 3), 2)
    XCTAssertThrowsError(try IntentHistoryIndex.resolve(number: 0, itemCount: 3))
    XCTAssertThrowsError(try IntentHistoryIndex.resolve(number: -1, itemCount: 3))
    XCTAssertThrowsError(try IntentHistoryIndex.resolve(number: 4, itemCount: 3))
  }

  func testIntentImageStoreCreatesUniqueFilesAndCleansUpStale() throws {
    let data = Data("clipboard-image".utf8)
    let file1 = try IntentImageStore.writeImage(data)
    let file2 = try IntentImageStore.writeImage(data)

    XCTAssertNotEqual(file1, file2)
    XCTAssertTrue(file1.path.contains(NSTemporaryDirectory()))
    XCTAssertTrue(file2.path.contains(NSTemporaryDirectory()))
    XCTAssertTrue(FileManager.default.fileExists(atPath: file1.path))
    XCTAssertTrue(FileManager.default.fileExists(atPath: file2.path))

    let oldDate = Date().addingTimeInterval(-48 * 60 * 60)
    try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: file1.path)
    IntentImageStore.cleanupStaleFiles(now: Date())

    XCTAssertFalse(FileManager.default.fileExists(atPath: file1.path))
    XCTAssertTrue(FileManager.default.fileExists(atPath: file2.path))

    try? FileManager.default.removeItem(at: file2)
  }

  func testThrottlerRunsImmediatelyOnFirstInvocation() {
    let queue = DispatchQueue(label: "ThrottlerTestsQueue")
    let throttler = Throttler(minimumDelay: 0.15, queue: queue)
    let expectation = expectation(description: "throttled")
    let startedAt = Date()

    throttler.throttle {
      expectation.fulfill()
    }

    waitForExpectations(timeout: 1)
    XCTAssertLessThan(Date().timeIntervalSince(startedAt), 0.12)
  }

  @MainActor
  func testLargeHistorySearchFindsOldestItem() async throws {
    let history = History.shared
    let savedSize = Defaults[.size]
    let savedSortBy = Defaults[.sortBy]
    let savedSearchMode = Defaults[.searchMode]
    let savedThreshold = Defaults[.largeHistoryThreshold]
    let savedPageSize = Defaults[.largeHistoryPageSize]

    defer {
      history.clearAll()
      history.searchQuery = ""
      Defaults[.size] = savedSize
      Defaults[.sortBy] = savedSortBy
      Defaults[.searchMode] = savedSearchMode
      Defaults[.largeHistoryThreshold] = savedThreshold
      Defaults[.largeHistoryPageSize] = savedPageSize
    }

    history.clearAll()
    Defaults[.size] = 1_000
    Defaults[.sortBy] = .lastCopiedAt
    Defaults[.searchMode] = .exact
    Defaults[.largeHistoryThreshold] = 50
    Defaults[.largeHistoryPageSize] = 100

    for index in 0..<300 {
      let item = HistoryItem()
      Storage.shared.context.insert(item)
      item.contents = [
        HistoryItemContent(
          type: NSPasteboard.PasteboardType.string.rawValue,
          value: "large-item-\(index)".data(using: .utf8)
        )
      ]
      item.firstCopiedAt = Date(timeIntervalSince1970: TimeInterval(index))
      item.lastCopiedAt = item.firstCopiedAt
      item.title = item.generateTitle()
    }
    Storage.shared.context.processPendingChanges()
    try Storage.shared.context.save()

    try await history.load()
    XCTAssertTrue(history.largeHistoryMode)

    history.searchQuery = "large-item-0"
    await waitUntil(timeoutSeconds: 5) {
      history.items.count == 1 && history.items.first?.title == "large-item-0"
    }

    XCTAssertEqual(history.items.count, 1)
    XCTAssertEqual(history.items.first?.title, "large-item-0")
  }

  private func search(_ string: String) -> [Search.SearchResult] {
    return Search().search(string: string, within: items)
  }

  // swiftlint:disable:next identifier_name
  private func range(from: Int, to: Int, in item: HistoryItemDecorator) -> Range<String.Index> {
    let startIndex = item.title.startIndex
    let lowerBound = item.title.index(startIndex, offsetBy: from)
    let upperBound = item.title.index(startIndex, offsetBy: to + 1)

    return lowerBound..<upperBound
  }

  @MainActor
  private func historyItemWithTitle(_ value: String?) -> HistoryItem {
    let contents = [
      HistoryItemContent(
        type: NSPasteboard.PasteboardType.string.rawValue,
        value: value?.data(using: .utf8)
      )
    ]
    let item = HistoryItem()
    Storage.shared.context.insert(item)
    item.contents = contents
    item.title = item.generateTitle()

    return item
  }

  private func waitUntil(timeoutSeconds: Double, condition: () -> Bool) async {
    let timeout = Date().addingTimeInterval(timeoutSeconds)
    while Date() < timeout {
      if condition() {
        return
      }
      try? await Task.sleep(for: .milliseconds(20))
    }
  }
}

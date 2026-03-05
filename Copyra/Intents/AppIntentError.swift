import Foundation

enum AppIntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
  case notFound

  var localizedStringResource: LocalizedStringResource {
    switch self {
      case .notFound: return "Clipboard item not found"
    }
  }
}

enum IntentHistoryIndex {
  static func resolve(number: Int, itemCount: Int, positionOffset: Int = 1) throws -> Int {
    let index = number - positionOffset
    guard index >= 0, index < itemCount else {
      throw AppIntentError.notFound
    }
    return index
  }
}

enum IntentImageStore {
  private static let prefix = "copyra-intent-image-"
  private static let directoryName = "CopyraIntentImages"
  private static let maxAge: TimeInterval = 24 * 60 * 60

  static func writeImage(_ data: Data) throws -> URL {
    cleanupStaleFiles()

    let directory = directoryURL
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let filename = "\(prefix)\(UUID().uuidString).png"
    let fileURL = directory.appending(path: filename)
    try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    return fileURL
  }

  static func cleanupStaleFiles(now: Date = .now) {
    let directory = directoryURL
    guard let enumerator = FileManager.default.enumerator(
      at: directory,
      includingPropertiesForKeys: [.contentModificationDateKey],
      options: [.skipsHiddenFiles]
    ) else {
      return
    }

    for case let fileURL as URL in enumerator {
      guard fileURL.lastPathComponent.hasPrefix(prefix) else { continue }
      let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey])
      let modifiedAt = values?.contentModificationDate ?? .distantPast
      guard now.timeIntervalSince(modifiedAt) > maxAge else { continue }
      try? FileManager.default.removeItem(at: fileURL)
    }
  }

  private static var directoryURL: URL {
    FileManager.default.temporaryDirectory.appending(path: directoryName, directoryHint: .isDirectory)
  }
}

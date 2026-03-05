import SwiftUI
import Defaults
import Settings

struct StorageSettingsPane: View {
  @Observable
  class ViewModel {
    var saveFiles = false {
      didSet {
        Defaults.withoutPropagation {
          if saveFiles {
            Defaults[.enabledPasteboardTypes].formUnion(StorageType.files.types)
          } else {
            Defaults[.enabledPasteboardTypes].subtract(StorageType.files.types)
          }
        }
      }
    }

    var saveImages = false {
      didSet {
        Defaults.withoutPropagation {
          if saveImages {
            Defaults[.enabledPasteboardTypes].formUnion(StorageType.images.types)
          } else {
            Defaults[.enabledPasteboardTypes].subtract(StorageType.images.types)
          }
        }
      }
    }

    var saveText = false {
      didSet {
        Defaults.withoutPropagation {
          if saveText {
            Defaults[.enabledPasteboardTypes].formUnion(StorageType.text.types)
          } else {
            Defaults[.enabledPasteboardTypes].subtract(StorageType.text.types)
          }
        }
      }
    }

    private var observer: Defaults.Observation?

    init() {
      observer = Defaults.observe(.enabledPasteboardTypes) { change in
        self.saveFiles = change.newValue.isSuperset(of: StorageType.files.types)
        self.saveImages = change.newValue.isSuperset(of: StorageType.images.types)
        self.saveText = change.newValue.isSuperset(of: StorageType.text.types)
      }
    }

    deinit {
      observer?.invalidate()
    }
  }

  @Default(.size) private var size
  @Default(.sortBy) private var sortBy
  @Default(.largeHistoryThreshold) private var largeHistoryThreshold
  @Default(.largeHistoryPageSize) private var largeHistoryPageSize
  @Default(.largeHistoryMaxLoadedPages) private var largeHistoryMaxLoadedPages
  @Default(.thumbnailCacheCountLimit) private var thumbnailCacheCountLimit
  @Default(.thumbnailCacheTotalCostLimit) private var thumbnailCacheTotalCostLimit

  @State private var viewModel = ViewModel()
  @State private var storageSize = Storage.shared.size
  @State private var finiteHistorySize = 200_000

  private let sizeFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.minimum = 1
    formatter.maximum = 1_000_000
    return formatter
  }()

  private let thresholdFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.minimum = 1_000
    formatter.maximum = 200_000
    return formatter
  }()

  private let pageSizeFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.minimum = 80
    formatter.maximum = 500
    return formatter
  }()

  private let maxPagesFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.minimum = 2
    formatter.maximum = 5
    return formatter
  }()

  private let cacheCountFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.minimum = 32
    formatter.maximum = 256
    return formatter
  }()

  private let cacheMegabytesFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.minimum = 8
    formatter.maximum = 128
    return formatter
  }()

  var body: some View {
    Settings.Container(contentWidth: 500) {
      Settings.Section(
        bottomDivider: true,
        label: { Text("Save", tableName: "StorageSettings") }
      ) {
        Toggle(
          isOn: $viewModel.saveFiles,
          label: { Text("Files", tableName: "StorageSettings") }
        )
        Toggle(
          isOn: $viewModel.saveImages,
          label: { Text("Images", tableName: "StorageSettings") }
        )
        Toggle(
          isOn: $viewModel.saveText,
          label: { Text("Text", tableName: "StorageSettings") }
        )
        Text("SaveDescription", tableName: "StorageSettings")
          .controlSize(.small)
          .foregroundStyle(.gray)
      }

      Settings.Section(label: { Text("Size", tableName: "StorageSettings") }) {
        Toggle(isOn: unlimitedHistoryBinding) {
          Text("Unlimited history")
        }

        HStack {
          TextField("", value: $size, formatter: sizeFormatter)
            .frame(width: 80)
            .disabled(size <= 0)
            .help(Text("SizeTooltip", tableName: "StorageSettings"))
          Stepper("", value: $size, in: 1...1_000_000)
            .labelsHidden()
            .disabled(size <= 0)
          Text(storageSize)
            .controlSize(.small)
            .foregroundStyle(.gray)
            .help(Text("CurrentSizeTooltip", tableName: "StorageSettings"))
            .onAppear {
              storageSize = Storage.shared.size
            }
        }
      }

      Settings.Section(
        bottomDivider: true,
        label: { Text("Performance (Large History)") }
      ) {
        HStack {
          Text("Large-history threshold")
          Spacer()
          TextField("", value: $largeHistoryThreshold, formatter: thresholdFormatter)
            .frame(width: 90)
          Stepper("", value: $largeHistoryThreshold, in: 1_000...200_000)
            .labelsHidden()
        }

        HStack {
          Text("Page size")
          Spacer()
          TextField("", value: $largeHistoryPageSize, formatter: pageSizeFormatter)
            .frame(width: 90)
          Stepper("", value: $largeHistoryPageSize, in: 80...500)
            .labelsHidden()
        }

        HStack {
          Text("Max loaded pages")
          Spacer()
          TextField("", value: $largeHistoryMaxLoadedPages, formatter: maxPagesFormatter)
            .frame(width: 90)
          Stepper("", value: $largeHistoryMaxLoadedPages, in: 2...5)
            .labelsHidden()
        }

        HStack {
          Text("Thumbnail cache items")
          Spacer()
          TextField("", value: $thumbnailCacheCountLimit, formatter: cacheCountFormatter)
            .frame(width: 90)
          Stepper("", value: $thumbnailCacheCountLimit, in: 32...256)
            .labelsHidden()
        }

        HStack {
          Text("Thumbnail cache size (MB)")
          Spacer()
          TextField("", value: thumbnailCacheMegabytesBinding, formatter: cacheMegabytesFormatter)
            .frame(width: 90)
          Stepper("", value: thumbnailCacheMegabytesBinding, in: 8...128)
            .labelsHidden()
        }

        Button("Reset recommended") {
          largeHistoryThreshold = 3_000
          largeHistoryPageSize = 200
          largeHistoryMaxLoadedPages = 3
          thumbnailCacheCountLimit = 96
          thumbnailCacheTotalCostLimit = 24 * 1024 * 1024
        }
        .buttonStyle(.borderless)

        Text("Changes apply immediately.")
          .controlSize(.small)
          .foregroundStyle(.gray)
      }

      Settings.Section(label: { Text("SortBy", tableName: "StorageSettings") }) {
        Picker("", selection: $sortBy) {
          ForEach(Sorter.By.allCases) { mode in
            Text(mode.description)
          }
        }
        .labelsHidden()
        .frame(width: 160, alignment: .leading)
        .help(Text("SortByTooltip", tableName: "StorageSettings"))
      }
    }
    .onAppear {
      if size > 0 {
        finiteHistorySize = size
      }
      clampPerformanceValues()
    }
    .onChange(of: size) {
      if size > 0 {
        finiteHistorySize = size
      }
    }
    .onChange(of: largeHistoryThreshold) { _ in
      clampPerformanceValues()
    }
    .onChange(of: largeHistoryPageSize) { _ in
      clampPerformanceValues()
    }
    .onChange(of: largeHistoryMaxLoadedPages) { _ in
      clampPerformanceValues()
    }
    .onChange(of: thumbnailCacheCountLimit) { _ in
      clampPerformanceValues()
    }
    .onChange(of: thumbnailCacheTotalCostLimit) { _ in
      clampPerformanceValues()
    }
  }

  private var unlimitedHistoryBinding: Binding<Bool> {
    Binding(
      get: { size <= 0 },
      set: { enabled in
        if enabled {
          if size > 0 {
            finiteHistorySize = size
          }
          size = 0
        } else if size <= 0 {
          size = max(1, finiteHistorySize)
        }
      }
    )
  }

  private var thumbnailCacheMegabytesBinding: Binding<Int> {
    Binding(
      get: { max(8, thumbnailCacheTotalCostLimit / (1024 * 1024)) },
      set: { megabytes in
        let clamped = min(max(8, megabytes), 128)
        thumbnailCacheTotalCostLimit = clamped * 1024 * 1024
      }
    )
  }

  private func clampPerformanceValues() {
    largeHistoryThreshold = min(max(1_000, largeHistoryThreshold), 200_000)
    largeHistoryPageSize = min(max(80, largeHistoryPageSize), 500)
    largeHistoryMaxLoadedPages = min(max(2, largeHistoryMaxLoadedPages), 5)
    thumbnailCacheCountLimit = min(max(32, thumbnailCacheCountLimit), 256)
    thumbnailCacheTotalCostLimit = min(max(8 * 1024 * 1024, thumbnailCacheTotalCostLimit), 128 * 1024 * 1024)
  }
}

#Preview {
  StorageSettingsPane()
    .environment(\.locale, .init(identifier: "en"))
}

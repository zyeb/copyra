import Defaults
import SwiftUI

struct HistoryListView: View {
  @Binding var searchQuery: String
  @FocusState.Binding var searchFocused: Bool

  @Environment(AppState.self) private var appState
  @Environment(ModifierFlags.self) private var modifierFlags
  @Environment(\.scenePhase) private var scenePhase

  @Default(.pinTo) private var pinTo
  @Default(.previewDelay) private var previewDelay
  @Default(.showFooter) private var showFooter

  private var pinnedItems: [HistoryItemDecorator] {
    appState.history.pinnedItems.filter(\.isVisible)
  }
  private var unpinnedItems: [HistoryItemDecorator] {
    if appState.history.shouldUseVirtualizedHistoryList {
      return appState.history.unpinnedItems
    }
    return appState.history.unpinnedItems.filter(\.isVisible)
  }
  private var showPinsSeparator: Bool {
    pinsVisible && !unpinnedItems.isEmpty
  }

  private var pinsVisible: Bool {
    return !pinnedItems.isEmpty
  }

  private var pasteStackVisible: Bool {
    if let stack = appState.history.pasteStack,
       !stack.items.isEmpty {
      return true
    }
    return false
  }

  private var topPadding: CGFloat {
    return Popup.verticalSeparatorPadding
  }

  private var bottomPadding: CGFloat {
    return showFooter
      ? Popup.verticalSeparatorPadding
      : (Popup.verticalSeparatorPadding - 1)
  }

  private func topSeparator() -> some View {
    ThemedDivider()
      .padding(.horizontal, Popup.horizontalSeparatorPadding)
      .padding(.top, Popup.verticalSeparatorPadding)
  }

  @ViewBuilder
  private func bottomSeparator() -> some View {
    ThemedDivider()
      .padding(.horizontal, Popup.horizontalSeparatorPadding)
      .padding(.bottom, Popup.verticalSeparatorPadding)
  }

  @ViewBuilder
  private func separator() -> some View {
    ThemedDivider()
      .padding(.horizontal, Popup.horizontalSeparatorPadding)
      .padding(.vertical, Popup.verticalSeparatorPadding)
  }

  var body: some View {
    let topPinsVisible = pinTo == .top && pinsVisible
    let bottomPinsVisible = pinTo == .bottom && pinsVisible
    let topSeparatorVisible = topPinsVisible || pasteStackVisible
    let bottomSeparatorVisible = bottomPinsVisible
    let scrollTopPadding = topSeparatorVisible ? Popup.verticalSeparatorPadding : topPadding
    let scrollBottomPadding = bottomSeparatorVisible ? Popup.verticalSeparatorPadding : bottomPadding

    VStack(spacing: 0) {
      if let stack = appState.history.pasteStack,
         !stack.items.isEmpty {
        PasteStackView(stack: stack)

        if topPinsVisible {
          separator()
        }
      }

      if topPinsVisible {
        PinsView(items: pinnedItems)
      }

      if topSeparatorVisible {
        topSeparator()
      }
    }
    .padding(.top, topSeparatorVisible ? topPadding : 0)
    .readHeight(appState, into: \.popup.extraTopHeight)

    ScrollView {
      ScrollViewReader { proxy in
        VStack(spacing: 0) {
          if appState.history.shouldUseVirtualizedHistoryList && appState.history.hasMorePagedItemsBefore {
            Button("Load newer items") {
              Task {
                await appState.history.loadPreviousItems()
              }
            }
            .buttonStyle(.plain)
            .font(CopyraTheme.Typography.caption)
            .foregroundStyle(CopyraTheme.Colors.accent)
            .padding(.vertical, 8)
          }

          MultipleSelectionListView(items: unpinnedItems) { previous, item, next, index in
            HistoryItemView(item: item, previous: previous, next: next, index: index)
          }

          if appState.history.shouldUseVirtualizedHistoryList && appState.history.hasMorePagedItemsAfter {
            Button("Load older items") {
              Task {
                await appState.history.loadMoreItems()
              }
            }
            .buttonStyle(.plain)
            .font(CopyraTheme.Typography.caption)
            .foregroundStyle(CopyraTheme.Colors.accent)
            .padding(.vertical, 8)
          }

          if appState.history.shouldUseVirtualizedHistoryList {
            let total = appState.history.pagedUnpinnedTotalCount
            let start = total > 0 ? (appState.history.pagedWindowStartIndex + 1) : 0
            let end = total > 0 ? min(appState.history.pagedWindowEndIndex, total) : 0
            Text("Showing \(start)-\(end) of \(total)")
              .font(CopyraTheme.Typography.caption)
              .foregroundStyle(CopyraTheme.Colors.textMuted)
              .padding(.bottom, 8)
          }
        }
        .padding(.top, scrollTopPadding)
        .padding(.bottom, scrollBottomPadding)
        .task(id: appState.navigator.scrollTarget) {
          guard appState.navigator.scrollTarget != nil else { return }

          try? await Task.sleep(for: .milliseconds(10))
          guard !Task.isCancelled else { return }

          if let selection = appState.navigator.scrollTarget {
            proxy.scrollTo(selection)
            appState.navigator.scrollTarget = nil
          }
        }
        .onChange(of: scenePhase) {
          if scenePhase == .active {
            searchFocused = true
            appState.navigator.isKeyboardNavigating = true
            appState.navigator.select(item: appState.history.unpinnedItems.first ?? appState.history.pinnedItems.first)
            appState.preview.enableAutoOpen()
            appState.preview.resetAutoOpenSuppression()
            appState.preview.startAutoOpen()
          } else {
            modifierFlags.flags = []
            appState.navigator.isKeyboardNavigating = true
            appState.preview.cancelAutoOpen()
          }
        }
        // Calculate the total height inside a scroll view.
        .background {
          GeometryReader { geo in
            Color.clear
              .task(id: appState.popup.needsResize) {
                try? await Task.sleep(for: .milliseconds(10))
                guard !Task.isCancelled else { return }

                if appState.popup.needsResize {
                  appState.popup.resize(height: geo.size.height)
                }
              }
          }
        }
      }
      .contentMargins(.leading, 10, for: .scrollIndicators)
      .contentMargins(.top, scrollTopPadding, for: .scrollIndicators)
      .contentMargins(.bottom, scrollBottomPadding, for: .scrollIndicators)
    }

    VStack(spacing: 0) {
      if bottomSeparatorVisible {
        bottomSeparator()
      }

      if bottomPinsVisible {
        PinsView(items: pinnedItems)
      }
    }
    .padding(.bottom, bottomSeparatorVisible ? bottomPadding : 0)
    .readHeight(appState, into: \.popup.extraBottomHeight)
  }
}

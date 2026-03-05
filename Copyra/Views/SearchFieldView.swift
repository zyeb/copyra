import SwiftUI

struct SearchFieldView: View {
  var placeholder: LocalizedStringKey
  @Binding var query: String

  @Environment(AppState.self) private var appState

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: CopyraTheme.Radius.md, style: .continuous)
        .fill(CopyraTheme.Colors.surfaceElevated)
        .overlay(
          RoundedRectangle(cornerRadius: CopyraTheme.Radius.md, style: .continuous)
            .strokeBorder(CopyraTheme.Colors.borderSubtle, lineWidth: 0.5)
        )
        .frame(height: 23)

      HStack {
        Image(systemName: "magnifyingglass")
          .frame(width: 11, height: 11)
          .padding(.leading, 5)
          .foregroundStyle(CopyraTheme.Colors.textMuted)

        TextField(placeholder, text: $query)
          .disableAutocorrection(true)
          .lineLimit(1)
          .textFieldStyle(.plain)
          .foregroundStyle(CopyraTheme.Colors.textPrimary)
          .onSubmit {
            appState.select()
          }

        if !query.isEmpty {
          Button {
            query = ""
          } label: {
            Image(systemName: "xmark.circle.fill")
              .frame(width: 11, height: 11)
              .padding(.trailing, 5)
          }
          .buttonStyle(.plain)
          .foregroundStyle(CopyraTheme.Colors.textSecondary)
        }
      }
    }
  }
}

#Preview {
  return List {
    SearchFieldView(placeholder: "search_placeholder", query: .constant(""))
    SearchFieldView(placeholder: "search_placeholder", query: .constant("search"))
  }
  .frame(width: 300)
  .environment(\.locale, .init(identifier: "en"))
}

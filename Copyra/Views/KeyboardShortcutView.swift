import SwiftUI

struct KeyboardShortcutView: View {
  var shortcut: KeyShortcut?

  var modifiers: String {
    if var shortcut = shortcut?.description {
      _ = shortcut.popLast()
      return shortcut
    }
    return ""
  }

  var character: String {
    return shortcut?.description.last?.description ?? ""
  }

  var body: some View {
    HStack(spacing: 1) {
      ForEach(Array(modifiers.unicodeScalars), id: \.self) { scalar in
          Text(String(scalar))
      }
      Text(character).frame(width: 12, alignment: .center)
    }
    .font(CopyraTheme.Typography.shortcut)
    .lineLimit(1)
    .foregroundStyle(CopyraTheme.Colors.textMuted)
    .opacity(character.isEmpty ? 0 : 1)
  }
}

#Preview {
  List {
    KeyboardShortcutView(shortcut: KeyShortcut(key: .a, modifierFlags: [.command]))
    KeyboardShortcutView(shortcut: KeyShortcut(key: .w))
    KeyboardShortcutView(shortcut: KeyShortcut(key: .one, modifierFlags: [.command]))
    KeyboardShortcutView(shortcut: KeyShortcut(key: .two, modifierFlags: [.command]))
    KeyboardShortcutView()

    KeyboardShortcutView(shortcut: KeyShortcut(key: .delete, modifierFlags: [.command, .option, .control, .shift]))
    KeyboardShortcutView(shortcut: KeyShortcut(key: .c, modifierFlags: [.command, .option]))
  }
}

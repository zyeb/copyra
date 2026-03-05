import KeyboardShortcuts
import SwiftUI

struct PreviewItemView: View {
  var item: HistoryItemDecorator

  @ViewBuilder
  func previewImage(content: () -> some View) -> some View {
    content()
      .aspectRatio(contentMode: .fit)
      .clipShape(.rect(cornerRadius: 5))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if item.hasImage {
        AsyncView<NSImage?, _, _> {
          return await item.asyncGetPreviewImage()
        } content: { image in
          if let image = image {
            previewImage {
              Image(nsImage: image)
                .resizable()
            }
          } else {
            previewImage {
              ZStack {
                CopyraTheme.Colors.placeholder
                  .frame(
                    idealWidth: HistoryItemDecorator.previewImageSize.width,
                    idealHeight: HistoryItemDecorator.previewImageSize.height
                  )
                Image(systemName: "photo.badge.exclamationmark")
                  .symbolRenderingMode(.multicolor)
                  .frame(alignment: .center)
              }
            }
          }
        } placeholder: {
          previewImage {
            ZStack {
              CopyraTheme.Colors.placeholder
                .frame(
                  idealWidth: HistoryItemDecorator.previewImageSize.width,
                  idealHeight: HistoryItemDecorator.previewImageSize.height
                )
              ProgressView()
                .frame(alignment: .center)
            }
          }
        }
      } else {
        ScrollView {
          Text(item.text)
            .font(CopyraTheme.Typography.body)
            .foregroundStyle(CopyraTheme.Colors.textPrimary)
        }
      }

      Spacer(minLength: 0)

      Spacer(minLength: CopyraTheme.Spacing.md)

      VStack(alignment: .leading, spacing: CopyraTheme.Spacing.xs) {
        if let application = item.application {
          HStack(spacing: 3) {
            Text("Application", tableName: "PreviewItemView")
              .foregroundStyle(CopyraTheme.Colors.textMuted)
            AppImageView(
              appImage: item.applicationImage,
              size: NSSize(width: 11, height: 11)
            )
            Text(application)
              .foregroundStyle(CopyraTheme.Colors.textSecondary)
          }
        }

        HStack(spacing: 3) {
          Text("FirstCopyTime", tableName: "PreviewItemView")
            .foregroundStyle(CopyraTheme.Colors.textMuted)
          Text(item.item.firstCopiedAt, style: .date)
            .foregroundStyle(CopyraTheme.Colors.textSecondary)
          Text(item.item.firstCopiedAt, style: .time)
            .foregroundStyle(CopyraTheme.Colors.textSecondary)
        }

        HStack(spacing: 3) {
          Text("LastCopyTime", tableName: "PreviewItemView")
            .foregroundStyle(CopyraTheme.Colors.textMuted)
          Text(item.item.lastCopiedAt, style: .date)
            .foregroundStyle(CopyraTheme.Colors.textSecondary)
          Text(item.item.lastCopiedAt, style: .time)
            .foregroundStyle(CopyraTheme.Colors.textSecondary)
        }

        HStack(spacing: 3) {
          Text("NumberOfCopies", tableName: "PreviewItemView")
            .foregroundStyle(CopyraTheme.Colors.textMuted)
          Text(String(item.item.numberOfCopies))
            .foregroundStyle(CopyraTheme.Colors.textSecondary)
        }
      }
      .font(CopyraTheme.Typography.metadata)
      .padding(CopyraTheme.Spacing.md)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        RoundedRectangle(cornerRadius: CopyraTheme.Radius.md, style: .continuous)
          .fill(CopyraTheme.Colors.surfaceCard)
          .overlay(
            RoundedRectangle(cornerRadius: CopyraTheme.Radius.md, style: .continuous)
              .strokeBorder(CopyraTheme.Colors.borderSubtle, lineWidth: 0.5)
          )
      )
    }
    .controlSize(.small)
  }
}

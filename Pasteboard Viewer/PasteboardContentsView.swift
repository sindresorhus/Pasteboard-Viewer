import SwiftUI

struct PasteboardContentsView: View {
	@EnvironmentObject private var pasteboardObservable: NSPasteboard.Observable

	let type: Pasteboard.Type_

	var body: some View {
		let data = type.data()
		let sizeString = ByteCountFormatter.string(fromByteCount: Int64(data?.count ?? 0), countStyle: .file)

		func textSubtitle(_ string: String) -> String {
			let lineCount = string.lineCount()
			let suffix = lineCount == 1 ? "line" : "lines"
			return "\(sizeString) — \(lineCount) \(suffix)"
		}

		return Group {
			if
				let data = data,
				let image = NSImage(data: data)
			{
				Image(nsImage: image)
					.resizable()
					.aspectRatio(contentMode: .fit)
					.navigationSubtitle("\(sizeString) — \(image.size.formatted)")
			} else if
				let data = data,
				data.isRtf, // The below initializer is too lenient with non-RTF data.
				let attributedString = NSAttributedString(rtf: data, documentAttributes: nil)
			{
				ScrollableAttributedTextView(
					attributedText: attributedString,
					borderType: .noBorder
				)
					.navigationSubtitle(textSubtitle(attributedString.string))
			} else if let string = type.string() {
				ScrollableTextView(
					text: .constant(string),
					borderType: .noBorder
				)
					.navigationSubtitle(textSubtitle(string))
			} else if
				let data = data,
				let view = QuickLookPreview(data: data, contentType: type.nsType.toUTType ?? .plainText)
			{
				view
					.background(Color(.textBackgroundColor))
					.navigationSubtitle(sizeString)
			} else if let data = data {
				ScrollableTextView(
					text: .constant(String(describing: data)),
					borderType: .noBorder
				)
					.navigationSubtitle(textSubtitle(String(describing: data)))
			} else {
				Text("No Preview")
					.emptyStateTextStyle()
			}
		}
			.fillFrame()
			.navigationTitle(type.title)
	}
}

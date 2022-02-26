import SwiftUI

struct ContentsScreen: View {
	@EnvironmentObject private var pasteboardObservable: NSPasteboard.Observable

	let type: Pasteboard.Type_

	var body: some View {
		let data = type.data()
		let sizeString = (data?.count ?? 0).formatted(.byteCount(style: .file))

		func textSubtitle(_ string: String) -> String {
			let lineCount = string.lineCount()
			let suffix = lineCount == 1 ? "line" : "lines"
			return "\(sizeString) — \(lineCount) \(suffix)"
		}

		func renderString(_ string: String) -> some View {
			ScrollableTextView(
				text: .constant(string),
				borderType: .noBorder
			)
				.navigationSubtitle(textSubtitle(string))
		}

		return Group {
			// Ensure plain text is always rendered as plain text.
			if
				type.nsType.toUTType?.conforms(to: .plainText) == true,
				let string = type.string()
			{
				renderString(string)
			} else if
				type.nsType.toUTType?.conforms(to: .utf16ExternalPlainText) == true,
				let data = type.data(),
				let string = String(data: data, encoding: .utf16)
			{
				renderString(string)
			} else if
				let data = data,
				let image = NSImage(data: data)
			{
				Image(nsImage: image)
					.resizable()
					.aspectRatio(contentMode: .fit)
					.frame(maxWidth: image.size.width, maxHeight: image.size.height)
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
				renderString(string)
			} else if
				let data = data,
				let view = QuickLookPreview(data: data, contentType: type.nsType.toUTType ?? .plainText)
			{
				view
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
			.background(.background)
			.fillFrame()
			.navigationTitle(type.title)
	}
}

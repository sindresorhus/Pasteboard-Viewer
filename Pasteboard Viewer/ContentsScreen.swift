import SwiftUI

struct ContentsScreen: View {
	@EnvironmentObject private var pasteboardObservable: NSPasteboard.Observable

	let type: Pasteboard.Type_

	var body: some View {
		let data = type.data()
		let sizeString = (data?.count ?? 0).formatted(.byteCount(style: .file))
		let contentType = type.nsType.toUTType

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

		#if DEBUG
		print("Type", type.nsType)
		#endif

		return Group {
			// Ensure plain text is always rendered as plain text.
			if
				contentType?.conforms(to: .plainText) == true,
				let string = type.string()
			{
				renderString(string)
			} else if
				contentType?.conforms(to: .utf16ExternalPlainText) == true,
				let data = type.data(),
				let string = String(data: data, encoding: .utf16)
			{
				renderString(string)
			} else if
				contentType?.conforms(to: .html) == true,
				let string = type.data()?.decodeStringWithUnknownEncoding()
			{
				renderString(string)
			} else if
				let data,
				let image = NSImage(data: data)
			{
				Image(nsImage: image)
					.resizable()
					.aspectRatio(contentMode: .fit)
					.frame(maxWidth: image.size.width, maxHeight: image.size.height)
					.navigationSubtitle("\(sizeString) — \(image.pixelSize.formatted)")
			} else if
				let data,
				data.isRtf || contentType?.conforms(to: .rtfd) == true || contentType?.conforms(to: .flatRTFD) == true, // The below initializer is too lenient with non-RTF data.
				let attributedString = NSAttributedString(rtf: data, documentAttributes: nil) ?? NSAttributedString(rtfd: data, documentAttributes: nil)
			{
				ScrollableAttributedTextView(
					attributedText: attributedString,
					borderType: .noBorder
				)
					.navigationSubtitle(textSubtitle(attributedString.string))
			} else if let string = type.string() {
				renderString(string)
			} else if
				let data,
				let view = QuickLookPreview(data: data, contentType: type.nsType.toUTType ?? .plainText)
			{
				view
					.navigationSubtitle(sizeString)
			} else if let data {
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
			.navigationTitle(type.decodedDynamicTitleIfAvailable ?? type.title)
	}
}

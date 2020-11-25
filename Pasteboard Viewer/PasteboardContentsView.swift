import SwiftUI

struct PasteboardContentsView: View {
	@EnvironmentObject private var pasteboardObservable: NSPasteboard.Observable

	let type: Pasteboard.Type_

	var body: some View {
		let data = type.data()

		return Group {
			if
				let data = data,
				let image = NSImage(data: data)
			{
				Image(nsImage: image)
					.resizable()
					.aspectRatio(contentMode: .fit)
			} else if
				let data = data,
				data.isRtf, // The below initializer is too lenient with non-RTF data.
				let attributedString = NSAttributedString(rtf: data, documentAttributes: nil)
			{
				ScrollableAttributedTextView(
					attributedText: attributedString,
					borderType: .noBorder
				)
			} else if let string = type.string() {
				ScrollableTextView(
					text: .constant(string),
					borderType: .noBorder
				)
			} else if
				let data = data,
				let view = QuickLookPreview(data: data, contentType: type.nsType.toUTType ?? .text)
			{
				view
					.background(Color(NSColor.textBackgroundColor))
			} else if let data = data {
				ScrollableTextView(
					text: .constant(String(describing: data)),
					borderType: .noBorder
				)
			} else {
				Text("No Preview")
					.emptyStateTextStyle()
			}
		}
			.fillFrame()
	}
}

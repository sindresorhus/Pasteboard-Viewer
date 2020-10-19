import SwiftUI

struct PasteboardContentsView: View {
	// TODO: Try removing this when targeting macOS 11.
	@EnvironmentObject private var pasteboardObservable: NSPasteboard.Observable

	var type: Pasteboard.PasteboardType?

	// TODO: Find a way to return `some View` here. With macOS 11, we can since it supports `if-let`.
	var contents: AnyView {
		guard let type = type else {
			// TODO: Use my empty state modifier.
			return Text("No Pasteboard Items")
				.foregroundColor(.secondary)
				.eraseToAnyView()
		}

		let pasteboard = type.pasteboard
		let nsPasteboardType = type.type
		let data = pasteboard.nsPasteboard.data(forType: nsPasteboardType)

		if
			let data = data,
			let image = NSImage(data: data)
		{
			return Image(nsImage: image)
				.resizable()
				.aspectRatio(contentMode: .fit)
				.eraseToAnyView()
		}

		if
			let data = data,
			let attributedString = NSAttributedString(rtf: data, documentAttributes: nil)
		{
			return ScrollableAttributedTextView(
				attributedText: attributedString,
				borderType: .noBorder
			)
				.eraseToAnyView()
		}

		if let string = pasteboard.nsPasteboard.string(forType: nsPasteboardType) {
			return ScrollableTextView(
				text: .constant(string),
				borderType: .noBorder
			)
				.eraseToAnyView()
		}

		if
			let data = data,
			let view = QuickLookPreview(data: data, typeIdentifier: nsPasteboardType.rawValue)
		{
			return view
				.background(Color(NSColor.textBackgroundColor))
				.eraseToAnyView()
		}

		if let data = data {
			return ScrollableTextView(
				text: .constant(String(describing: data)),
				borderType: .noBorder
			)
				.eraseToAnyView()
		}

		return Text("Could not read")
			.foregroundColor(.secondary)
			.eraseToAnyView()
	}

	var body: some View {
		contents
			.frame(maxWidth: .infinity, maxHeight: .infinity)
	}
}

import SwiftUI

struct PasteboardContentsView: View {
	// TODO: When using Swift 5.2, make this `@Lazy @ObservedObject` and remove the explicit init.
	@ObservedObject private var pasteboardObservable: NSPasteboard.Observable

	var pasteboard: Pasteboard
	var type: Pasteboard.PasteboardType?

	// TODO: Find a way to return `some View` here.
	var contents: AnyView {
		guard let type = self.type?.type else {
			return Text("No pasteboard items")
				.foregroundColor(.secondary)
				.eraseToAnyView()
		}

		let data = pasteboard.nsPasteboard.data(forType: type)

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

		if let string = (pasteboard.nsPasteboard.string(forType: type) ?? data.map { String(describing: $0) }) {
			return ScrollableTextView(
				text: .constant(string),
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

	init(pasteboard: Pasteboard, type: Pasteboard.PasteboardType?) {
		self.pasteboard = pasteboard
		self.type = type
		self.pasteboardObservable = NSPasteboard.Observable(pasteboard.nsPasteboard)
	}
}

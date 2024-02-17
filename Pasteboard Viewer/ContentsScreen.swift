import SwiftUI
import UniformTypeIdentifiers

struct ContentsScreen: View {
	@EnvironmentObject private var pasteboardObservable: XPasteboard.Observable

	let type: Pasteboard.Type_

	var body: some View {
		let data = type.data()
		let sizeString = (data?.count ?? 0).formatted(.byteCount(style: .file))
		let contentType = type.utType

		func textSubtitle(_ string: String) -> String {
			let lineCount = string.lineCount()
			let suffix = lineCount == 1 ? "line" : "lines"
			return "\(sizeString) — \(lineCount) \(suffix)"
		}

		func renderString(_ string: String, customExtraInfo: String? = nil) -> some View {
			ScrollableTextView(
				text: .constant(string),
				borderType: .noBorder
			)
			.extraInfo(customExtraInfo ?? textSubtitle(string))
		}

		#if DEBUG
		print("Type", type.xType.rawValue)
		#endif

		return VStack {
			// Ensure plain text is always rendered as plain text.
			if
				contentType?.conforms(to: .plainText) == true,
				let string = type.string()
			{
				renderString(string)
			} else if
				contentType?.conforms(to: .utf16ExternalPlainText) == true,
				let data = type.data(),
				!data.isRtf, // We want to render RTF further down.
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
				let image = XImage(data: data)
			{
				Image(xImage: image)
					.resizable()
					.aspectRatio(contentMode: .fit)
					.draggable(Image(xImage: image))
					.frame(maxWidth: image.size.width, maxHeight: image.size.height)
					.extraInfo("\(sizeString) — \(image.pixelSize.formatted)")
			} else if
				let data,
				data.isRtf || contentType?.conforms(to: .rtfd) == true || contentType?.conforms(to: .flatRTFD) == true, // The below initializer is too lenient with non-RTF data.
				let attributedString = NSAttributedString(rtf: data, documentAttributes: nil) ?? NSAttributedString(rtfd: data, documentAttributes: nil)
			{
				ScrollableAttributedTextView(
					attributedText: attributedString,
					borderType: .noBorder,
					backgroundColor: OS.isIOS ? .white : nil // We only do this on iOS as its text view cannot adapt text correctly when in dark mode.
				)
				.extraInfo(textSubtitle(attributedString.string))
			} else if
				let data,
				data.propertyListFormat == .binary,
				let string = (try? data.convertPropertyListToXML().toString)
			{
				renderString(string, customExtraInfo: "Decoded Binary Property List")
			} else if let string = type.string() {
				// Copying from Sublime Text adds a dynamic type with null bytes. We escape those so that it actually displays the content.
				renderString(string.escapingNullBytes())
			} else if
				let data,
				let view = QuickLookPreview(data: data, contentType: type.utType ?? .plainText)
			{
				view
					.extraInfo(sizeString)
			} else if let data {
				renderString(String(describing: data))
			} else {
				Text("No Preview")
					.emptyStateTextStyle()
			}
		}
			.fillFrame()
			.navigationTitle(type.decodedDynamicTitleIfAvailable ?? type.title)
			.toolbar {
				moreButton
			}
	}

	private var moreButton: some View {
		Menu("More", systemImage: OS.isMacOrVision ? "ellipsis" : "ellipsis.circle") {
			Section {
				if type.xType == .URL {
					Button("Open in Browser", systemImage: "safari") {
						#if os(macOS)
						type.string()?.toURL?.open()
						#else
						// On iOS, `.URL` is usually wrapped in a plist, but in case it's a plain string, we try it first.
						if let url = type.string()?.toURL {
							url.open()
							return
						}

						guard
							let data = type.data(),
							let array = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [Any],
							let url = array.first as? String
						else {
							return
						}

						url.openUrl()
						#endif
					}
				}
			}
			Section {
				let plainTextForSharing: String? = {
					let (utType, data) = type.forSharing

					// TODO: DRY.
					if
						data.isRtf || utType.conforms(to: .rtfd) || utType.conforms(to: .flatRTFD), // The below initializer is too lenient with non-RTF data.
						let attributedString = NSAttributedString(rtf: data, documentAttributes: nil) ?? NSAttributedString(rtfd: data, documentAttributes: nil)
					{
						return attributedString.string
					}

					return data.toString ?? data.decodeStringWithUnknownEncoding()
				}()
				if !type.isEmpty {
					if let plainTextForSharing {
						Button("Copy as Plain Text", systemImage: "doc.on.doc") {
							plainTextForSharing.copyToPasteboard()
						}
					}
					PasteboardItemShareButton(type: type)
				}
			}
			CopyTypeIdentifierButtons(type: type)
		}
		.menuIndicator(.hidden)
	}
}

extension View {
	fileprivate func extraInfo(_ text: String) -> some View {
		#if os(macOS)
		navigationSubtitleIfMacOS(text)
		#else
		// Note: Using `ToolbarItem(placement: .bottomBar)` caused it to loose the "back" button when starting to swiping to go back, but then deciding not to.
		fillFrame()
			.safeAreaInset(edge: .bottom) {
				Text(text)
					.foregroundStyle(.secondary)
					.font(.system(.subheadline))
					.padding(4)
			}
		#endif
	}
}

private struct PasteboardItemShareButton: View {
	let type: Pasteboard.Type_

	var body: some View {
		let (utType, data) = type.forSharing
		lazy var url: URL? = {
			do {
				let directoryURL = URL.temporaryDirectory
					.appending(component: "PasteboardItemShareButton", directoryHint: .isDirectory)
					.appending(component: UUID().uuidString, directoryHint: .isDirectory)
				try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
				let url = directoryURL.appendingPathComponent(utType.localizedDescription?.capitalizedFirstCharacter ?? "Data", conformingTo: utType)
				try data.write(to: url)
				return url
			} catch {
				print("Error:", error.localizedDescription)
				return nil
			}
		}()
		Group {
			if
				utType.conforms(to: .plainText) || utType == .text,
				let string = type.string() ?? data.decodeStringWithUnknownEncoding()
			{
				ShareLink(item: string)
			} else if let url {
				ShareLink(item: url)
			}
		}
		.onDisappear {
			DispatchQueue.global(qos: .utility).async {
				try? FileManager.default.removeItem(at: .temporaryDirectory.appending(component: "PasteboardItemShareButton", directoryHint: .isDirectory))
			}
		}
	}
}

struct CopyTypeIdentifierButtons: View {
	let type: Pasteboard.Type_

	var body: some View {
		Section {
			Button("Copy Type Identifier", systemImage: "doc.on.doc") {
				type.xType.rawValue.copyToPasteboard()
			}
			if let dynamicTitle = type.decodedDynamicTitleIfAvailable {
				Button("Copy Decoded Type Identifier", systemImage: "doc.on.doc") {
					dynamicTitle.copyToPasteboard()
				}
			}
		}
	}
}

extension Pasteboard.Type_ {
	var forSharing: (utType: UTType, data: Data) {
		let data = data() ?? Data()
		let utType = utType ?? .data

		if
			// We don't do this as not all binary property list items correctly conform to this.
//			utType.conforms(to: .propertyList),
			let format = data.propertyListFormat,
			format == .binary, // We only do binary as `.xml` and `.openStep` also work when the contents is just a plain string.
			let decoded = try? data.convertPropertyListToXML()
		{
			return (.xmlPropertyList, decoded)
		}

		if
			utType.isDynamic,
			data.isPropertyList
		{
			return (.xmlPropertyList, data)
		}

		// Handle cases like `org.nspasteboard.source`.
		if
			utType == .data,
			data.toString != nil
		{
			return (.utf8PlainText, data)
		}

		return (utType, data)
	}
}

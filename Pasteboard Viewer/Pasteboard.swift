import AppKit

enum Pasteboard: Equatable, CaseIterable {
	case general
	case drag
	case find
	case font
	case ruler

	struct Type_: Hashable, Identifiable {
		let item: Item
		let nsType: NSPasteboard.PasteboardType

		var id: String { "\(item.id)-\(nsType.rawValue)" }
		var title: String { nsType.rawValue }

		func data() -> Data? { item.rawValue.data(forType: nsType) }
		func string() -> String? { item.rawValue.string(forType: nsType) }
	}

	struct Item: RawRepresentable, Hashable, Identifiable {
		let rawValue: NSPasteboardItem

		var id: Int { rawValue.hashValue }

		var types: [Type_] {
			rawValue.modernTypes.map { Type_(item: self, nsType: $0) }
		}
	}

	var items: [Item] {
		nsPasteboard.pasteboardItems?.map { Item(rawValue: $0) } ?? []
	}

	var firstType: Type_? { items.first?.types.first }

	var nsPasteboard: NSPasteboard {
		switch self {
		case .general:
			return .general
		case .drag:
			return .init(name: .drag)
		case .find:
			return .init(name: .find)
		case .font:
			return .init(name: .font)
		case .ruler:
			return .init(name: .ruler)
		}
	}
}


extension NSPasteboardItem {
	private static var typeExclusions = [
		"NSStringPboardType": "public.utf8-plain-text",
		"NSFilenamesPboardType": "public.file-url",
		"NeXT TIFF v4.0 pasteboard type": "public.tiff",
		"NeXT Rich Text Format v1.0 pasteboard type": "public.rtf",
		"NeXT RTFD pasteboard type": "com.apple.flat-rtfd",
		"Apple HTML pasteboard type": "public.html",
		"Apple Web Archive pasteboard type": "com.apple.webarchive",
		"Apple URL pasteboard type": "public.url",
		"Apple PDF pasteboard type": "com.adobe.pdf",
		"Apple PNG pasteboard type": "public.png",
		"NSColor pasteboard type": "com.apple.cocoa.pasteboard.color"
	]

	/// `.types` without legacy junk.
	var modernTypes: [NSPasteboard.PasteboardType] {
		guard !types.isEmpty else {
			return []
		}

		let typeRawValues = types.map(\.rawValue)

		return types
			// Filter out legacy formats that have more modern alternatives.
			.filter {
				let id = $0.rawValue

				if id.hasPrefix("CorePasteboardFlavorType") {
					return false
				}

				if
					id == "Apple URL pasteboard type",
					typeRawValues.contains("public.file-url")
				{
					return false
				}

				if
					let value = Self.typeExclusions[id],
					typeRawValues.contains(value)
				{
					return false
				}

				return true
			}
	}
}

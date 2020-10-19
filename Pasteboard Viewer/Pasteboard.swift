import AppKit

enum Pasteboard: CaseIterable {
	case general
	case drag
	case find
	case font
	case ruler

	struct PasteboardType: Hashable, Identifiable {
		let pasteboard: Pasteboard
		let type: NSPasteboard.PasteboardType
		var id: String { type.rawValue }
		var title: String { type.rawValue }
	}

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

	var types: [PasteboardType] {
		guard let types = nsPasteboard.types else {
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
			.map { PasteboardType(pasteboard: self, type: $0) }
	}
}

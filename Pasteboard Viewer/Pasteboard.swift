import SwiftUI
import UniformTypeIdentifiers

enum Pasteboard: Equatable, CaseIterable {
	case general

	#if os(macOS)
	case drag
	case find
	case font
	case ruler
	#endif

	struct Type_: Hashable, Identifiable {
		private static let ignoredIdentifiers: Set<String> = [
			"com.apple.pasteboard.promised-suggested-file-name" // Trying to get the data/string of this type causes the app to hang indefinitely. (macOS 12.4)
		]

		let item: Item
		let xType: XPasteboard.PasteboardType

		var id: String { "\(item.id)-\(xType.rawValue)" }
		var title: String { xType.rawValue }
		var decodedDynamicTitleIfAvailable: String? { xType.decodedDynamic?.rawValue }
		var utType: UTType? { xType.toUTType }

		var isEmpty: Bool { data().map(\.isEmpty) ?? true }

		func data() -> Data? {
			guard !Self.ignoredIdentifiers.contains(xType.rawValue) else {
				return nil
			}

			return item.rawValue.data(forType: xType)
		}

		func string() -> String? {
			guard !Self.ignoredIdentifiers.contains(xType.rawValue) else {
				return nil
			}

			return item.rawValue.string(forType: xType)
		}
	}

	struct Item: RawRepresentable, Hashable, Identifiable {
		let rawValue: XPasteboardItem

		var id: Int { rawValue.hashValue }

		var types: [Type_] {
			rawValue.modernTypes.map { Type_(item: self, xType: $0) }
		}
	}

	private static var itemsCache: (changeCount: Int, items: [Item])?

	var items: [Item] {
		#if !os(macOS)
		// We cache access to avoid triggering the system toast about pasteboard access.
		if
			let cache = Self.itemsCache,
			cache.changeCount == UIPasteboard.general.changeCount
		{
			return cache.items
		}
		#endif

		let allItems = xPasteboard.xItems.map { Item(rawValue: $0) }

		#if !os(macOS)
		Self.itemsCache = (UIPasteboard.general.changeCount, allItems)
		#endif

		return allItems
	}

	var firstType: Type_? { items.first?.types.first }

	var xPasteboard: XPasteboard {
		switch self {
		case .general:
			.general
		#if os(macOS)
		case .drag:
			.init(name: .drag)
		case .find:
			.init(name: .find)
		case .font:
			.init(name: .font)
		case .ruler:
			.init(name: .ruler)
		#endif
		}
	}
}


extension XPasteboardItem {
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
		"NSColor pasteboard type": "com.apple.cocoa.pasteboard.color",
		"iOS rich content paste pasteboard type": "com.apple.uikit.attributedstring"
	]

	/**
	`.types` without legacy junk.
	*/
	var modernTypes: [XPasteboard.PasteboardType] {
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

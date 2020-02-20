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
			return NSPasteboard(name: .drag)
		case .find:
			return NSPasteboard(name: .find)
		case .font:
			return NSPasteboard(name: .font)
		case .ruler:
			return NSPasteboard(name: .ruler)
		}
	}

	var types: [PasteboardType] {
		nsPasteboard.types?.map { PasteboardType(pasteboard: self, type: $0) } ?? []
	}
}

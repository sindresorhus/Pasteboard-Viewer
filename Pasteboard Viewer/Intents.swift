import AppIntents

struct GetPasteboardItemsIntent: AppIntent {
	static let title: LocalizedStringResource = "Get Pasteboard Items"

	static let description = IntentDescription(
		"""
		Returns a list of items from the general pasteboard, where each item includes a list of types and their corresponding data, accessible via the “types” property.

		Note: For convenience, binary property lists (.plist) are decoded into XML property lists.
		""",
		searchKeywords: [
			"clipboard",
			"nspasteboard",
			"uipasteboard"
		],
		resultValueName: "Pasteboard Items"
	)

	// Note: This would have been better as `[[PasteboardItem_AppEntity]]` but that crashes the Shortcuts app. (macOS 14.3)
	func perform() async throws -> some IntentResult & ReturnsValue<[PasteboardItem_AppEntity]> {
		let result = Pasteboard.general.items.indexed().map { index, item in
			let finalItem = PasteboardItem_AppEntity()
			finalItem.index = index

			finalItem.types = item.types.map {
				let type = $0
				let (utType, data) = $0.forSharing

				let finalType = PasteboardItemType_AppEntity()

				finalType.identifier = type.xType.rawValue

				finalType.data = IntentFile(
					data: data,
					filename: "Item \(index + 1) - \(type.title) - File", // We end it with `- File` so the UTType is not used as extension. For example, without this, `public.rtf` would just show as `public`.
					type: utType
				)

				return finalType
			}

			return finalItem
		}

		return .result(value: result)
	}
}

struct PasteboardItem_AppEntity: TransientAppEntity {
	static let typeDisplayRepresentation: TypeDisplayRepresentation = "Pasteboard Item"

	@Property(title: "Index")
	var index: Int

	@Property(title: "Types")
	var types: [PasteboardItemType_AppEntity]

	var displayRepresentation: DisplayRepresentation {
		.init(
			title:
				"""
				Item \(index + 1)

				\(types.count) types:
				\(types.map(\.identifier).map { "- \($0)" }.joined(separator: "\n"))
				"""
		)
	}
}

struct PasteboardItemType_AppEntity: TransientAppEntity {
	static let typeDisplayRepresentation: TypeDisplayRepresentation = "Pasteboard Item Type"

	@Property(title: "Identifier")
	var identifier: String

	@Property(title: "Data")
	var data: IntentFile

	var displayRepresentation: DisplayRepresentation {
		.init(
			title:
				"""
				\(identifier)
				\(data.data.count.formatted(.byteCount(style: .file)))
				"""
		)
	}
}

struct GetPasteboardContentsAsFilesIntent: AppIntent {
	static let title: LocalizedStringResource = "Get Pasteboard Contents as Files"

	static let description = IntentDescription(
		"""
		Returns the contents of the general pasteboard as files.

		Note: For convenience, binary property lists (.plist) are decoded to XML property lists.
		""",
		searchKeywords: [
			"clipboard",
			"nspasteboard",
			"uipasteboard"
		],
		resultValueName: "Pasteboard Contents"
	)

	func perform() async throws -> some IntentResult & ReturnsValue<[IntentFile]> {
		let result = Pasteboard.general.items.indexed().flatMap { index, item in
			item.types.map {
				let type = $0
				let (utType, data) = $0.forSharing
				return IntentFile(
					data: data,
					filename: "Item \(index + 1) - \(type.title) - File", // We end it with `- File` so the UTType is not used as extension. For example, without this, `public.rtf` would just show as `public`.
					type: utType
				)
			}
		}

		return .result(value: result)
	}
}

struct ClearPasteboardIntent: AppIntent {
	static let title: LocalizedStringResource = "Clear Pasteboard"

	static let description = IntentDescription(
		"""
		Clears the system pasteboard.
		""",
		searchKeywords: [
			"clipboard",
			"nspasteboard",
			"uipasteboard"
		]
	)

	func perform() async throws -> some IntentResult {
		XPasteboard.general.clear()
		return .result()
	}
}

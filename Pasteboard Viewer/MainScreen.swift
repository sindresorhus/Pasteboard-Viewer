import SwiftUI
import UniformTypeIdentifiers
import StoreKit
import TipKit

#if os(macOS)
import SwiftUIIntrospect
#endif

struct MainScreen: View {
	@Environment(\.requestReview) private var requestReview
	@Environment(\.horizontalSizeClass) private var horizontalSizeClass
	@State private var pasteboardObservable = XPasteboard.Observable(.general)
	@Default(.stayOnTop) private var stayOnTop
	@State private var columnVisibility = NavigationSplitViewVisibility.all
	@State private var selectedPasteboard = Pasteboard.general
	@State private var selectedType: Pasteboard.Type_?

	var body: some View {
		NavigationSplitView(columnVisibility: $columnVisibility) {
			sidebar
		} detail: {
			mainContent
		}
		.navigationSplitViewStyle(.balanced)
		.focusedValue(\.selectedPasteboard, $selectedPasteboard)
		#if os(macOS)
		// Prevent sidebar from collapsing.
		.introspect(.navigationSplitView, on: .macOS(.v15)) { splitview in
			guard let delegate = splitview.delegate as? NSSplitViewController else {
				return
			}

			delegate.splitViewItems.first?.canCollapse = false
			delegate.splitViewItems.first?.canCollapseFromWindowResize = false
		}
		// TODO: Change the `minWidth` to `320` when the sidebar can be made unhidable.
		.frame(minWidth: 240, minHeight: 120)
		.onChange(of: selectedPasteboard) {
			pasteboardObservable.pasteboard = selectedPasteboard.xPasteboard
			selectedType = selectedPasteboard.firstType
		}
		// Prevent sidebar from collapsing.
		.onChange(of: columnVisibility, initial: true) {
			Task { @MainActor in
				columnVisibility = .all
			}
		}
		.windowTabbingMode(.disallowed)
		.windowLevel(stayOnTop ? .floating : .normal)
		#endif
		.task(id: pasteboardObservable.info) {
			// Tries to work around an obscure crash.
			selectedType = nil
			await Task.yield()

			// We don't want to go straight into the first type on iPhone.
			guard horizontalSizeClass != .compact else {
				return
			}

			selectedType = selectedPasteboard.items.first?.types.first { $0.utType == .utf8PlainText } ?? selectedPasteboard.firstType
		}
		.task {
			guard Defaults[.launchCount] == 3 else {
				return
			}

			requestReview()
		}
	}

	private var mainContent: some View {
		Group {
			if let selectedType {
				ContentsScreen(type: selectedType)
					.id(selectedType.id)
					.id(pasteboardObservable.info?.id)
					.environment(pasteboardObservable)
			} else {
				#if os(macOS)
				Text("No Pasteboard Items")
					.emptyStateTextStyle()
				#else
				Text("No Selected Item")
					.emptyStateTextStyle()
				#endif
			}
		}
		.toolbarTitleDisplayMode(.inline)
	}

	@ViewBuilder
	private var sidebar: some View {
		#if os(iOS)
		if SSApp.isFirstLaunch { // TODO: We have to guard this as TipView does not seem to persist dismissal.
			TipView(AvoidPasteboardPromptTip())
				.padding()
		}
		#endif
		List(selectedPasteboard.items.indexed(), id: \.1, selection: $selectedType) { index, item in
			Section("Item \(index + 1)") {
				ForEach(item.types, id: \.self) {
					SidebarItemView(type: $0)
				}
			}
		}
		#if os(macOS)
		.padding(.bottom, 1) // The safe area inset does not work without this. (macOS 12.2)
		.safeAreaInset(edge: .bottom, alignment: .leading) {
			sourceAppView
		}
		// TODO: Use this when SwiftUI is able to persist the sidebar size.
		// .frame(minWidth: 180, idealWidth: 200)
		.frame(minWidth: 200)
		.toolbar {
			ToolbarItem(placement: .primaryAction) {
				EnumPicker("Pasteboard", selection: $selectedPasteboard) {
					Text($0.xPasteboard.presentableName)
				}
			}
		}
		.toolbar(removing: .sidebarToggle)
		.overlay {
			if isPasteboardAccessDenied {
				ContentUnavailableView {
					Label("Clipboard Access Denied", systemImage: "clipboard")
				} description: {
					Text("Allow clipboard access in System Settings → Privacy & Security → Paste from Other Apps.")
				}
			}
		}
		#else
		.navigationTitle("Pasteboard")
		.toolbar {
			moreButton
		}
		.overlay {
			if selectedPasteboard.items.isEmpty {
				VStack(spacing: 16) {
					Text("No Items")
						.emptyStateTextStyle()
					if SSApp.isFirstLaunch {
						Button("Add Example Data") {
							UIPasteboard.general.url = URL("https://sindresorhus.com/pasteboard-viewer")
						}
					}
				}
			}
		}
		#endif
	}

	#if os(macOS)
	private var isPasteboardAccessDenied: Bool {
		NSPasteboard.general.accessBehavior == .alwaysDeny
	}

	@ViewBuilder
	private var sourceAppView: some View {
		if
			selectedPasteboard == .general,
			let appURL = pasteboardObservable.info?.sourceAppURL
		{
			VStack(alignment: .leading) {
				Section {
					HStack(spacing: 0) {
						URLIcon(url: appURL)
							.frame(height: 18)
						Text(NSWorkspace.shared.appName(for: appURL))
							.lineLimit(1)
							.padding(.leading, 4)
					}
				} header: {
					Text("Source")
						.font(.subheadline)
						.fontWeight(.semibold)
						.foregroundStyle(.secondary)
				}
			}
			.padding()
			.respectInactive()
		}
	}
	#endif

	#if !os(macOS)
	private var moreButton: some View {
		Menu("More", systemImage: OS.isMacOrVision || OS.is26OrLater ? "ellipsis" : "ellipsis.circle") {
			ClearPasteboardButton()
			Divider()
			SendFeedbackButton()
			Divider()
			Link("Website", systemImage: "safari", destination: "https://sindresorhus.com/pasteboard-viewer")
			Divider()
			RateOnAppStoreButton(appStoreID: "1499215709")
			ShareAppButton(appStoreID: "1499215709")
			MoreAppsButton()
			Divider()
			AppLicensesButton()
		}
	}
	#endif
}

#Preview {
	MainScreen()
}

private struct SidebarItemView: View {
	@State private var isSafariAlertPresented = false

	let type: Pasteboard.Type_

	var body: some View {
		Group {
			#if os(macOS)
			contents
			#else
			NavigationLink(value: type) {
				contents
			}
			#endif
		}
		.lineLimit(2)
		.contextMenu {
			CopyTypeIdentifierButtons(type: type)
			Divider()
			#if os(macOS)
			if type.canOpenWith {
				OpenWithMenu(
					type: type,
					isSafariAlertPresented: $isSafariAlertPresented
				)
			}
			SaveButton(type: type)
			if type.xType == .fileURL {
				Button("Show in Finder", systemImage: "finder") {
					type.fileURLValue?.showInFinder()
				}
			}
			#endif
		}
		.alert(
			"Cannot Open in Safari",
			isPresented: $isSafariAlertPresented
		) {
			Button("OK") {}
		} message: {
			Text("Safari's renderer runs in a separate, stricter sandbox and cannot access files from Pasteboard Viewer. Try a different app or select “Save” instead.")
		}
	}

	var contents: some View {
		VStack(alignment: .leading) {
			if let dynamicTitle = type.decodedDynamicTitleIfAvailable {
				Text(dynamicTitle)
				Text(type.title)
					.sidebarSubtitleStyle()
					.lineLimit(1)
			} else {
				Text(type.title)
				#if !os(macOS)
				if let description = type.utType?.localizedDescription {
					Text(description.capitalizedFirstCharacter)
						.sidebarSubtitleStyle()
				}
				#endif
			}
		}
	}
}

#if os(iOS)
private struct AvoidPasteboardPromptTip: Tip {
	var title: Text {
		Text("Pasteboard Prompt")
	}

	var message: Text? {
		Text("To avoid the pasteboard prompt, allow “Paste from Other Apps” in the app settings.")
	}

	var image: Image? {
		Image(systemName: "checkmark.circle.trianglebadge.exclamationmark")
	}

	var actions: [Action] {
		Action(title: "Open App Settings") {
			invalidate(reason: .actionPerformed)
			URL(string: UIApplication.openSettingsURLString)!.open()
		}
	}
}
#endif

#if os(macOS)
private struct OpenWithMenu: View {
	let type: Pasteboard.Type_
	@Binding var isSafariAlertPresented: Bool

	var body: some View {
		let appURLs = openWithAppURLs

		if appURLs.isEmpty {
			Button("Open With…", systemImage: "arrow.up.forward.app") {
				Task {
					await chooseApp()
				}
			}
		} else {
			let defaultAppURL = defaultOpenWithAppURL
			let otherApps = appURLs
				.filter { $0 != defaultAppURL }
				.sorted { $0.localizedName.localizedStandardCompare($1.localizedName) == .orderedAscending }
			Menu("Open With", systemImage: "arrow.up.forward.app") {
				if let defaultAppURL {
					appButton(for: defaultAppURL)
					Divider()
				}
				ForEach(otherApps, id: \.self) { appURL in
					appButton(for: appURL)
				}
				Section {
					Button("Other…", systemImage: "arrow.up.forward.app") {
						Task {
							await chooseApp()
						}
					}
				}
			}
		}
	}

	private func appButton(for appURL: URL) -> some View {
		Button {
			open(using: appURL)
		} label: {
			Label {
				Text(NSWorkspace.shared.appName(for: appURL))
			} icon: {
				Image(nsImage: appURL.appIcon)
			}
		}
	}

	private func chooseApp() async {
		guard let window = NSApp.activeWindow else {
			return
		}

		let panel = NSOpenPanel()
		panel.allowedContentTypes = [.application]
		panel.directoryURL = URL(filePath: "/Applications")

		guard
			await panel.beginSheetModal(for: window) == .OK,
			let appURL = panel.url
		else {
			return
		}

		open(using: appURL)
	}

	private func open(using appURL: URL) {
		/*
		Safari's WebContent renderer runs in a stricter sandbox than its main process and cannot inherit the sandbox extension that Launch Services grants, so it cannot read temp files from our container. Show a warning instead of silently failing.
		*/
		if
			type.fileURLValue == nil,
			Bundle(url: appURL)?.bundleIdentifier == "com.apple.Safari"
		{
			isSafariAlertPresented = true
			return
		}

		do {
			let fileURL = try type.openWithFileURL()

			NSWorkspace.shared.open(
				[fileURL],
				withApplicationAt: appURL,
				configuration: NSWorkspace.OpenConfiguration()
			)
		} catch {
			print("Error:", error.localizedDescription)
		}
	}

	private var openWithAppURLs: [URL] {
		if let fileURLValue = type.fileURLValue {
			return NSWorkspace.shared.urlsForApplications(toOpen: fileURLValue)
		}

		guard let exactFileRepresentation = type.exactFileRepresentation else {
			return []
		}

		return NSWorkspace.shared.urlsForApplications(toOpen: exactFileRepresentation.utType)
	}

	private var defaultOpenWithAppURL: URL? {
		if let fileURLValue = type.fileURLValue {
			return NSWorkspace.shared.urlForApplication(toOpen: fileURLValue)
		}

		guard let exactFileRepresentation = type.exactFileRepresentation else {
			return nil
		}

		return NSWorkspace.shared.urlForApplication(toOpen: exactFileRepresentation.utType)
	}
}

private struct SaveButton: View {
	let type: Pasteboard.Type_

	var body: some View {
		Button("Save…", systemImage: "square.and.arrow.down") {
			Task {
				await save()
			}
		}
		.disabled(type.isEmpty)
	}

	private func save() async {
		guard let window = NSApp.activeWindow else {
			return
		}

		let fileURLValue = type.fileURLValue

		let panel = NSSavePanel()
		if let fileURLValue {
			panel.nameFieldStringValue = fileURLValue.lastPathComponent
		} else {
			let utType = type.utType ?? .data
			panel.allowedContentTypes = [utType]
			panel.nameFieldStringValue = URL(filePath: "/").appendingPathComponent(
				utType.localizedDescription?.capitalizedFirstCharacter ?? "Data",
				conformingTo: utType
			).lastPathComponent
		}

		guard
			await panel.beginSheetModal(for: window) == .OK,
			let url = panel.url
		else {
			return
		}

		do {
			guard let fileURLValue else {
				try (type.data() ?? Data()).write(to: url)
				return
			}

			guard fileURLValue != url else {
				return
			}

			if FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
				let replacementDirectoryURL = try FileManager.default.url(
					for: .itemReplacementDirectory,
					in: .userDomainMask,
					appropriateFor: url,
					create: true
				)
				let replacementURL = replacementDirectoryURL.appending(component: fileURLValue.lastPathComponent)
				try FileManager.default.copyItem(at: fileURLValue, to: replacementURL)
				_ = try FileManager.default.replaceItemAt(url, withItemAt: replacementURL)
			} else {
				try FileManager.default.copyItem(at: fileURLValue, to: url)
			}
		} catch {
			print("Error:", error.localizedDescription)
		}
	}
}

private extension Pasteboard.Type_ {
	/**
	Resolve a copied Finder file item to its underlying file URL.
	*/
	var fileURLValue: URL? {
		guard xType == .fileURL else {
			return nil
		}

		return string()?.toURL
	}

	/**
	A faithful file representation of the selected pasteboard type without `forSharing` conversions.
	*/
	var exactFileRepresentation: (utType: UTType, data: Data)? {
		guard let data = data() else {
			return nil
		}

		return (utType ?? .data, data)
	}

	/**
	Whether this type has something to hand off to an external app. URL types are excluded because they are a web address, not a file.
	*/
	var canOpenWith: Bool {
		guard xType != .URL else {
			return false
		}

		return fileURLValue != nil || exactFileRepresentation != nil
	}

	/**
	Returns a file URL suitable for opening in an external app. For file-URL types this is the original file; for all other types a temporary file is created from the raw pasteboard data.
	*/
	func openWithFileURL() throws -> URL {
		if let fileURLValue {
			return fileURLValue
		}

		guard let exactFileRepresentation else {
			throw CocoaError(.fileReadUnknown)
		}

		/*
		For non-file pasteboard items, any temporary file we create from inside the sandbox will still live inside this app's sandbox container, regardless of which temporary-directory API we use. Some sandboxed multi-process apps like Safari therefore cannot read the handed-off file, so this is a platform limitation of the current approach, not something solved by picking a different temp location.
		*/
		let temporaryDirectory = try FileManager.default.url(
			for: .itemReplacementDirectory,
			in: .userDomainMask,
			appropriateFor: FileManager.default.temporaryDirectory,
			create: true
		)

		let fileURL = temporaryDirectory.appendingPathComponent(
			exactFileRepresentation.utType.localizedDescription?.capitalizedFirstCharacter ?? "Data",
			conformingTo: exactFileRepresentation.utType
		)

		try exactFileRepresentation.data.write(to: fileURL)

		return fileURL
	}
}
#endif

extension View {
	fileprivate func sidebarSubtitleStyle() -> some View {
		foregroundStyle(.secondary)
		#if os(macOS)
			.font(.system(size: 10))
			.respectInactive()
		#else
			.font(.subheadline)
		#endif
	}
}

struct ClearPasteboardButton: View {
	@FocusedBinding(\.selectedPasteboard) private var selectedPasteboard

	// Only needed to get the iOS menu item to update disabled state.
	@State private var pasteboardObservable = XPasteboard.Observable(.general)

	var body: some View {
		Button(
			OS.isMacOS ? "Clear" : "Clear Pasteboard",
			systemImage: "xmark.circle",
			role: .destructive
		) {
			let pasteboard = selectedPasteboard ?? .general
			pasteboard.xPasteboard.clear()
		}
		.disabled((selectedPasteboard ?? .general).xPasteboard.isEmpty)
		.observing(pasteboardObservable.info)
		.keyboardShortcut("c", modifiers: [.option, .command])
		.onChange(of: selectedPasteboard, initial: true) { _, newValue in
			if let newValue {
				pasteboardObservable.pasteboard = newValue.xPasteboard
			}
		}
	}
}

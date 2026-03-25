import SwiftUI
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
			if type.xType == .fileURL {
				#if os(macOS)
				Button("Show in Finder", systemImage: "finder") {
					type.string()?.toURL?.showInFinder()
				}
				#endif
			}
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

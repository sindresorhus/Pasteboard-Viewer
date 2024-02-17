import SwiftUI
import StoreKit
import TipKit

struct MainScreen: View {
	@Environment(\.requestReview) private var requestReview
	@Environment(\.horizontalSizeClass) private var horizontalSizeClass
	@StateObject private var pasteboardObservable = XPasteboard.Observable(.general)
	@Default(.stayOnTop) private var stayOnTop
	@State private var selectedPasteboard = Pasteboard.general
	@State private var selectedType: Pasteboard.Type_?

	var body: some View {
		Group {
			#if os(macOS)
			// TODO: Set the sidebar to not be collapsible when SwiftUI supports that.
			// TODO: We intentionally do not use `NavigationSplitView` as there is no way to prevent it from collapsing. (macOS 14.2)
			NavigationView {
				sidebar
				mainContent
			}
			#else
			NavigationSplitView {
				sidebar
			} detail: {
				mainContent
			}
			.navigationSplitViewStyle(.balanced)
			#endif
		}
			#if os(macOS)
			.preventSidebarCollapse()
			// TODO: Change the `minWidth` to `320` when the sidebar can be made unhidable.
			.frame(minWidth: 240, minHeight: 120)
			.onChange(of: selectedPasteboard) {
				pasteboardObservable.pasteboard = selectedPasteboard.xPasteboard
				selectedType = selectedPasteboard.firstType
			}
			.windowTabbingMode(.disallowed)
			.windowLevel(stayOnTop ? .floating : .normal)
			#else
			.task(id: pasteboardObservable.info) {
				selectedType = nil
			}
			#endif
			.task(id: pasteboardObservable.info) {
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
					.environmentObject(pasteboardObservable)
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
		Menu("More", systemImage: OS.isMacOrVision ? "ellipsis" : "ellipsis.circle") {
			ClearPasteboardButton()
			Divider()
			SendFeedbackButton()
			Divider()
			Link("Website", systemImage: "safari", destination: "https://sindresorhus.com/pasteboard-viewer")
			Divider()
			RateOnAppStoreButton(appStoreID: "1499215709")
			ShareAppButton(appStoreID: "1499215709")
			MoreAppsButton()
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
		VStack(alignment: .leading) {
			if let dynamicTitle = type.decodedDynamicTitleIfAvailable {
				Text(dynamicTitle)
				Text(type.title)
					.foregroundStyle(.secondary)
					#if os(macOS)
					.font(.system(size: 10))
					.respectInactive()
					#else
					.font(.subheadline)
					#endif
					.lineLimit(1)
			} else {
				Text(type.title)
				// TODO: DRY.
				#if !os(macOS)
				if let description = type.utType?.localizedDescription {
					Text(description.capitalizedFirstCharacter)
						.foregroundStyle(.secondary)
						#if os(macOS)
						.font(.system(size: 10))
						.respectInactive()
						#else
						.font(.subheadline)
						#endif
				}
				#endif
			}
		}
			.lineLimit(2)
			.contextMenu {
				CopyTypeIdentifierButtons(type: type)
				Divider()
				if type.xType == .fileURL {
					#if os(macOS)
					Button("Show in Finder") {
						type.string()?.toURL?.showInFinder()
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

struct ClearPasteboardButton: View {
	@StateObject private var _pasteboardObservable = XPasteboard.Observable(.general)

	var body: some View {
		Button("Clear Pasteboard", systemImage: "xmark.circle", role: .destructive) {
			XPasteboard.general.clear()
		}
		.disabled(XPasteboard.general.isEmpty)
	}
}

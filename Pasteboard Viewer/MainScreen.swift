import SwiftUI

private struct SidebarItemView: View {
	let type: Pasteboard.Type_

	var body: some View {
		Text(type.title)
			.contextMenu {
				Button("Copy Type Identifier") {
					// TODO: Pause realtime pasteboard view here when we support that.
					type.nsType.rawValue.copyToPasteboard()
				}
				Divider()
				if type.nsType == .fileURL {
					Button("Show in Finder") {
						type.string()?.toURL?.showInFinder()
					}
				} else if type.nsType == .URL {
					Button("Open in Browser") {
						type.string()?.toURL?.open()
					}
				}
			}
	}
}

struct MainScreen: View {
	@StateObject private var pasteboardObservable = NSPasteboard.Observable(.general)
	@Default(.stayOnTop) private var stayOnTop
	@State private var selectedPasteboard = Pasteboard.general
	@State private var selectedType: Pasteboard.Type_?

	var body: some View {
		// TODO: Set the sidebar to not be collapsible when SwiftUI supports that.
		NavigationView {
			sidebar
			mainContent
		}
			// TODO: Change the `minWidth` to `320` when the sidebar can be made unhidable.
			.frame(minWidth: 240, minHeight: 120)
			.onChange(of: selectedPasteboard) {
				pasteboardObservable.pasteboard = $0.nsPasteboard
				selectedType = $0.firstType
			}
			.onChange(of: pasteboardObservable.info, initial: true) { _ in
				selectedType = selectedPasteboard.firstType
			}
			.windowTabbingMode(.disallowed)
			.windowLevel(stayOnTop ? .floating : .normal)
	}

	@ViewBuilder
	private var mainContent: some View {
		if let selectedType {
			ContentsScreen(type: selectedType)
				.environmentObject(pasteboardObservable)
		} else {
			Text("No Pasteboard Items")
				.emptyStateTextStyle()
		}
	}

	@ViewBuilder
	private var sidebar: some View {
		List(selectedPasteboard.items.indexed(), id: \.1, selection: $selectedType) { index, item in
			Section("Item \(index + 1)") {
				ForEach(item.types, id: \.self) {
					SidebarItemView(type: $0)
				}
			}
		}
			.listStyle(.sidebar)
			.padding(.bottom, 1) // The safe area inset does not work without this. (macOS 12.2)
			.safeAreaInset(edge: .bottom, alignment: .leading) {
				sourceAppView
			}
			// TODO: Use this when SwiftUI is able to persist the sidebar size.
			// .frame(minWidth: 180, idealWidth: 200, maxWidth: 300)
			.frame(minWidth: 200, maxWidth: 300)
			.toolbar {
				ToolbarItem(placement: .primaryAction) {
					EnumPicker("Pasteboard", enumBinding: $selectedPasteboard) { pasteboard, _ in
						Text(pasteboard.nsPasteboard.presentableName)
					}
				}
			}
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
		}
	}
}

struct MainScreen_Previews: PreviewProvider {
	static var previews: some View {
		MainScreen()
	}
}

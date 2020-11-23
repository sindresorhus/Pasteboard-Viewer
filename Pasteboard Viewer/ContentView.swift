import SwiftUI
import Combine

struct ContentView: View {
	// Use `@StateObject` when targeting macOS 11.
	@ObservedObject private var pasteboardObservable = NSPasteboard.Observable(.general)
	@State private var selectedPasteboard = Pasteboard.general
	@State private var selectedType: Pasteboard.PasteboardType?

	private func setWindowTitle() {
		AppDelegate.shared.window.title = selectedType?.title ?? SSApp.name
	}

	private func setPasteboardType() {
		guard
			selectedType == nil
				|| (!selectedPasteboard.types.contains { $0 == selectedType }
		) else {
			return
		}

		DispatchQueue.main.async {
			selectedType = selectedPasteboard.types.first
		}
	}

	private var sourceAppUrl: URL? {
		guard
			let bundleIdentifier = pasteboardObservable.info?.sourceAppBundleIdentifier,
			let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
		else {
			return nil
		}

		return appUrl
	}

	@ViewBuilder
	private func sourceAppView() -> some View {
		if let sourceAppUrl = sourceAppUrl {
			VStack(alignment: .leading) {
				Text("Source")
					.foregroundColor(.secondary)
					.font(.system(size: NSFont.smallSystemFontSize))
					// TODO: Check how the below looks on macOS 11.
					//.font(.subheadline)
					.fontWeight(.semibold)
				HStack(spacing: 0) {
					URLIcon(url: sourceAppUrl)
						.frame(height: 18)
					Text(NSWorkspace.shared.appName(forBundleIdentifier: pasteboardObservable.info?.sourceAppBundleIdentifier ?? "") ?? "")
						.lineLimit(1)
						.padding(.leading, 4)
				}
			}
				.padding()
		}
	}

	var body: some View {
		// TODO: These should use `View#onChange` when targeting macOS 11.
		setWindowTitle()
		setPasteboardType()

		// TODO: Set the sidebar to not be collapsible when SwiftUI supports that.
		return NavigationView {
			VStack(alignment: .leading) {
				EnumPicker(
					"Pasteboard Type",
					// TODO: This should use `View#onChange` when targeting macOS 11.
					enumBinding: $selectedPasteboard.onChange { _ in
						selectedType = selectedPasteboard.types.first
						pasteboardObservable.pasteboard = selectedPasteboard.nsPasteboard
					}
				) { pasteboard, _ in
					// TODO: Add Command+1/2/3/4 keyboard shortcuts when targeting macOS 11 (`View#keyboardShortcut()`).
					Text(pasteboard.nsPasteboard.presentableName)
				}
					.labelsHidden()
					.padding()
				List(selection: $selectedType) {
					// TODO: I can hopefully remove this when targeting macOS 11, and then remove the `ForEach` too.
					// The `Divider` is a workaround for SwiftUI bug where the selection highlight for the first element in the list would dissapear in some cases when the view is updated, for example, when you copy something new to the pasteboard.
					Divider()
						.opacity(0)
					ForEach(selectedPasteboard.types, id: \.self) { type in
						Text(type.title)
							.frame(maxWidth: .infinity, alignment: .leading)
							.contextMenu {
								Button("Copy Type Identifier") {
									// TODO: Pause realtime pasteboard view here when we support that.
									type.id.copyToPasteboard()
								}
							}
					}
						// Works around the sidebar not getting focus at launch.
						.forceFocus()
				}
					.listStyle(SidebarListStyle())
					.padding(.top, -22) // Workaround for SwiftUI bug.
				sourceAppView()
			}
				// TODO: Use this when SwiftUI is able to persist the sidebar size.
				// .frame(minWidth: 180, idealWidth: 200, maxWidth: 300)
				.frame(minWidth: 200, maxWidth: 300)
			PasteboardContentsView(type: selectedType)
				.environmentObject(pasteboardObservable)
		}
			.frame(minWidth: 500, minHeight: 300)
	}
}

struct ContentView_Previews: PreviewProvider {
	static var previews: some View {
		ContentView()
	}
}

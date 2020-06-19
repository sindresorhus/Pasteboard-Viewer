import SwiftUI
import Combine

struct ContentView: View {
	// Use `@StateObject` when targeting macOS 11.
	@ObservedObject private var pasteboardObservable = NSPasteboard.Observable(.general)
	@State private var selectedPasteboard = Pasteboard.general
	@State private var selectedType: Pasteboard.PasteboardType?

	private func setWindowTitle() {
		AppDelegate.shared.window.title = selectedType?.title ?? App.name
	}

	private func setPasteboardType() {
		guard
			selectedType == nil
				|| (!selectedPasteboard.types.contains { $0 == selectedType }
		) else {
			return
		}

		DispatchQueue.main.async {
			self.selectedType = self.selectedPasteboard.types.first
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
		// TODO: Use `if-let` when using Swift 5.3.
		if sourceAppUrl != nil {
			VStack(alignment: .leading) {
				Text("Source")
					.foregroundColor(.secondary)
					.font(.system(size: NSFont.smallSystemFontSize))
					.bold()
				HStack(spacing: 0) {
					URLIcon(url: sourceAppUrl!)
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
					"",
					// TODO: This should use `View#onChange` when targeting macOS 11.
					enumBinding: $selectedPasteboard.onChange { _ in
						self.selectedType = self.selectedPasteboard.types.first
						self.pasteboardObservable.pasteboard = self.selectedPasteboard.nsPasteboard
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
				// TODO: Make this `minWidth: 180` when SwiftUI is able to persist the sidebar size.
				.frame(minWidth: 200, maxWidth: 300)
			PasteboardContentsView(
				pasteboard: self.selectedPasteboard,
				type: self.selectedType
			)
		}
			.frame(minWidth: 500, minHeight: 300)
	}
}

struct ContentView_Previews: PreviewProvider {
	static var previews: some View {
		ContentView()
	}
}

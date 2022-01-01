import SwiftUI
import Defaults

@main
struct AppMain: App {
	@NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
	@StateObject private var appState = AppState()
	// TODO: `@Default` doesn't update the state in the menu. Probably a macOS 11 bug. (macOS 11.3)
	// @Default(.stayOnTop) private var stayOnTop
	@AppStorage(.stayOnTop) private var stayOnTop
	@State var window: NSWindow? // swiftlint:disable:this swiftui_state_private

	var body: some Scene {
		WindowGroup {
			ContentView()
				.environmentObject(appState)
				.onAppear(perform: onAppear)
				.bindNativeWindow($window)
				.windowTabbingMode(.disallowed)
				.windowLevel(stayOnTop ? .floating : .normal)
				.eraseToAnyView() // This fixes an issue where the window size is not persisted. (macOS 11.3)
		}
			.commands {
				// TODO: Remove this when SwiftUI support preventing the sidebar from being hidden.
				SidebarCommands()
				CommandGroup(replacing: .newItem) {}
				CommandGroup(after: .windowSize) {
					// TODO: Use Defaults.Toggle
					Toggle("Stay on Top", isOn: $stayOnTop)
				}
				CommandGroup(replacing: .help) {
					// TODO: `Link` doesn't yet work here. (macOS 11.3)
					// Link("Website", destination: "https://sindresorhus.com/pasteboard-viewer")
					Button("Website") {
						"https://sindresorhus.com/pasteboard-viewer".openUrl()
					}
					Button("Rate on the App Store") {
						"macappstore://apps.apple.com/app/id1499215709?action=write-review".openUrl()
					}
					Button("More Apps by Me") {
						"macappstore://apps.apple.com/developer/id328077650".openUrl()
					}
					Divider()
					Button("Send Feedback…") {
						SSApp.openSendFeedbackPage()
					}
				}
			}
	}

	private func onAppear() {
		DispatchQueue.main.async {
			showWelcomeScreenIfNeeded()
		}
	}
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
	func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

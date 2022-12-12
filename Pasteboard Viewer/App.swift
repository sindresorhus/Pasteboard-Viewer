import SwiftUI

/*
TODO when targeting macOS 13:
- Upload non-App Store version.
*/

@main
struct AppMain: App {
	@NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
	@StateObject private var appState = AppState()
	@State var hostingWindow: NSWindow? // swiftlint:disable:this swiftui_state_private

	var body: some Scene {
		WindowGroup {
			MainScreen()
				.environmentObject(appState)
				.task {
					DispatchQueue.main.async {
						showWelcomeScreenIfNeeded()
					}
				}
				.bindHostingWindow($hostingWindow)
				.eraseToAnyView() // This fixes an issue where the window size is not persisted. (macOS 12.1)
		}
			.commands {
				// TODO: Remove this when SwiftUI support preventing the sidebar from being hidden.
				SidebarCommands()
				CommandGroup(replacing: .newItem) {}
				CommandGroup(after: .windowSize) {
					Defaults.Toggle("Stay on Top", key: .stayOnTop)
						.keyboardShortcut("t", modifiers: [.control, .command])
				}
				CommandGroup(replacing: .help) {
					Link("Website", destination: "https://sindresorhus.com/pasteboard-viewer")
					Divider()
					Link("Rate on the App Store", destination: "macappstore://apps.apple.com/app/id1499215709?action=write-review")
					Link("More Apps by Me", destination: "macappstore://apps.apple.com/developer/id328077650")
					Divider()
					Button("Send Feedback…") {
						SSApp.openSendFeedbackPage()
					}
				}
			}
	}
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
	func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

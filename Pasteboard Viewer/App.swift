import SwiftUI

@main
struct AppMain: App {
	@StateObject private var appState = AppState()
	@State var hostingWindow: NSWindow? // swiftlint:disable:this swiftui_state_private

	init() {
		setUpConfig()
	}

	var body: some Scene {
		Window(SSApp.name, id: "main") {
			MainScreen()
				.environmentObject(appState)
				.task {
					DispatchQueue.main.async {
						showWelcomeScreenIfNeeded()
					}
				}
				.bindHostingWindow($hostingWindow)
				.eraseToAnyView() // This fixes an issue where the window size is not persisted. (macOS 13.1)
		}
			.commands {
				CommandGroup(replacing: .newItem) {}
				CommandGroup(after: .toolbar) {
					Defaults.Toggle("Show \"Clear Pasteboard\" Button", key: .showClearPasteboardButton)
					Divider()
				}
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

	private func setUpConfig() {
		UserDefaults.standard.register(
			defaults: [
				"NSApplicationCrashOnExceptions": true
			]
		)

		SSApp.initSentry("https://ded0fb3f6f7e4f0ca1f06048bfc26d57@o844094.ingest.sentry.io/6255818")
	}
}

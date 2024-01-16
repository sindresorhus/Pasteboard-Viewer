import SwiftUI

@main
struct AppMain: App {
	@State var hostingWindow: NSWindow? // swiftlint:disable:this swiftui_state_private

	init() {
		setUpConfig()

		DispatchQueue.main.async { [self] in
			didLaunch()
		}
	}

	var body: some Scene {
		Window(SSApp.name, id: "main") {
			MainScreen()
				.task {
					DispatchQueue.main.async {
						showWelcomeScreenIfNeeded()
					}
				}
				.bindHostingWindow($hostingWindow)
				.eraseToAnyView() // This fixes an issue where the window size is not persisted. (macOS 13.4)
		}
			.commands {
				CommandGroup(replacing: .newItem) {}
				CommandGroup(after: .windowSize) {
					Defaults.Toggle("Stay on Top", key: .stayOnTop)
						.keyboardShortcut("t", modifiers: [.control, .command])
				}
				CommandGroup(replacing: .help) {
					Link("Website", destination: "https://sindresorhus.com/pasteboard-viewer")
					Divider()
					Link("Rate App", destination: "macappstore://apps.apple.com/app/id1499215709?action=write-review")
					// TODO: Doesn't work. (macOS 14.2)
//					ShareLink("Share App", item: "https://apps.apple.com/app/id1499215709")
					Link("More Apps by Me", destination: "macappstore://apps.apple.com/developer/id328077650")
					Divider()
					Button("Send Feedback…") {
						SSApp.openSendFeedbackPage()
					}
				}
			}
	}

	private func didLaunch() {
		SSApp.requestReviewAfterBeingCalledThisManyTimes([3, 50, 200, 500, 100])
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

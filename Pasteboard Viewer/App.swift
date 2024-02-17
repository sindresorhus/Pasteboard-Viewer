import SwiftUI
import TipKit

/**
TODO iOS 18:
- Native visionOS version.
*/

@main
struct AppMain: App {
	#if os(macOS)
	@State var hostingWindow: NSWindow? // swiftlint:disable:this swiftui_state_private
	#endif

	init() {
		setUpConfig()

		DispatchQueue.main.async { [self] in
			didLaunch()
		}

		#if DEBUG
//		UIPasteboard.general.items = []
		#endif
	}

	var body: some Scene {
		WindowIfMacOS(SSApp.name, id: "main") {
			MainScreen()
				#if os(macOS)
				.task {
					DispatchQueue.main.async {
						showWelcomeScreenIfNeeded()
					}
				}
				.bindHostingWindow($hostingWindow)
				.eraseToAnyView() // This fixes an issue where the window size is not persisted. (macOS 13.4)
				#endif
		}
			.commands {
				CommandGroup(replacing: .newItem) {
					// TODO: Do this. I need to get the selected pasteboard.
//					ClearPasteboardButton()
				}
				#if os(macOS)
				CommandGroup(after: .windowSize) {
					Defaults.Toggle("Stay on Top", key: .stayOnTop)
						.keyboardShortcut("t", modifiers: [.control, .command])
				}
				#endif
				CommandGroup(replacing: .help) {
					Link("Website", destination: "https://sindresorhus.com/pasteboard-viewer")
					Divider()
					RateOnAppStoreButton(appStoreID: "1499215709")
					// TODO: Doesn't work. (macOS 14.3)
//					ShareAppButton(appStoreID: "1499215709")
					MoreAppsButton()
					Divider()
					SendFeedbackButton()
				}
			}
	}

	private func didLaunch() {}

	private func setUpConfig() {
		UserDefaults.standard.register(
			defaults: [
				"NSApplicationCrashOnExceptions": true
			]
		)

		SSApp.initSentry("https://ded0fb3f6f7e4f0ca1f06048bfc26d57@o844094.ingest.sentry.io/6255818")

		Defaults[.launchCount].increment()

		try? Tips.configure()
	}
}

import SwiftUI
import TipKit

/**
TODO iOS 28:
- Native visionOS version.
*/

@main
struct AppMain: App {
	#if os(macOS)
	@State var hostingWindow: NSWindow? // swiftlint:disable:this swiftui_state_private
	#endif

	@Default(.viewAsText) private var viewAsText

	init() {
		setUpConfig()

		Task { @MainActor [self] in
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
					showWelcomeScreenIfNeeded()
				}
				.bindHostingWindow($hostingWindow)
				.eraseToAnyView() // This fixes an issue where the window size is not persisted. (macOS 13.4)
				#endif
		}
		.commands {
			#if os(macOS)
			CommandGroup(after: .windowSize) {
				Defaults.Toggle("Stay on Top", systemImage: "pin", key: .stayOnTop)
					.keyboardShortcut("t", modifiers: [.control, .command])
			}
			CommandGroup(after: .toolbar) {
				FormatPickerView(selection: $viewAsText)
					.pickerStyle(.inline)
			}
			PasteboardCommands()
			#endif
			CommandGroup(replacing: .help) {
				Link("Website", systemImage: "safari", destination: "https://sindresorhus.com/pasteboard-viewer")
				Divider()
				RateOnAppStoreButton(appStoreID: "1499215709")
				ShareAppButton(appStoreID: "1499215709")
				MoreAppsButton()
				Divider()
				AppLicensesButton()
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

		SSApp.setUpExternalEventListeners()

		Defaults[.launchCount].increment()

		try? Tips.configure()
	}
}

#if os(macOS)
struct FormatPickerView: View {
	@Binding var selection: Bool
	
	var body: some View {
		Picker("View As", selection: $selection) {
			Label("Text", systemImage: "textformat")
				.tag(true)
				.help("View as text")
				.keyboardShortcut("1")
			Label("Hex", systemImage: "number")
				.tag(false)
				.help("View as hex")
				.keyboardShortcut("2")
		}
	}
}

struct PasteboardCommands: Commands {
	var body: some Commands {
		CommandMenu("Pasteboard") {
			PasteboardMenuView()
		}
	}
}

private struct PasteboardMenuView: View {
	@FocusedBinding(\.selectedPasteboard) private var selectedPasteboard
	
	var body: some View {
		if selectedPasteboard != nil {
			Picker(
				"Switch",
				selection: .init(
					get: { selectedPasteboard ?? .general },
					set: { selectedPasteboard = $0 }
				)
			) {
				ForEach(Pasteboard.allCases, id: \.self) { pasteboard in
					Label(pasteboard.xPasteboard.presentableName, systemImage: icon(for: pasteboard))
						.tag(pasteboard)
						.keyboardShortcut(key(for: pasteboard), modifiers: [.control])
				}
			}
			.pickerStyle(.inline)
			Section {
				ClearPasteboardButton()
			}
		}
	}
	
	private func key(for pasteboard: Pasteboard) -> KeyEquivalent {
		switch pasteboard {
		case .general:
			"1"
		case .drag:
			"2"
		case .find:
			"3"
		case .font:
			"4"
		case .ruler:
			"5"
		}
	}
	
	private func icon(for pasteboard: Pasteboard) -> String {
		switch pasteboard {
		case .general:
			"doc.on.clipboard"
		case .drag:
			"hand.draw"
		case .find:
			"magnifyingglass"
		case .font:
			"textformat"
		case .ruler:
			"ruler"
		}
	}
}
#endif

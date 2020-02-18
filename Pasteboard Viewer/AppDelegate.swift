import Cocoa
import SwiftUI
import AppCenter
import AppCenterCrashes
import Defaults

@NSApplicationMain
final class AppDelegate: NSObject, NSApplicationDelegate {
	var window: NSWindow!

	func applicationWillFinishLaunching(_ notification: Notification) {
		UserDefaults.standard.register(
			defaults: [
				"NSApplicationCrashOnExceptions": true
			]
		)
	}

	func applicationDidFinishLaunching(_ notification: Notification) {
		MSAppCenter.start(
			"3da13331-e82c-4245-b7fa-023424c17f16",
			withServices: [
				MSCrashes.self
			]
		)

		let contentView = ContentView()

		window = NSWindow(
			contentRect: CGRect(x: 0, y: 0, width: 600, height: 400),
			styleMask: [
				.titled,
				.closable,
				.miniaturizable,
				.resizable,
				.fullSizeContentView
			],
			backing: .buffered,
			defer: false
		)

		window.title = App.name
		window.tabbingMode = .disallowed
		window.center()
		window.setFrameAutosaveName("Main Window")
		window.contentView = NSHostingView(rootView: contentView)

		setUpEvents()

		window.makeKeyAndOrderFront(nil)
	}

	func setUpEvents() {
		Defaults.observe(.stayInFront) {
			self.window.level = $0.newValue ? .floating : .normal
		}
			.tieToLifetime(of: self)
	}

	func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

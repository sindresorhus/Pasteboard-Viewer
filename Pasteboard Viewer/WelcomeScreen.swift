import Cocoa

// TODO: Make a proper welcome window.

extension AppMain {
	func showWelcomeScreenIfNeeded() {
		guard SSApp.isFirstLaunch else {
			return
		}

		NSApp.activate(ignoringOtherApps: true)

		NSAlert.showModal(
			for: hostingWindow,
			title: "Welcome to Pasteboard Viewer!",
			message:
				"""
				If you have any feedback, bug reports, or feature requests, use the feedback button in the “Help” menu. I quickly respond to all submissions.
				""",
			buttonTitles: [
				"Get Started"
			],
			defaultButtonIndex: -1
		)
	}
}

import Cocoa

// TODO: Make a proper welcome window.

extension AppMain {
	func showWelcomeScreenIfNeeded() {
		guard SSApp.isFirstLaunch else {
			return
		}

		NSApp.activate(ignoringOtherApps: true)

		// TODO: Remove the crash warning at some point.

		NSAlert.showModal(
			for: window,
			title: "Welcome to Pasteboard Viewer!",
			message:
				"""
				Please note that Pasteboard Viewer can sometimes crash. This is a macOS bug that I cannot work around.

				(Technical reason: SwiftUI internally crashes NSOutlineView)
				""",
			buttonTitles: [
				"Continue"
			],
			defaultButtonIndex: -1
		)

		NSAlert.showModal(
			for: window,
			title: "Feedback Welcome",
			message:
				"""
				If you have any feedback, bug reports, or feature requests, use the feedback button in the “Help” menu. I quickly respond to all submissions.
				""",
			buttonTitles: [
				"Get Started"
			]
		)
	}
}

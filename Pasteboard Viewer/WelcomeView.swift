import Cocoa

extension AppDelegate {
	func showWelcomeScreenIfNeeded() {
		guard SSApp.isFirstLaunch else {
			return
		}

		NSAlert.showModal(
			for: window,
			message: "Welcome to Pasteboard Viewer!",
			informativeText:
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
			message: "Feedback Welcome 🙌🏻",
			informativeText:
				"""
				If you have any feedback, bug reports, or feature requests, kindly use the “Send Feedback” button in the “Help” menu. I respond to all submissions. It's preferable that you report bugs this way rather than as an App Store review, since the App Store will not allow me to contact you for more information.
				""",
			buttonTitles: [
				"Get Started"
			]
		)
	}
}

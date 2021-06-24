import Combine
import AppCenter
import AppCenterCrashes

final class AppState: ObservableObject {
	init() {
		setUpConfig()
		DispatchQueue.main.async(execute: didLaunch)
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

		AppCenter.start(
			withAppSecret: "3da13331-e82c-4245-b7fa-023424c17f16",
			services: [
				Crashes.self
			]
		)
	}
}

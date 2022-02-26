import SwiftUI
import Sentry

@MainActor
final class AppState: ObservableObject {
	init() {
		setUpConfig()

		DispatchQueue.main.async { [self] in
			didLaunch()
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

		#if !DEBUG
		SentrySDK.start {
			$0.dsn = "https://ded0fb3f6f7e4f0ca1f06048bfc26d57@o844094.ingest.sentry.io/6255818"
			$0.enableSwizzling = false
		}
		#endif
	}
}

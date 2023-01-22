import SwiftUI

@MainActor
final class AppState: ObservableObject {
	init() {
		DispatchQueue.main.async { [self] in
			didLaunch()
		}
	}

	private func didLaunch() {
		SSApp.requestReviewAfterBeingCalledThisManyTimes([3, 50, 200, 500, 100])
	}
}

import SwiftUI
import Combine

struct ContentView: View {
	@ObservedObject private var pasteboardObservable = NSPasteboard.Observable(.general)
	@State private var selectedPasteboard = Pasteboard.general
	@State private var selectedType: Pasteboard.PasteboardType?

	// This is a workaround for a SwiftUI bug where it crashes in NSOutlineView if you change from 16 to 15 elements in the list. We work around that by clearing the list first if the count changed.
	@State private var previousChangeCount = 0
	private var types: [Pasteboard.PasteboardType] {
		let changeCount = selectedPasteboard.nsPasteboard.changeCount

		DispatchQueue.main.async {
			if
				self.selectedType == nil
					|| (!self.selectedPasteboard.types.contains { $0 == self.selectedType }
			) {
				self.selectedType = self.selectedPasteboard.types.first
			}

			self.previousChangeCount = changeCount
		}

		return changeCount != previousChangeCount ? [] : selectedPasteboard.types
	}

	private func setWindowTitle() {
		AppDelegate.shared.window.title = selectedType?.title ?? App.name
	}

	var body: some View {
		setWindowTitle()

		// TODO: Set the sidebar to not be collapsible when SwiftUI supports that.
		return NavigationView {
			VStack(alignment: .leading) {
				EnumPicker(
					"",
					enumBinding: $selectedPasteboard.onChange { _ in
						self.selectedType = self.selectedPasteboard.types.first
						self.pasteboardObservable.pasteboard = self.selectedPasteboard.nsPasteboard
					}
				) { pasteboard, _ in
					Text(pasteboard.nsPasteboard.presentableName)
				}
					.labelsHidden()
					.padding()
				List(selection: $selectedType) {
					// The `Divider` is a workaround for SwiftUI bug where the selection highlight for the first element in the list would dissapear in some cases when the view is updated, for example, when you copy something new to the pasteboard.
					Divider()
						.opacity(0)
					ForEach(types, id: \.self) {
						Text($0.title)
							.frame(maxWidth: .infinity, alignment: .leading)
					}
						// Works around the sidebar not getting focus at launch.
						.forceFocus()
				}
					.listStyle(SidebarListStyle())
					.padding(.top, -22) // Workaround for SwiftUI bug.
			}
				// TODO: Make this `minWidth: 180` when SwiftUI is able to persist the sidebar size.
				.frame(minWidth: 200, maxWidth: 300)
			PasteboardContentsView(
				pasteboard: self.selectedPasteboard,
				type: self.selectedType
			)
		}
			.frame(minWidth: 500, minHeight: 300)
	}
}

struct ContentView_Previews: PreviewProvider {
	static var previews: some View {
		ContentView()
	}
}

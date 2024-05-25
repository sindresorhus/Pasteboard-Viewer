import SwiftUI
import Combine
import UniformTypeIdentifiers
import QuickLook
import Defaults
import Collections
//import Sentry

#if os(macOS)
import Quartz
#endif

#if os(macOS)
typealias WindowIfMacOS = Window
typealias XPasteboard = NSPasteboard
typealias XPasteboardItem = NSPasteboardItem
typealias XImage = NSImage
#else
typealias WindowIfMacOS = WindowGroup
typealias XPasteboard = UIPasteboard
typealias XPasteboardItem = UIPasteboardItem
typealias XImage = UIImage
#endif

typealias Defaults = _Defaults
typealias Default = _Default
typealias AnyCancellable = Combine.AnyCancellable


final class ObjectAssociation<T> {
	subscript(index: AnyObject) -> T? {
		get {
			objc_getAssociatedObject(index, Unmanaged.passUnretained(self).toOpaque()) as! T?
		} set {
			objc_setAssociatedObject(index, Unmanaged.passUnretained(self).toOpaque(), newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
		}
	}
}


extension AnyCancellable {
	private static var foreverStore = Set<AnyCancellable>()

	func storeForever() {
		store(in: &Self.foreverStore)
	}
}


enum SSApp {
	static let idString = Bundle.main.bundleIdentifier!
	static let name = Bundle.main.object(forInfoDictionaryKey: kCFBundleNameKey as String) as! String
	static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
	static let build = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as! String
	static let versionWithBuild = "\(version) (\(build))"

	static let isFirstLaunch: Bool = {
		let key = "SS_hasLaunched"

		if UserDefaults.standard.bool(forKey: key) {
			return false
		}

		UserDefaults.standard.set(true, forKey: key)
		return true
	}()
}


extension SSApp {
	static let debugInfo =
		"""
		\(name) \(versionWithBuild) - \(idString)
		macOS \(System.osVersion)
		\(System.hardwareModel)
		"""

	/**
	- Note: Call this lazily only when actually needed as otherwise it won't get the live info.
	*/
	static func appFeedbackUrl() -> URL {
		let query: [String: String] = [
			"product": name,
			"metadata": debugInfo
		]

		return URL(string: "https://sindresorhus.com/feedback")!.addingDictionaryAsQuery(query)
	}
}


extension SSApp {
	/**
	Initialize Sentry.
	*/
	static func initSentry(_ dsn: String) {
		#if !DEBUG && canImport(Sentry)
		SentrySDK.start {
			$0.dsn = dsn
			$0.enableSwizzling = false
			$0.enableAppHangTracking = false // https://github.com/getsentry/sentry-cocoa/issues/2643
		}
		#endif
	}
}


extension SSApp {
	static func setUpExternalEventListeners() {
		#if os(macOS)
		DistributedNotificationCenter.default.publisher(for: .init("\(SSApp.idString):openSendFeedback"))
			.sink { _ in
				DispatchQueue.main.async {
					SSApp.appFeedbackUrl().open()
				}
			}
			.storeForever()

		DistributedNotificationCenter.default.publisher(for: .init("\(SSApp.idString):copyDebugInfo"))
			.sink { _ in
				DispatchQueue.main.async {
					NSPasteboard.general.prepareForNewContents()
					NSPasteboard.general.setString(SSApp.debugInfo, forType: .string)
				}
			}
			.storeForever()
		#endif
	}
}


extension URL {
	func open() {
		#if os(macOS)
		NSWorkspace.shared.open(self)
		#elseif !APP_EXTENSION
		Task { @MainActor in
			UIApplication.shared.open(self)
		}
		#endif
	}
}

extension String {
	/*
	```
	"https://sindresorhus.com".openURL()
	```
	*/
	func openURL() {
		URL(string: self)?.open()
	}
}


struct SendFeedbackButton: View {
	var body: some View {
		Link(
			"Feedback & Support",
			systemImage: "exclamationmark.bubble",
			destination: SSApp.appFeedbackUrl()
		)
	}
}


struct MoreAppsButton: View {
	var body: some View {
		Link(
			"More Apps by Me",
			systemImage: "app.dashed",
			destination: "itms-apps://apps.apple.com/developer/id328077650"
		)
	}
}


struct ShareAppButton: View {
	let appStoreID: String

	var body: some View {
		ShareLink("Share App", item: "https://apps.apple.com/app/id\(appStoreID)")
	}
}


struct RateOnAppStoreButton: View {
	let appStoreID: String

	var body: some View {
		Link(
			"Rate App",
			systemImage: "star",
			destination: URL(string: "itms-apps://apps.apple.com/app/id\(appStoreID)?action=write-review")!
		)
	}
}


struct AppLicensesButton: View {
	var body: some View {
		NavigationLink {
			AppLicensesScreen()
		} label: {
			Label("Licenses", systemImage: "scroll")
		}
	}
}

private struct AppLicensesScreen: View {
	var body: some View {
		ScrollView {
			let url = Bundle.main.url(forResource: "Licenses", withExtension: "txt")!
			Text(try! String(contentsOf: url, encoding: .utf8))
		}
		.contentMargins(16, for: .scrollContent)
		.navigationTitle("Licenses")
		.toolbarTitleDisplayMode(.inline)
		#if os(macOS)
		.frame(minWidth: 300, minHeight: 300)
		#endif
	}
}


private func escapeQuery(_ query: String) -> String {
	// From RFC 3986
	let generalDelimiters = ":#[]@"
	let subDelimiters = "!$&'()*+,;="

	var allowedCharacters = CharacterSet.urlQueryAllowed
	allowedCharacters.remove(charactersIn: generalDelimiters + subDelimiters)
	return query.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? query
}


extension Dictionary where Key: ExpressibleByStringLiteral, Value: ExpressibleByStringLiteral {
	var asQueryItems: [URLQueryItem] {
		map {
			URLQueryItem(
				name: escapeQuery($0 as! String),
				value: escapeQuery($1 as! String)
			)
		}
	}

	var asQueryString: String {
		var components = URLComponents()
		components.queryItems = asQueryItems
		return components.query!
	}
}


extension URLComponents {
	mutating func addDictionaryAsQuery(_ dict: [String: String]) {
		percentEncodedQuery = dict.asQueryString
	}
}


extension URL {
	func addingDictionaryAsQuery(_ dict: [String: String]) -> Self {
		var components = URLComponents(url: self, resolvingAgainstBaseURL: false)!
		components.addDictionaryAsQuery(dict)
		return components.url ?? self
	}
}


enum System {
	static let osVersion: String = {
		let os = ProcessInfo.processInfo.operatingSystemVersion
		return "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
	}()

	static let hardwareModel: String = {
		var size = 0
		sysctlbyname("hw.model", nil, &size, nil, 0)
		var model = [CChar](repeating: 0, count: size)
		sysctlbyname("hw.model", &model, &size, nil, 0)
		return String(cString: model)
	}()
}


/**
Useful in SwiftUI:

```
ForEach(persons.indexed(), id: \.1.id) { index, person in
	// …
}
```
*/
struct IndexedCollection<Base: RandomAccessCollection>: RandomAccessCollection {
	typealias Index = Base.Index
	typealias Element = (index: Index, element: Base.Element)

	let base: Base
	var startIndex: Index { base.startIndex }
	var endIndex: Index { base.endIndex }

	func index(after index: Index) -> Index {
		base.index(after: index)
	}

	func index(before index: Index) -> Index {
		base.index(before: index)
	}

	func index(_ index: Index, offsetBy distance: Int) -> Index {
		base.index(index, offsetBy: distance)
	}

	subscript(position: Index) -> Element {
		(index: position, element: base[position])
	}
}

extension RandomAccessCollection {
	func indexed() -> IndexedCollection<Self> {
		IndexedCollection(base: self)
	}
}


extension Binding where Value: CaseIterable & Equatable {
	/**
	```
	enum Priority: String, CaseIterable {
		case no
		case low
		case medium
		case high
	}

	// …

	Picker("Priority", selection: $priority.caseIndex) {
		ForEach(Priority.allCases.indices) { priorityIndex in
			Text(
				Priority.allCases[priorityIndex].rawValue.capitalized
			)
			.tag(priorityIndex)
		}
	}
	```
	*/
	var caseIndex: Binding<Value.AllCases.Index> {
		.init(
			get: { Value.allCases.firstIndex(of: wrappedValue)! },
			set: { wrappedValue = Value.allCases[$0] }
		)
	}
}


struct EnumPicker<Enum, Label, Content>: View where Enum: CaseIterable & Equatable, Enum.AllCases.Index: Hashable, Label: View, Content: View {
	let selection: Binding<Enum>
	@ViewBuilder let content: (Enum) -> Content
	@ViewBuilder let label: () -> Label

	var body: some View {
		Picker(selection: selection.caseIndex) {
			ForEach(Array(Enum.allCases).indexed(), id: \.0) { index, element in
				content(element)
					.tag(index)
			}
		} label: {
			label()
		}
	}
}

extension EnumPicker where Label == Text {
	init(
		_ title: some StringProtocol,
		selection: Binding<Enum>,
		@ViewBuilder content: @escaping (Enum) -> Content
	) {
		self.selection = selection
		self.content = content
		self.label = { Text(title) }
	}
}


extension Link<Label<Text, Image>> {
	init(
		_ title: String,
		systemImage: String,
		destination: URL
	) {
		self.init(destination: destination) {
			Label(title, systemImage: systemImage)
		}
	}
}


#if os(macOS)
/**
A scrollable and and optionally editable text view.

- Note: This exist as the SwiftUI `TextField` is unusable for multiline purposes.

It supports the `.lineLimit()` view modifier.

```
struct ContentView: View {
	@State private var text = ""

	var body: some View {
		VStack {
			Text("Custom CSS:")
			ScrollableTextView(text: $text)
				.frame(height: 100)
		}
	}
}
```
*/
struct ScrollableTextView: NSViewRepresentable {
	typealias NSViewType = NSScrollView

	final class Coordinator: NSObject, NSTextViewDelegate {
		var view: ScrollableTextView

		init(_ view: ScrollableTextView) {
			self.view = view
		}

		func textDidChange(_ notification: Notification) {
			guard let textView = notification.object as? NSTextView else {
				return
			}

			view.text = textView.string
		}
	}

	@Binding var text: String
	var font = NSFont.controlContentFont(ofSize: 0)
	var borderType = NSBorderType.bezelBorder
	var drawsBackground = true
	var isEditable = false

	func makeCoordinator() -> Coordinator {
		Coordinator(self)
	}

	func makeNSView(context: Context) -> NSViewType {
		let scrollView = NSTextView.scrollableTextView()

		let textView = scrollView.documentView as! NSTextView
		textView.delegate = context.coordinator
		textView.drawsBackground = false
		textView.isSelectable = true
		textView.allowsUndo = true
		textView.textContainerInset = CGSize(width: 5, height: 10)
		textView.usesAdaptiveColorMappingForDarkAppearance = true

		return scrollView
	}

	func updateNSView(_ nsView: NSViewType, context: Context) {
		nsView.borderType = borderType
		nsView.drawsBackground = drawsBackground

		let textView = (nsView.documentView as! NSTextView)
		textView.isEditable = isEditable
		textView.font = font

		if text != textView.string {
			textView.string = text
		}

		if let lineLimit = context.environment.lineLimit {
			textView.textContainer?.maximumNumberOfLines = lineLimit
		}
	}
}
#else
enum _Internal_BorderType: Sendable {
	case bezelBorder
	case grooveBorder
	case lineBorder
	case noBorder
}

struct ScrollableTextView: UIViewRepresentable {
	typealias UIViewType = UITextView

	final class Coordinator: NSObject, UITextViewDelegate {
		var parent: ScrollableTextView

		init(_ parent: ScrollableTextView) {
			self.parent = parent
		}

		func textViewDidChange(_ textView: UITextView) {
			parent.text = textView.text
		}
	}

	@Binding var text: String
	var font = UIFont.preferredFont(forTextStyle: .body)
	var borderType = _Internal_BorderType.bezelBorder
	var isEditable = false
	var backgroundColor: UIColor?

	func makeCoordinator() -> Coordinator {
		Coordinator(self)
	}

	func makeUIView(context: Context) -> UITextView {
		let textView = UITextView()
		textView.delegate = context.coordinator
		textView.textContainerInset = .init(top: 10, left: 5, bottom: 10, right: 5)
		return textView
	}

	func updateUIView(_ uiView: UITextView, context: Context) {
		uiView.text = text
		uiView.font = font
		uiView.isEditable = isEditable
		uiView.backgroundColor = backgroundColor
	}
}
#endif


#if os(macOS)
struct ScrollableAttributedTextView: NSViewRepresentable {
	typealias NSViewType = NSScrollView

	var attributedText: NSAttributedString?
	var font: NSFont?
	var borderType = NSBorderType.bezelBorder
	var backgroundColor: NSColor?
	var drawsBackground = true
	var isEditable = false

	func makeNSView(context: Context) -> NSViewType {
		let scrollView = NSTextView.scrollableTextView()

		let textView = scrollView.documentView as! NSTextView
		textView.drawsBackground = false
		textView.isSelectable = true
		textView.textContainerInset = CGSize(width: 5, height: 10)
		textView.textColor = .controlTextColor
		textView.usesAdaptiveColorMappingForDarkAppearance = true

		return scrollView
	}

	func updateNSView(_ nsView: NSViewType, context: Context) {
		nsView.borderType = borderType
		nsView.drawsBackground = drawsBackground

		let textView = (nsView.documentView as! NSTextView)
		textView.isEditable = isEditable
		textView.backgroundColor = backgroundColor ?? NSTextView().backgroundColor

		if
			let attributedText,
			attributedText != textView.attributedString()
		{
			textView.textStorage?.setAttributedString(attributedText)
		}

		if let font {
			textView.font = font
		}

		if let lineLimit = context.environment.lineLimit {
			textView.textContainer?.maximumNumberOfLines = lineLimit
		}
	}
}
#else
struct ScrollableAttributedTextView: UIViewRepresentable {
	typealias UIViewType = UITextView

	var attributedText: NSAttributedString?
	var font: UIFont?
	var borderType = _Internal_BorderType.bezelBorder
	var backgroundColor: UIColor?
	var isEditable = false

	func makeUIView(context: Context) -> UIViewType {
		let textView = UITextView()
		textView.textContainerInset = .init(top: 10, left: 5, bottom: 10, right: 5)
		return textView
	}

	func updateUIView(_ uiView: UIViewType, context: Context) {
		uiView.backgroundColor = backgroundColor
		uiView.isEditable = isEditable

		if
			let attributedText,
			attributedText != uiView.attributedText
		{
			uiView.attributedText = attributedText
		}

		if let font {
			uiView.font = font
		}

		if let lineLimit = context.environment.lineLimit {
			uiView.textContainer.maximumNumberOfLines = lineLimit
		}
	}
}
#endif


#if canImport(UIKit)
@available(iOSApplicationExtension, unavailable)
@available(tvOSApplicationExtension, unavailable)
@available(visionOSApplicationExtension, unavailable)
extension SSApp {
	private static var settingsUrl = URL(string: UIApplication.openSettingsURLString)!

	/**
	Whether the settings view in Settings for the current app exists and can be opened.
	*/
	static var canOpenSettings = UIApplication.shared.canOpenURL(settingsUrl)

	/**
	Open the settings view in Settings for the current app.

	- Important: Ensure you use `.canOpenSettings`.
	*/
	@MainActor
	static func openSettings() async {
		settingsUrl.open()
	}
}

/**
Open the settings view in Settings for this app.

The button is only visible if the settings view exists and can be opened.
*/
struct OpenAppSettingsButton: View {
	private static let settingsUrl = URL(string: UIApplication.openSettingsURLString)!

	let title: String

	var body: some View {
		if SSApp.canOpenSettings {
			Link(title, destination: Self.settingsUrl)
		}
	}
}
#endif


extension View {
	/**
	Returns a type-erased version of `self`.

	- Important: Use `Group` instead whenever possible!
	*/
	func eraseToAnyView() -> AnyView {
		AnyView(self)
	}
}


#if os(macOS)
extension NSPasteboard {
	/**
	Human-readable name of the pasteboard.
	*/
	var presentableName: String {
		switch name {
		case .general:
			"General"
		case .drag:
			"Drag"
		case .find:
			"Find"
		case .font:
			"Font"
		case .ruler:
			"Ruler"
		default:
			String(describing: self)
		}
	}
}
#endif


extension BinaryInteger {
	var boolValue: Bool { self != 0 }
}


#if os(macOS)
extension NSRunningApplication {
	/**
	Like `.localizedName` but guaranteed to return something useful even if the name is not available.
	*/
	var localizedTitle: String {
		localizedName
			?? executableURL?.deletingPathExtension().lastPathComponent
			?? bundleURL?.deletingPathExtension().lastPathComponent
			?? bundleIdentifier
			?? (processIdentifier == -1 ? nil : "PID\(processIdentifier)")
			?? "<Unknown>"
	}
}
#endif


#if os(macOS)
/**
Static representation of a window.

- Note: The `name` property is always `nil` on macOS 10.15 and later unless you request “Screen Recording” permission.
*/
struct WindowInfo {
	struct Owner {
		let name: String
		let processIdentifier: Int
		let bundleIdentifier: String?
		let app: NSRunningApplication?
	}

	// Most of these keys are guaranteed to exist: https://developer.apple.com/documentation/coregraphics/quartz_window_services/required_window_list_keys

	let identifier: CGWindowID
	let name: String?
	let owner: Owner
	let bounds: CGRect
	let layer: Int
	let alpha: Double
	let memoryUsage: Int
	let sharingState: CGWindowSharingType // https://stackoverflow.com/questions/27695742/what-does-kcgwindowsharingstate-actually-do
	let isOnScreen: Bool
	let fillsScreen: Bool

	/**
	Accepts a window dictionary coming from `CGWindowListCopyWindowInfo`.
	*/
	private init(windowDictionary window: [String: Any]) {
		self.identifier = window[kCGWindowNumber as String] as! CGWindowID
		self.name = window[kCGWindowName as String] as? String

		let processIdentifier = window[kCGWindowOwnerPID as String] as! Int
		let app = NSRunningApplication(processIdentifier: pid_t(processIdentifier))

		self.owner = Owner(
			name: window[kCGWindowOwnerName as String] as? String ?? app?.localizedTitle ?? "<Unknown>",
			processIdentifier: processIdentifier,
			bundleIdentifier: app?.bundleIdentifier,
			app: app
		)

		let bounds = CGRect(dictionaryRepresentation: window[kCGWindowBounds as String] as! CFDictionary)!

		self.bounds = bounds
		self.layer = window[kCGWindowLayer as String] as! Int
		self.alpha = window[kCGWindowAlpha as String] as! Double
		self.memoryUsage = window[kCGWindowMemoryUsage as String] as? Int ?? 0
		self.sharingState = CGWindowSharingType(rawValue: window[kCGWindowSharingState as String] as! UInt32)!
		self.isOnScreen = (window[kCGWindowIsOnscreen as String] as? Int)?.boolValue ?? false
		self.fillsScreen = NSScreen.screens.contains { $0.frame == bounds }
	}
}

extension WindowInfo {
	typealias Filter = (Self) -> Bool

	private static let appIgnoreList = [
		"com.apple.dock",
		"com.apple.notificationcenterui",
		"com.apple.screencaptureui",
		"com.apple.PIPAgent",
		"com.sindresorhus.Pasteboard-Viewer",
		"co.hypercritical.SwitchGlass", // Dock replacement
		"app.macgrid.Grid", // https://macgrid.app
		"com.edge.LGCatalyst", // https://apps.apple.com/app/id1602004436 - It adds a floating player.
		"com.replay.sleeve" // https://replay.software/sleeve - It adds a floating player.
	]

	/**
	Filters out fully transparent windows and windows smaller than 50 width or height.
	*/
	static func defaultFilter(window: Self) -> Bool {
		let minimumWindowSize = 50.0

		// Skip windows outside the expected level range.
		guard
			window.layer < NSWindow.Level.mainMenu.rawValue,
			window.layer >= NSWindow.Level.normal.rawValue
		else {
			return false
		}

		// Skip fully transparent windows, like with Chrome.
		// We consider everything below 0.2 to be fully transparent.
		guard window.alpha > 0.2 else {
			return false
		}

		if
			window.alpha < 0.5,
			window.fillsScreen
		{
			return false
		}

		// Skip tiny windows, like the Chrome link hover statusbar.
		guard
			window.bounds.width >= minimumWindowSize,
			window.bounds.height >= minimumWindowSize
		else {
			return false
		}

		// You might think that we could simply skip windows that are `window.owner.app?.activationPolicy != .regular`, but menu bar apps are `.accessory`, and they might be the source of some copied data.
		guard !window.owner.name.lowercased().hasSuffix("agent") else {
			return false
		}

		if let bundleIdentifier = window.owner.bundleIdentifier {
			if Self.appIgnoreList.contains(bundleIdentifier) {
				return false
			}

			let frontmostApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
			let grammarly = "com.grammarly.ProjectLlama"

			// Grammarly puts some hidden window above all other windows. Ignore that.
			if
				bundleIdentifier == grammarly,
				frontmostApp != grammarly
			{
				return false
			}
		}

		return true
	}

	static func allWindows(
		options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements],
		filter: Filter = defaultFilter
	) -> [Self] {
		let info = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
		return info.map { self.init(windowDictionary: $0) }.filter(filter)
	}
}

extension WindowInfo {
	struct UserApp: Hashable, Identifiable {
		let url: URL
		let bundleIdentifier: String

		var id: URL { url }
	}

	/**
	Returns the URL and bundle identifier of the app that owns the frontmost window.

	This method returns more correct results than `NSWorkspace.shared.frontmostApplication?.bundleIdentifier`. For example, the latter cannot correctly detect the 1Password Mini window.
	*/
	static func appOwningFrontmostWindow() -> UserApp? {
		func createApp(_ runningApp: NSRunningApplication?) -> UserApp? {
			guard
				let runningApp,
				let url = runningApp.bundleURL,
				let bundleIdentifier = runningApp.bundleIdentifier
			else {
				return nil
			}

			return UserApp(url: url, bundleIdentifier: bundleIdentifier)
		}

		guard
			let app = (
				allWindows()
					// TODO: Use `.firstNonNil()` here when available.
					.lazy
					.compactMap { createApp($0.owner.app) }
					.first
			)
		else {
			return createApp(NSWorkspace.shared.frontmostApplication)
		}

		return app
	}
}
#endif


extension XPasteboard.PasteboardType {
	/**
	Convention for getting the bundle identifier of the source app.

	> This marker’s presence indicates that the source of the content is the application with the bundle identifier matching its UTF–8 string content. For example: `pasteboard.setString("com.sindresorhus.Foo" forType: "org.nspasteboard.source")`. This is useful when the source is not the foreground application. This is meant to be shown to the user by a supporting app for informational purposes only. Note that an empty string is a valid value as explained below.
	> - http://nspasteboard.org
	*/
	static let sourceAppBundleIdentifier = Self("org.nspasteboard.source")
}


extension XPasteboard {
	/**
	Information about the pasteboard contents.
	*/
	struct ContentsInfo: Equatable, Identifiable {
		let id = UUID()

		/**
		The date when the current pasteboard data was added.
		*/
		let created = Date()

		/**
		The bundle identifier of the app that put the data on the pasteboard.
		*/
		let sourceAppBundleIdentifier: String?

		/**
		The URL of the app that put the data on the pasteboard.

		- Note: Don't assume this is non-optional if `sourceAppBundleIdentifier` is.
		*/
		let sourceAppURL: URL?
	}

	/**
	Returns a publisher that emits when the pasteboard changes.
	*/
	var publisher: some Publisher<ContentsInfo, Never> {
		#if os(macOS)
		var isFirst = true

		return Timer.publish(every: 0.2, tolerance: 0.1, on: .main, in: .common)
			.autoconnect()
			.prepend([Date()]) // We want the publisher to also emit immediately when someone subscribes.
			.compactMap { [weak self] _ in
				self?.changeCount
			}
			.removeDuplicates()
			.compactMap { [weak self] _ -> ContentsInfo? in
				defer {
					if isFirst {
						isFirst = false
					}
				}

				guard
					let self,
					let source = string(forType: .sourceAppBundleIdentifier)
				else {
					// We ignore the first event in this case as we cannot know if the existing pasteboard contents came from the frontmost app.
					guard !isFirst else {
						return nil
					}

					let app = WindowInfo.appOwningFrontmostWindow()

					return ContentsInfo(
						sourceAppBundleIdentifier: app?.bundleIdentifier,
						sourceAppURL: app?.url
					)
				}

				guard !source.isEmpty else {
					// An empty string has special behavior ( http://nspasteboard.org ).
					// > In case the original source of the content is not known, set `org.nspasteboard.source` to the empty string.
					return ContentsInfo(
						sourceAppBundleIdentifier: nil,
						sourceAppURL: nil
					)
				}

				return ContentsInfo(
					sourceAppBundleIdentifier: source,
					sourceAppURL: NSWorkspace.shared.urlForApplication(withBundleIdentifier: source)
				)
			}
		#else
		Publishers.Merge3(
			// We have to do this for iPad split-view as `XPasteboard.changedNotification` does not fire when the app is not focused.
			Timer.publish(every: 0.2, tolerance: 0.1, on: .main, in: .common)
				.autoconnect()
				.prepend([Date()]) // We want the publisher to also emit immediately when someone subscribes.
				.compactMap { [weak self] _ in
					self?.changeCount
				}
				.removeDuplicates()
				.map { _ in },
			NotificationCenter.default.publisher(for: XPasteboard.changedNotification)
				.map { _ in },
			NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
				.map { _ in }
		)
		.map { _ in
			ContentsInfo(sourceAppBundleIdentifier: nil, sourceAppURL: nil)
		}
		#endif
	}
}

extension XPasteboard {
	/**
	An observable object that publishes updates when the given pasteboard changes.
	*/
	@MainActor
	final class Observable: ObservableObject {
		private var cancellable: AnyCancellable?

		@Published var pasteboard: XPasteboard {
			didSet {
				start()
			}
		}

		@Published var info: ContentsInfo?

		private func start() {
			cancellable = pasteboard.publisher.sink { [weak self] in
				guard let self else {
					return
				}

				info = $0
			}
		}

		init(_ pasteboard: XPasteboard) {
			self.pasteboard = pasteboard
			start()
		}
	}
}


extension XPasteboard {
	func clear() {
		#if os(macOS)
		clearContents()
		#else
		items = []
		#endif
	}
}


extension XPasteboard {
	var itemCount: Int {
		#if os(macOS)
		pasteboardItems?.count ?? 0
		#else
		numberOfItems
		#endif
	}

	var isEmpty: Bool { itemCount == 0 }
}


#if os(macOS)
struct QuickLookPreview: NSViewRepresentable {
	typealias NSViewType = QLPreviewView

	static func dismantleNSView(_ nsView: QLPreviewView, coordinator: Coordinator) {
		nsView.close()

		if
			coordinator.parent.shouldCleanUp,
			let url = coordinator.parent.previewItem.previewItemURL
		{
			DispatchQueue.global(qos: .utility).async {
				try? FileManager.default.removeItem(at: url)
			}
		}
	}

	fileprivate var shouldCleanUp = false

	let previewItem: QLPreviewItem

	func makeNSView(context: Context) -> NSViewType {
		let nsView = NSViewType()
		nsView.shouldCloseWithWindow = false // This prevents some crashes I was seeing.
		return nsView
	}

	func updateNSView(_ nsView: NSViewType, context: Context) {
		nsView.previewItem = previewItem
	}

	func makeCoordinator() -> Coordinator {
		Coordinator(self)
	}

	final class Coordinator: NSObject {
		var parent: QuickLookPreview

		init(_ parent: QuickLookPreview) {
			self.parent = parent
		}
	}
}
#else
struct QuickLookPreview: UIViewControllerRepresentable {
	fileprivate var shouldCleanUp = false

	let previewItem: QLPreviewItem

	static func dismantleUIViewController(_ uiViewController: QLPreviewController, coordinator: Coordinator) {
		if
			coordinator.parent.shouldCleanUp,
			let url = coordinator.parent.previewItem.previewItemURL
		{
			DispatchQueue.global(qos: .utility).async {
				try? FileManager.default.removeItem(at: url)
			}
		}
	}

	func makeUIViewController(context: Context) -> QLPreviewController {
		let controller = QLPreviewController()
		controller.dataSource = context.coordinator
		return controller
	}

	func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
		uiViewController.reloadData()
	}

	func makeCoordinator() -> Coordinator {
		Coordinator(self)
	}

	final class Coordinator: NSObject, QLPreviewControllerDataSource {
		var parent: QuickLookPreview

		init(_ parent: QuickLookPreview) {
			self.parent = parent
		}

		func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
			1
		}

		func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
			parent.previewItem
		}
	}
}
#endif

extension QuickLookPreview {
	/**
	- Note: The initializer will return `nil` if the URL is not a file URL.
	*/
	init?(url: URL) {
		guard url.isFileURL else {
			return nil
		}

		self.previewItem = url as NSURL
	}
}

extension QuickLookPreview {
	init?(data: Data, contentType: UTType) {
		guard
			let temporaryDirectory = try? FileManager.default.url(
				for: .itemReplacementDirectory,
				in: .userDomainMask,
				appropriateFor: FileManager.default.temporaryDirectory,
				create: true
			)
		else {
			return nil
		}

		let url = temporaryDirectory
			.appendingPathComponent("data", conformingTo: contentType)

		guard (try? data.write(to: url)) != nil else {
			return nil
		}

		self.init(url: url)
		self.shouldCleanUp = true
	}
}


extension XPasteboard.PasteboardType {
	/**
	Convert a pasteboard type to a `UTType`.
	*/
	var toUTType: UTType? { UTType(rawValue) }
}


extension URL: @retroactive ExpressibleByStringLiteral {
	/**
	Example:

	```
	let url: URL = "https://sindresorhus.com"
	```
	*/
	public init(stringLiteral value: StaticString) {
		self.init(string: "\(value)")!
	}
}


extension URL {
	/**
	Example:

	```
	URL("https://sindresorhus.com")
	```
	*/
	init(_ staticString: StaticString) {
		self.init(string: "\(staticString)")!
	}
}


extension URL {
	private func resourceValue<T>(forKey key: URLResourceKey) -> T? {
		guard let values = try? resourceValues(forKeys: [key]) else {
			return nil
		}

		return values.allValues[key] as? T
	}

	var localizedName: String { resourceValue(forKey: .localizedNameKey) ?? lastPathComponent }
}


extension String {
	func copyToPasteboard() {
		#if os(macOS)
		NSPasteboard.general.prepareForNewContents()
		NSPasteboard.general.setString(self, forType: .string)
		NSPasteboard.general.setString(SSApp.idString, forType: .sourceAppBundleIdentifier)
		#else
		UIPasteboard.general.string = self
		#endif
	}
}


extension String {
	func removingSuffix(_ suffix: Self, caseSensitive: Bool = true) -> Self {
		guard caseSensitive else {
			guard let range = range(of: suffix, options: [.caseInsensitive, .anchored, .backwards]) else {
				return self
			}

			return replacingCharacters(in: range, with: "")
		}

		guard hasSuffix(suffix) else {
			return self
		}

		return Self(dropLast(suffix.count))
	}

	var capitalizedFirstCharacter: Self {
		guard let first else {
			return ""
		}

		return Self(first).capitalized + dropFirst()
	}
}


#if os(macOS)
/**
Icon for a file/directory/bundle at the given URL.
*/
struct URLIcon: View {
	let url: URL

	var body: some View {
		Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
			.renderingMode(.original)
			.resizable()
			.scaledToFit()
			.accessibilityHidden(true)
	}
}
#endif


#if os(macOS)
extension NSWorkspace {
	/**
	Get an app name from an app URL.

	```
	NSWorkspace.shared.appName(for: …)
	//=> "Lungo"
	```
	*/
	func appName(for url: URL) -> String {
		url.localizedName.removingSuffix(".app")
	}
}
#endif


#if os(macOS)
extension NSAlert {
	/**
	Show an alert as a window-modal sheet, or as an app-modal (window-indepedendent) alert if the window is `nil` or not given.
	*/
	@discardableResult
	static func showModal(
		for window: NSWindow? = nil,
		title: String,
		message: String? = nil,
		style: Style = .warning,
		buttonTitles: [String] = [],
		defaultButtonIndex: Int? = nil
	) -> NSApplication.ModalResponse {
		NSAlert(
			title: title,
			message: message,
			style: style,
			buttonTitles: buttonTitles,
			defaultButtonIndex: defaultButtonIndex
		)
		.runModal(for: window)
	}

	/**
	The index in the `buttonTitles` array for the button to use as default.

	Set `-1` to not have any default. Useful for really destructive actions.
	*/
	var defaultButtonIndex: Int {
		get {
			buttons.firstIndex { $0.keyEquivalent == "\r" } ?? -1
		}
		set {
			// Clear the default button indicator from other buttons.
			for button in buttons where button.keyEquivalent == "\r" {
				button.keyEquivalent = ""
			}

			if newValue != -1 {
				buttons[newValue].keyEquivalent = "\r"
			}
		}
	}

	convenience init(
		title: String,
		message: String? = nil,
		style: Style = .warning,
		buttonTitles: [String] = [],
		defaultButtonIndex: Int? = nil
	) {
		self.init()
		self.messageText = title
		self.alertStyle = style

		if let message {
			self.informativeText = message
		}

		addButtons(withTitles: buttonTitles)

		if let defaultButtonIndex {
			self.defaultButtonIndex = defaultButtonIndex
		}
	}

	/**
	Runs the alert as a window-modal sheet, or as an app-modal (window-indepedendent) alert if the window is `nil` or not given.
	*/
	@discardableResult
	func runModal(for window: NSWindow? = nil) -> NSApplication.ModalResponse {
		guard let window else {
			return runModal()
		}

		beginSheetModal(for: window) { returnCode in
			NSApp.stopModal(withCode: returnCode)
		}

		return NSApp.runModal(for: window)
	}

	/**
	Adds buttons with the given titles to the alert.
	*/
	func addButtons(withTitles buttonTitles: [String]) {
		for buttonTitle in buttonTitles {
			addButton(withTitle: buttonTitle)
		}
	}
}
#endif


#if os(macOS)
private struct WindowAccessor: NSViewRepresentable {
	private final class WindowAccessorView: NSView {
		@Binding var windowBinding: NSWindow?

		init(binding: Binding<NSWindow?>) {
			self._windowBinding = binding
			super.init(frame: .zero)
		}

		override func viewDidMoveToWindow() {
			super.viewDidMoveToWindow()
			windowBinding = window
		}

		@available(*, unavailable)
		required init?(coder: NSCoder) {
			fatalError("init(coder:) has not been implemented")
		}
	}

	@Binding var window: NSWindow?

	init(_ window: Binding<NSWindow?>) {
		self._window = window
	}

	func makeNSView(context: Context) -> NSView {
		WindowAccessorView(binding: $window)
	}

	func updateNSView(_ nsView: NSView, context: Context) {}
}

extension View {
	/**
	Bind the native backing-window of a SwiftUI window to a property.
	*/
	func bindHostingWindow(_ window: Binding<NSWindow?>) -> some View {
		background(WindowAccessor(window))
	}
}

private struct WindowViewModifier: ViewModifier {
	@State private var window: NSWindow?

	let onWindow: (NSWindow?) -> Void

	func body(content: Content) -> some View {
		// We're intentionally not using `.onChange` as we need it to execute for every SwiftUI change as the window properties can be changed at any time by SwiftUI.
		onWindow(window)

		return content
			.bindHostingWindow($window)
	}
}

extension View {
	/**
	Access the native backing-window of a SwiftUI window.
	*/
	func accessHostingWindow(_ onWindow: @escaping (NSWindow?) -> Void) -> some View {
		modifier(WindowViewModifier(onWindow: onWindow))
	}

	/**
	Set the window level of a SwiftUI window.
	*/
	func windowLevel(_ level: NSWindow.Level) -> some View {
		accessHostingWindow {
			$0?.level = level
		}
	}

	/**
	Set the window tabbing mode of a SwiftUI window.
	*/
	func windowTabbingMode(_ tabbingMode: NSWindow.TabbingMode) -> some View {
		accessHostingWindow {
			$0?.tabbingMode = tabbingMode
		}
	}
}
#endif


extension View {
	/**
	For empty states in the UI. For example, no items in a list, no search results, etc.
	*/
	func emptyStateTextStyle() -> some View {
		font(.title2)
			.foregroundStyle(.secondary)
	}
}


extension View {
	/**
	Fill the frame.
	*/
	func fillFrame(
		_ axis: Axis.Set = [.horizontal, .vertical],
		alignment: Alignment = .center
	) -> some View {
		frame(
			maxWidth: axis.contains(.horizontal) ? .infinity : nil,
			maxHeight: axis.contains(.vertical) ? .infinity : nil,
			alignment: alignment
		)
	}
}


extension Data {
	/**
	Detect whether the data is RTF.
	*/
	var isRtf: Bool {
		guard count > 6 else {
			return false
		}

		return [UInt8](self)[0..<6] == [0x7B, 0x5C, 0x72, 0x74, 0x66, 0x31]
	}
}


extension Double {
	/**
	Converts the number to a string and strips fractional trailing zeros.
	```
	print(1.0)
	//=> "1.0"

	print(1.0.formatted)
	//=> "1"

	print(0.0100.formatted)
	//=> "0.01"
	```
	*/
	var formatted: String {
		truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", self) : String(self)
	}
}


extension CGSize {
	/**
	Example: `140×100`
	*/
	var formatted: String { "\(Double(width).formatted)×\(Double(height).formatted)" }
}


enum OperatingSystem {
	case macOS
	case iOS
	case tvOS
	case watchOS
	case visionOS

	#if os(macOS)
	static let current = macOS
	#elseif os(iOS)
	static let current = iOS
	#elseif os(tvOS)
	static let current = tvOS
	#elseif os(watchOS)
	static let current = watchOS
	#elseif os(visionOS)
	static let current = visionOS
	#else
	#error("Unsupported platform")
	#endif
}

extension OperatingSystem {
	static let isMacOS = current == .macOS
	static let isIOS = current == .iOS
	static let isVisionOS = current == .visionOS
	static let isMacOrVision = isMacOS || isVisionOS
	static let isIOSOrVision = isIOS || isVisionOS
}

typealias OS = OperatingSystem


extension StringProtocol {
	func lineCount() -> Int {
		var count = 0
		enumerateLines { _, _ in
			count += 1
		}

		return count
	}
}


#if os(macOS)
extension URL {
	/**
	Show the URL (file or directory) in Finder by selecting it.
	*/
	func showInFinder() {
		NSWorkspace.shared.activateFileViewerSelecting([resolvingSymlinksInPath()])
	}
}
#endif


extension StringProtocol {
	/**
	Convert a string URL to a `URL` type.
	*/
	var toURL: URL? { URL(string: String(self), encodingInvalidCharacters: false) }
}


extension Numeric {
	@discardableResult
	mutating func increment(by value: Self = 1) -> Self {
		self += value
		return self
	}

	@discardableResult
	mutating func decrement(by value: Self = 1) -> Self {
		self -= value
		return self
	}

	func incremented(by value: Self = 1) -> Self {
		self + value
	}

	func decremented(by value: Self = 1) -> Self {
		self - value
	}
}


extension CGImage {
	var size: CGSize { CGSize(width: width, height: height) }
}


extension XImage {
	var toCGImage: CGImage? {
		#if os(macOS)
		cgImage(forProposedRect: nil, context: nil, hints: nil)
		#else
		cgImage
		#endif
	}

	var pixelSize: CGSize { toCGImage?.size ?? size }
}


extension Data {
	var toString: String? { String(data: self, encoding: .utf8) } // swiftlint:disable:this non_optional_string_data_conversion
}


extension Collection {
	subscript(safe index: Index) -> Element? {
		indices.contains(index) ? self[index] : nil
	}
}


extension XPasteboard.PasteboardType {
	var isDynamic: Bool { rawValue.hasPrefix("dyn.") }

	/**
	If the type is dynamic, decodes the dynamic pasteboard type to its underlying type.
	*/
	var decodedDynamic: Self? {
		guard
			isDynamic,
			// We intentionally do not resolve this to `UTType` first as then it doesn't work.
			let identifier = UTType.decodeDynamicType(rawValue)["com.apple.nspboard-type"]
		else {
			return nil
		}

		return .init(identifier)
	}
}


extension UTType {
	/**
	Decode a dynamic Uniform Type Identifier.
	*/
	static func decodeDynamicType(_ identifier: String) -> [String: String] {
		let alphabet = "abcdefghkmnpqrstuvwxyz0123456789"

		guard
			// We only support the `a` variant. Unclear if there are actually other variants.
			identifier.hasPrefix("dyn.a"),
			// Drop `dyn.a` (the first 5 characters) as it's not Base32 encoded.
			let decodedIdentifier = naiveBase32Decode(String(identifier.dropFirst(5)), alphabet: alphabet)?.toString
		else {
			return [:]
		}

		let components = decodedIdentifier
			.trimmingPrefix("?")
			.components(separatedBy: ":")

		var result = [String: String]()

		for component in components {
			let pair = component.components(separatedBy: "=")

			guard
				let key = pair[safe: 0],
				let value = pair[safe: 1]
			else {
				continue
			}

			let expandedKey = dynamicTranslation[key, default: key]
			let expandedValue = dynamicTranslation[value, default: value]
			result[expandedKey] = expandedValue
		}

		return result
	}

	private static let dynamicTranslation: [String: String] = [
		"0": "UTTypeConformsTo",
		"1": "public.filename-extension",
		"2": "com.apple.ostype",
		"3": "public.mime-type",
		"4": "com.apple.nspboard-type",
		"5": "public.url-scheme",
		"6": "public.data",
		"7": "public.text",
		"8": "public.plain-text",
		"9": "public.utf16-plain-text",
		"A": "com.apple.traditional-mac-plain-text",
		"B": "public.image",
		"C": "public.video",
		"D": "public.audio",
		"E": "public.directory",
		"F": "public.folder"
	]

	private static func naiveBase32Decode(_ string: String, alphabet: String) -> Data? {
		let lookup = Dictionary(uniqueKeysWithValues: Swift.zip(alphabet, 0..<alphabet.count))

		var result = Data()
		var decoded = 0
		var decodedBits = 0

		for character in string {
			guard let position = lookup[character] else {
				print("Found character not in alphabet: \(character)")
				return nil
			}

			decoded = (decoded << 5) | position
			decodedBits += 5

			while decodedBits >= 8 {
				let extra = decodedBits - 8
				result.append(UInt8(decoded >> extra))
				decoded &= (1 << extra) - 1
				decodedBits = extra
			}
		}

		if decoded > 0 {
			print("\(decodedBits) leftover bits: \(decoded)")
			return nil
		}

		return result
	}
}


#if os(macOS)
extension View {
	/**
	Make the view respect window inactive state by lowering the opacity.
	*/
	func respectInactive() -> some View {
		modifier(RespectInactiveViewModifier())
	}
}

private struct RespectInactiveViewModifier: ViewModifier {
	@Environment(\.appearsActive) private var appearsActive

	func body(content: Content) -> some View {
		content.opacity(appearsActive ? 1 : 0.5)
	}
}
#endif


extension View {
	func navigationSubtitleIfMacOS(_ subtitle: String) -> some View {
		#if os(macOS)
		navigationSubtitle(subtitle)
		#else
		self
		#endif
	}
}


extension Data {
	/**
	Decodes the string by detecting the encoding.
	*/
	func decodeStringWithUnknownEncoding() -> String? {
		stringEncoding.flatMap { String(data: self, encoding: $0) }
	}

	/**
	Attempts to detect the string encoding of the `Data`.
	*/
	var stringEncoding: String.Encoding? {
		let rawValue = NSString.stringEncoding(
			for: prefix(1000 * 1000), // We only check the first 1kb since this check is slow.
			encodingOptions: [.allowLossyKey: false],
			convertedString: nil,
			usedLossyConversion: nil
		)

		guard rawValue != 0 else {
			return nil
		}

		return .init(rawValue: rawValue)
	}
}


extension Image {
	/**
	Create a SwiftUI `Image` from either `NSImage` or `UIImage`.
	*/
	init(xImage: XImage) {
		#if os(macOS)
		self.init(nsImage: xImage)
		#else
		self.init(uiImage: xImage)
		#endif
	}
}


extension Sequence {
	/**
	Moves elements that satisfy a given condition to the end of the array, while preserving the order of other elements.

	- Parameter condition: A closure that takes an element of the sequence as its argument and returns a Boolean value indicating whether the element should be moved to the end.
	- Returns: A new array with elements that satisfy the condition moved to the end, while maintaining the original order of other elements.
	*/
	func moveToEnd(where condition: (Element) -> Bool) -> [Element] {
		let (matching, remaining) = reduce(into: ([Element](), [Element]())) { result, element in
			if condition(element) {
				result.0.append(element) // Move to matching
			} else {
				result.1.append(element) // Move to remaining
			}
		}

		return remaining + matching
	}
}


#if !os(macOS)
extension UIPasteboard {
	struct PasteboardType: Hashable, RawRepresentable, Sendable {
		let rawValue: String
	}
}

extension UIPasteboard.PasteboardType {
	init(_ rawValue: String) {
		self.init(rawValue: rawValue)
	}
}

extension UIPasteboard.PasteboardType {
	static let URL = Self("public.url")
	static let fileURL = Self("public.file-url")
}

struct UIPasteboardItem: Hashable {
	let contents: OrderedDictionary<UIPasteboard.PasteboardType, Data>

	init(_ contents: OrderedDictionary<UIPasteboard.PasteboardType, Data>) {
		self.contents = contents
	}

	var types: [UIPasteboard.PasteboardType] {
		Array(contents.keys)
	}

	func data(forType type: XPasteboard.PasteboardType) -> Data? {
		contents[type]
	}

	func string(forType type: XPasteboard.PasteboardType) -> String? {
		data(forType: type)?.toString
	}
}
#endif


extension XPasteboard {
	private static var xItemsCache: (changeCount: Int, items: [XPasteboardItem])?

	// TODO: Sort `.dyn` last on macOS too.
	var xItems: [XPasteboardItem] {
		#if os(macOS)
		pasteboardItems ?? []
		#else
		let allItems = items.enumerated().compactMap { index, itemDictionary in
			var contents = OrderedDictionary<UIPasteboard.PasteboardType, Data>()

			for type in itemDictionary.map(\.key).sorted().moveToEnd(where: { $0.starts(with: "dyn.") }) {
				guard let data = data(forPasteboardType: type, inItemSet: IndexSet(integer: index))?.first else {
					continue
				}

				contents[.init(type)] = data
			}

			return contents.isEmpty ? nil : UIPasteboardItem(contents)
		}

		if
			let cache = Self.xItemsCache,
			cache.changeCount == UIPasteboard.general.changeCount
		{
			return cache.items
		}

		Self.xItemsCache = (UIPasteboard.general.changeCount, allItems)

		return allItems
		#endif
	}
}


#if !os(macOS)
extension NSAttributedString {
	/**
	AppKit polyfill.
	*/
	convenience init?(
		rtf data: Data,
		documentAttributes: AutoreleasingUnsafeMutablePointer<NSDictionary?>?
	) {
		try? self.init(
			data: data,
			options: [.documentType: NSAttributedString.DocumentType.rtf],
			documentAttributes: documentAttributes
		)
	}

	/**
	AppKit polyfill.
	*/
	convenience init?(
		rtfd data: Data,
		documentAttributes: AutoreleasingUnsafeMutablePointer<NSDictionary?>?
	) {
		try? self.init(
			data: data,
			options: [.documentType: NSAttributedString.DocumentType.rtfd],
			documentAttributes: documentAttributes
		)
	}
}
#endif


extension Data {
	/**
	Converts binary property list data into a debug-friendly string.

	- Note: Returns `nil` If the property list is in XML format.
	*/
	func binaryPropertyListToDebugString() -> String? {
		var format = PropertyListSerialization.PropertyListFormat.openStep

		guard
			let plistObject = try? PropertyListSerialization.propertyList(from: self, options: [], format: &format),
			format == .binary
		else {
			return nil
		}

		return String(describing: plistObject)
	}

	func convertPropertyListToXML() throws -> Data {
		let plistObject = try PropertyListSerialization.propertyList(from: self, options: [], format: nil)
		return try PropertyListSerialization.data(fromPropertyList: plistObject, format: .xml, options: 0)
	}

	var propertyListFormat: PropertyListSerialization.PropertyListFormat? {
		var format = PropertyListSerialization.PropertyListFormat.openStep

		do {
			try PropertyListSerialization.propertyList(from: self, options: [], format: &format)
		} catch {
			return nil
		}

		return format
	}

	var isPropertyList: Bool { propertyListFormat != nil }
	var isBinaryPropertyList: Bool { propertyListFormat == .binary }
}


extension String {
	/**
	Escapes null bytes in the string.

	- Returns: A new string where null bytes are replaced with the literal "\0".

	```
	let inputString = "\u{03}\0\0\0\0#\0\0\0Packages/Text/Plain text.tmLanguage\0\0\0\0"
	let escapedString = inputString.escapeNullBytes()
	print(escapedString)
	```
	*/
	func escapingNullBytes() -> String {
		replacing("\u{0000}", with: "\\0")
	}
}

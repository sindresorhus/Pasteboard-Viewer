import SwiftUI
import Combine
import Quartz
import UniformTypeIdentifiers
import StoreKit
import Defaults
import Introspect
//import Sentry

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
		} else {
			UserDefaults.standard.set(true, forKey: key)
			return true
		}
	}()

	static func openSendFeedbackPage() {
		let metadata =
			"""
			\(name) \(versionWithBuild) - \(idString)
			macOS \(System.osVersion)
			\(System.hardwareModel)
			"""

		let query: [String: String] = [
			"product": name,
			"metadata": metadata
		]

		URL("https://sindresorhus.com/feedback").addingDictionaryAsQuery(query).open()
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
		}
		#endif
	}
}


extension URL {
	/**
	Convenience for opening URLs.
	*/
	func open() {
		NSWorkspace.shared.open(self)
	}
}

extension String {
	/*
	```
	"https://sindresorhus.com".openUrl()
	```
	*/
	func openUrl() {
		URL(string: self)?.open()
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


/**
Create a `Picker` from an enum.

```
enum EventIndicatorsInCalendar: String, Codable, CaseIterable {
	case none
	case one
	case maxThree

	var title: String {
		switch self {
		case .none:
			return "None"
		case .one:
			return "Single Gray Dot"
		case .maxThree:
			return "Up To Three Colored Dots"
		}
	}
}

struct ContentView: View {
	@Default(.indicateEventsInCalendar) private var indicator

	var body: some View {
		EnumPicker(
			"Foo"
			enumCase: $indicator
		) {
			Text($0.title)
		}
	}
}
```
*/
struct EnumPicker<Enum, Label, Content>: View where Enum: CaseIterable & Equatable, Enum.AllCases.Index: Hashable, Label: View, Content: View {
	let enumBinding: Binding<Enum>
	let label: Label
	@ViewBuilder let content: (Enum, Bool) -> Content

	var body: some View {
		Picker(selection: enumBinding.caseIndex, label: label) {
			ForEach(Array(Enum.allCases).indexed(), id: \.0) { index, element in
				// TODO: Is `isSelected` really useful? If not, remove it.
				content(element, element == enumBinding.wrappedValue)
					.tag(index)
			}
		}
	}
}

extension EnumPicker where Label == Text {
	init(
		_ title: some StringProtocol,
		enumBinding: Binding<Enum>,
		@ViewBuilder content: @escaping (Enum, Bool) -> Content
	) {
		self.enumBinding = enumBinding
		self.label = Text(title)
		self.content = content
	}
}


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

struct ScrollableAttributedTextView: NSViewRepresentable {
	typealias NSViewType = NSScrollView

	var attributedText: NSAttributedString?
	var font: NSFont?
	var borderType = NSBorderType.bezelBorder
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


extension View {
	/**
	Returns a type-erased version of `self`.

	- Important: Use `Group` instead whenever possible!
	*/
	func eraseToAnyView() -> AnyView {
		AnyView(self)
	}
}


extension NSPasteboard {
	/**
	Human-readable name of the pasteboard.
	*/
	var presentableName: String {
		switch name {
		case .general:
			return "General"
		case .drag:
			return "Drag"
		case .find:
			return "Find"
		case .font:
			return "Font"
		case .ruler:
			return "Ruler"
		default:
			return String(describing: self)
		}
	}
}


extension BinaryInteger {
	var boolValue: Bool { self != 0 }
}


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

		self.bounds = CGRect(dictionaryRepresentation: window[kCGWindowBounds as String] as! CFDictionary)!
		self.layer = window[kCGWindowLayer as String] as! Int
		self.alpha = window[kCGWindowAlpha as String] as! Double
		self.memoryUsage = window[kCGWindowMemoryUsage as String] as? Int ?? 0
		self.sharingState = CGWindowSharingType(rawValue: window[kCGWindowSharingState as String] as! UInt32)!
		self.isOnScreen = (window[kCGWindowIsOnscreen as String] as? Int)?.boolValue ?? false
	}
}

extension WindowInfo {
	typealias Filter = (Self) -> Bool

	/**
	Filters out fully transparent windows and windows smaller than 50 width or height.
	*/
	static func defaultFilter(window: Self) -> Bool {
		let minimumWindowSize = 50.0

		// Skip windows outside the expected level range.
		guard
			window.layer < NSWindow.Level.screenSaver.rawValue,
			window.layer >= NSWindow.Level.normal.rawValue
		else {
			return false
		}

		// Skip fully transparent windows, like with Chrome.
		guard window.alpha > 0 else {
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

		let appIgnoreList = [
			"com.apple.dock",
			"com.apple.notificationcenterui",
			"com.apple.screencaptureui",
			"com.apple.PIPAgent",
			"com.sindresorhus.Pasteboard-Viewer",
			"co.hypercritical.SwitchGlass" // Dock replacement
		]

		if appIgnoreList.contains(window.owner.bundleIdentifier ?? "") {
			return false
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


extension NSPasteboard.PasteboardType {
	/**
	Convention for getting the bundle identifier of the source app.

	> This marker’s presence indicates that the source of the content is the application with the bundle identifier matching its UTF–8 string content. For example: `pasteboard.setString("com.sindresorhus.Foo" forType: "org.nspasteboard.source")`. This is useful when the source is not the foreground application. This is meant to be shown to the user by a supporting app for informational purposes only. Note that an empty string is a valid value as explained below.
	> - http://nspasteboard.org
	*/
	static let sourceAppBundleIdentifier = Self("org.nspasteboard.source")
}

extension NSPasteboard {
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
	var publisher: AnyPublisher<ContentsInfo, Never> {
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
					let source = self.string(forType: .sourceAppBundleIdentifier)
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
			.eraseToAnyPublisher()
	}
}

extension NSPasteboard {
	/**
	An observable object that publishes updates when the given pasteboard changes.
	*/
	final class Observable: ObservableObject {
		private var cancellable: AnyCancellable?

		@Published var pasteboard: NSPasteboard {
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

				self.info = $0
			}
		}

		init(_ pasteboard: NSPasteboard) {
			self.pasteboard = pasteboard
			start()
		}
	}
}


struct QuickLookPreview: NSViewRepresentable {
	typealias NSViewType = QLPreviewView

	static func dismantleNSView(_ nsView: QLPreviewView, coordinator: Void) {
		nsView.close()
	}

	/**
	The item to preview.
	*/
	let previewItem: QLPreviewItem

	func makeNSView(context: Context) -> NSViewType {
		let nsView = NSViewType()
		nsView.shouldCloseWithWindow = false // This prevents some crashes I was seeing.
		return nsView
	}

	func updateNSView(_ nsView: NSViewType, context: Context) {
		nsView.previewItem = previewItem
	}
}

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
				appropriateFor: FileManager.default.homeDirectoryForCurrentUser,
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
	}
}


extension NSPasteboard.PasteboardType {
	/**
	Convert a pasteboard type to a `UTType`.
	*/
	var toUTType: UTType? { UTType(rawValue) }
}


extension URL: ExpressibleByStringLiteral {
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
		NSPasteboard.general.prepareForNewContents()
		NSPasteboard.general.setString(self, forType: .string)
		NSPasteboard.general.setString(SSApp.idString, forType: .sourceAppBundleIdentifier)
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
}


/**
Icon for a file/directory/bundle at the given URL.
*/
struct URLIcon: View {
	let url: URL

	var body: some View {
		Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
			.renderingMode(.original)
			.resizable()
			.aspectRatio(contentMode: .fit)
			.accessibilityHidden(true)
	}
}


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


extension StringProtocol {
	func lineCount() -> Int {
		var count = 0
		enumerateLines { _, _ in
			count += 1
		}

		return count
	}
}


extension URL {
	/**
	Show the URL (file or directory) in Finder by selecting it.
	*/
	func showInFinder() {
		NSWorkspace.shared.activateFileViewerSelecting([resolvingSymlinksInPath()])
	}
}


extension StringProtocol {
	/**
	Convert a string URL to a `URL` type.
	*/
	var toURL: URL? { URL(string: String(self)) }
}


extension Numeric {
	mutating func increment(by value: Self = 1) -> Self {
		self += value
		return self
	}

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


extension SSApp {
	private static let key = Defaults.Key("SSApp_requestReview", default: 0)

	/**
	Requests a review only after this method has been called the given amount of times.
	*/
	static func requestReviewAfterBeingCalledThisManyTimes(_ counts: [Int]) {
		guard
			!SSApp.isFirstLaunch,
			counts.contains(Defaults[key].increment())
		else {
			return
		}

		SKStoreReviewController.requestReview()
	}
}


extension CGImage {
	var size: CGSize { CGSize(width: width, height: height) }
}


extension NSImage {
	var cgImage: CGImage? { cgImage(forProposedRect: nil, context: nil, hints: nil) }

	var pixelSize: CGSize { cgImage?.size ?? size }
}


extension Data {
	var toString: String? { String(data: self, encoding: .utf8) }
}


extension Collection {
	subscript(safe index: Index) -> Element? {
		indices.contains(index) ? self[index] : nil
	}
}


extension NSPasteboard.PasteboardType {
	var isDynamic: Bool { rawValue.hasPrefix("dyn.") }

	/**
	If the type is dynamic, decodes the dynamic pasteboard type to its underlying type.
	*/
	var decodedDynamic: Self? {
		guard
			isDynamic,
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


extension View {
	func introspectSplitView(customize: @escaping (NSSplitView) -> Void) -> some View {
		inject(
			AppKitIntrospectionView(
				selector: { introspectionView in
					guard let viewHost = Introspect.findViewHost(from: introspectionView) else {
						return nil
					}

					return Introspect.findAncestorOrAncestorChild(ofType: NSSplitView.self, from: viewHost)
				},
				customize: customize
			)
		)
	}
}

extension View {
	/**
	- Note: This only works on the old `NavigationView` and not `NavigationSplitView`.
	*/
	func preventSidebarCollapse() -> some View {
		introspectSplitView {
			($0.delegate as? NSSplitViewController)?.splitViewItems.first?.canCollapse = false
		}
	}
}

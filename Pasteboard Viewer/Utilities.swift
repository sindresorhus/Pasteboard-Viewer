import SwiftUI
import Combine
import Quartz


/// Subclass this in Interface Builder with the title "Send Feedback…".
final class FeedbackMenuItem: NSMenuItem {
	required init(coder decoder: NSCoder) {
		super.init(coder: decoder)

		onAction = { _ in
			SSApp.openSendFeedbackPage()
		}
	}
}


/// Subclass this in Interface Builder and set the `Url` field there.
final class UrlMenuItem: NSMenuItem {
	@IBInspectable var url: String?

	required init(coder decoder: NSCoder) {
		super.init(coder: decoder)

		onAction = { [weak self] _ in
			guard
				let self = self,
				let url = self.url
			else {
				return
			}

			NSWorkspace.shared.open(URL(string: url)!)
		}
	}
}


final class ObjectAssociation<T: Any> {
	subscript(index: AnyObject) -> T? {
		get {
			objc_getAssociatedObject(index, Unmanaged.passUnretained(self).toOpaque()) as! T?
		} set {
			objc_setAssociatedObject(index, Unmanaged.passUnretained(self).toOpaque(), newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
		}
	}
}


extension NSMenuItem {
	typealias ActionClosure = ((NSMenuItem) -> Void)

	private enum AssociatedKeys {
		static let onActionClosure = ObjectAssociation<ActionClosure>()
	}

	// The explicit naming here is to prevent conflicts since this method is exposed to Objective-C.
	@objc
	private func callClosurePasteboardViewer(_ sender: NSMenuItem) {
		onAction?(sender)
	}

	/**
	Closure version of `.action`.

	```
	let menuItem = NSMenuItem(title: "Unicorn")

	menuItem.onAction = { sender in
		print("NSMenuItem action: \(sender)")
	}
	```
	*/
	var onAction: ActionClosure? {
		get { AssociatedKeys.onActionClosure[self] }
		set {
			AssociatedKeys.onActionClosure[self] = newValue
			action = #selector(callClosurePasteboardViewer)
			target = self
		}
	}
}


extension NSControl {
	typealias ActionClosure = ((NSControl) -> Void)

	private enum AssociatedKeys {
		static let onActionClosure = ObjectAssociation<ActionClosure>()
	}

	@objc
	private func callClosurePasteboardViewer(_ sender: NSControl) {
		onAction?(sender)
	}

	/**
	Closure version of `.action`.

	```
	let button = NSButton(title: "Unicorn", target: nil, action: nil)

	button.onAction = { sender in
		print("Button action: \(sender)")
	}
	```
	*/
	var onAction: ActionClosure? {
		get { AssociatedKeys.onActionClosure[self] }
		set {
			AssociatedKeys.onActionClosure[self] = newValue
			action = #selector(callClosurePasteboardViewer)
			target = self
		}
	}
}


enum SSApp {
	static let id = Bundle.main.bundleIdentifier!
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
			\(SSApp.name) \(SSApp.versionWithBuild) - \(SSApp.id)
			macOS \(System.osVersion)
			\(System.hardwareModel)
			"""

		let query: [String: String] = [
			"product": SSApp.name,
			"metadata": metadata
		]

		URL("https://sindresorhus.com/feedback/").addingDictionaryAsQuery(query).open()
	}
}


/// Convenience for opening URLs.
extension URL {
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
struct EnumPicker<Enum, Label, Content>: View where Enum: CaseIterable & Equatable, Enum.AllCases.Index == Int, Label: View, Content: View {
	private let enumBinding: Binding<Enum>
	private let label: Label
	private let content: (Enum, Bool) -> Content

	var body: some View {
		Picker(selection: enumBinding.caseIndex, label: label) {
			ForEach(Array(Enum.allCases).indexed(), id: \.0) { index, element in
				content(element, element == enumBinding.wrappedValue)
					.tag(index)
			}
		}
	}

	init(
		enumBinding: Binding<Enum>,
		label: Label,
		@ViewBuilder content: @escaping (Enum, Bool) -> Content
	) {
		self.enumBinding = enumBinding
		self.label = label
		self.content = content
	}
}

extension EnumPicker where Label == Text {
	init<S>(
		_ title: S,
		enumBinding: Binding<Enum>,
		@ViewBuilder content: @escaping (Enum, Bool) -> Content
	) where S: StringProtocol {
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
		textView.textColor = .controlTextColor

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

		return scrollView
	}

	func updateNSView(_ nsView: NSViewType, context: Context) {
		nsView.borderType = borderType
		nsView.drawsBackground = drawsBackground

		let textView = (nsView.documentView as! NSTextView)
		textView.isEditable = isEditable

		if
			let attributedText = attributedText,
			attributedText != textView.attributedString()
		{
			textView.textStorage?.setAttributedString(attributedText)
		}

		if let font = font {
			textView.font = font
		}

		if let lineLimit = context.environment.lineLimit {
			textView.textContainer?.maximumNumberOfLines = lineLimit
		}
	}
}


extension View {
	/// Returns a type-erased version of `self`.
	/// - Important: Use `Group` instead whenever possible!
	func eraseToAnyView() -> AnyView {
		AnyView(self)
	}
}


extension Binding where Value: Equatable {
	/**
	Get notified when the binding value changes to a different one.

	Can be useful to manually update non-reactive properties.

	```
	Toggle(
		"Foo",
		isOn: $foo.onChange {
			bar.isEnabled = $0
		}
	)
	```
	*/
	func onChange(_ action: @escaping (Value) -> Void) -> Self {
		.init(
			get: { wrappedValue },
			set: {
				let oldValue = wrappedValue
				wrappedValue = $0
				let newValue = wrappedValue
				if newValue != oldValue {
					action(newValue)
				}
			}
		)
	}
}


extension AppDelegate {
	static let shared = NSApp.delegate as! AppDelegate
}


extension NSPasteboard {
	/// Human-readable name of the pasteboard.
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


private struct ForceFocusView: NSViewRepresentable {
	final class CocoaForceFocusView: NSView {
		private var hasFocused = false

		override func viewDidMoveToWindow() {
			guard
				!hasFocused,
				let window = window
			else {
				return
			}

			DispatchQueue.main.async { [self] in
				hasFocused = true
				window.makeFirstResponder(self)
			}
		}
	}

	typealias NSViewType = CocoaForceFocusView

	func makeNSView(context: Context) -> NSViewType { .init() }

	func updateNSView(_ nsView: NSViewType, context: Context) {}
}

private struct ForceFocusModifier: ViewModifier {
	func body(content: Content) -> some View {
		content
			.background(ForceFocusView())
	}
}

extension View {
	/**
	Force the focus on a view once.

	This can be useful as a workaround for SwiftUI's focus issues, for example, the sidebar not getting initial focus.
	*/
	func forceFocus() -> some View {
		modifier(ForceFocusModifier())
	}
}


extension BinaryInteger {
	var boolValue: Bool { self != 0 }
}


extension NSRunningApplication {
	/// Like `.localizedName` but guaranteed to return something useful even if the name is not available.
	var localizedTitle: String {
		localizedName
			?? executableURL?.deletingPathExtension().lastPathComponent
			?? bundleURL?.deletingPathExtension().lastPathComponent
			?? bundleIdentifier
			?? (processIdentifier == -1 ? nil : "PID\(processIdentifier)")
			?? "<Unknown>"
	}
}


/// Static representation of a window.
/// - Note: The `name` property is always `nil` on macOS 10.15 and later unless you request “Screen Recording” permission.
struct Window {
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

	/// Accepts a window dictionary coming from `CGWindowListCopyWindowInfo`.
	private init(windowDictionary window: [String: Any]) {
		self.identifier = window[kCGWindowNumber as String] as! CGWindowID
		self.name = window[kCGWindowName as String] as? String

		let processIdentifier = window[kCGWindowOwnerPID as String] as! Int
		let app = NSRunningApplication(processIdentifier: pid_t(processIdentifier))
		// TODO: When MS AppCenter supports manually sending crash logs, send one here when `window[kCGWindowOwnerName as String]` is `nil` so I can figure out in what cases it would e `nil` and improve the logic.
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

extension Window {
	typealias Filter = (Self) -> Bool

	/// Filters out fully transparent windows and windows smaller than 50 width or height.
	static func defaultFilter(window: Self) -> Bool {
		let minimumWindowSize: CGFloat = 50

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

		let appIgnoreList = [
			"com.apple.dock",
			"com.apple.notificationcenterui"
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

	/**
	Returns the bundle identifier of the app that owns the frontmost window.

	This method returns more correct results than `NSWorkspace.shared.frontmostApplication?.bundleIdentifier`. For example, the latter cannot correctly detect the 1Password Mini window.
	*/
	static func appBundleIdentifierForFrontmostWindow() -> String? {
		allWindows().lazy.compactMap(\.owner.bundleIdentifier).first ?? NSWorkspace.shared.frontmostApplication?.bundleIdentifier
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
	/// Information about the pasteboard contents.
	struct ContentsInfo: Identifiable {
		let id = UUID()

		/// The date when the current pasteboard data was added.
		let created = Date()

		/// The bundle identifier of the app that put the data on the pasteboard.
		let sourceAppBundleIdentifier: String?
	}

	/// Returns a publisher that emits when the pasteboard changes.
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
					let self = self,
					let source = self.string(forType: .sourceAppBundleIdentifier)
				else {
					// We ignore the first event in this case as we cannot know if the existing pasteboard contents came from the frontmost app.
					return isFirst ? nil : ContentsInfo(sourceAppBundleIdentifier: Window.appBundleIdentifierForFrontmostWindow())
				}

				// An empty string has special behavior ( http://nspasteboard.org ).
				// > In case the original source of the content is not known, set `org.nspasteboard.source` to the empty string.
				return ContentsInfo(sourceAppBundleIdentifier: source.isEmpty ? nil : source)
			}
			.eraseToAnyPublisher()
	}
}

extension NSPasteboard {
	/// An observable object that publishes updates when the given pasteboard changes.
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
				guard let self = self else {
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

// TODO: Use UTType when targeting macOS 11.
extension URL {
	/**
	Returns the type identifier for a file extension.

	```
	URL.fileExtensionForTypeIdentifier("public.png")
	//=> "png"
	```
	*/
	static func fileExtensionForTypeIdentifier(_ typeIdentifier: String) -> String? {
		UTTypeCopyPreferredTagWithClass(typeIdentifier as CFString, kUTTagClassFilenameExtension)?.takeRetainedValue() as String?
	}
}


struct QuickLookPreview: NSViewRepresentable {
	typealias NSViewType = QLPreviewView

	/// The item to preview.
	let previewItem: QLPreviewItem

	func makeNSView(context: Context) -> NSViewType { .init() }

	func updateNSView(_ nsView: NSViewType, context: Context) {
		nsView.previewItem = previewItem
	}
}

extension QuickLookPreview {
	/// - Note: The initializer will return `nil` if the URL is not a file URL.
	init?(url: URL) {
		guard url.isFileURL else {
			return nil
		}

		self.previewItem = url as NSURL
	}
}

extension QuickLookPreview {
	init?(data: Data, typeIdentifier: String) {
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

		let fileExtension = URL.fileExtensionForTypeIdentifier(typeIdentifier) ?? "txt"

		// TODO: When targeting macOS 11, use `UTType` here https://developer.apple.com/documentation/foundation/nsurl/3584837-appendingpathextension
		let url = temporaryDirectory
			.appendingPathComponent("data", isDirectory: false)
			.appendingPathExtension(fileExtension)

		guard (try? data.write(to: url)) != nil else {
			return nil
		}

		self.init(url: url)
	}
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


extension String {
	func copyToPasteboard() {
		NSPasteboard.general.clearContents()
		NSPasteboard.general.setString(self, forType: .string)
		NSPasteboard.general.setString(SSApp.id, forType: .sourceAppBundleIdentifier)
	}
}


/// Icon for a file/directory/bundle at the given URL.
struct URLIcon: View {
	let url: URL

	var body: some View {
		Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
			.renderingMode(.original)
			.resizable()
			.aspectRatio(contentMode: .fit)
	}
}


extension Bundle {
	private func string(forInfoDictionaryKey key: String) -> String? {
		// `object(forInfoDictionaryKey:)` prefers localized info dictionary over the regular one automatically
		object(forInfoDictionaryKey: key) as? String
	}

	var name: String {
		string(forInfoDictionaryKey: "CFBundleDisplayName")
			?? string(forInfoDictionaryKey: "CFBundleName")
			?? string(forInfoDictionaryKey: "CFBundleExecutable")
			?? bundleIdentifier
			?? ProcessInfo.processInfo.processName
	}
}


extension NSWorkspace {
	/**
	Get an app name from an app bundle identifier.

	```
	NSWorkspace.shared.appName(forBundleIdentifier: "com.sindresorhus.Lungo")
	//=> "Lungo"
	```
	*/
	func appName(forBundleIdentifier bundleIdentifier: String) -> String? {
		guard
			let url = urlForApplication(withBundleIdentifier: bundleIdentifier),
			let bundle = Bundle(url: url)
		else {
			return nil
		}

		return bundle.name
	}
}


extension NSAlert {
	/// Show an alert as a window-modal sheet, or as an app-modal (window-indepedendent) alert if the window is `nil` or not given.
	@discardableResult
	static func showModal(
		for window: NSWindow? = nil,
		message: String,
		informativeText: String? = nil,
		style: Style = .warning,
		buttonTitles: [String] = [],
		defaultButtonIndex: Int? = nil
	) -> NSApplication.ModalResponse {
		NSAlert(
			message: message,
			informativeText: informativeText,
			style: style,
			buttonTitles: buttonTitles,
			defaultButtonIndex: defaultButtonIndex
		).runModal(for: window)
	}

	/// The index in the `buttonTitles` array for the button to use as default.
	/// Set `-1` to not have any default. Useful for really destructive actions.
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
		message: String,
		informativeText: String? = nil,
		style: Style = .warning,
		buttonTitles: [String] = [],
		defaultButtonIndex: Int? = nil
	) {
		self.init()
		self.messageText = message
		self.alertStyle = style

		if let informativeText = informativeText {
			self.informativeText = informativeText
		}

		addButtons(withTitles: buttonTitles)

		if let defaultButtonIndex = defaultButtonIndex {
			self.defaultButtonIndex = defaultButtonIndex
		}
	}

	/// Runs the alert as a window-modal sheet, or as an app-modal (window-indepedendent) alert if the window is `nil` or not given.
	@discardableResult
	func runModal(for window: NSWindow? = nil) -> NSApplication.ModalResponse {
		guard let window = window else {
			return runModal()
		}

		beginSheetModal(for: window) { returnCode in
			NSApp.stopModal(withCode: returnCode)
		}

		return NSApp.runModal(for: window)
	}

	/// Adds buttons with the given titles to the alert.
	func addButtons(withTitles buttonTitles: [String]) {
		for buttonTitle in buttonTitles {
			addButton(withTitle: buttonTitle)
		}
	}
}

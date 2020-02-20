import SwiftUI
import Combine


/// Subclass this in Interface Builder with the title "Send Feedback…".
final class FeedbackMenuItem: NSMenuItem {
	required init(coder decoder: NSCoder) {
		super.init(coder: decoder)

		onAction = { _ in
			Meta.openSubmitFeedbackPage()
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
	subscript(index: Any) -> T? {
		get {
			objc_getAssociatedObject(index, Unmanaged.passUnretained(self).toOpaque()) as! T?
		} set {
			objc_setAssociatedObject(index, Unmanaged.passUnretained(self).toOpaque(), newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
		}
	}
}


extension NSMenuItem {
	typealias ActionClosure = ((NSMenuItem) -> Void)

	private struct AssociatedKeys {
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

	private struct AssociatedKeys {
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


struct App {
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


struct System {
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


struct Meta {
	static func openSubmitFeedbackPage() {
		let metadata =
			"""
			\(App.name) \(App.versionWithBuild) - \(App.id)
			macOS \(System.osVersion)
			\(System.hardwareModel)
			"""

		let query: [String: String] = [
			"product": App.name,
			"metadata": metadata
		]

		URL(string: "https://sindresorhus.com/feedback/")!.addingDictionaryAsQuery(query).open()
	}
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
			get: { Value.allCases.firstIndex(of: self.wrappedValue)! },
			set: { self.wrappedValue = Value.allCases[$0] }
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
struct EnumPicker<EnumCase, Label, Content>: View where EnumCase: CaseIterable & Equatable, EnumCase.AllCases.Index == Int, Label: View, Content: View {
	private let enumCase: Binding<EnumCase>
	private let label: Label
	private let content: (EnumCase, Bool) -> Content

	var body: some View {
		Picker(selection: enumCase.caseIndex, label: label) {
			ForEach(Array(EnumCase.allCases).indexed(), id: \.0) { index, element in
				self.content(element, element == self.enumCase.wrappedValue)
					.tag(index)
			}
		}
	}

	init(
		enumCase: Binding<EnumCase>,
		label: Label,
		@ViewBuilder content: @escaping (EnumCase, Bool) -> Content
	) {
		self.enumCase = enumCase
		self.label = label
		self.content = content
	}
}

extension EnumPicker where Label == Text {
	init<S>(
		_ title: S,
		enumCase: Binding<EnumCase>,
		@ViewBuilder content: @escaping (EnumCase, Bool) -> Content
	) where S: StringProtocol {
		self.enumCase = enumCase
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
		scrollView.borderType = .bezelBorder
		scrollView.drawsBackground = false

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
		scrollView.borderType = .bezelBorder
		scrollView.drawsBackground = false

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
			get: { self.wrappedValue },
			set: {
				let oldValue = self.wrappedValue
				self.wrappedValue = $0
				let newValue = self.wrappedValue
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
				let window = self.window
			else {
				return
			}

			DispatchQueue.main.async {
				self.hasFocused = true
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


extension NSPasteboard {
	/// Returns a publisher that emits when the pasteboard is changes.
	var publisher: AnyPublisher<Void, Never> {
		Timer.publish(every: 0.5, tolerance: 0.2, on: .main, in: .common)
			.autoconnect()
			.map { _ in self.changeCount }
			.removeDuplicates()
			.map { _ in }
			.eraseToAnyPublisher()
	}
}

extension NSPasteboard {
	/// An observable object that emits updates when the given pasteboard changes.
	final class Observable: ObservableObject {
		private var cancellable: AnyCancellable?

		@Published var pasteboard: NSPasteboard {
			didSet {
				start()
			}
		}

		private func start() {
			cancellable = pasteboard.publisher.sink { [weak self] in
				self?.objectWillChange.send()
			}
		}

		init(_ pasteboard: NSPasteboard) {
			self.pasteboard = pasteboard
			start()
		}
	}
}

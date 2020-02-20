<div align="center">
	<a href="https://sindresorhus.com/pasteboard-viewer">
		<img src="Stuff/AppIcon-readme.png" width="200" height="200">
	</a>
	<h1>Pasteboard Viewer</h1>
	<p>
		<b>Inspect the system pasteboards</b>
	</p>
	<br>
	<br>
	<br>
</div>

This is a developer utility that lets you inspect the various system pasteboards. This can be useful to ensure your app is putting the correct data on [NSPasteboard](https://developer.apple.com/documentation/appkit/nspasteboard). The app refreshes the pasteboard contents live and can preview text, RTF, and images.

Note that this is not a clipboard manager. If you're not a Mac developer, you probably don't want this app.

You can make the window always stay in front by enabling “Stay in Front” in the “Window” menu.

Use the up/down arrow keys to switch between the pasteboard items.

It hides obsolete system pasteboard types that have modern equivalents. This includes `CorePasteboardFlavorType`, `NSStringPboardType`, `NSFilenamesPboardType`, etc.

## Download

[![](https://linkmaker.itunes.apple.com/assets/shared/badges/en-us/macappstore-lrg.svg)](https://apps.apple.com/app/id1499215709?mt=12)

Requires macOS 10.15 or later.

## Screenshot

<img src="Stuff/screenshot1.jpg" width="1163">

## FAQ

#### What's with the genie lamp?

It's a reference to the icon of Apple's old NSPasteboard sample app called [Clipboard Viewer](https://developer.apple.com/library/archive/samplecode/ClipboardViewer/Introduction/Intro.html).

<img src="https://user-images.githubusercontent.com/170270/74718709-5a658a80-5265-11ea-8c93-02a12f72f8d1.png" width="64" height="64">

#### Can I contribute localizations?

I'm not interested in localizing the app.

#### Can you add support for macOS 10.14 or older?

This app uses SwiftUI, which only works on macOS 10.15 and later.

## Related

- [Website](https://sindresorhus.com/pasteboard-viewer)
- [Dato](https://sindresorhus.com/dato) - Better menu bar clock with calendar and time zones
- [Gifski](https://github.com/sindresorhus/Gifski) - Convert videos to high-quality GIFs
- [More apps…](https://sindresorhus.com/apps)

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

This is a developer utility that lets you inspect the various system pasteboards. This can be useful to ensure your app is putting the correct data on [NSPasteboard](https://developer.apple.com/documentation/appkit/nspasteboard). The app refreshes the pasteboard contents live and can preview text, RTF, images, and anything that has a Quick Look preview.

Note that this is not a clipboard manager. If you're not a Mac developer, you probably don't want this app.

You can make the window always stay in front by enabling “Stay in Front” in the “Window” menu.

Use the up/down arrow keys to switch between the pasteboard items.

It hides obsolete system pasteboard types that have modern equivalents. This includes `CorePasteboardFlavorType`, `NSStringPboardType`, `NSFilenamesPboardType`, etc.

Tip: Right-click an item in the sidebar to copy the type identifier.

## Download

[![](https://tools.applemediaservices.com/api/badges/download-on-the-mac-app-store/black/en-us?size=250x83&releaseDate=1615852800)](https://apps.apple.com/app/id1499215709)

Requires macOS 14 or later.

**Older versions**

- [2.5.1](https://github.com/sindresorhus/Pasteboard-Viewer/releases/download/v2.5.1/Pasteboard.Viewer.2.5.1.-.macOS.13.zip) for macOS 13+
- [2.4.1](https://github.com/sindresorhus/meta/files/13539167/Pasteboard-Viewer-2.4.1-macOS-12.zip) for macOS 12+
- [2.2.2](https://github.com/sindresorhus/Pasteboard-Viewer/releases/download/v2.2.2/Pasteboard.Viewer.2.2.2.-.macOS.11.zip) for macOS 11+
- [1.5.1](https://github.com/sindresorhus/Pasteboard-Viewer/releases/tag/v1.5.1) for macOS 10.15+

**Non-App Store version**

A special version for users that cannot access the App Store. It won't receive automatic updates. I will update it here once a year.

[Download](https://www.dropbox.com/scl/fi/z6tj464zryabggzlydcy3/Pasteboard-Viewer-2.6.0-1705413886.zip?rlkey=dnap7eyta0e1xm28clsqkuclf&raw=1) *(2.6.0 · macOS 14+)*

## Screenshot

![](Stuff/screenshot1.jpg)

## FAQ

#### What's with the genie lamp?

It's a reference to the icon of Apple's old NSPasteboard sample app called [Clipboard Viewer](https://developer.apple.com/library/archive/samplecode/ClipboardViewer/Introduction/Intro.html).

<img src="https://user-images.githubusercontent.com/170270/74718709-5a658a80-5265-11ea-8c93-02a12f72f8d1.png" width="64" height="64">

#### Can I contribute localizations?

I don't have any immediate plans to localize the app.

## Links

- [Website](https://sindresorhus.com/pasteboard-viewer)
- [More apps by me](https://sindresorhus.com/apps)

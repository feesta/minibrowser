# mini

A tiny one-window web browser for macOS.

Most browsers end up using a lot of memory just to show a few pages. mini is
the no-frills version: one window, one page, no tabs, no extensions, no sync,
no history. It's built on the WebKit that already ships with macOS, the whole
app is a single Swift file, and it sits at roughly 110–135 MB.

Nothing sticks around. Cookies, cache, local storage and history live in memory
and are gone when you quit, and the app wipes WebKit's on-disk store on the way
out as well.

## Download

Get `mini.zip` from the [latest release](https://github.com/feesta/minibrowser/releases/latest),
unzip it and drag `mini.app` wherever you like. It's a universal build for macOS 12
and later, signed with a Developer ID.

If macOS says it "could not verify" the app, open System Settings → Privacy &
Security, scroll down and click **Open Anyway**. You only have to do that once.

## Building it

```
./build.sh                  # needs the Xcode Command Line Tools; makes build/mini.app
open build/mini.app         # opens home.html
build/mini.app/Contents/MacOS/mini https://example.com
build/mini.app/Contents/MacOS/mini ~/some/page.html
```

`build.sh` signs the app if your keychain has a Developer ID Application
certificate, and `./build.sh notarize` also sends it to Apple's notary service
(see the comments at the top of the script). To just hack on it, a bare binary
next to `home.html` works too: `swiftc -O mini.swift -o mini && ./mini`.

The page fills the window. Move the mouse to the top edge and a bar slides out
with back, forward, the address and a reload button that turns into stop while
a page loads. It tucks away again when the mouse leaves. Drag the bar's
background to move the window.

⌘L address bar · ⌘R reload · ⌘← back · ⌘→ forward · ⌘Q quit

Only http, https and file URLs load. Anything else is dropped, so a page can
never open another app.

## Files

- `mini.swift` – the whole app
- `home.html`, `putty-ink.css` – the start page, loaded from `Contents/Resources` (or the folder next to a bare binary)
- `icon.png` – the Dock icon; `mkicon.swift` turns it into the `.icns` at build time
- `Info.plist`, `build.sh` – the app bundle

## License

MIT, see [LICENSE](LICENSE). mini uses only the AppKit and WebKit frameworks
that come with macOS; there is no third-party code in it.

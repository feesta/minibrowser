# mini

A tiny one-window web browser for macOS.

Most browsers end up using a lot of memory just to show a few pages. mini is
the no-frills version: one window, one page, no tabs, no extensions, no sync,
no history. It's built on the WebKit that already ships with macOS, the whole
app is a single Swift file, and it sits at roughly 110–135 MB.

Nothing sticks around. Cookies, cache, local storage and history live in memory
and are gone when you quit, and the app wipes WebKit's on-disk store on the way
out as well.

## Using it

```
./build.sh                  # needs the Xcode Command Line Tools
./mini                      # opens home.html
./mini https://example.com
./mini ~/some/page.html
```

The page fills the window. Move the mouse to the top edge and a bar slides out
with back, forward, the address and a reload button that turns into stop while
a page loads. It tucks away again when the mouse leaves. Drag the bar's
background to move the window.

⌘L address bar · ⌘R reload · ⌘[ back · ⌘] forward · ⌘Q quit

Only http, https and file URLs load. Anything else is dropped, so a page can
never open another app.

## Files

- `mini.swift` – the whole app
- `home.html`, `putty-ink.css` – the start page, loaded from the folder next to the binary
- `build.sh`

## License

MIT, see [LICENSE](LICENSE). mini uses only the AppKit and WebKit frameworks
that come with macOS; there is no third-party code in it.

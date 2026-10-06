# mini

A one-window WebKit browser for macOS, ~110–135 MB all in, in the Putty & Ink
style. No tabs, no extensions, no sync. Just a URL bar and a page.

```
./build.sh
./mini                      # opens home.html
./mini https://example.com
./mini ~/some/page.html
```

Keys: ⌘L focus the bar · ⌘R reload · ⌘[ back · ⌘] forward · ⌘Q quit.
Closing the window quits. The bar's border turns orange while a page loads.

Nothing persists. The web view uses WebKit's non-persistent data store, so
cookies, cache, local storage, IndexedDB and history live in memory and vanish
on quit; the app also wipes its default store on exit. Verified: after a run
nothing exists under ~/Library/WebKit/mini, ~/Library/Caches/mini or
~/Library/HTTPStorages/mini.binarycookies.

Files: `mini.swift` (the whole app), `home.html` + `putty-ink.css` (start page,
loaded from the folder next to the binary), `build.sh`.

# mini

A one-window WebKit browser for macOS, ~110–135 MB all in, in the Putty & Ink
style. No tabs, no extensions, no sync. The page fills the whole window; move the
mouse to the top edge and the window grows upward by a strip, the bar sliding up
from behind the page and fading in over 150ms, with back,
forward, the address and a reload button that turns into stop while a page is
loading; the page itself never moves. The bar stays up while the mouse is in it or
in the strip of page just below it; 350ms after the mouse leaves, it fades and slides
back down behind the page as the window shrinks back. (At the very top
of the screen there is no room to grow, so the window slides down for the bar
and back up after.) Drag the bar's putty
background to move the window, the way a title bar would. Only http, https and
file urls load; a page or link that points at any other scheme is dropped, so nothing
in the browser can ever open another app.

```
./build.sh
./mini                      # opens home.html
./mini https://example.com
./mini ~/some/page.html
```

Keys: ⌘L show the bar and focus the address (esc hides it) · ⌘R reload · ⌘[ back · ⌘] forward · ⌘Q quit.
Closing the window quits. The address border turns orange while a page loads.
Set MINI_DEBUG=1 to log the bar's show/hide events to stderr.

Nothing persists. The web view uses WebKit's non-persistent data store, so
cookies, cache, local storage, IndexedDB and history live in memory and vanish
on quit; the app also wipes its default store on exit. Verified: after a run
nothing exists under ~/Library/WebKit/mini, ~/Library/Caches/mini or
~/Library/HTTPStorages/mini.binarycookies.

Files: `mini.swift` (the whole app), `home.html` + `putty-ink.css` (start page,
loaded from the folder next to the binary), `icon.png` (the Dock icon, also loaded
from next to the binary), `build.sh`.

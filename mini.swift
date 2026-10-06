import Cocoa
import WebKit

// mini: a one-window WebKit browser in the Putty & Ink style.
// Usage: ./mini [url-or-file]    (no argument opens home.html)

// Putty & Ink tokens
let putty  = NSColor(srgbRed: 0xEA/255, green: 0xE8/255, blue: 0xE1/255, alpha: 1)
let panel  = NSColor(srgbRed: 0xF4/255, green: 0xF2/255, blue: 0xEC/255, alpha: 1)
let ink    = NSColor(srgbRed: 0x1A/255, green: 0x1A/255, blue: 0x1A/255, alpha: 1)
let border = ink.withAlphaComponent(0.9)
let accent = NSColor(srgbRed: 0xFF/255, green: 0x4A/255, blue: 0x00/255, alpha: 1)
let mono   = NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold)
let barH: CGFloat = 56, stroke: CGFloat = 1.5, radius: CGFloat = 8

let app = NSApplication.shared
app.setActivationPolicy(.regular)

let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 800),
                      styleMask: [.titled, .closable, .resizable, .miniaturizable],
                      backing: .buffered, defer: false)
win.center()
win.backgroundColor = putty
win.titlebarAppearsTransparent = true
win.appearance = NSAppearance(named: .aqua)   // light only, by design
let root = win.contentView!
let W = root.bounds.width, H = root.bounds.height

// Top bar: putty ground, one bordered field
let bar = NSView(frame: NSRect(x: 0, y: H - barH, width: W, height: barH))
bar.autoresizingMask = [.width, .minYMargin]
root.addSubview(bar)

let box = NSView(frame: NSRect(x: 12, y: 10, width: W - 24, height: barH - 20))
box.autoresizingMask = [.width]
box.wantsLayer = true
box.layer!.backgroundColor = panel.cgColor
box.layer!.borderColor = border.cgColor
box.layer!.borderWidth = stroke
box.layer!.cornerRadius = radius
bar.addSubview(box)

let field = NSTextField(frame: NSRect(x: 10, y: (box.bounds.height - 18) / 2, width: box.bounds.width - 20, height: 18))
field.autoresizingMask = [.width]
field.isBezeled = false; field.drawsBackground = false; field.focusRingType = .none
field.font = mono; field.textColor = ink
field.placeholderAttributedString = NSAttributedString(string: "url or file",
    attributes: [.font: mono, .foregroundColor: ink.withAlphaComponent(0.55)])
box.addSubview(field)

// Page
// Nothing persists: cookies, cache, local storage, IndexedDB and history live in memory and die with the process
let cfg = WKWebViewConfiguration()
cfg.websiteDataStore = WKWebsiteDataStore.nonPersistent()
let web = WKWebView(frame: NSRect(x: 0, y: 0, width: W, height: H - barH), configuration: cfg)
web.autoresizingMask = [.width, .height]
web.setValue(false, forKey: "drawsBackground")   // putty shows through until the page paints
root.addSubview(web)

func go(_ s: String) {
    let t = s.trimmingCharacters(in: .whitespaces)
    guard !t.isEmpty else { return }
    var u = URL(string: t)
    if u?.scheme == nil {
        let p = (t as NSString).expandingTildeInPath
        u = FileManager.default.fileExists(atPath: p) ? URL(fileURLWithPath: p) : URL(string: "https://" + t)
    }
    guard let url = u else { return }
    if url.isFileURL { web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent()) }
    else { web.load(URLRequest(url: url)) }
}

class Ctl: NSObject, NSWindowDelegate, WKNavigationDelegate, NSApplicationDelegate {
    func windowWillClose(_ n: Notification) { NSApp.terminate(nil) }
    // belt and braces: wipe anything WebKit may have written to the default store for this app
    func applicationWillTerminate(_ n: Notification) {
        let done = DispatchSemaphore(value: 0)
        WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) { done.signal() }
        _ = done.wait(timeout: .now() + 2)
    }
    @objc func enter(_ s: Any?) { go(field.stringValue); win.makeFirstResponder(web) }
    @objc func openLocation(_ s: Any?) { win.makeFirstResponder(field); field.selectText(nil) }
    @objc func reload(_ s: Any?) { web.reload() }
    @objc func back(_ s: Any?) { web.goBack() }
    @objc func forward(_ s: Any?) { web.goForward() }
    // orange means one thing here: loading
    func webView(_ w: WKWebView, didStartProvisionalNavigation n: WKNavigation!) { box.layer!.borderColor = accent.cgColor }
    func webView(_ w: WKWebView, didCommit n: WKNavigation!) { sync() }
    func webView(_ w: WKWebView, didFinish n: WKNavigation!) { box.layer!.borderColor = border.cgColor; sync() }
    func webView(_ w: WKWebView, didFail n: WKNavigation!, withError e: Error) { box.layer!.borderColor = border.cgColor }
    func webView(_ w: WKWebView, didFailProvisionalNavigation n: WKNavigation!, withError e: Error) { box.layer!.borderColor = border.cgColor }
    func sync() {
        if let u = web.url, !u.isFileURL || !u.lastPathComponent.hasPrefix("home.html") { field.stringValue = u.absoluteString }
        else { field.stringValue = "" }
        win.title = (web.title?.isEmpty == false ? web.title! : "mini").lowercased()
    }
}
let ctl = Ctl()
win.delegate = ctl
app.delegate = ctl
web.navigationDelegate = ctl
field.target = ctl; field.action = #selector(Ctl.enter(_:))

// Menus: app (navigation) + edit (so paste works in the field)
let menu = NSMenu()
let appItem = NSMenuItem(); menu.addItem(appItem); let m = NSMenu()
m.addItem(withTitle: "Open Location…", action: #selector(Ctl.openLocation(_:)), keyEquivalent: "l").target = ctl
m.addItem(withTitle: "Reload", action: #selector(Ctl.reload(_:)), keyEquivalent: "r").target = ctl
m.addItem(withTitle: "Back", action: #selector(Ctl.back(_:)), keyEquivalent: "[").target = ctl
m.addItem(withTitle: "Forward", action: #selector(Ctl.forward(_:)), keyEquivalent: "]").target = ctl
m.addItem(NSMenuItem.separator())
m.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
appItem.submenu = m
let editItem = NSMenuItem(); menu.addItem(editItem); let e = NSMenu(title: "Edit")
e.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
e.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
e.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
e.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
e.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
editItem.submenu = e
app.mainMenu = menu

// Start
let here = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath().deletingLastPathComponent()
if CommandLine.arguments.count > 1 { go(CommandLine.arguments[1]) }
else { go(here.appendingPathComponent("home.html").path) }
win.makeKeyAndOrderFront(nil)
app.activate(ignoringOtherApps: true)
app.run()

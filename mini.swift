import Cocoa
import WebKit

// mini: a one-window WebKit browser in the Putty & Ink style.
// Usage: ./mini [url-or-file]    (no argument opens home.html)
// The page fills the window. Move the mouse to the top edge for the bar.

// Putty & Ink tokens
let putty  = NSColor(srgbRed: 0xEA/255, green: 0xE8/255, blue: 0xE1/255, alpha: 1)
let panelColor = NSColor(srgbRed: 0xF4/255, green: 0xF2/255, blue: 0xEC/255, alpha: 1)
let ink    = NSColor(srgbRed: 0x1A/255, green: 0x1A/255, blue: 0x1A/255, alpha: 1)
let border = ink.withAlphaComponent(0.9)
let accent = NSColor(srgbRed: 0xFF/255, green: 0x4A/255, blue: 0x00/255, alpha: 1)
let mono   = NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold)
let glyph  = NSFont.monospacedSystemFont(ofSize: 15, weight: .bold)
let barH: CGFloat = 60, btn: CGFloat = 38, stroke: CGFloat = 1.5, radius: CGFloat = 8
let lightsW: CGFloat = 78   // room for the traffic lights

let app = NSApplication.shared
app.setActivationPolicy(.regular)

let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 800),
                   styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
                   backing: .buffered, defer: false)
win.center()
win.backgroundColor = putty
win.titleVisibility = .hidden
win.titlebarAppearsTransparent = true
win.appearance = NSAppearance(named: .aqua)   // light only, by design
let root = win.contentView!
let W = root.bounds.width, H = root.bounds.height

// Page: fills the window, including where the title bar would be
// Nothing persists: cookies, cache, local storage, IndexedDB and history live in memory and die with the process
let cfg = WKWebViewConfiguration()
cfg.websiteDataStore = WKWebsiteDataStore.nonPersistent()
let web = WKWebView(frame: root.bounds, configuration: cfg)
web.autoresizingMask = [.width, .height]
web.setValue(false, forKey: "drawsBackground")   // putty shows through until the page paints
root.addSubview(web)

// Hardware button: circular, flat, 1.5px ink border, panel fill, ink glyph; press = opacity .55 scale .96 over 80ms
class HW: NSButton {
    convenience init(_ g: String, _ a: Selector) {
        self.init(frame: NSRect(x: 0, y: 0, width: btn, height: btn))
        title = g; font = glyph; action = a
        isBordered = false; (cell as? NSButtonCell)?.highlightsBy = []
        attributedTitle = NSAttributedString(string: g, attributes: [.font: glyph, .foregroundColor: ink])
        wantsLayer = true
        layer!.backgroundColor = panelColor.cgColor; layer!.borderColor = border.cgColor
        layer!.borderWidth = stroke; layer!.cornerRadius = btn / 2
    }
    override func mouseDown(with e: NSEvent) {
        guard isEnabled else { return }
        NSAnimationContext.runAnimationGroup { c in c.duration = 0.08; animator().alphaValue = 0.55 }
        layer!.setAffineTransform(CGAffineTransform(translationX: btn/2, y: btn/2).scaledBy(x: 0.96, y: 0.96).translatedBy(x: -btn/2, y: -btn/2))
        super.mouseDown(with: e)   // tracks until mouse up, fires the action
        NSAnimationContext.runAnimationGroup { c in c.duration = 0.08; animator().alphaValue = self.isEnabled ? 1 : 0.35 }
        layer!.setAffineTransform(.identity)
    }
    func enable(_ on: Bool) { isEnabled = on; alphaValue = on ? 1 : 0.35 }
}

// Bar: lives over the top strip, invisible until the mouse arrives, lets clicks through while hidden
class Bar: NSView {
    var inside = false
    override var mouseDownCanMoveWindow: Bool { true }
    override func mouseDown(with e: NSEvent) {   // putty background drags the window, like a title bar
        dbg("drag")
        if field.currentEditor() != nil { ctl.leaveField() }
        win.performDrag(with: e)
    }
    override func hitTest(_ p: NSPoint) -> NSView? { alphaValue == 0 ? nil : super.hitTest(p) }
    override func updateTrackingAreas() {   // add first, then super: super is what registers it with the window
        if trackingAreas.first?.rect != bounds {
            trackingAreas.forEach(removeTrackingArea)
            addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil))
        }
        super.updateTrackingAreas()
    }
    override func mouseEntered(with e: NSEvent) { dbg("entered"); inside = true; show(true) }
    override func mouseExited(with e: NSEvent) {
        if bounds.contains(convert(e.locationInWindow, from: nil)) { return }   // relayout noise, still inside
        dbg("exited"); inside = false
        if field.currentEditor() == nil { show(false) }
    }
}
func dbg(_ s: String) { if ProcessInfo.processInfo.environment["MINI_DEBUG"] != nil { FileHandle.standardError.write((s + "\n").data(using: .utf8)!) } }
func show(_ on: Bool) {   // 50ms fade, both ways; the traffic lights ride along
    dbg("show \(on) editing=\(field.currentEditor() != nil)")
    let lights = [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton].compactMap { win.standardWindowButton($0) }
    if on { lights.forEach { $0.isHidden = false } }
    NSAnimationContext.runAnimationGroup({ c in
        c.duration = 0.05
        bar.animator().alphaValue = on ? 1 : 0
        lights.forEach { $0.animator().alphaValue = on ? 1 : 0 }
    }, completionHandler: { if !on, bar.alphaValue == 0 { lights.forEach { $0.isHidden = true } } })
}

let bar = Bar(frame: NSRect(x: 0, y: H - barH, width: W, height: barH))
bar.autoresizingMask = [.width, .minYMargin]
bar.wantsLayer = true
bar.layer!.backgroundColor = putty.cgColor
root.addSubview(bar)

let y = (barH - btn) / 2
let backBtn = HW("←", #selector(Ctl.back(_:)));       backBtn.frame.origin = NSPoint(x: lightsW, y: y)
let fwdBtn = HW("→", #selector(Ctl.forward(_:)));    fwdBtn.frame.origin  = NSPoint(x: lightsW + btn + 8, y: y)
let loadBtn = HW("↻", #selector(Ctl.stopOrReload(_:))); loadBtn.frame.origin = NSPoint(x: W - 12 - btn, y: y)
loadBtn.autoresizingMask = [.minXMargin]
let boxX = lightsW + btn * 2 + 8 + 12
let box = NSView(frame: NSRect(x: boxX, y: y, width: W - boxX - 12 - btn - 12, height: btn))
box.autoresizingMask = [.width]
box.wantsLayer = true
box.layer!.backgroundColor = panelColor.cgColor; box.layer!.borderColor = border.cgColor
box.layer!.borderWidth = stroke; box.layer!.cornerRadius = radius
let field = NSTextField(frame: NSRect(x: 10, y: (btn - 18) / 2, width: box.bounds.width - 20, height: 18))
field.autoresizingMask = [.width]
field.isBezeled = false; field.drawsBackground = false; field.focusRingType = .none
field.font = mono; field.textColor = ink
field.placeholderAttributedString = NSAttributedString(string: "url or file",
    attributes: [.font: mono, .foregroundColor: ink.withAlphaComponent(0.55)])
box.addSubview(field)
[backBtn, fwdBtn, box, loadBtn].forEach(bar.addSubview)

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

class Ctl: NSObject, NSWindowDelegate, WKNavigationDelegate, NSApplicationDelegate, NSTextFieldDelegate {
    func windowWillClose(_ n: Notification) { NSApp.terminate(nil) }
    // belt and braces: wipe anything WebKit may have written to the default store for this app
    func applicationWillTerminate(_ n: Notification) {
        let done = DispatchSemaphore(value: 0)
        WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) { done.signal() }
        _ = done.wait(timeout: .now() + 2)
    }
    @objc func enter(_ s: Any?) { go(field.stringValue); leaveField() }
    @objc func openLocation(_ s: Any?) { show(true); win.makeFirstResponder(field); field.selectText(nil) }
    @objc func back(_ s: Any?) { web.goBack() }
    @objc func forward(_ s: Any?) { web.goForward() }
    @objc func stopOrReload(_ s: Any?) { if web.isLoading { web.stopLoading(); sync() } else { web.reload() } }
    @objc func reload(_ s: Any?) { web.reload() }
    func leaveField() { win.makeFirstResponder(web); if !bar.inside { show(false) } }
    // esc in the field: give up and hide the bar
    func control(_ c: NSControl, textView: NSTextView, doCommandBy sel: Selector) -> Bool {
        if sel == #selector(NSResponder.cancelOperation(_:)) { sync(); leaveField(); return true }
        return false
    }
    // orange means one thing here: loading
    func webView(_ w: WKWebView, didStartProvisionalNavigation n: WKNavigation!) { box.layer!.borderColor = accent.cgColor; sync() }
    func webView(_ w: WKWebView, didCommit n: WKNavigation!) { sync() }
    func webView(_ w: WKWebView, didFinish n: WKNavigation!) { box.layer!.borderColor = border.cgColor; sync() }
    func webView(_ w: WKWebView, didFail n: WKNavigation!, withError e: Error) { box.layer!.borderColor = border.cgColor; sync() }
    func webView(_ w: WKWebView, didFailProvisionalNavigation n: WKNavigation!, withError e: Error) { box.layer!.borderColor = border.cgColor; sync() }
    func sync() {
        if field.currentEditor() == nil {
            if let u = web.url, !u.isFileURL || !u.lastPathComponent.hasPrefix("home.html") { field.stringValue = u.absoluteString }
            else { field.stringValue = "" }
        }
        win.title = (web.title?.isEmpty == false ? web.title! : "mini").lowercased()
        backBtn.enable(web.canGoBack); fwdBtn.enable(web.canGoForward)
        let g = web.isLoading ? "×" : "↻"
        loadBtn.attributedTitle = NSAttributedString(string: g, attributes: [.font: glyph, .foregroundColor: ink])
    }
}
let ctl = Ctl()
win.delegate = ctl
app.delegate = ctl
web.navigationDelegate = ctl
field.delegate = ctl
field.target = ctl; field.action = #selector(Ctl.enter(_:))
[backBtn, fwdBtn, loadBtn].forEach { $0.target = ctl }

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
show(false)
ctl.sync()
win.makeKeyAndOrderFront(nil)
win.makeFirstResponder(web)
app.activate(ignoringOtherApps: true)
app.run()

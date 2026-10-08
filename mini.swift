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
// Hover: the bar shows when the cursor is in the top strip, and hides 350ms after it is more than a strip below the bar.
// That gap means the bit of page the bar used to cover stays clickable while the bar is up.
var shown = false                                // where the bar is headed
var reveal: CGFloat = 0                          // where it is: 0 tucked behind the page .. 1 all the way up
var grown = (dy: CGFloat(0), dh: CGFloat(0))     // how much the window gets pushed and grown at full reveal
var applied = (dy: CGFloat(0), dh: CGFloat(0))   // how much of that is on the window right now
var tide: Timer?, ebb: Timer?                    // the 150ms slide, and the 350ms wait before a hide
func inZone() -> Bool {   // is the cursor where the bar should stay up?
    let p = root.convert(win.mouseLocationOutsideOfEventStream, from: nil)
    return root.bounds.contains(p) && root.bounds.height - p.y <= (shown ? barH * 2 : barH)
}
let root = win.contentView!
let W = root.bounds.width, H = root.bounds.height

// Page: fills the window, including where the title bar would be
// Nothing persists: cookies, cache, local storage, IndexedDB and history live in memory and die with the process
let cfg = WKWebViewConfiguration()
cfg.websiteDataStore = WKWebsiteDataStore.nonPersistent()
let web = WKWebView(frame: root.bounds, configuration: cfg)
web.autoresizingMask = [.width]   // height is placeWeb's alone, so growing the window for the bar never stretches the page
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
    // an SF Symbol in place of the text glyph, drawn in ink at the glyph's size and weight
    func symbol(_ name: String) {
        let c = NSImage.SymbolConfiguration(pointSize: 15, weight: .bold).applying(.init(paletteColors: [ink]))
        image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(c)
        imagePosition = .imageOnly; title = ""
    }
}

// Bar: lives in the strip above the page, clipped to it, invisible until the mouse arrives, lets clicks through while hidden
class Bar: NSView {
    override var mouseDownCanMoveWindow: Bool { true }
    override func mouseDown(with e: NSEvent) {   // putty background drags the window, like a title bar
        dbg("drag")
        if field.currentEditor() != nil { ctl.leaveField() }
        win.performDrag(with: e)
    }
    override func hitTest(_ p: NSPoint) -> NSView? { alphaValue == 0 ? nil : super.hitTest(p) }
}
func dbg(_ s: String) { if ProcessInfo.processInfo.environment["MINI_DEBUG"] != nil { FileHandle.standardError.write((s + "\n").data(using: .utf8)!) } }
func placeWeb() {   // the bar sits above the page, never over it, in a strip as tall as it has slid up
    let b = root.bounds, full = win.styleMask.contains(.fullScreen)
    let strip = full ? 0 : (barH * reveal).rounded()
    let f = NSRect(x: 0, y: 0, width: b.width, height: b.height - strip)
    if web.frame != f { web.frame = f }
    let g = full ? NSRect(x: 0, y: b.height - barH, width: b.width, height: barH) : NSRect(x: 0, y: f.maxY, width: b.width, height: strip)
    if bar.frame != g { bar.frame = g }   // its contents hang from its top, so they rise out from behind the page
}
var lights: [NSButton] { [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton].compactMap { win.standardWindowButton($0) } }
func setReveal(_ p: CGFloat) {   // window, page, bar and traffic lights all where p says; the page only moves if the window has to slide down
    reveal = p
    if !win.styleMask.contains(.fullScreen) {
        let want = (dy: (grown.dy * p).rounded(), dh: (grown.dh * p).rounded())
        var t = win.frame; t.origin.y += want.dy - applied.dy; t.size.height += want.dh - applied.dh
        applied = want
        if t != win.frame { win.setFrame(t, display: true) }
    }
    placeWeb()
    bar.alphaValue = p
    lights.forEach { $0.isHidden = p == 0; $0.alphaValue = p }
}
func show(_ on: Bool, after wait: TimeInterval = 0) {   // the window grows up for the bar as it slides out from behind the page, fading in, and back after; 150ms, popping up and easing down
    if !on, wait > 0 {   // the mouse wandered off: hide in a moment, unless it comes back first
        if shown, ebb == nil {
            ebb = Timer(timeInterval: wait, repeats: false) { _ in ebb = nil; if field.currentEditor() == nil { show(false) } }
            RunLoop.main.add(ebb!, forMode: .common)
        }
        return
    }
    ebb?.invalidate(); ebb = nil
    guard on != shown else { return }
    shown = on
    dbg("show \(on) editing=\(field.currentEditor() != nil) from=\(reveal)")
    if on, reveal == 0, !win.styleMask.contains(.fullScreen) {
        let f = win.frame
        var t = f; t.size.height += barH   // same origin: the top edge moves up, the page stays put
        t = win.constrainFrameRect(t, to: win.screen)   // no room above the menu bar: the window slides down instead
        grown = (t.origin.y - f.origin.y, t.height - f.height); applied = (0, 0)
        dbg("growing \(f) by \(grown)")
    }
    // up: ease-out quint, a quick pop that lands without overshooting; down: ease-out cubic.
    // picked up from wherever the bar is on the curve, so turning back mid-slide never jumps
    tide?.invalidate()
    let ease = { (c: CGFloat) in on ? 1 - pow(1 - c, 5) : pow(1 - c, 3) }
    var c = on ? 1 - pow(1 - reveal, 0.2) : 1 - cbrt(reveal), last = CACurrentMediaTime()
    tide = Timer(timeInterval: 1.0 / 120, repeats: true) { t in
        let now = CACurrentMediaTime()
        c = min(1, c + CGFloat((now - last) / 0.15)); last = now
        setReveal(ease(c))
        if c == 1 { t.invalidate(); tide = nil; if !on { grown = (0, 0) } }
    }
    RunLoop.main.add(tide!, forMode: .common)
}

// Zone: see-through, covers the window, watches the cursor; clicks go straight through to the page
class Zone: NSView {
    override func hitTest(_ p: NSPoint) -> NSView? { nil }
    override func updateTrackingAreas() {   // add first, then super: super is what registers it with the window
        if trackingAreas.first?.rect != bounds {
            trackingAreas.forEach(removeTrackingArea)
            addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil))
        }
        super.updateTrackingAreas()
    }
    override func mouseEntered(with e: NSEvent) { track(e) }
    override func mouseMoved(with e: NSEvent) { track(e) }
    override func mouseExited(with e: NSEvent) {
        if bounds.contains(convert(e.locationInWindow, from: nil)) { return }   // relayout noise, still inside
        dbg("left window"); if shown, field.currentEditor() == nil { show(false, after: 0.35) }
    }
    func track(_ e: NSEvent) {
        let fromTop = bounds.height - convert(e.locationInWindow, from: nil).y
        if fromTop <= (shown ? barH * 2 : barH) { show(true) }   // back in the zone also calls off a pending hide
        else if shown, field.currentEditor() == nil { show(false, after: 0.35) }
    }
}
let zone = Zone(frame: root.bounds)
zone.autoresizingMask = [.width, .height]
root.addSubview(zone)

let bar = Bar(frame: NSRect(x: 0, y: H - barH, width: W, height: barH))
bar.autoresizingMask = [.width, .minYMargin]
bar.wantsLayer = true
bar.layer!.backgroundColor = putty.cgColor
bar.layer!.masksToBounds = true
root.addSubview(bar)

let y = (barH - btn) / 2
let backBtn = HW("←", #selector(Ctl.back(_:)));       backBtn.frame.origin = NSPoint(x: lightsW, y: y)
let fwdBtn = HW("→", #selector(Ctl.forward(_:)));    fwdBtn.frame.origin  = NSPoint(x: lightsW + btn + 8, y: y)
let loadBtn = HW("", #selector(Ctl.stopOrReload(_:))); loadBtn.frame.origin = NSPoint(x: W - 12 - btn, y: y)
loadBtn.symbol("arrow.clockwise")
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
[backBtn, fwdBtn, box, loadBtn].forEach { $0.autoresizingMask.insert(.minYMargin); bar.addSubview($0) }   // pinned to the bar's top edge

func go(_ s: String) {
    let t = s.trimmingCharacters(in: .whitespaces)
    guard !t.isEmpty else { return }
    var u: URL?
    if let x = URL(string: t), let sc = x.scheme?.lowercased(), ["http", "https", "file"].contains(sc) {
        u = x   // a real scheme; "host:8001" also parses as a scheme, so anything else falls through
    } else {
        let p = (t as NSString).expandingTildeInPath
        if FileManager.default.fileExists(atPath: p) { u = URL(fileURLWithPath: p) }
        else {
            let host = t.split(separator: "/", maxSplits: 1)[0].lowercased()
            let name = host.split(separator: ":")[0]
            let local = name == "localhost" || name.hasSuffix(".local") || !name.contains(".") || name.allSatisfy { $0.isNumber || $0 == "." }
            u = URL(string: (local ? "http://" : "https://") + t)   // local hosts and ips rarely speak tls
        }
    }
    guard let url = u else { return }
    if url.isFileURL { web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent()) }
    else { web.load(URLRequest(url: url)) }
}

// About panel text. The LICENSE file next to the source is the same text.
let mit = """
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
"""

class Ctl: NSObject, NSWindowDelegate, WKNavigationDelegate, NSApplicationDelegate, NSTextFieldDelegate {
    func windowWillClose(_ n: Notification) { NSApp.terminate(nil) }
    func windowDidResize(_ n: Notification) { placeWeb() }
    // belt and braces: wipe anything WebKit may have written to the default store for this app, then quit.
    // The wipe reports back on the main thread, so we must not block it: say "later" and keep the run loop
    // going until the wipe is done. Blocking on a semaphore here silently waited out its whole timeout on every quit.
    func applicationShouldTerminate(_ a: NSApplication) -> NSApplication.TerminateReply {
        let t0 = Date(); var replied = false
        func finish(_ how: String) {
            if replied { return }; replied = true
            dbg("quit: \(how) after \(Int(Date().timeIntervalSince(t0) * 1000)) ms")
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) { finish("wiped") }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { finish("gave up on the wipe") }   // never hang on quit
        return .terminateLater
    }
    @objc func enter(_ s: Any?) { go(field.stringValue); leaveField() }
    @objc func openLocation(_ s: Any?) { show(true); win.makeFirstResponder(field); field.selectText(nil) }
    @objc func back(_ s: Any?) { web.goBack() }
    @objc func forward(_ s: Any?) { web.goForward() }
    @objc func stopOrReload(_ s: Any?) { if web.isLoading { web.stopLoading(); sync() } else { web.reload() } }
    @objc func reload(_ s: Any?) { web.reload() }
    // About: a small putty panel with the name, what it is, who made it and the license
    var aboutPanel: NSPanel?
    @objc func about(_ s: Any?) {
        if aboutPanel == nil {
            let w: CGFloat = 420, pad: CGFloat = 24, inner = w - pad * 2, faint = ink.withAlphaComponent(0.55)
            let lines: [(String, CGFloat, NSFont.Weight, NSColor, CGFloat, CGFloat)] = [   // text, size, weight, color, kern, gap below
                ("mini browser", 22, .bold, ink, 3, 6),
                ("© 2026 jeff easter · mit license\nbuilt on apple's appkit and webkit; no third-party code", 12, .regular, faint, 0, 14),
                (mit.trimmingCharacters(in: .newlines), 11, .regular, faint, 0, 0),
            ]
            var labels: [(NSTextField, CGFloat, CGFloat)] = [], total = pad + 20   // paddings: 20 top, 24 bottom
            for (text, size, weight, color, kern, gap) in lines {
                let t = NSTextField(wrappingLabelWithString: "")
                t.attributedStringValue = NSAttributedString(string: text, attributes: [.font: NSFont.monospacedSystemFont(ofSize: size, weight: weight), .foregroundColor: color, .kern: kern])
                let h = t.cell!.cellSize(forBounds: NSRect(x: 0, y: 0, width: inner, height: 10_000)).height.rounded(.up)
                labels.append((t, h, gap)); total += h + gap
            }
            let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: w, height: total), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            p.titleVisibility = .hidden; p.titlebarAppearsTransparent = true
            p.backgroundColor = putty; p.appearance = NSAppearance(named: .aqua); p.isReleasedWhenClosed = false
            var top = total - 20
            for (t, h, gap) in labels {
                t.frame = NSRect(x: pad, y: top - h, width: inner, height: h)
                p.contentView!.addSubview(t); top -= h + gap
            }
            aboutPanel = p
        }
        aboutPanel!.center(); aboutPanel!.makeKeyAndOrderFront(nil)
    }
    func leaveField() { win.makeFirstResponder(web); if !inZone() { show(false) } }
    // esc in the field: give up and hide the bar
    func control(_ c: NSControl, textView: NSTextView, doCommandBy sel: Selector) -> Bool {
        if sel == #selector(NSResponder.cancelOperation(_:)) { sync(); leaveField(); return true }
        return false
    }
    // orange means one thing here: loading
    func webView(_ w: WKWebView, decidePolicyFor a: WKNavigationAction, decisionHandler d: @escaping (WKNavigationActionPolicy) -> Void) {
        let sc = a.request.url?.scheme?.lowercased() ?? ""
        d(["http", "https", "file", "about", "blob", "data"].contains(sc) ? .allow : .cancel)   // http, https, file, plus webkit-internal pseudo-schemes that never leave the process; nothing is ever handed to another app
    }
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
        loadBtn.symbol(web.isLoading ? "xmark" : "arrow.clockwise")
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
m.addItem(withTitle: "About mini", action: #selector(Ctl.about(_:)), keyEquivalent: "").target = ctl
m.addItem(NSMenuItem.separator())
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
setReveal(0)
ctl.sync()
win.makeKeyAndOrderFront(nil)
win.makeFirstResponder(web)
app.activate(ignoringOtherApps: true)
app.run()

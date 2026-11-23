import UIKit
import WebKit

class ExternalBrowserViewController: UIViewController, WKNavigationDelegate {
    var webView: WKWebView!
    var chromeTabURLs: [String] = ["https://google.com"]
    var chromeTabTitles: [String] = ["Google"]
    var activeChromeTab: Int = 0
    var isChromeMode: Bool = false

    let cursorView = UIView()
    private let desktopView = UIView()
    private let chromeTopBar = UIView()
    private let chromeTabScroll = UIScrollView()
    private let dockView = UIVisualEffectView(
        effect: UIBlurEffect(style: .systemThinMaterialDark)
    )
    private let lastURLKey = "SavedLastVisitedURL"
    private var isVideoZoomedFull = false
    private var didInitialLoad = false
    var onInputSelected: ((String) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        setupDesktopWallpaper()
        setupWebView()
        setupChromeTopBar()
        setupFloatingDock()
        setupCursor()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(pauseAllMediaOnBackground),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let gradient = desktopView.layer.sublayers?.first as? CAGradientLayer {
            gradient.frame = desktopView.bounds
        }
        chromeTopBar.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 42)
        chromeTabScroll.frame = CGRect(x: 8, y: 4, width: view.bounds.width - 16, height: 34)

        let topOffset: CGFloat = isChromeMode ? 42 : 0
        webView.frame = CGRect(
            x: 0,
            y: topOffset,
            width: view.bounds.width,
            height: max(100, view.bounds.height - topOffset)
        )

        if cursorView.center == .zero {
            cursorView.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        }
        view.bringSubviewToFront(chromeTopBar)
        view.bringSubviewToFront(dockView)
        view.bringSubviewToFront(cursorView)

        if !didInitialLoad && view.bounds.width > 200 {
            didInitialLoad = true
            let saved = UserDefaults.standard.string(forKey: lastURLKey) ?? ""
            if saved.hasPrefix("http") {
                if saved.contains("google.com") {
                    launchChrome(urlString: saved)
                } else {
                    openSingleApp(saved)
                }
            } else {
                showDesktop()
            }
        }
    }

    @objc private func pauseAllMediaOnBackground() {
        let js = "document.querySelectorAll('video,audio').forEach(function(m){m.pause();});"
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }

    private func setupDesktopWallpaper() {
        desktopView.frame = view.bounds
        desktopView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        let gradient = CAGradientLayer()
        gradient.frame = view.bounds
        gradient.colors = [
            UIColor(red: 0.08, green: 0.12, blue: 0.24, alpha: 1).cgColor,
            UIColor(red: 0.16, green: 0.09, blue: 0.28, alpha: 1).cgColor,
            UIColor(red: 0.05, green: 0.06, blue: 0.12, alpha: 1).cgColor
        ]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        desktopView.layer.insertSublayer(gradient, at: 0)

        let titleLabel = UILabel()
        titleLabel.text = "MyDesktop OS"
        titleLabel.font = .systemFont(ofSize: 38, weight: .bold)
        titleLabel.textColor = UIColor.white.withAlphaComponent(0.9)
        titleLabel.textAlignment = .center
        titleLabel.frame = CGRect(
            x: 0, y: 120, width: view.bounds.width, height: 50
        )
        titleLabel.autoresizingMask = [.flexibleWidth]
        desktopView.addSubview(titleLabel)

        let subLabel = UILabel()
        subLabel.text = "Click an app below or use your iPhone trackpad"
        subLabel.font = .systemFont(ofSize: 18, weight: .medium)
        subLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        subLabel.textAlignment = .center
        subLabel.frame = CGRect(
            x: 0, y: 172, width: view.bounds.width, height: 30
        )
        subLabel.autoresizingMask = [.flexibleWidth]
        desktopView.addSubview(subLabel)

        view.addSubview(desktopView)
    }

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let s1 = "setInterval(function(){"
        let s2 = "var s=document.querySelector('.ytp-skip-ad-button,.ytp-ad-skip-button,.ytp-ad-skip-button-modern');"
        let s3 = "if(s){s.click();}"
        let s4 = "var o=document.querySelector('.ytp-ad-player-overlay,.ad-showing');"
        let s5 = "var v=document.querySelector('#movie_player video,.html5-main-video');"
        let s6 = "if(o&&v&&isFinite(v.duration)&&v.duration>0){v.currentTime=v.duration;}"
        let s7 = "},400);"
        let scriptSource = s1 + s2 + s3 + s4 + s5 + s6 + s7

        let userScript = WKUserScript(
            source: scriptSource,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        config.userContentController.addUserScript(userScript)

        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.navigationDelegate = self
        webView.scrollView.minimumZoomScale = 0.5
        webView.scrollView.maximumZoomScale = 3.0
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"
        webView.isHidden = true
        view.addSubview(webView)
    }

    // Desktop-style Google Chrome Top Tab Strip on the External Monitor!
    private func setupChromeTopBar() {
        chromeTopBar.backgroundColor = UIColor(red: 0.13, green: 0.14, blue: 0.17, alpha: 1)
        chromeTopBar.isHidden = true
        chromeTopBar.addSubview(chromeTabScroll)
        view.addSubview(chromeTopBar)
    }

    private func rebuildMonitorChromeTabs() {
        for sub in chromeTabScroll.subviews { sub.removeFromSuperview() }
        var x: CGFloat = 4

        for (i, title) in chromeTabTitles.enumerated() {
            let isSelected = (i == activeChromeTab)
            let tabW: CGFloat = 170

            let tabPill = UIView(frame: CGRect(x: x, y: 2, width: tabW, height: 30))
            tabPill.backgroundColor = isSelected
                ? UIColor(red: 0.24, green: 0.25, blue: 0.29, alpha: 1)
                : UIColor(red: 0.17, green: 0.18, blue: 0.21, alpha: 1)
            tabPill.layer.cornerRadius = 8

            let selectBtn = UIButton(type: .custom)
            selectBtn.frame = CGRect(x: 0, y: 0, width: tabW - 28, height: 30)
            selectBtn.tag = i
            selectBtn.setTitle("  " + title, for: .normal)
            selectBtn.contentHorizontalAlignment = .left
            selectBtn.titleLabel?.font = .systemFont(ofSize: 13, weight: isSelected ? .semibold : .regular)
            selectBtn.titleLabel?.lineBreakMode = .byTruncatingTail
            selectBtn.setTitleColor(.white, for: .normal)
            selectBtn.addTarget(self, action: #selector(monitorSelectTab(_:)), for: .touchUpInside)
            tabPill.addSubview(selectBtn)

            let closeBtn = UIButton(type: .custom)
            closeBtn.frame = CGRect(x: tabW - 26, y: 3, width: 22, height: 24)
            closeBtn.tag = i
            closeBtn.setTitle("×", for: .normal)
            closeBtn.titleLabel?.font = .systemFont(ofSize: 15, weight: .bold)
            closeBtn.setTitleColor(.lightGray, for: .normal)
            closeBtn.addTarget(self, action: #selector(monitorCloseTab(_:)), for: .touchUpInside)
            tabPill.addSubview(closeBtn)

            chromeTabScroll.addSubview(tabPill)
            x += tabW + 6
        }

        let addBtn = UIButton(type: .custom)
        addBtn.frame = CGRect(x: x, y: 3, width: 28, height: 28)
        addBtn.setTitle("+", for: .normal)
        addBtn.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        addBtn.setTitleColor(.white, for: .normal)
        addBtn.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        addBtn.layer.cornerRadius = 14
        addBtn.addTarget(self, action: #selector(monitorAddTab), for: .touchUpInside)
        chromeTabScroll.addSubview(addBtn)
        x += 36

        chromeTabScroll.contentSize = CGSize(width: max(x, chromeTabScroll.bounds.width), height: 34)
    }

    @objc private func monitorSelectTab(_ sender: UIButton) {
        switchChromeTab(index: sender.tag)
    }

    @objc private func monitorCloseTab(_ sender: UIButton) {
        closeChromeTab(index: sender.tag)
    }

    @objc private func monitorAddTab() {
        addChromeTab(urlString: "https://google.com")
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let current = webView.url?.absoluteString, current.hasPrefix("http") {
            UserDefaults.standard.set(current, forKey: lastURLKey)
            if isChromeMode && chromeTabURLs.indices.contains(activeChromeTab) {
                chromeTabURLs[activeChromeTab] = current
                let pageTitle = (webView.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let host = webView.url?.host?.replacingOccurrences(of: "www.", with: "") ?? "Google"
                chromeTabTitles[activeChromeTab] = pageTitle.isEmpty ? host : pageTitle
                rebuildMonitorChromeTabs()
            }
        }
    }

    private func setupFloatingDock() {
        let dockWidth: CGFloat = 460
        let dockHeight: CGFloat = 86
        dockView.frame = CGRect(
x: (view.bounds.width - dockWidth) / 2,
y: view.bounds.height - dockHeight - 24,
width: dockWidth,
height: dockHeight
)
dockView.layer.cornerRadius = 24
dockView.clipsToBounds = true
dockView.layer.borderWidth = 1
dockView.layer.borderColor = UIColor.white.withAlphaComponent(0.25).cgColor
dockView.autoresizingMask = [
.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin
]
view.addSubview(dockView)
let apps: [(String, String, UIColor, Selector)] = [
("Desktop", "macwindow", .systemIndigo, #selector(showDesktop)),
("YouTube", "play.rectangle.fill", .systemRed, #selector(launchYouTube)),
("Chrome", "globe", .systemBlue, #selector(launchChromeDefault)),
("Netflix", "film.fill", .systemOrange, #selector(launchNetflix))
]
let itemWidth: CGFloat = 95
let spacing: CGFloat = 14
let totalW = CGFloat(apps.count) * itemWidth + CGFloat(apps.count - 1) * spacing
let startX: CGFloat = (dockWidth - totalW) / 2
for (i, app) in apps.enumerated() {
let btn = UIButton(type: .custom)
btn.frame = CGRect(
x: startX + CGFloat(i) * (itemWidth + spacing),
y: 10,
width: itemWidth,
height: 66
)
btn.addTarget(self, action: app.3, for: .touchUpInside)
let iconBg = UIView(
frame: CGRect(x: (itemWidth - 44) / 2, y: 0, width: 44, height: 44)
)
iconBg.backgroundColor = app.2
iconBg.layer.cornerRadius = 12
iconBg.isUserInteractionEnabled = false
let iconImg = UIImageView(image: UIImage(systemName: app.1))
iconImg.tintColor = .white
iconImg.contentMode = .scaleAspectFit
iconImg.frame = CGRect(x: 10, y: 10, width: 24, height: 24)
iconBg.addSubview(iconImg)
btn.addSubview(iconBg)
let label = UILabel(
frame: CGRect(x: 0, y: 47, width: itemWidth, height: 18)
)
label.text = app.0
label.font = .systemFont(ofSize: 12, weight: .semibold)
label.textColor = .white
label.textAlignment = .center
btn.addSubview(label)
dockView.contentView.addSubview(btn)
}
}
private func setupCursor() {
cursorView.frame = CGRect(x: 0, y: 0, width: 22, height: 22)
cursorView.backgroundColor = UIColor.systemRed.withAlphaComponent(0.9)
cursorView.layer.cornerRadius = 11
cursorView.layer.borderWidth = 2.5
cursorView.layer.borderColor = UIColor.white.cgColor
cursorView.layer.shadowColor = UIColor.black.cgColor
cursorView.layer.shadowOpacity = 0.6
cursorView.layer.shadowRadius = 4
cursorView.layer.shadowOffset = CGSize(width: 0, height: 2)
cursorView.isUserInteractionEnabled = false
view.addSubview(cursorView)
}
@objc func showDesktop() {
pauseAllMediaOnBackground()
isChromeMode = false
isVideoZoomedFull = false
chromeTopBar.isHidden = true
webView.isHidden = true
desktopView.isHidden = false
dockView.isHidden = false
UserDefaults.standard.removeObject(forKey: lastURLKey)
}
@objc func launchYouTube() { openSingleApp("youtube.com") }
@objc func launchNetflix() { openSingleApp("netflix.com") }
@objc func launchChromeDefault() { launchChrome(urlString: "google.com") }
func openSingleApp(_ urlString: String) {
isChromeMode = false
isVideoZoomedFull = false
chromeTopBar.isHidden = true
desktopView.isHidden = true
dockView.isHidden = true
webView.frame = view.bounds
webView.isHidden = false
UserDefaults.standard.set(urlString, forKey: lastURLKey)
if let url = URL(string: urlString) {
webView.load(URLRequest(url: url))
}
}
func launchChrome(urlString: String = "google.com") {
isChromeMode = true
isVideoZoomedFull = false
desktopView.isHidden = true
dockView.isHidden = true
chromeTopBar.isHidden = false
webView.frame = CGRect(x: 0, y: 42, width: view.bounds.width, height: max(100, view.bounds.height - 42))
webView.isHidden = false
if chromeTabURLs.isEmpty {
chromeTabURLs = [urlString]
chromeTabTitles = ["Google"]
activeChromeTab = 0
} else {
chromeTabURLs[activeChromeTab] = urlString
}
rebuildMonitorChromeTabs()
UserDefaults.standard.set(urlString, forKey: lastURLKey)
if let url = URL(string: urlString) {
webView.load(URLRequest(url: url))
}
}
func addChromeTab(urlString: String = "google.com") {
isChromeMode = true
chromeTabURLs.append(urlString)
chromeTabTitles.append("New Tab")
activeChromeTab = chromeTabURLs.count - 1
launchChrome(urlString: urlString)
}
func switchChromeTab(index: Int) {
guard chromeTabURLs.indices.contains(index) else { return }
activeChromeTab = index
launchChrome(urlString: chromeTabURLs[index])
}
func closeChromeTab(index: Int) {
guard chromeTabURLs.indices.contains(index) else { return }
chromeTabURLs.remove(at: index)
chromeTabTitles.remove(at: index)
if chromeTabURLs.isEmpty {
chromeTabURLs = ["google.com"]
chromeTabTitles = ["Google"]
activeChromeTab = 0
} else {
activeChromeTab = min(index, chromeTabURLs.count - 1)
}
launchChrome(urlString: chromeTabURLs[activeChromeTab])
}
func toggleDock() {
dockView.isHidden.toggle()
}
func moveCursor(dx: CGFloat, dy: CGFloat) {
let newX = min(max(0, cursorView.center.x + dx), view.bounds.width)
let newY = min(max(0, cursorView.center.y + dy), view.bounds.height)
cursorView.center = CGPoint(x: newX, y: newY)
}
func clickAtCursor() {
let point = cursorView.center
UIView.animate(withDuration: 0.08, animations: {
self.cursorView.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
}) { _ in
UIView.animate(withDuration: 0.08) {
self.cursorView.transform = .identity
}
}
// Check Desktop Dock clicks
if !dockView.isHidden {
let pointInDock = view.convert(point, to: dockView.contentView)
for subview in dockView.contentView.subviews {
if let btn = subview as? UIButton, btn.frame.contains(pointInDock) {
btn.sendActions(for: .touchUpInside)
return
}
}
}
// Check Chrome Top Tab Bar clicks on the Monitor!
if !chromeTopBar.isHidden && point.y <= 42 {
let ptInScroll = view.convert(point, to: chromeTabScroll)
for sub in chromeTabScroll.subviews {
if let addBtn = sub as? UIButton, addBtn.frame.contains(ptInScroll) {
addBtn.sendActions(for: .touchUpInside)
return
}
if sub.frame.contains(ptInScroll) {
for child in sub.subviews {
if let btn = child as? UIButton {
let ptInChild = chromeTabScroll.convert(ptInScroll, to: sub)
if btn.frame.contains(ptInChild) {
btn.sendActions(for: .touchUpInside)
return
}
}
}
}
}
return
}
guard !webView.isHidden else { return }
let webPoint = view.convert(point, to: webView)
let scale = max(0.1, webView.scrollView.zoomScale)
let px = String(Double(webPoint.x / scale))
let py = String(Double(webPoint.y / scale))
let txtSel = "textarea,input:not([type=hidden]):not([type=file]):not([type=submit]):not([type=button]):not([type=checkbox]):not([type=radio])"
let c1 = "(function(){var x=" + px + ";var y=" + py + ";"
let c2 = "var el=document.elementFromPoint(x,y);if(!el)return null;"
let c3 = "var inp=el.matches('" + txtSel + "')?el:el.closest('" + txtSel + "');"
let c4 = "if(!inp&&!el.closest('button,[role=button],a,[role=option],li')){var box=el.closest('[role=search],[role=combobox],.RNNXgb,.ytSearchboxComponentInputBox');if(box){inp=box.querySelector('" + txtSel + "');}}"
let c5 = "if(inp){window.__lastFocusedInput=inp;inp.focus();return {isInput:true,val:(inp.value||'')};}"
let c6 = "window.__lastFocusedInput=null;"
let c7 = "if(el.closest('.ytp-fullscreen-button')){return {isInput:false,hitFullscreen:true};}"
let c8 = "var t=el.closest('a,button,[role=button],[role=option],[role=tab],[role=link],[role=menuitem],[role=menuitemradio],[role=menuitemcheckbox],.ytp-menuitem,li,select,label,yt-formatted-string,ytd-thumbnail')||el;"
let c9 = "if(t.focus){t.focus();}"
let c10 = "var po={view:window,bubbles:true,cancelable:true,clientX:x,clientY:y,pointerId:1,pointerType:'mouse',isPrimary:true,button:0,buttons:1};"
let c11 = "var mo={view:window,bubbles:true,cancelable:true,clientX:x,clientY:y,button:0,buttons:1};"
let c12 = "if(window.PointerEvent){t.dispatchEvent(new PointerEvent('pointerdown',po));}"
let c13 = "t.dispatchEvent(new MouseEvent('mousedown',mo));"
let c14 = "if(window.PointerEvent){t.dispatchEvent(new PointerEvent('pointerup',po));}"
let c15 = "t.dispatchEvent(new MouseEvent('mouseup',mo));"
let c16 = "t.dispatchEvent(new MouseEvent('click',mo));"
let c17 = "if(t.tagName==='A'&&t.href&&t.href.indexOf('javascript:')!==0){window.location.href=t.href;}"
let c18 = "return {isInput:false,hitFullscreen:false};})();"
webView.evaluateJavaScript(c1 + c2 + c3 + c4 + c5 + c6 + c7 + c8 + c9 + c10 + c11 + c12 + c13 + c14 + c15 + c16 + c17 + c18) { [weak self] res, _ in
guard let dict = res as? [String: Any] else { return }
if let hitFS = dict["hitFullscreen"] as? Bool, hitFS {
self?.toggleFullscreen()
return
}
if let isInput = dict["isInput"] as? Bool, isInput {
let existingText = (dict["val"] as? String) ?? ""
self?.onInputSelected?(existingText)
}
}
}
func typeTextIntoFocusedInput(_ text: String, submit: Bool) {
let base64 = Data(text.utf8).base64EncodedString()
let submitFlag = submit ? "true" : "false"
let txtSel = "textarea,input:not([type=hidden]):not([type=file]):not([type=submit]):not([type=button]):not([type=checkbox]):not([type=radio])"
let t1 = "(function(){var bin=atob('" + base64 + "');var b=new Uint8Array(bin.length);"
let t2 = "for(var i=0;i<bin.length;i++){b[i]=bin.charCodeAt(i);}"
let t3 = "var val=new TextDecoder().decode(b);var inp=window.__lastFocusedInput||document.activeElement;"
let t4 = "if(!inp||!inp.matches('" + txtSel + "')){inp=document.querySelector('" + txtSel + "');}"
let t5 = "if(!inp)return;window.__lastFocusedInput=inp;inp.focus();"
let t6 = "var s=Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype,'value');"
let t7 = "var ts=Object.getOwnPropertyDescriptor(window.HTMLTextAreaElement.prototype,'value');"
let t8 = "if(inp.tagName==='TEXTAREA'&&ts&&ts.set){ts.set.call(inp,val);}else if(s&&s.set){s.set.call(inp,val);}else{inp.value=val;}"
let t9 = "inp.dispatchEvent(new Event('input',{bubbles:true}));inp.dispatchEvent(new Event('change',{bubbles:true}));"
let t10 = "if(" + submitFlag + "){"
let t11 = "inp.dispatchEvent(new KeyboardEvent('keydown',{key:'Enter',code:'Enter',keyCode:13,which:13,bubbles:true}));"
let t12 = "inp.dispatchEvent(new KeyboardEvent('keypress',{key:'Enter',code:'Enter',keyCode:13,which:13,bubbles:true}));"
let t13 = "inp.dispatchEvent(new KeyboardEvent('keyup',{key:'Enter',code:'Enter',keyCode:13,which:13,bubbles:true}));"
let t14 = "var f=inp.closest('form');if(f){f.dispatchEvent(new Event('submit',{bubbles:true,cancelable:true}));f.submit();}"
let t15 = "}})();"
webView.evaluateJavaScript(t1 + t2 + t3 + t4 + t5 + t6 + t7 + t8 + t9 + t10 + t11 + t12 + t13 + t14 + t15, completionHandler: nil)
}
func hasFocusedInput(completion: @escaping (Bool) -> Void) {
let js = "Boolean(window.__lastFocusedInput)"
webView.evaluateJavaScript(js) { res, _ in
completion((res as? Bool) ?? false)
}
}
func skipVideo(seconds: Double) {
let sec = String(seconds)
let k1 = "(function(){var vids=Array.from(document.querySelectorAll('video'));"
let k2 = "var v=vids.find(function(x){return !x.paused&&x.duration>0;})||document.querySelector('#movie_player video')||vids;"
let k3 = "if(v&&isFinite(v.duration)){v.currentTime=Math.min(Math.max(0,v.currentTime+" + sec + "),v.duration);}})();"
webView.evaluateJavaScript(k1 + k2 + k3, completionHandler: nil)
}
func seekVideo(fraction: Double) {
let frac = String(fraction)
let k1 = "(function(){var vids=Array.from(document.querySelectorAll('video'));"
let k2 = "var v=vids.find(function(x){return !x.paused&&x.duration>0;})||document.querySelector('#movie_player video')||vids;"
let k3 = "if(v&&isFinite(v.duration)&&v.duration>0){v.currentTime=v.duration*" + frac + ";}})();"
webView.evaluateJavaScript(k1 + k2 + k3, completionHandler: nil)
}
func toggleFullscreen() {
isVideoZoomedFull.toggle()
let fullFlag = isVideoZoomedFull ? "true" : "false"
let f1 = "(function(){var style=document.getElementById('custom-fs-style');"
let f2 = "if(" + fullFlag + "){"
let f3 = "if(!style){style=document.createElement('style');style.id='custom-fs-style';"
let f4 = "style.textContent='body{overflow:hidden!important;}#movie_player,.html5-video-player{position:fixed!important;top:0!important;left:0!important;width:100vw!important;height:100vh!important;z-index:999999!important;background:#000!important;}#movie_player video,.html5-main-video{width:100vw!important;height:100vh!important;left:0!important;top:0!important;object-fit:contain!important;}ytd-masthead,#secondary,#below,#guide{display:none!important;}';"
let f5 = "document.head.appendChild(style);}"
let f6 = "}else{if(style){style.remove();}}window.dispatchEvent(new Event('resize'));})();"
webView.evaluateJavaScript(f1 + f2 + f3 + f4 + f5 + f6, completionHandler: nil)
}
}
class ViewController: UIViewController {
private let urlField = UITextField()
private let reloadBtn = UIButton(type: .system)
private let trackpadView = UIView()
private let videoSlider = UISlider()
private let timeLabel = UILabel()
private var isScrubbing = false
private var progressTimer: Timer?
override func viewDidLoad() {
super.viewDidLoad()
view.backgroundColor = .systemBackground
let w = view.bounds.width
view.addSubview(makeNavButton(title: "⌂", frame: CGRect(x: 10, y: 54, width: 34, height: 38), action: #selector(goHome)))
view.addSubview(makeNavButton(title: "←", frame: CGRect(x: 48, y: 54, width: 34, height: 38), action: #selector(goBack)))
view.addSubview(makeNavButton(title: "→", frame: CGRect(x: 86, y: 54, width: 34, height: 38), action: #selector(goForward)))
reloadBtn.setTitle("↻", for: .normal)
reloadBtn.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
reloadBtn.backgroundColor = .secondarySystemBackground
reloadBtn.layer.cornerRadius = 8
reloadBtn.frame = CGRect(x: 124, y: 54, width: 34, height: 38)
reloadBtn.addTarget(self, action: #selector(reloadPage), for: .touchUpInside)
view.addSubview(reloadBtn)
urlField.placeholder = "Type URL, search, or box text..."
urlField.borderStyle = .roundedRect
urlField.returnKeyType = .go
urlField.clearButtonMode = .whileEditing
urlField.autocapitalizationType = .none
urlField.autocorrectionType = .no
urlField.addTarget(self, action: #selector(liveTextChanged), for: .editingChanged)
urlField.addTarget(self, action: #selector(handleTextSubmit), for: .editingDidEndOnExit)
urlField.frame = CGRect(x: 162, y: 54, width: w - 172, height: 38)
view.addSubview(urlField)
let row2: [(String, Selector)] = [
("YouTube", #selector(openYouTube)),
("Chrome", #selector(openChrome)),
("Type Box", #selector(sendTextToPageBox)),
("Dock", #selector(toggleDock))
]
let btnW4 = (w - 38) / 4
for (i, item) in row2.enumerated() {
let btn = makeSmallButton(
title: item.0,
frame: CGRect(x: 10 + CGFloat(i) * (btnW4 + 6), y: 100, width: btnW4, height: 34),
action: item.1
)
view.addSubview(btn)
}
let row3: [(String, Selector)] = [
("-15s", #selector(rewind15)),
("Play/Pause", #selector(togglePlayPause)),
("+15s", #selector(forward15)),
("Full / Exit", #selector(toggleFullscreen))
]
for (i, item) in row3.enumerated() {
let btn = makeSmallButton(
title: item.0,
frame: CGRect(x: 10 + CGFloat(i) * (btnW4 + 6), y: 140, width: btnW4, height: 34),
action: item.1
)
view.addSubview(btn)
}
timeLabel.text = "0:00 / 0:00"
timeLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
timeLabel.textColor = .secondaryLabel
timeLabel.textAlignment = .right
timeLabel.frame = CGRect(x: w - 94, y: 182, width: 84, height: 28)
view.addSubview(timeLabel)
videoSlider.minimumValue = 0
videoSlider.maximumValue = 1
videoSlider.value = 0
videoSlider.frame = CGRect(x: 12, y: 180, width: w - 112, height: 32)
videoSlider.addTarget(self, action: #selector(sliderTouchDown), for: .touchDown)
videoSlider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
videoSlider.addTarget(self, action: #selector(sliderTouchUp), for: [.touchUpInside, .touchUpOutside])
view.addSubview(videoSlider)
let hintLabel = UILabel(frame: CGRect(x: 12, y: 214, width: w - 24, height: 18))
hintLabel.text = "1-finger: Cursor • Tap: Click • Double-tap L/R: ±15s • 2-finger: Scroll/Zoom"
hintLabel.font = .systemFont(ofSize: 10.5)
hintLabel.textColor = .secondaryLabel
hintLabel.textAlignment = .center
view.addSubview(hintLabel)
trackpadView.backgroundColor = .secondarySystemBackground
trackpadView.layer.cornerRadius = 16
trackpadView.frame = CGRect(x: 10, y: 236, width: w - 20, height: view.bounds.height - 264)
view.addSubview(trackpadView)
let movePan = UIPanGestureRecognizer(target: self, action: #selector(handleMovePan(_:)))
movePan.maximumNumberOfTouches = 1
let scrollPan = UIPanGestureRecognizer(target: self, action: #selector(handleScrollPan(_:)))
scrollPan.minimumNumberOfTouches = 2
scrollPan.maximumNumberOfTouches = 2
let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
doubleTap.numberOfTapsRequired = 2
let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap))
singleTap.numberOfTapsRequired = 1
singleTap.require(toFail: doubleTap)
singleTap.require(toFail: movePan)
trackpadView.addGestureRecognizer(movePan)
trackpadView.addGestureRecognizer(scrollPan)
trackpadView.addGestureRecognizer(pinch)
trackpadView.addGestureRecognizer(doubleTap)
trackpadView.addGestureRecognizer(singleTap)
startVideoProgressTimer()
}
private func bindExternalCallbacks() {
guard let ext = externalVC, ext.onInputSelected == nil else { return }
ext.onInputSelected = { [weak self] existingText in
DispatchQueue.main.async {
self?.urlField.text = existingText
self?.urlField.becomeFirstResponder()
}
}
}
private func makeNavButton(title: String, frame: CGRect, action: Selector) -> UIButton {
let btn = UIButton(type: .system)
btn.setTitle(title, for: .normal)
btn.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
btn.backgroundColor = .secondarySystemBackground
btn.layer.cornerRadius = 8
btn.frame = frame
btn.addTarget(self, action: action, for: .touchUpInside)
return btn
}
private func makeSmallButton(title: String, frame: CGRect, action: Selector) -> UIButton {
let btn = UIButton(type: .system)
btn.setTitle(title, for: .normal)
btn.titleLabel?.font = .systemFont(ofSize: 12.5, weight: .semibold)
btn.backgroundColor = .secondarySystemBackground
btn.layer.cornerRadius = 8
btn.frame = frame
btn.addTarget(self, action: action, for: .touchUpInside)
return btn
}
private var externalVC: ExternalBrowserViewController? {
UIApplication.shared.connectedScenes
.compactMap { $0 as? UIWindowScene }
.first(where: { $0.session.role == .windowExternalDisplayNonInteractive })?
.windows.first?.rootViewController as? ExternalBrowserViewController
}
@objc private func goHome() { externalVC?.showDesktop() }
@objc private func goBack() { externalVC?.webView?.goBack() }
@objc private func goForward() { externalVC?.webView?.goForward() }
@objc private func reloadPage() { externalVC?.webView?.reload() }
@objc private func openYouTube() { urlField.text = ""; externalVC?.launchYouTube() }
@objc private func openChrome() { urlField.text = ""; externalVC?.launchChrome() }
@objc private func toggleDock() { externalVC?.toggleDock() }
@objc private func rewind15() { externalVC?.skipVideo(seconds: -15) }
@objc private func forward15() { externalVC?.skipVideo(seconds: 15) }
@objc private func toggleFullscreen() { externalVC?.toggleFullscreen() }
@objc private func togglePlayPause() {
let p1 = "(function(){var vids=Array.from(document.querySelectorAll('video'));"
let p2 = "var v=vids.find(function(x){return x.duration>0;})||vids;"
let p3 = "if(v){v.paused?v.play():v.pause();}})();"
externalVC?.webView?.evaluateJavaScript(p1 + p2 + p3, completionHandler: nil)
}
@objc private func liveTextChanged() {
let text = urlField.text ?? ""
externalVC?.hasFocusedInput { [weak self] focused in
if focused {
self?.externalVC?.typeTextIntoFocusedInput(text, submit: false)
}
}
}
@objc private func sendTextToPageBox() {
let text = urlField.text ?? ""
externalVC?.typeTextIntoFocusedInput(text, submit: true)
urlField.resignFirstResponder()
}
@objc private func handleTextSubmit() {
guard let text = urlField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return }
externalVC?.hasFocusedInput { [weak self] isFocused in
guard let self = self else { return }
if isFocused {
self.externalVC?.typeTextIntoFocusedInput(text, submit: true)
} else {
let target: String
if text.hasPrefix("http://") || text.hasPrefix("https://") {
target = text
} else if text.contains(".") && !text.contains(" ") {
target = "https://" + text
} else {
let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
target = "google.com" + encoded
}
if self.externalVC?.isChromeMode == true {
self.externalVC?.launchChrome(urlString: target)
} else {
self.externalVC?.openSingleApp(target)
}
}
self.urlField.resignFirstResponder()
}
}
@objc private func sliderTouchDown() { isScrubbing = true }
@objc private func sliderChanged() {
externalVC?.seekVideo(fraction: Double(videoSlider.value))
}
@objc private func sliderTouchUp() {
externalVC?.seekVideo(fraction: Double(videoSlider.value))
isScrubbing = false
}
private func startVideoProgressTimer() {
progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
guard let self = self else { return }
self.bindExternalCallbacks()
guard !self.isScrubbing, let webView = self.externalVC?.webView, !webView.isHidden else { return }
let t1 = "(function(){var vids=Array.from(document.querySelectorAll('video'));"
let t2 = "var v=vids.find(function(x){return !x.paused&&x.duration>0;})||document.querySelector('#movie_player video')||vids;"
let t3 = "if(!v||!isFinite(v.duration)||v.duration<=0)return null;return [v.currentTime,v.duration];})();"
webView.evaluateJavaScript(t1 + t2 + t3) { result, _ in
guard let arr = result as? [Double], let cur = arr.first, let dur = arr.last, dur > 0 else { return }
self.videoSlider.value = Float(cur / dur)
self.timeLabel.text = self.formatTime(cur) + " / " + self.formatTime(dur)
}
}
}
private func formatTime(_ seconds: Double) -> String {
let total = Int(seconds)
let m = total / 60
let s = total % 60
return String(format: "%d:%02d", m, s)
}
@objc private func handleMovePan(_ gesture: UIPanGestureRecognizer) {
guard let ext = externalVC else { return }
let delta = gesture.translation(in: trackpadView)
gesture.setTranslation(.zero, in: trackpadView)
ext.moveCursor(dx: delta.x * 2.2, dy: delta.y * 2.2)
}
@objc private func handleScrollPan(_ gesture: UIPanGestureRecognizer) {
guard let webView = externalVC?.webView else { return }
let delta = gesture.translation(in: trackpadView)
gesture.setTranslation(.zero, in: trackpadView)
let newY = max(0, webView.scrollView.contentOffset.y - delta.y * 2.0)
webView.scrollView.setContentOffset(CGPoint(x: 0, y: newY), animated: false)
}
@objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
guard let scrollView = externalVC?.webView?.scrollView else { return }
if gesture.state == .changed {
let newScale = min(max(scrollView.minimumZoomScale, scrollView.zoomScale * gesture.scale), scrollView.maximumZoomScale)
scrollView.setZoomScale(newScale, animated: false)
gesture.scale = 1.0
}
}
@objc private func handleSingleTap() {
bindExternalCallbacks()
externalVC?.clickAtCursor()
}
@objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
let tapX = gesture.location(in: trackpadView).x
if tapX < trackpadView.bounds.width / 2 {
externalVC?.skipVideo(seconds: -15)
} else {
externalVC?.skipVideo(seconds: 15)
}
}
}

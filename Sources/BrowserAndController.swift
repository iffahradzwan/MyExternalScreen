import UIKit
import WebKit

class ExternalBrowserViewController: UIViewController, WKNavigationDelegate {
    var webView: WKWebView!
    let cursorView = UIView()
    private let desktopView = UIView()
    private let dockView = UIVisualEffectView(
        effect: UIBlurEffect(style: .systemThinMaterialDark)
    )
    private let lastURLKey = "SavedLastVisitedURL"
    private var isVideoZoomedFull = false
    var onInputSelected: ((String) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        setupDesktopWallpaper()
        setupWebView()
        setupFloatingDock()
        setupCursor()

        let saved = UserDefaults.standard.string(forKey: lastURLKey) ?? ""
        if !saved.isEmpty {
            openURL(saved)
        } else {
            showDesktop()
        }
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
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = false
        config.mediaTypesRequiringUserActionForPlayback = [.all]
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        let s1 = "HTMLVideoElement.prototype.webkitEnterFullscreen = function(){};"
        let s2 = "HTMLVideoElement.prototype.webkitEnterFullScreen = function(){};"
        let s3 = "setInterval(function(){"
        let s4 = "document.querySelectorAll('video').forEach(function(v){v.setAttribute('playsinline','');v.setAttribute('webkit-playsinline','');});"
        let s5 = "var s=document.querySelector('.ytp-skip-ad-button,.ytp-ad-skip-button,.ytp-ad-skip-button-modern');"
        let s6 = "if(s){s.click();}"
        let s7 = "var o=document.querySelector('.ytp-ad-player-overlay,.ad-showing');"
        let s8 = "var v=document.querySelector('#movie_player video,.html5-main-video');"
        let s9 = "if(o&&v&&isFinite(v.duration)&&v.duration>0){v.currentTime=v.duration;}"
        let s10 = "},400);"
        let scriptSource = s1 + s2 + s3 + s4 + s5 + s6 + s7 + s8 + s9 + s10

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

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let current = webView.url?.absoluteString, !current.isEmpty {
            UserDefaults.standard.set(current, forKey: lastURLKey)
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
            ("Chrome", "globe", .systemBlue, #selector(launchChrome)),
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

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let gradient = desktopView.layer.sublayers?.first as? CAGradientLayer {
            gradient.frame = desktopView.bounds
        }
        if cursorView.center == .zero {
            cursorView.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        }
        view.bringSubviewToFront(dockView)
        view.bringSubviewToFront(cursorView)
    }

    @objc func showDesktop() {
        desktopView.isHidden = false
        webView.isHidden = true
        dockView.isHidden = false
        isVideoZoomedFull = false
        UserDefaults.standard.removeObject(forKey: lastURLKey)
    }

    @objc func launchYouTube() { openURL("https://youtube.com") }
    @objc func launchChrome() { openURL("https://google.com") }
    @objc func launchNetflix() { openURL("https://netflix.com") }

    func openURL(_ urlString: String) {
        desktopView.isHidden = true
        webView.isHidden = false
        dockView.isHidden = true
        isVideoZoomedFull = false
        UserDefaults.standard.set(urlString, forKey: lastURLKey)
        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }
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

        if !dockView.isHidden {
let pointInDock = view.convert(point, to: dockView.contentView)
for subview in dockView.contentView.subviews {
if let btn = subview as? UIButton, btn.frame.contains(pointInDock) {
btn.sendActions(for: .touchUpInside)
return
}
}
}
guard !webView.isHidden else { return }
let scale = max(0.1, webView.scrollView.zoomScale)
let px = String(Double(point.x / scale))
let py = String(Double(point.y / scale))
// Strictly exclude input[type=file] so iOS never opens Photo Library / Choose File!
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
private let videoSlider = UISlider()
private let timeLabel = UILabel()
private let trackpadView = UIView()
private var isScrubbing = false
private var progressTimer: Timer?
override func viewDidLoad() {
super.viewDidLoad()
view.backgroundColor = .systemBackground
let w = view.bounds.width
view.addSubview(makeNavButton(title: "⌂", frame: CGRect(x: 12, y: 54, width: 38, height: 38), action: #selector(goHome)))
view.addSubview(makeNavButton(title: "←", frame: CGRect(x: 54, y: 54, width: 38, height: 38), action: #selector(goBack)))
view.addSubview(makeNavButton(title: "→", frame: CGRect(x: 96, y: 54, width: 38, height: 38), action: #selector(goForward)))
urlField.placeholder = "Type URL, search, or text for page box..."
urlField.borderStyle = .roundedRect
urlField.returnKeyType = .go
urlField.clearButtonMode = .whileEditing
urlField.autocapitalizationType = .none
urlField.autocorrectionType = .no
urlField.addTarget(self, action: #selector(liveTextChanged), for: .editingChanged)
urlField.addTarget(self, action: #selector(handleTextSubmit), for: .editingDidEndOnExit)
urlField.frame = CGRect(x: 140, y: 54, width: w - 152, height: 38)
view.addSubview(urlField)
let row2: [(String, Selector)] = [
("YouTube", #selector(openYouTube)),
("Chrome", #selector(openChrome)),
("Type Box", #selector(sendTextToPageBox)),
("Dock", #selector(toggleDock))
]
let btnW4 = (w - 42) / 4
for (i, item) in row2.enumerated() {
let btn = makeSmallButton(
title: item.0,
frame: CGRect(x: 12 + CGFloat(i) * (btnW4 + 6), y: 100, width: btnW4, height: 34),
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
frame: CGRect(x: 12 + CGFloat(i) * (btnW4 + 6), y: 140, width: btnW4, height: 34),
action: item.1
)
view.addSubview(btn)
}
timeLabel.text = "0:00 / 0:00"
timeLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
timeLabel.textColor = .secondaryLabel
timeLabel.textAlignment = .right
timeLabel.frame = CGRect(x: w - 96, y: 182, width: 84, height: 28)
view.addSubview(timeLabel)
videoSlider.minimumValue = 0
videoSlider.maximumValue = 1
videoSlider.value = 0
videoSlider.frame = CGRect(x: 14, y: 180, width: w - 116, height: 32)
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
trackpadView.frame = CGRect(x: 12, y: 236, width: w - 24, height: view.bounds.height - 264)
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
btn.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
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
@objc private func goBack() { externalVC?.webView.goBack() }
@objc private func goForward() { externalVC?.webView.goForward() }
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
externalVC?.webView.evaluateJavaScript(p1 + p2 + p3, completionHandler: nil)
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
self.externalVC?.openURL(target)
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
guard let scrollView = externalVC?.webView.scrollView else { return }
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

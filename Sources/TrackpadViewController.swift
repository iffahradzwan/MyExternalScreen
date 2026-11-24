import UIKit
import WebKit

class ViewController: UIViewController {
    private let urlField = UITextField()
    private let reloadBtn = UIButton(type: .system)
    private let trackpadView = UIView()
    private let videoSlider = UISlider()
    private let timeLabel = UILabel()
    private var isScrubbing = false
    private var progressTimer: Timer?
    private var navButtons: [UIButton] = []
private var row2Buttons: [UIButton] = []
private var row3Buttons: [UIButton] = []
private let hintLabel = UILabel()
private let padWatermark = UILabel()

deinit {
    progressTimer?.invalidate()
}

    
   override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground

    let navSpecs: [(String, Selector)] = [
        ("⌂", #selector(goHome)),
        ("←", #selector(goBack)),
        ("→", #selector(goForward))
    ]
    for item in navSpecs {
        let btn = makeNavButton(title: item.0, frame: .zero, action: item.1)
        navButtons.append(btn)
        view.addSubview(btn)
    }

    reloadBtn.setTitle("↻", for: .normal)
    reloadBtn.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
    reloadBtn.backgroundColor = .secondarySystemBackground
    reloadBtn.layer.cornerRadius = 10
    reloadBtn.addTarget(self, action: #selector(reloadPage), for: .touchUpInside)
    view.addSubview(reloadBtn)

    urlField.placeholder = "Search Google, enter URL, or type..."
    urlField.borderStyle = .roundedRect
    urlField.returnKeyType = .go
    urlField.clearButtonMode = .whileEditing
    urlField.autocapitalizationType = .none
    urlField.autocorrectionType = .no
    urlField.addTarget(self, action: #selector(liveTextChanged), for: .editingChanged)
    urlField.addTarget(self, action: #selector(handleTextSubmit), for: .editingDidEndOnExit)
    view.addSubview(urlField)

    let row2: [(String, Selector)] = [
        ("YouTube", #selector(openYouTube)),
        ("Chrome", #selector(openChrome)),
        ("Netflix", #selector(openNetflix)),
        ("Dock", #selector(toggleDock))
    ]
    for item in row2 {
        let btn = makeSmallButton(title: item.0, frame: .zero, action: item.1)
        row2Buttons.append(btn)
        view.addSubview(btn)
    }

    let row3: [(String, Selector)] = [
        ("-15s", #selector(rewind15)),
        ("Play / Pause", #selector(togglePlayPause)),
        ("+15s", #selector(forward15)),
        ("Full / Exit", #selector(toggleFullscreen))
    ]
    for item in row3 {
        let btn = makeSmallButton(title: item.0, frame: .zero, action: item.1)
        row3Buttons.append(btn)
        view.addSubview(btn)
    }

        
       timeLabel.text = "0:00 / 0:00"
timeLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
timeLabel.textColor = .secondaryLabel
timeLabel.textAlignment = .right
view.addSubview(timeLabel)

videoSlider.minimumValue = 0
videoSlider.maximumValue = 1
videoSlider.value = 0
videoSlider.addTarget(self, action: #selector(sliderTouchDown), for: .touchDown)
videoSlider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
videoSlider.addTarget(self, action: #selector(sliderTouchUp), for: [.touchUpInside, .touchUpOutside])
view.addSubview(videoSlider)

hintLabel.text = "1-finger: Cursor • Tap: Click • Double-tap L/R: ±15s • 2-finger: Scroll/Zoom"
hintLabel.font = .systemFont(ofSize: 10.5, weight: .medium)
hintLabel.textColor = .secondaryLabel
hintLabel.textAlignment = .center
view.addSubview(hintLabel)

trackpadView.backgroundColor = .secondarySystemBackground
trackpadView.layer.cornerRadius = 20
trackpadView.layer.borderWidth = 1
trackpadView.layer.borderColor = UIColor.separator.withAlphaComponent(0.4).cgColor
view.addSubview(trackpadView)

padWatermark.text = "XeOS TRACKPAD"
padWatermark.font = .systemFont(ofSize: 12, weight: .bold)
padWatermark.textColor = .tertiaryLabel
padWatermark.textAlignment = .center
trackpadView.addSubview(padWatermark)
        
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

       let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(goBack))
swipeRight.direction = .right
swipeRight.numberOfTouchesRequired = 2
scrollPan.require(toFail: swipeRight)

let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(goForward))
swipeLeft.direction = .left
swipeLeft.numberOfTouchesRequired = 2
scrollPan.require(toFail: swipeLeft)

trackpadView.addGestureRecognizer(swipeRight)
trackpadView.addGestureRecognizer(swipeLeft)

        startVideoProgressTimer()
    }
    override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    let w = view.bounds.width
    let top = view.safeAreaInsets.top + 8
    let bottom = view.safeAreaInsets.bottom + 12

    for (i, btn) in navButtons.enumerated() {
        btn.frame = CGRect(x: 12 + CGFloat(i) * 40, y: top, width: 36, height: 38)
    }
    reloadBtn.frame = CGRect(x: 132, y: top, width: 36, height: 38)
    urlField.frame = CGRect(x: 174, y: top, width: w - 186, height: 38)

    let btnW4 = (w - 42) / 4
    let r2Y = top + 46
    for (i, btn) in row2Buttons.enumerated() {
        btn.frame = CGRect(x: 12 + CGFloat(i) * (btnW4 + 6), y: r2Y, width: btnW4, height: 35)
    }

    let r3Y = r2Y + 41
    for (i, btn) in row3Buttons.enumerated() {
        btn.frame = CGRect(x: 12 + CGFloat(i) * (btnW4 + 6), y: r3Y, width: btnW4, height: 35)
    }

    let sliderY = r3Y + 41
    timeLabel.frame = CGRect(x: w - 96, y: sliderY + 2, width: 84, height: 28)
    videoSlider.frame = CGRect(x: 14, y: sliderY, width: w - 116, height: 32)

    let hintY = sliderY + 34
    hintLabel.frame = CGRect(x: 12, y: hintY, width: w - 24, height: 18)

    let padY = hintY + 24
    trackpadView.frame = CGRect(x: 12, y: padY, width: w - 24, height: max(120, view.bounds.height - padY - bottom))
    padWatermark.frame = CGRect(x: 0, y: trackpadView.bounds.height - 32, width: trackpadView.bounds.width, height: 20)
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
        btn.layer.cornerRadius = 10
        btn.frame = frame
        btn.addTarget(self, action: action, for: .touchUpInside)
        return btn
    }
    
    private func makeSmallButton(title: String, frame: CGRect, action: Selector) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 12.5, weight: .semibold)
        btn.backgroundColor = .secondarySystemBackground
        btn.layer.cornerRadius = 10
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
    @objc private func goBack() { externalVC?.activeWebView?.goBack() }
    @objc private func goForward() { externalVC?.activeWebView?.goForward() }
    @objc private func reloadPage() { externalVC?.activeWebView?.reload() }
    @objc private func openYouTube() {
    urlField.text = ""
    externalVC?.launchYouTube()
    if let url = URL(string: "https://youtube.com") {
        externalVC?.youtubeWebView.load(URLRequest(url: url))
    }
}

    @objc private func openChrome() { urlField.text = ""; externalVC?.launchChromeDefault() }
    @objc private func openNetflix() { urlField.text = ""; externalVC?.launchNetflix() }
    @objc private func toggleDock() { externalVC?.toggleDock() }
    @objc private func rewind15() { WebEngine.skipVideo(seconds: -15, in: externalVC?.activeWebView) }
    @objc private func forward15() { WebEngine.skipVideo(seconds: 15, in: externalVC?.activeWebView) }
    @objc private func toggleFullscreen() { externalVC?.toggleFullscreen() }
    @objc private func togglePlayPause() { WebEngine.togglePlayPause(in: externalVC?.activeWebView) }
    
    @objc private func liveTextChanged() {
        let text = urlField.text ?? ""
        let webView = externalVC?.activeWebView
        WebEngine.hasFocusedInput(in: webView) { focused in
            if focused {
                WebEngine.typeText(text, submit: false, into: webView)
            }
        }
    }
    
    @objc private func handleTextSubmit() {
        guard let text = urlField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return }
        let webView = externalVC?.activeWebView
        WebEngine.hasFocusedInput(in: webView) { [weak self] isFocused in
            guard let self = self else { return }
if isFocused {
WebEngine.typeText(text, submit: true, into: webView)
} else {
let target: String
if text.hasPrefix("http://") || text.hasPrefix("https://") {
target = text
} else if text.contains(".") && !text.contains(" ") {
target = "https://" + text
} else {
   var comps = URLComponents(string: "https://google.com")!
comps.queryItems = [URLQueryItem(name: "q", value: text)]
target = comps.url?.absoluteString ?? "https://google.com"

}

if self.externalVC?.currentMode == .youtube {
    if text.hasPrefix("http://") || text.hasPrefix("https://"), let url = URL(string: target) {
        self.externalVC?.youtubeWebView.load(URLRequest(url: url))
    } else {
        var ytComps = URLComponents(string: "https://youtube.com" + "/results")!
        ytComps.queryItems = [URLQueryItem(name: "search_query", value: text)]
        if let ytURL = ytComps.url {
            self.externalVC?.youtubeWebView.load(URLRequest(url: ytURL))
        }
    }
}
 else if self.externalVC?.currentMode == .netflix, let url = URL(string: target) {
self.externalVC?.netflixWebView.load(URLRequest(url: url))
} else {
self.externalVC?.openInChrome(urlString: target)
}
}
self.urlField.resignFirstResponder()
}
}
@objc private func sliderTouchDown() { isScrubbing = true }
@objc private func sliderChanged() { WebEngine.seekVideo(fraction: Double(videoSlider.value), in: externalVC?.activeWebView) }
@objc private func sliderTouchUp() {
WebEngine.seekVideo(fraction: Double(videoSlider.value), in: externalVC?.activeWebView)
isScrubbing = false
}
private func startVideoProgressTimer() {
progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
guard let self = self else { return }
self.bindExternalCallbacks()
guard !self.isScrubbing, let webView = self.externalVC?.activeWebView,
self.externalVC?.currentMode != .desktop else { return }
WebEngine.getVideoProgress(in: webView) { cur, dur in
self.videoSlider.value = Float(cur / dur)
self.timeLabel.text = self.formatTime(cur) + " / " + self.formatTime(dur)
}
}
}
private func formatTime(_ seconds: Double) -> String {
let total = Int(seconds)
return String(format: "%d:%02d", total / 60, total % 60)
}
@objc private func handleMovePan(_ gesture: UIPanGestureRecognizer) {
guard let ext = externalVC else { return }
let delta = gesture.translation(in: trackpadView)
gesture.setTranslation(.zero, in: trackpadView)
ext.moveCursor(dx: delta.x * 2.2, dy: delta.y * 2.2)
}
@objc private func handleScrollPan(_ gesture: UIPanGestureRecognizer) {
    guard let ext = externalVC, let webView = ext.activeWebView else { return }
    let delta = gesture.translation(in: trackpadView)
    gesture.setTranslation(.zero, in: trackpadView)
    let dx = -Double(delta.x) * 2.2
    let dy = -Double(delta.y) * 2.2
    let tip = CGPoint(x: ext.cursorView.frame.minX + 4, y: ext.cursorView.frame.minY + 3)
    let pt = ext.view.convert(tip, to: webView)

    let s1 = "(function(){var el=document.elementFromPoint(\(pt.x),\(pt.y));"
    let s2 = "while(el&&el!==document.body&&el!==document.documentElement){"
    let s3 = "var st=getComputedStyle(el);"
    let s4 = "if((st.overflowY==='auto'||st.overflowY==='scroll')&&el.scrollHeight>el.clientHeight+2){el.scrollTop+=\(dy);return true;}"
    let s5 = "el=el.parentElement;}return false;})()"

    webView.evaluateJavaScript(s1 + s2 + s3 + s4 + s5) { res, _ in
        if (res as? Bool) != true {
            let sv = webView.scrollView
            let maxX = max(0, sv.contentSize.width - sv.bounds.width)
            let maxY = max(0, sv.contentSize.height - sv.bounds.height)
            let nx = min(max(0, sv.contentOffset.x + CGFloat(dx)), maxX)
            let ny = min(max(0, sv.contentOffset.y + CGFloat(dy)), maxY)
            sv.setContentOffset(CGPoint(x: nx, y: ny), animated: false)
        }
    }
}


@objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
guard let scrollView = externalVC?.activeWebView?.scrollView else { return }
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
let sec: Double = (tapX < trackpadView.bounds.width / 2) ? -15 : 15
WebEngine.skipVideo(seconds: sec, in: externalVC?.activeWebView)
}
}

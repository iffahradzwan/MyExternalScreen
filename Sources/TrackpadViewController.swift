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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let w = view.bounds.width
        
        view.addSubview(makeNavButton(title: "⌂", frame: CGRect(x: 12, y: 56, width: 36, height: 38), action: #selector(goHome)))
        view.addSubview(makeNavButton(title: "←", frame: CGRect(x: 52, y: 56, width: 36, height: 38), action: #selector(goBack)))
        view.addSubview(makeNavButton(title: "→", frame: CGRect(x: 92, y: 56, width: 36, height: 38), action: #selector(goForward)))
        
        reloadBtn.setTitle("↻", for: .normal)
        reloadBtn.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        reloadBtn.backgroundColor = .secondarySystemBackground
        reloadBtn.layer.cornerRadius = 10
        reloadBtn.frame = CGRect(x: 132, y: 56, width: 36, height: 38)
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
        urlField.frame = CGRect(x: 174, y: 56, width: w - 186, height: 38)
        view.addSubview(urlField)
        
        let row2: [(String, Selector)] = [
            ("YouTube", #selector(openYouTube)),
            ("Chrome", #selector(openChrome)),
            ("Netflix", #selector(openNetflix)),
            ("Dock", #selector(toggleDock))
        ]
        let btnW4 = (w - 42) / 4
        for (i, item) in row2.enumerated() {
            let btn = makeSmallButton(
                title: item.0,
                frame: CGRect(x: 12 + CGFloat(i) * (btnW4 + 6), y: 102, width: btnW4, height: 35),
                action: item.1
            )
            view.addSubview(btn)
        }
        
        let row3: [(String, Selector)] = [
            ("-15s", #selector(rewind15)),
            ("Play / Pause", #selector(togglePlayPause)),
            ("+15s", #selector(forward15)),
            ("Full / Exit", #selector(toggleFullscreen))
        ]
        for (i, item) in row3.enumerated() {
            let btn = makeSmallButton(
                title: item.0,
                frame: CGRect(x: 12 + CGFloat(i) * (btnW4 + 6), y: 143, width: btnW4, height: 35),
                action: item.1
            )
            view.addSubview(btn)
        }
        
        timeLabel.text = "0:00 / 0:00"
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        timeLabel.textColor = .secondaryLabel
        timeLabel.textAlignment = .right
        timeLabel.frame = CGRect(x: w - 96, y: 186, width: 84, height: 28)
        view.addSubview(timeLabel)
        
        videoSlider.minimumValue = 0
        videoSlider.maximumValue = 1
        videoSlider.value = 0
        videoSlider.frame = CGRect(x: 14, y: 184, width: w - 116, height: 32)
        videoSlider.addTarget(self, action: #selector(sliderTouchDown), for: .touchDown)
        videoSlider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
        videoSlider.addTarget(self, action: #selector(sliderTouchUp), for: [.touchUpInside, .touchUpOutside])
        view.addSubview(videoSlider)
        
        let hintLabel = UILabel(frame: CGRect(x: 12, y: 218, width: w - 24, height: 18))
        hintLabel.text = "1-finger: Cursor • Tap: Click • Double-tap L/R: ±15s • 2-finger: Scroll/Zoom"
        hintLabel.font = .systemFont(ofSize: 10.5, weight: .medium)
        hintLabel.textColor = .secondaryLabel
        hintLabel.textAlignment = .center
        view.addSubview(hintLabel)
        
        trackpadView.backgroundColor = .secondarySystemBackground
        trackpadView.layer.cornerRadius = 20
        trackpadView.layer.borderWidth = 1
        trackpadView.layer.borderColor = UIColor.separator.withAlphaComponent(0.4).cgColor
        trackpadView.frame = CGRect(x: 12, y: 242, width: w - 24, height: view.bounds.height - 270)
        view.addSubview(trackpadView)
        
        let padWatermark = UILabel()
        padWatermark.text = "XeOS TRACKPAD"
        padWatermark.font = .systemFont(ofSize: 12, weight: .bold)
        padWatermark.textColor = .tertiaryLabel
        padWatermark.textAlignment = .center
        padWatermark.frame = CGRect(x: 0, y: trackpadView.bounds.height - 32, width: trackpadView.bounds.width, height: 20)
        padWatermark.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
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
    @objc private func openYouTube() { urlField.text = ""; externalVC?.launchYouTube() }
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
let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
target = "google.com" + encoded
}
if self.externalVC?.currentMode == .youtube, let url = URL(string: target) {
self.externalVC?.youtubeWebView.load(URLRequest(url: url))
} else if self.externalVC?.currentMode == .netflix, let url = URL(string: target) {
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
guard let webView = externalVC?.activeWebView else { return }
let delta = gesture.translation(in: trackpadView)
gesture.setTranslation(.zero, in: trackpadView)
let maxScrollY = max(0, webView.scrollView.contentSize.height - webView.bounds.height)
let newY = min(maxScrollY, max(0, webView.scrollView.contentOffset.y - delta.y * 2.0))
webView.scrollView.setContentOffset(CGPoint(x: 0, y: newY), animated: false)
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

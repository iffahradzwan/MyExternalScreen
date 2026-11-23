import UIKit
import WebKit

class ExternalBrowserViewController: UIViewController, WKNavigationDelegate {
    var webView: WKWebView!
    let cursorView = UIView()
    private let desktopView = UIView()
    private let dockView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
    private let lastURLKey = "SavedLastVisitedURL"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        setupDesktopWallpaper()
        setupWebView()
        setupFloatingDock()
        setupCursor()

        if let savedURL = UserDefaults.standard.string(forKey: lastURLKey), !savedURL.isEmpty {
            openURL(savedURL)
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
        titleLabel.frame = CGRect(x: 0, y: 120, width: view.bounds.width, height: 50)
        titleLabel.autoresizingMask = [.flexibleWidth]
        desktopView.addSubview(titleLabel)

        let subLabel = UILabel()
        subLabel.text = "Click an app below or use your iPhone trackpad"
        subLabel.font = .systemFont(ofSize: 18, weight: .medium)
        subLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        subLabel.textAlignment = .center
        subLabel.frame = CGRect(x: 0, y: 172, width: view.bounds.width, height: 30)
        subLabel.autoresizingMask = [.flexibleWidth]
        desktopView.addSubview(subLabel)

        view.addSubview(desktopView)
    }

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        let scriptSource = """
        // Auto-skip YouTube ads safely without touching homepage hover previews
        setInterval(() => {
            const skipBtn = document.querySelector('.ytp-skip-ad-button, .ytp-ad-skip-button, .ytp-ad-skip-button-modern, .ytp-skip-ad-button__text');
            if (skipBtn) { skipBtn.click(); }
            const adOverlay = document.querySelector('.ytp-ad-player-overlay, .ad-showing');
            const mainVideo = document.querySelector('#movie_player video, .html5-main-video');
            if (adOverlay && mainVideo && isFinite(mainVideo.duration) && mainVideo.duration > 0) {
                mainVideo.currentTime = mainVideo.duration;
            }
        }, 400);
        """
        let userScript = WKUserScript(source: scriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: false)
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
        dockView.frame = CGRect(x: (view.bounds.width - dockWidth) / 2, y: view.bounds.height - dockHeight - 24, width: dockWidth, height: dockHeight)
        dockView.layer.cornerRadius = 24
        dockView.clipsToBounds = true
        dockView.layer.borderWidth = 1
        dockView.layer.borderColor = UIColor.white.withAlphaComponent(0.25).cgColor
        dockView.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin]
        view.addSubview(dockView)

        let apps: [(String, String, UIColor, Selector)] = [
            ("Desktop", "macwindow", UIColor.systemIndigo, #selector(showDesktop)),
            ("YouTube", "play.rectangle.fill", UIColor.systemRed, #selector(launchYouTube)),
            ("Chrome", "globe", UIColor.systemBlue, #selector(launchChrome)),
            ("Netflix", "film.fill", UIColor.systemOrange, #selector(launchNetflix))
        ]

        let itemWidth: CGFloat = 95
        let spacing: CGFloat = 14
        let startX: CGFloat = (dockWidth - (CGFloat(apps.count) * itemWidth + CGFloat(apps.count - 1) * spacing)) / 2

        for (i, app) in apps.enumerated() {
            let btn = UIButton(type: .custom)
            btn.frame = CGRect(x: startX + CGFloat(i) * (itemWidth + spacing), y: 10, width: itemWidth, height: 66)
            btn.addTarget(self, action: app.3, for: .touchUpInside)

            let iconBg = UIView(frame: CGRect(x: (itemWidth - 44) / 2, y: 0, width: 44, height: 44))
            iconBg.backgroundColor = app.2
            iconBg.layer.cornerRadius = 12
            iconBg.isUserInteractionEnabled = false

            let iconImg = UIImageView(image: UIImage(systemName: app.1))
            iconImg.tintColor = .white
            iconImg.contentMode = .scaleAspectFit
            iconImg.frame = CGRect(x: 10, y: 10, width: 24, height: 24)
            iconBg.addSubview(iconImg)
            btn.addSubview(iconBg)

            let label = UILabel(frame: CGRect(x: 0, y: 47, width: itemWidth, height: 18))
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
        UserDefaults.standard.removeObject(forKey: lastURLKey)
    }

    @objc func launchYouTube() { openURL("https://youtube.com") }
    @objc func launchChrome() { openURL("https://google.com") }
    @objc func launchNetflix() { openURL("https://netflix.com") }

    func openURL(_ urlString: String) {
        desktopView.isHidden = true
        webView.isHidden = false
        dockView.isHidden = true
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
        let js = """
        (function() {
            let el = document.elementFromPoint(\(point.x), \(point.y));
            if (!el) return;
            const target = el.closest('a, button, [role="button"], input, textarea, select, label, yt-formatted-string, ytd-thumbnail') || el;
window.__lastFocusedInput = (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA') ? target : target.querySelector('input, textarea');
if (window.__lastFocusedInput) {
window.__lastFocusedInput.focus();
window.__lastFocusedInput.click();
} else {
target.focus();
}
const opts = { view: window, bubbles: true, cancelable: true, clientX: (point.x), clientY: (point.y), pageX: (point.x) + window.scrollX, pageY: (point.y) + window.scrollY };
['pointerdown', 'mousedown', 'pointerup', 'mouseup', 'click'].forEach(type => {
target.dispatchEvent(new MouseEvent(type, opts));
});
if (target.tagName === 'A' && target.href && !target.href.startsWith('javascript:')) {
window.location.href = target.href;
}
})();
"""
webView.evaluateJavaScript(js, completionHandler: nil)
}
func typeTextIntoFocusedInput(_ text: String, submit: Bool) {
let escaped = text
.replacingOccurrences(of: "\", with: "\\")
.replacingOccurrences(of: """, with: "\"")
.replacingOccurrences(of: "\n", with: "\n")
let js = """
(function() {
let input = document.activeElement;
if (!input || (input.tagName !== 'INPUT' && input.tagName !== 'TEXTAREA')) {
input = window.__lastFocusedInput || document.querySelector('input[type="search"], input[name="search_query"], input[name="q"], input[type="email"], input[type="text"], input:not([type="hidden"])');
}
if (!input) return false;
input.focus();
const nativeSetter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value')?.set
|| Object.getOwnPropertyDescriptor(window.HTMLTextAreaElement.prototype, 'value')?.set;
if (nativeSetter) {
nativeSetter.call(input, "(escaped)");
} else {
input.value = "(escaped)";
}
input.dispatchEvent(new Event('input', { bubbles: true }));
input.dispatchEvent(new Event('change', { bubbles: true }));
if ((submit ? "true" : "false")) {
const form = input.closest('form');
if (form) {
form.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }));
form.submit();
} else {
input.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true }));
input.dispatchEvent(new KeyboardEvent('keyup', { key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true }));
}
}
return true;
})();
"""
webView.evaluateJavaScript(js, completionHandler: nil)
}
func skipVideo(seconds: Double) {
let js = """
(function() {
const v = document.querySelector('#movie_player video, .html5-main-video') || document.querySelector('video');
if (v && isFinite(v.duration)) {
v.currentTime = Math.min(Math.max(0, v.currentTime + (seconds)), v.duration);
}
})();
"""
webView.evaluateJavaScript(js, completionHandler: nil)
}
func seekVideo(fraction: Double) {
let js = """
(function() {
const v = document.querySelector('#movie_player video, .html5-main-video') || document.querySelector('video');
if (v && isFinite(v.duration) && v.duration > 0) {
v.currentTime = v.duration * (fraction);
}
})();
"""
webView.evaluateJavaScript(js, completionHandler: nil)
}
func toggleFullscreen() {
let js = """
(function() {
if (document.fullscreenElement) {
document.exitFullscreen();
return;
}
const fsBtn = document.querySelector('.ytp-fullscreen-button');
if (fsBtn) {
fsBtn.click();
return;
}
const player = document.querySelector('#movie_player') || document.querySelector('video');
if (player && player.requestFullscreen) {
player.requestFullscreen();
}
})();
"""
webView.evaluateJavaScript(js, completionHandler: nil)
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
// Row 1: Navigation + URL / Input Bar
view.addSubview(makeNavButton(title: "⌂", frame: CGRect(x: 12, y: 54, width: 38, height: 38), action: #selector(goHome)))
view.addSubview(makeNavButton(title: "←", frame: CGRect(x: 54, y: 54, width: 38, height: 38), action: #selector(goBack)))
view.addSubview(makeNavButton(title: "→", frame: CGRect(x: 96, y: 54, width: 38, height: 38), action: #selector(goForward)))
urlField.placeholder = "Type URL, search, or text for page box..."
urlField.borderStyle = .roundedRect
urlField.returnKeyType = .go
urlField.clearButtonMode = .whileEditing
urlField.autocapitalizationType = .none
urlField.autocorrectionType = .no
urlField.addTarget(self, action: #selector(handleTextSubmit), for: .editingDidEndOnExit)
urlField.frame = CGRect(x: 140, y: 54, width: w - 152, height: 38)
view.addSubview(urlField)
// Row 2: App & Text Injection Shortcuts
let row2: [(String, Selector)] = [
("YouTube", #selector(openYouTube)),
("Chrome", #selector(openChrome)),
("Type Box", #selector(sendTextToPageBox)),
("Dock", #selector(toggleDock))
]
let btnW4 = (w - 42) / 4
for (i, item) in row2.enumerated() {
let btn = makeSmallButton(title: item.0, frame: CGRect(x: 12 + CGFloat(i) * (btnW4 + 6), y: 100, width: btnW4, height: 34), action: item.1)
view.addSubview(btn)
}
// Row 3: Video Playback & Full-Screen Controls
let row3: [(String, Selector)] = [
("-15s", #selector(rewind15)),
("Play/Pause", #selector(togglePlayPause)),
("+15s", #selector(forward15)),
("Full / Exit", #selector(toggleFullscreen))
]
for (i, item) in row3.enumerated() {
let btn = makeSmallButton(title: item.0, frame: CGRect(x: 12 + CGFloat(i) * (btnW4 + 6), y: 140, width: btnW4, height: 34), action: item.1)
view.addSubview(btn)
}
// Row 4: Video Scrubbing Slider + Timestamp
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
// Row 5: Trackpad Hint
let hintLabel = UILabel(frame: CGRect(x: 12, y: 214, width: w - 24, height: 18))
hintLabel.text = "1-finger: Cursor • Tap: Click • Double-tap L/R: ±15s • 2-finger: Scroll/Zoom"
hintLabel.font = .systemFont(ofSize: 10.5)
hintLabel.textColor = .secondaryLabel
hintLabel.textAlignment = .center
view.addSubview(hintLabel)
// Trackpad Surface
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
@objc private func openYouTube() { externalVC?.launchYouTube() }
@objc private func openChrome() { externalVC?.launchChrome() }
@objc private func toggleDock() { externalVC?.toggleDock() }
@objc private func rewind15() { externalVC?.skipVideo(seconds: -15) }
@objc private func forward15() { externalVC?.skipVideo(seconds: 15) }
@objc private func toggleFullscreen() { externalVC?.toggleFullscreen() }
@objc private func togglePlayPause() {
let js = """
const v = document.querySelector('#movie_player video, .html5-main-video') || document.querySelector('video');
if (v) { v.paused ? v.play() : v.pause(); }
"""
externalVC?.webView.evaluateJavaScript(js, completionHandler: nil)
}
@objc private func sendTextToPageBox() {
guard let text = urlField.text, !text.isEmpty else { return }
externalVC?.typeTextIntoFocusedInput(text, submit: true)
urlField.text = ""
urlField.resignFirstResponder()
}
@objc private func handleTextSubmit() {
guard let text = urlField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return }
// If a text box (like Google Search, YouTube Search, or Netflix Email) is focused on the monitor, type directly into it!
let checkFocusJS = "Boolean(document.activeElement && (document.activeElement.tagName === 'INPUT' || document.activeElement.tagName === 'TEXTAREA'))"
externalVC?.webView.evaluateJavaScript(checkFocusJS) { [weak self] result, _ in
guard let self = self else { return }
if let isFocused = result as? Bool, isFocused {
self.externalVC?.typeTextIntoFocusedInput(text, submit: true)
self.urlField.text = ""
} else {
let target: String
if text.hasPrefix("http://") || text.hasPrefix("https://") {
target = text
} else if text.contains(".") && !text.contains(" ") {
target = "https://(text)"
} else {
let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
target = "google.com"
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
guard let self = self, !self.isScrubbing, let webView = self.externalVC?.webView, !webView.isHidden else { return }
let js = """
(function() {
const v = document.querySelector('#movie_player video, .html5-main-video') || document.querySelector('video');
if (!v || !isFinite(v.duration) || v.duration <= 0) return null;
return [v.currentTime, v.duration];
})();
"""
webView.evaluateJavaScript(js) { result, _ in
guard let arr = result as? [Double], arr.count == 2 else { return }
let cur = arr[0]
let dur = arr[1]
self.videoSlider.value = Float(cur / dur)
self.timeLabel.text = "(self.formatTime(cur)) / (self.formatTime(dur))"
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

import UIKit
import WebKit

class ExternalBrowserViewController: UIViewController {
    var webView: WKWebView!
    let cursorView = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let scriptSource = """
        // Auto-skip YouTube ads
        setInterval(() => {
            const skipBtn = document.querySelector('.ytp-skip-ad-button, .ytp-ad-skip-button, .ytp-ad-skip-button-modern, .ytp-skip-ad-button__text');
            if (skipBtn) { skipBtn.click(); }
            const adOverlay = document.querySelector('.ytp-ad-player-overlay, .ad-showing');
            const video = document.querySelector('video');
            if (adOverlay && video && isFinite(video.duration) && video.duration > 0) {
                video.currentTime = video.duration;
            }
        }, 400);
        """
        let userScript = WKUserScript(source: scriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        config.userContentController.addUserScript(userScript)

        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"
        view.addSubview(webView)

        // Native hardware-accelerated cursor (zero JavaScript lag)
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

        if let url = URL(string: "https://www.youtube.com") {
            webView.load(URLRequest(url: url))
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if cursorView.center == .zero {
            cursorView.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        }
    }

    func moveCursor(dx: CGFloat, dy: CGFloat) {
        let newX = min(max(0, cursorView.center.x + dx), view.bounds.width)
        let newY = min(max(0, cursorView.center.y + dy), view.bounds.height)
        cursorView.center = CGPoint(x: newX, y: newY)
    }

    func clickAtCursor() {
        let x = cursorView.center.x
        let y = cursorView.center.y

        UIView.animate(withDuration: 0.08, animations: {
            self.cursorView.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
        }) { _ in
            UIView.animate(withDuration: 0.08) {
                self.cursorView.transform = .identity
            }
        }

        let js = """
        (function() {
            let el = document.elementFromPoint(\(x), \(y));
            if (!el) return;
            const clickable = el.closest('a, button, [role="button"], input, yt-formatted-string, ytd-thumbnail');
            const target = clickable || el;
            target.focus();
            ['pointerdown', 'mousedown', 'pointerup', 'mouseup', 'click'].forEach(type => {
                target.dispatchEvent(new MouseEvent(type, {
                    view: window,
                    bubbles: true,
                    cancelable: true,
                    clientX: \(x),
                    clientY: \(y)
                }));
            });
        })();
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
    }
}

class ViewController: UIViewController {
    private let urlField = UITextField()
    private let trackpadView = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let w = view.bounds.width

        view.addSubview(makeNavButton(title: "←", frame: CGRect(x: 12, y: 56, width: 38, height: 40), action: #selector(goBack)))
        view.addSubview(makeNavButton(title: "→", frame: CGRect(x: 54, y: 56, width: 38, height: 40), action: #selector(goForward)))
        view.addSubview(makeNavButton(title: "↻", frame: CGRect(x: 96, y: 56, width: 38, height: 40), action: #selector(reloadPage)))

        urlField.placeholder = "Search Google or type URL..."
        urlField.borderStyle = .roundedRect
        urlField.returnKeyType = .go
        urlField.clearButtonMode = .whileEditing
        urlField.autocapitalizationType = .none
        urlField.autocorrectionType = .no
        urlField.addTarget(self, action: #selector(loadURL), for: .editingDidEndOnExit)
        urlField.frame = CGRect(x: 140, y: 56, width: w - 152, height: 40)
        view.addSubview(urlField)

        let sites: [(String, Selector)] = [
            ("YouTube", #selector(openYouTube)),
            ("Google", #selector(openGoogle)),
            ("Full Screen", #selector(toggleVideoFullscreen)),
            ("Play/Pause", #selector(togglePlayPause))
        ]
        let btnWidth = (w - 42) / 4
        for (i, item) in sites.enumerated() {
            let btn = UIButton(type: .system)
            btn.setTitle(item.0, for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
            btn.backgroundColor = .secondarySystemBackground
            btn.layer.cornerRadius = 8
            btn.frame = CGRect(x: 12 + CGFloat(i) * (btnWidth + 6), y: 104, width: btnWidth, height: 36)
            btn.addTarget(self, action: item.1, for: .touchUpInside)
            view.addSubview(btn)
        }

        let hintLabel = UILabel(frame: CGRect(x: 12, y: 146, width: w - 24, height: 20))
        hintLabel.text = "1 finger: Move cursor  •  Tap: Click  •  2 fingers: Scroll"
        hintLabel.font = .systemFont(ofSize: 12)
        hintLabel.textColor = .secondaryLabel
        hintLabel.textAlignment = .center
        view.addSubview(hintLabel)

        trackpadView.backgroundColor = .secondarySystemBackground
        trackpadView.layer.cornerRadius = 16
        trackpadView.frame = CGRect(x: 12, y: 172, width: w - 24, height: view.bounds.height - 204)
        view.addSubview(trackpadView)

        let movePan = UIPanGestureRecognizer(target: self, action: #selector(handleMovePan(_:)))
        movePan.maximumNumberOfTouches = 1

        let scrollPan = UIPanGestureRecognizer(target: self, action: #selector(handleScrollPan(_:)))
        scrollPan.minimumNumberOfTouches = 2
        scrollPan.maximumNumberOfTouches = 2

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tap.require(toFail: movePan)

        trackpadView.addGestureRecognizer(movePan)
        trackpadView.addGestureRecognizer(scrollPan)
        trackpadView.addGestureRecognizer(tap)
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

    private var externalVC: ExternalBrowserViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.session.role == .windowExternalDisplayNonInteractive })?
            .windows.first?.rootViewController as? ExternalBrowserViewController
    }

    @objc private func goBack() { externalVC?.webView.goBack() }
    @objc private func goForward() { externalVC?.webView.goForward() }
    @objc private func reloadPage() { externalVC?.webView.reload() }
    @objc private func openYouTube() { loadAddress("https://www.youtube.com") }
    @objc private func openGoogle() { loadAddress("https://google.com") }

    @objc private func toggleVideoFullscreen() {
        let js = """
        const fsBtn = document.querySelector('.ytp-fullscreen-button');
        if (fsBtn) { fsBtn.click(); }
        else {
            const v = document.querySelector('video');
            if (v) { document.fullscreenElement ? document.exitFullscreen() : v.requestFullscreen(); }
        }
        """
        externalVC?.webView.evaluateJavaScript(js, completionHandler: nil)
    }

    @objc private func togglePlayPause() {
        let js = """
        const v = document.querySelector('video');
        if (v) { v.paused ? v.play() : v.pause(); }
        """
        externalVC?.webView.evaluateJavaScript(js, completionHandler: nil)
    }

    private func loadAddress(_ urlString: String) {
        if let url = URL(string: urlString) {
            externalVC?.webView.load(URLRequest(url: url))
        }
    }

    @objc private func loadURL() {
        guard let text = urlField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return }
        let target: String
        if text.hasPrefix("http://") || text.hasPrefix("https://") {
            target = text
        } else if text.contains(".") && !text.contains(" ") {
            target = "https://\(text)"
        } else {
            let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            target = "https://google.com/search?q=\(encoded)"
        }
        loadAddress(target)
        urlField.resignFirstResponder()
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
@objc private func handleTap() {
externalVC?.clickAtCursor()
}
}

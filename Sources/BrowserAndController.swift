import UIKit
import WebKit

class ExternalBrowserViewController: UIViewController {
    var webView: WKWebView!

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

        // Visible cursor dot on external monitor
        window.addEventListener('DOMContentLoaded', () => {
            const dot = document.createElement('div');
            dot.id = 'custom-cursor-dot';
            dot.style.cssText = 'position:fixed;width:18px;height:18px;border-radius:50%;background:rgba(255,59,48,0.85);border:2px solid white;pointer-events:none;z-index:999999;left:50%;top:50%;transform:translate(-50%,-50%);';
            document.body.appendChild(dot);
        });
        """
        let userScript = WKUserScript(source: scriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        config.userContentController.addUserScript(userScript)

        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"
        view.addSubview(webView)

        if let url = URL(string: "https://youtube.com") {
            webView.load(URLRequest(url: url))
        }
    }
}

class ViewController: UIViewController {
    private let urlField = UITextField()
    private let backBtn = UIButton(type: .system)
    private let trackpadView = UIView()
    private var cursorX: CGFloat = 640
    private var cursorY: CGFloat = 360

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        backBtn.setTitle("← Back", for: .normal)
        backBtn.frame = CGRect(x: 16, y: 60, width: 70, height: 44)
        backBtn.addTarget(self, action: #selector(goBack), for: .touchUpInside)
        view.addSubview(backBtn)

        urlField.placeholder = "Search YouTube or enter URL..."
        urlField.borderStyle = .roundedRect
        urlField.returnKeyType = .go
        urlField.autocapitalizationType = .none
        urlField.autocorrectionType = .no
        urlField.addTarget(self, action: #selector(loadURL), for: .editingDidEndOnExit)
        urlField.frame = CGRect(x: 92, y: 60, width: view.bounds.width - 108, height: 44)
        view.addSubview(urlField)

        let hintLabel = UILabel(frame: CGRect(x: 16, y: 112, width: view.bounds.width - 32, height: 24))
        hintLabel.text = "1 finger: Move cursor  |  Tap: Click  |  2 fingers: Scroll"
        hintLabel.font = .systemFont(ofSize: 13)
        hintLabel.textColor = .secondaryLabel
        hintLabel.textAlignment = .center
        view.addSubview(hintLabel)

        trackpadView.backgroundColor = .secondarySystemBackground
        trackpadView.layer.cornerRadius = 16
        trackpadView.frame = CGRect(x: 16, y: 144, width: view.bounds.width - 32, height: view.bounds.height - 184)
        view.addSubview(trackpadView)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        trackpadView.addGestureRecognizer(pan)
        trackpadView.addGestureRecognizer(tap)
    }

    private var externalVC: ExternalBrowserViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.session.role == .windowExternalDisplayNonInteractive })?
            .windows.first?.rootViewController as? ExternalBrowserViewController
    }

    @objc private func goBack() {
        externalVC?.webView.goBack()
    }

    @objc private func loadURL() {
        guard let text = urlField.text, !text.isEmpty else { return }
        let target = text.starts(with: "http") ? text : "https://youtube.com/results?search_query=\(text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        if let url = URL(string: target) {
            externalVC?.webView.load(URLRequest(url: url))
        }
        urlField.resignFirstResponder()
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let webView = externalVC?.webView else { return }
        let delta = gesture.translation(in: trackpadView)
        gesture.setTranslation(.zero, in: trackpadView)

        if gesture.numberOfTouches >= 2 {
            let newY = max(0, webView.scrollView.contentOffset.y - delta.y * 1.8)
            webView.scrollView.setContentOffset(CGPoint(x: 0, y: newY), animated: false)
        } else {
            cursorX = min(max(0, cursorX + delta.x * 2.2), webView.bounds.width)
            cursorY = min(max(0, cursorY + delta.y * 2.2), webView.bounds.height)
            let js = """
            const dot = document.getElementById('custom-cursor-dot');
            if (dot) { dot.style.left = '\(cursorX)px'; dot.style.top = '\(cursorY)px'; }
            """
            webView.evaluateJavaScript(js)
        }
    }

    @objc private func handleTap() {
        guard let webView = externalVC?.webView else { return }
        let js = """
        const el = document.elementFromPoint(\(cursorX), \(cursorY));
        if (el) {
            el.focus();
            el.dispatchEvent(new MouseEvent('mousedown', {bubbles: true, clientX: \(cursorX), clientY: \(cursorY)}));
            el.dispatchEvent(new MouseEvent('mouseup', {bubbles: true, clientX: \(cursorX), clientY: \(cursorY)}));
            el.click();
        }
        """
        webView.evaluateJavaScript(js)
    }
}

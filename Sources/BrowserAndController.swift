import UIKit
import WebKit

class ExternalBrowserViewController: UIViewController {
    var webView: WKWebView!
    let cursorView = UIView()
    private let desktopView = UIView()
    private let dockView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        setupDesktopWallpaper()
        setupWebView()
        setupFloatingDock()
        setupCursor()
        showDesktop()
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
        webView.isHidden = true
        view.addSubview(webView)
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
    }

    @objc func launchYouTube() {
        openURL("https://youtube.com")
    }

    @objc func launchChrome() {
        openURL("https://google.com")
    }

    @objc func launchNetflix() {
        openURL("https://netflix.com")
    }

    func openURL(_ urlString: String) {
        desktopView.isHidden = true
        webView.isHidden = false
        dockView.isHidden = true
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

        // First check if cursor clicked an icon on the floating desktop dock
        if !dockView.isHidden {
            let pointInDock = view.convert(point, to: dockView.contentView)
            for subview in dockView.contentView.subviews {
                if let btn = subview as? UIButton, btn.frame.contains(pointInDock) {
                    btn.sendActions(for: .touchUpInside)
                    return
                }
            }
        }

        // Otherwise click inside the active web page
        guard !webView.isHidden else { return }
        let js = """
        (function() {
            let el = document.elementFromPoint(\(point.x), \(point.y));
            if (!el) return;
            const clickable = el.closest('a, button, [role="button"], input, yt-formatted-string, ytd-thumbnail');
            const target = clickable || el;
            target.focus();
            ['pointerdown', 'mousedown', 'pointerup', 'mouseup', 'click'].forEach(type => {
                target.dispatchEvent(new MouseEvent(type, {
                    view: window,
                    bubbles: true,
                    cancelable: true,
                    clientX: \(point.x),
                    clientY: \(point.y)
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

        // Row 1: Navigation + Search/URL bar
view.addSubview(makeNavButton(title: "⌂", frame: CGRect(x: 12, y: 56, width: 38, height: 40), action: #selector(goHome)))
view.addSubview(makeNavButton(title: "←", frame: CGRect(x: 54, y: 56, width: 38, height: 40), action: #selector(goBack)))
view.addSubview(makeNavButton(title: "→", frame: CGRect(x: 96, y: 56, width: 38, height: 40), action: #selector(goForward)))
urlField.placeholder = "Search Google Chrome or type URL..."
urlField.borderStyle = .roundedRect
urlField.returnKeyType = .go
urlField.clearButtonMode = .whileEditing
urlField.autocapitalizationType = .none
urlField.autocorrectionType = .no
urlField.addTarget(self, action: #selector(loadURL), for: .editingDidEndOnExit)
urlField.frame = CGRect(x: 140, y: 56, width: w - 152, height: 40)
view.addSubview(urlField)
// Row 2: App Launcher & Media Shortcuts
let sites: [(String, Selector)] = [
("YouTube", #selector(openYouTube)),
("Chrome", #selector(openChrome)),
("Dock", #selector(toggleDock)),
("Full Screen", #selector(toggleVideoFullscreen))
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
// Row 3: Trackpad Instructions
let hintLabel = UILabel(frame: CGRect(x: 12, y: 146, width: w - 24, height: 20))
hintLabel.text = "1 finger: Move cursor  •  Tap: Click  •  2 fingers: Scroll"
hintLabel.font = .systemFont(ofSize: 12)
hintLabel.textColor = .secondaryLabel
hintLabel.textAlignment = .center
view.addSubview(hintLabel)
// Trackpad Surface
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
@objc private func goHome() { externalVC?.showDesktop() }
@objc private func goBack() { externalVC?.webView.goBack() }
@objc private func goForward() { externalVC?.webView.goForward() }
@objc private func openYouTube() { externalVC?.launchYouTube() }
@objc private func openChrome() { externalVC?.launchChrome() }
@objc private func toggleDock() { externalVC?.toggleDock() }
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
@objc private func loadURL() {
guard let text = urlField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return }
let target: String
if text.hasPrefix("http://") || text.hasPrefix("https://") {
target = text
} else if text.contains(".") && !text.contains(" ") {
target = "https://(text)"
} else {
let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
target = "google.com"
}
externalVC?.openURL(target)
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

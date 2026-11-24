import UIKit
import WebKit

class ExternalBrowserViewController: UIViewController, WKNavigationDelegate {
    var youtubeWebView: WKWebView!
    var netflixWebView: WKWebView!
    var chromeWebView: WKWebView!
    
    var chromeTabURLs: [String] = ["https://www.google.com"]
    var chromeTabTitles: [String] = ["Google"]
    var activeChromeTab: Int = 0
    
    enum AppMode { case desktop, youtube, netflix, chrome }
    var currentMode: AppMode = .desktop
    var isWindowFullscreen: Bool = false
    
    var activeWebView: WKWebView? {
        switch currentMode {
        case .desktop: return nil
        case .youtube: return youtubeWebView
        case .netflix: return netflixWebView
        case .chrome: return chromeWebView
        }
    }
    
    // Core UI Layers
    let cursorView = UIView()
    private let desktopView = UIView()
    private let menuBar = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterialDark))
    private let menuAppTitleLabel = UILabel()
    private let menuClockLabel = UILabel()
    private let menuBatteryLabel = UILabel()
    
    // Desktop Widgets & Icons
    private let widgetStackView = UIView()
    private let widgetTimeLabel = UILabel()
    private let widgetDateLabel = UILabel()
    private let widgetGreetingLabel = UILabel()
    private let widgetStatusLabel = UILabel()
    
    // macOS Window Container
    private let appWindowContainer = UIView()
    private let windowTitleBar = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterialDark))
    private let windowTitleLabel = UILabel()
    private let chromeTabScroll = UIScrollView()
    private let windowContentHolder = UIView()
    
    // Floating macOS Dock
    private let dockView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
    private var dockDots: [AppMode: UIView] = [:]
    
    private var isVideoZoomedFull = false
    private var didSetupViews = false
    private var statusTimer: Timer?
    var onInputSelected: ((String) -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        setupDesktopEnvironment()
        
        youtubeWebView = WebEngine.makeWebView(delegate: self)
        netflixWebView = WebEngine.makeWebView(delegate: self)
        chromeWebView = WebEngine.makeWebView(delegate: self)
        
        setupAppWindow()
        setupTopMenuBar()
        setupFloatingDock()
        setupCursor()
        startClockAndStatusTimer()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(pauseAllMediaOnBackground),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }
    
    deinit {
        statusTimer?.invalidate()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let w = view.bounds.width
        let h = view.bounds.height
        guard w > 100, h > 100 else { return }
        
        desktopView.frame = view.bounds
        desktopView.layer.sublayers?.forEach { if $0 is CAGradientLayer { $0.frame = desktopView.bounds } }
        
        let menuH: CGFloat = 30
        menuBar.frame = CGRect(x: 0, y: 0, width: w, height: menuH)
        menuClockLabel.frame = CGRect(x: w - 210, y: 0, width: 196, height: menuH)
        menuBatteryLabel.frame = CGRect(x: w - 285, y: 0, width: 70, height: menuH)
        
        let widgetW: CGFloat = 250
        let widgetH: CGFloat = min(430, h - 130)
        widgetStackView.frame = CGRect(x: w - widgetW - 24, y: menuH + 20, width: widgetW, height: widgetH)
        
        let dockW: CGFloat = 256
        let dockH: CGFloat = 68
        dockView.frame = CGRect(x: (w - dockW) / 2, y: h - dockH - 14, width: dockW, height: dockH)
        
        let bottomClearance: CGFloat = dockView.isHidden ? 12 : (dockH + 26)
        if isWindowFullscreen {
            appWindowContainer.frame = CGRect(x: 0, y: menuH, width: w, height: h - menuH)
            appWindowContainer.layer.cornerRadius = 0
        } else {
            let sideMargin: CGFloat = max(24, w * 0.04)
            let topMargin: CGFloat = menuH + 14
            appWindowContainer.frame = CGRect(
                x: sideMargin,
                y: topMargin,
                width: w - (sideMargin * 2),
                height: max(200, h - topMargin - bottomClearance)
            )
            appWindowContainer.layer.cornerRadius = 16
        }
        
        let titleBarH: CGFloat = (currentMode == .chrome) ? 42 : 34
        windowTitleBar.frame = CGRect(x: 0, y: 0, width: appWindowContainer.bounds.width, height: titleBarH)
        windowTitleLabel.frame = CGRect(x: 90, y: 0, width: appWindowContainer.bounds.width - 180, height: 34)
        chromeTabScroll.frame = CGRect(x: 86, y: 4, width: appWindowContainer.bounds.width - 100, height: 34)
        
        windowContentHolder.frame = CGRect(
            x: 0,
            y: titleBarH,
            width: appWindowContainer.bounds.width,
            height: max(100, appWindowContainer.bounds.height - titleBarH)
        )
        
        youtubeWebView.frame = windowContentHolder.bounds
        netflixWebView.frame = windowContentHolder.bounds
        chromeWebView.frame = windowContentHolder.bounds
        
        if cursorView.center == .zero {
            cursorView.center = CGPoint(x: w / 2, y: h / 2)
        }
        
        view.bringSubviewToFront(menuBar)
        view.bringSubviewToFront(dockView)
        view.bringSubviewToFront(cursorView)
        
        if !didSetupViews && w > 200 {
            didSetupViews = true
            showDesktop()
        }
    }
    
    @objc private func pauseAllMediaOnBackground() {
        WebEngine.pauseAllMedia(in: [youtubeWebView, netflixWebView, chromeWebView])
    }
    
    // MARK: - Desktop Wallpaper, Icons & Widgets
    private func setupDesktopEnvironment() {
        desktopView.frame = view.bounds
        desktopView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        let bgGradient = CAGradientLayer()
        bgGradient.frame = view.bounds
        bgGradient.colors = [
            UIColor(red: 0.03, green: 0.05, blue: 0.13, alpha: 1).cgColor,
            UIColor(red: 0.06, green: 0.16, blue: 0.36, alpha: 1).cgColor,
            UIColor(red: 0.02, green: 0.04, blue: 0.09, alpha: 1).cgColor
        ]
        bgGradient.locations = [0.0, 0.55, 1.0]
        desktopView.layer.insertSublayer(bgGradient, at: 0)
        
        let glowGradient = CAGradientLayer()
        glowGradient.type = .radial
        glowGradient.frame = view.bounds
        glowGradient.colors = [
            UIColor(red: 0.10, green: 0.78, blue: 0.62, alpha: 0.30).cgColor,
            UIColor(red: 0.14, green: 0.40, blue: 0.90, alpha: 0.14).cgColor,
            UIColor.clear.cgColor
        ]
        glowGradient.startPoint = CGPoint(x: 0.5, y: 0.56)
        glowGradient.endPoint = CGPoint(x: 0.95, y: 0.95)
        desktopView.layer.insertSublayer(glowGradient, at: 1)
        
        let brandTitle = UILabel()
        brandTitle.text = "XeOS"
        brandTitle.font = .systemFont(ofSize: 48, weight: .bold)
        brandTitle.textColor = UIColor.white.withAlphaComponent(0.90)
        brandTitle.textAlignment = .center
        brandTitle.frame = CGRect(x: 0, y: 0, width: 320, height: 56)
        brandTitle.center = CGPoint(x: max(400, view.bounds.midX), y: max(260, view.bounds.midY + 24))
        brandTitle.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
        desktopView.addSubview(brandTitle)
        
        let brandSub = UILabel()
        brandSub.text = "D E S K T O P   E N V I R O N M E N T"
        brandSub.font = .systemFont(ofSize: 12, weight: .semibold)
        brandSub.textColor = UIColor.white.withAlphaComponent(0.55)
        brandSub.textAlignment = .center
        brandSub.frame = CGRect(x: 0, y: 0, width: 320, height: 20)
        brandSub.center = CGPoint(x: brandTitle.center.x, y: brandTitle.center.y + 36)
        brandSub.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
        desktopView.addSubview(brandSub)
        
        let shortcuts: [(String, String, UIColor, Selector)] = [
            ("Chrome", "globe", .systemBlue, #selector(launchChromeDefault)),
            ("YouTube", "play.rectangle.fill", .systemRed, #selector(launchYouTube)),
            ("Netflix", "film.fill", .systemOrange, #selector(launchNetflix))
        ]
        
        for (i, item) in shortcuts.enumerated() {
            let iconBtn = UIButton(type: .custom)
            iconBtn.frame = CGRect(x: 28, y: 54 + CGFloat(i) * 98, width: 82, height: 84)
            iconBtn.addTarget(self, action: item.3, for: .touchUpInside)
            
            let squircle = UIView(frame: CGRect(x: 15, y: 4, width: 52, height: 52))
            squircle.backgroundColor = item.2
            squircle.layer.cornerRadius = 14
            squircle.layer.borderWidth = 1
            squircle.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
            squircle.layer.shadowColor = item.2.cgColor
            squircle.layer.shadowOpacity = 0.45
            squircle.layer.shadowRadius = 8
            squircle.layer.shadowOffset = CGSize(width: 0, height: 4)
            squircle.isUserInteractionEnabled = false
            
            let img = UIImageView(image: UIImage(systemName: item.1))
            img.tintColor = .white
            img.contentMode = .scaleAspectFit
            img.frame = CGRect(x: 12, y: 12, width: 28, height: 28)
squircle.addSubview(img)
iconBtn.addSubview(squircle)
let lbl = UILabel(frame: CGRect(x: 0, y: 60, width: 82, height: 20))
lbl.text = item.0
lbl.font = .systemFont(ofSize: 12, weight: .semibold)
lbl.textColor = .white
lbl.textAlignment = .center
lbl.layer.shadowColor = UIColor.black.cgColor
lbl.layer.shadowOpacity = 0.85
lbl.layer.shadowRadius = 2
lbl.layer.shadowOffset = CGSize(width: 0, height: 1)
iconBtn.addSubview(lbl)
desktopView.addSubview(iconBtn)
}
setupDesktopWidgets()
view.addSubview(desktopView)
}
private func setupDesktopWidgets() {
widgetStackView.backgroundColor = .clear
desktopView.addSubview(widgetStackView)
// Card 1: Clock & Greeting
let clockCard = makeGlassCard(frame: CGRect(x: 0, y: 0, width: 250, height: 112))
widgetTimeLabel.frame = CGRect(x: 16, y: 12, width: 218, height: 42)
widgetTimeLabel.font = .monospacedDigitSystemFont(ofSize: 34, weight: .bold)
widgetTimeLabel.textColor = .white
clockCard.contentView.addSubview(widgetTimeLabel)
widgetDateLabel.frame = CGRect(x: 16, y: 54, width: 218, height: 20)
widgetDateLabel.font = .systemFont(ofSize: 13, weight: .medium)
widgetDateLabel.textColor = UIColor.white.withAlphaComponent(0.75)
clockCard.contentView.addSubview(widgetDateLabel)
widgetGreetingLabel.frame = CGRect(x: 16, y: 78, width: 218, height: 20)
widgetGreetingLabel.font = .systemFont(ofSize: 13, weight: .semibold)
widgetGreetingLabel.textColor = UIColor.systemTeal
clockCard.contentView.addSubview(widgetGreetingLabel)
widgetStackView.addSubview(clockCard)
// Card 2: Monthly Calendar
let calCard = makeGlassCard(frame: CGRect(x: 0, y: 124, width: 250, height: 186))
let calHeader = UILabel(frame: CGRect(x: 16, y: 12, width: 218, height: 20))
let headerFmt = DateFormatter()
headerFmt.dateFormat = "MMMM yyyy"
calHeader.text = headerFmt.string(from: Date()).uppercased()
calHeader.font = .systemFont(ofSize: 12, weight: .bold)
calHeader.textColor = UIColor.systemRed
calCard.contentView.addSubview(calHeader)
let days = ["S", "M", "T", "W", "T", "F", "S"]
let colW: CGFloat = 31
for (idx, d) in days.enumerated() {
let dLbl = UILabel(frame: CGRect(x: 14 + CGFloat(idx) * colW, y: 36, width: colW, height: 18))
dLbl.text = d
dLbl.font = .systemFont(ofSize: 11, weight: .bold)
dLbl.textColor = UIColor.white.withAlphaComponent(0.5)
dLbl.textAlignment = .center
calCard.contentView.addSubview(dLbl)
}
let cal = Calendar.current
let now = Date()
let todayDay = cal.component(.day, from: now)
let comps = cal.dateComponents([.year, .month], from: now)
if let firstOfMonth = cal.date(from: comps),
let range = cal.range(of: .day, in: .month, for: firstOfMonth) {
let firstWeekday = cal.component(.weekday, from: firstOfMonth) - 1
for day in range {
let slot = firstWeekday + (day - 1)
let row = slot / 7
let col = slot % 7
let dayLbl = UILabel(frame: CGRect(x: 14 + CGFloat(col) * colW, y: 58 + CGFloat(row) * 21, width: colW, height: 20))
dayLbl.text = "(day)"
dayLbl.font = .monospacedDigitSystemFont(ofSize: 11, weight: day == todayDay ? .bold : .medium)
dayLbl.textAlignment = .center
if day == todayDay {
dayLbl.backgroundColor = .systemRed
dayLbl.textColor = .white
dayLbl.layer.cornerRadius = 10
dayLbl.clipsToBounds = true
} else {
dayLbl.textColor = UIColor.white.withAlphaComponent(0.85)
}
calCard.contentView.addSubview(dayLbl)
}
}
widgetStackView.addSubview(calCard)
// Card 3: Workspace Status
let sysCard = makeGlassCard(frame: CGRect(x: 0, y: 322, width: 250, height: 84))
let sysTitle = UILabel(frame: CGRect(x: 16, y: 12, width: 218, height: 18))
sysTitle.text = "WORKSPACE STATUS"
sysTitle.font = .systemFont(ofSize: 11, weight: .bold)
sysTitle.textColor = UIColor.white.withAlphaComponent(0.55)
sysCard.contentView.addSubview(sysTitle)
widgetStatusLabel.frame = CGRect(x: 16, y: 34, width: 218, height: 38)
widgetStatusLabel.font = .systemFont(ofSize: 12.5, weight: .medium)
widgetStatusLabel.textColor = .white
widgetStatusLabel.numberOfLines = 2
widgetStatusLabel.text = "iPhone 17 Pro Max • Connected\n3 Apps Ready (Chrome, YT, Netflix)"
sysCard.contentView.addSubview(widgetStatusLabel)
widgetStackView.addSubview(sysCard)
}
private func makeGlassCard(frame: CGRect) -> UIVisualEffectView {
let card = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
card.frame = frame
card.layer.cornerRadius = 18
card.clipsToBounds = true
card.layer.borderWidth = 1
card.layer.borderColor = UIColor.white.withAlphaComponent(0.20).cgColor
return card
}
// MARK: - Top macOS Menu Bar
private func setupTopMenuBar() {
menuBar.layer.borderWidth = 0.5
menuBar.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor
view.addSubview(menuBar)
let logoIcon = UIImageView(image: UIImage(systemName: "desktopcomputer"))
logoIcon.tintColor = .white
logoIcon.contentMode = .scaleAspectFit
logoIcon.frame = CGRect(x: 14, y: 6, width: 18, height: 18)
menuBar.contentView.addSubview(logoIcon)
menuAppTitleLabel.frame = CGRect(x: 40, y: 0, width: 140, height: 30)
menuAppTitleLabel.font = .systemFont(ofSize: 13, weight: .bold)
menuAppTitleLabel.textColor = .white
menuAppTitleLabel.text = "Finder"
menuBar.contentView.addSubview(menuAppTitleLabel)
let dockToggleBtn = UIButton(type: .system)
dockToggleBtn.setTitle("Dock", for: .normal)
dockToggleBtn.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
dockToggleBtn.setTitleColor(UIColor.white.withAlphaComponent(0.85), for: .normal)
dockToggleBtn.frame = CGRect(x: 180, y: 0, width: 54, height: 30)
dockToggleBtn.addTarget(self, action: #selector(menuToggleDock), for: .touchUpInside)
menuBar.contentView.addSubview(dockToggleBtn)
menuBatteryLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
menuBatteryLabel.textColor = UIColor.white.withAlphaComponent(0.85)
menuBatteryLabel.textAlignment = .right
menuBar.contentView.addSubview(menuBatteryLabel)
menuClockLabel.font = .monospacedDigitSystemFont(ofSize: 12.5, weight: .semibold)
menuClockLabel.textColor = .white
menuClockLabel.textAlignment = .right
menuBar.contentView.addSubview(menuClockLabel)
updateClockAndStatus()
}
@objc private func menuToggleDock() { toggleDock() }
private func startClockAndStatusTimer() {
statusTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
self?.updateClockAndStatus()
}
}
private func updateClockAndStatus() {
let now = Date()
let menuFmt = DateFormatter()
menuFmt.dateFormat = "EEE d MMM  h:mm a"
menuClockLabel.text = menuFmt.string(from: now)
let bigTimeFmt = DateFormatter()
bigTimeFmt.dateFormat = "HH:mm"
widgetTimeLabel.text = bigTimeFmt.string(from: now)
let bigDateFmt = DateFormatter()
bigDateFmt.dateFormat = "EEEE, MMMM d"
widgetDateLabel.text = bigDateFmt.string(from: now)
let hour = Calendar.current.component(.hour, from: now)
if hour < 12 {
widgetGreetingLabel.text = "Good Morning • Ready to Work"
} else if hour < 18 {
widgetGreetingLabel.text = "Good Afternoon • Ready to Work"
} else {
widgetGreetingLabel.text = "Good Evening • Ready to Work"
}
let level = UIDevice.current.batteryLevel
menuBatteryLabel.text = level >= 0 ? "🔋 (Int(level * 100))%" : "🔋 100%"
}
// MARK: - macOS Floating Window Container
private func setupAppWindow() {
appWindowContainer.backgroundColor = UIColor(red: 0.11, green: 0.12, blue: 0.14, alpha: 1)
appWindowContainer.layer.cornerRadius = 16
appWindowContainer.layer.borderWidth = 1
appWindowContainer.layer.borderColor = UIColor.white.withAlphaComponent(0.24).cgColor
appWindowContainer.clipsToBounds = true
appWindowContainer.isHidden = true
view.addSubview(appWindowContainer)
appWindowContainer.addSubview(windowTitleBar)
let trafficSpecs: [(UIColor, Selector)] = [
(UIColor(red: 1.0, green: 0.37, blue: 0.34, alpha: 1), #selector(closeActiveWindow)),
(UIColor(red: 1.0, green: 0.74, blue: 0.18, alpha: 1), #selector(minimizeActiveWindow)),
(UIColor(red: 0.15, green: 0.79, blue: 0.25, alpha: 1), #selector(toggleWindowMaxSize))
]
for (i, spec) in trafficSpecs.enumerated() {
let dotBtn = UIButton(type: .custom)
dotBtn.frame = CGRect(x: 14 + CGFloat(i) * 22, y: 10, width: 14, height: 14)
dotBtn.backgroundColor = spec.0
dotBtn.layer.cornerRadius = 7
dotBtn.addTarget(self, action: spec.1, for: .touchUpInside)
windowTitleBar.contentView.addSubview(dotBtn)
}
windowTitleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
windowTitleLabel.textColor = UIColor.white.withAlphaComponent(0.85)
windowTitleLabel.textAlignment = .center
windowTitleBar.contentView.addSubview(windowTitleLabel)
chromeTabScroll.showsHorizontalScrollIndicator = false
windowTitleBar.contentView.addSubview(chromeTabScroll)
appWindowContainer.addSubview(windowContentHolder)
windowContentHolder.addSubview(youtubeWebView)
windowContentHolder.addSubview(netflixWebView)
windowContentHolder.addSubview(chromeWebView)
}
@objc private func closeActiveWindow() { showDesktop() }
@objc private func minimizeActiveWindow() { showDesktop() }
@objc private func toggleWindowMaxSize() {
isWindowFullscreen.toggle()
view.setNeedsLayout()
view.layoutIfNeeded()
}
// MARK: - Chrome Tabs
private func rebuildMonitorChromeTabs() {
chromeTabScroll.subviews.forEach { $0.removeFromSuperview() }
var x: CGFloat = 4
for (index, title) in chromeTabTitles.enumerated() {
let isActive = (index == activeChromeTab)
let tabW: CGFloat = 156
let tabContainer = UIView(frame: CGRect(x: x, y: 2, width: tabW, height: 30))
tabContainer.backgroundColor = isActive ? UIColor.white.withAlphaComponent(0.24) : UIColor.white.withAlphaComponent(0.08)
tabContainer.layer.cornerRadius = 8
let selectBtn = UIButton(type: .custom)
selectBtn.frame = CGRect(x: 8, y: 0, width: tabW - 32, height: 30)
selectBtn.setTitle(title, for: .normal)
selectBtn.titleLabel?.font = .systemFont(ofSize: 12, weight: isActive ? .semibold : .regular)
selectBtn.titleLabel?.lineBreakMode = .byTruncatingTail
selectBtn.contentHorizontalAlignment = .left
selectBtn.setTitleColor(.white, for: .normal)
selectBtn.tag = index
selectBtn.addTarget(self, action: #selector(monitorSelectTab(_:)), for: .touchUpInside)
tabContainer.addSubview(selectBtn)
let closeBtn = UIButton(type: .custom)
closeBtn.frame = CGRect(x: tabW - 24, y: 3, width: 22, height: 24)
closeBtn.setTitle("×", for: .normal)
closeBtn.titleLabel?.font = .systemFont(ofSize: 15, weight: .bold)
closeBtn.setTitleColor(UIColor.white.withAlphaComponent(0.75), for: .normal)
closeBtn.tag = index
closeBtn.addTarget(self, action: #selector(monitorCloseTab(_:)), for: .touchUpInside)
tabContainer.addSubview(closeBtn)
chromeTabScroll.addSubview(tabContainer)
x += tabW + 6
}
let addBtn = UIButton(type: .custom)
addBtn.frame = CGRect(x: x, y: 3, width: 28, height: 28)
addBtn.setTitle("+", for: .normal)
addBtn.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
addBtn.setTitleColor(.white, for: .normal)
addBtn.backgroundColor = UIColor.white.withAlphaComponent(0.14)
addBtn.layer.cornerRadius = 14
addBtn.addTarget(self, action: #selector(monitorAddTab), for: .touchUpInside)
chromeTabScroll.addSubview(addBtn)
x += 36
chromeTabScroll.contentSize = CGSize(width: max(x, chromeTabScroll.bounds.width), height: 34)
}
@objc private func monitorSelectTab(_ sender: UIButton) { switchChromeTab(index: sender.tag) }
@objc private func monitorCloseTab(_ sender: UIButton) { closeChromeTab(index: sender.tag) }
@objc private func monitorAddTab() { addChromeTab(urlString: "google.com") }
func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
if webView === chromeWebView, let current = webView.url?.absoluteString, current.hasPrefix("http") {
if chromeTabURLs.indices.contains(activeChromeTab) {
chromeTabURLs[activeChromeTab] = current
let pageTitle = (webView.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
let host = webView.url?.host?.replacingOccurrences(of: "www.", with: "") ?? "Google"
chromeTabTitles[activeChromeTab] = pageTitle.isEmpty ? host : pageTitle
rebuildMonitorChromeTabs()
}
}
}
// MARK: - Floating Dock & Arrow Cursor
private func setupFloatingDock() {
dockView.layer.cornerRadius = 22
dockView.clipsToBounds = true
dockView.layer.borderWidth = 1
dockView.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
view.addSubview(dockView)
let apps: [(AppMode, String, UIColor, Selector)] = [
(.desktop, "macwindow", .systemIndigo, #selector(showDesktop)),
(.chrome, "globe", .systemBlue, #selector(launchChromeDefault)),
(.youtube, "play.rectangle.fill", .systemRed, #selector(launchYouTube)),
(.netflix, "film.fill", .systemOrange, #selector(launchNetflix))
]
let iconSize: CGFloat = 44
let spacing: CGFloat = 14
let totalW = CGFloat(apps.count) * iconSize + CGFloat(apps.count - 1) * spacing
let startX = (256 - totalW) / 2
for (i, app) in apps.enumerated() {
let btn = UIButton(type: .custom)
btn.frame = CGRect(x: startX + CGFloat(i) * (iconSize + spacing), y: 9, width: iconSize, height: 52)
btn.addTarget(self, action: app.3, for: .touchUpInside)
let iconBg = UIView(frame: CGRect(x: 0, y: 0, width: iconSize, height: iconSize))
iconBg.backgroundColor = app.2
iconBg.layer.cornerRadius = 12
iconBg.layer.borderWidth = 0.8
iconBg.layer.borderColor = UIColor.white.withAlphaComponent(0.32).cgColor
iconBg.isUserInteractionEnabled = false
let iconImg = UIImageView(image: UIImage(systemName: app.1))
iconImg.tintColor = .white
iconImg.contentMode = .scaleAspectFit
iconImg.frame = CGRect(x: 10, y: 10, width: 24, height: 24)
iconBg.addSubview(iconImg)
btn.addSubview(iconBg)
let dot = UIView(frame: CGRect(x: (iconSize - 5) / 2, y: 47, width: 5, height: 5))
dot.backgroundColor = .white
dot.layer.cornerRadius = 2.5
dot.isHidden = (app.0 != .desktop)
btn.addSubview(dot)
dockDots[app.0] = dot
dockView.contentView.addSubview(btn)
}
}
private func updateDockIndicators() {
for (mode, dot) in dockDots { dot.isHidden = (mode != currentMode) }
}
private func setupCursor() {
cursorView.frame = CGRect(x: 0, y: 0, width: 24, height: 24)
cursorView.backgroundColor = .clear
cursorView.isUserInteractionEnabled = false
let arrowImg = UIImageView(image: UIImage(systemName: "cursorarrow"))
arrowImg.frame = CGRect(x: 0, y: 0, width: 22, height: 22)
arrowImg.tintColor = .white
arrowImg.contentMode = .scaleAspectFit
arrowImg.layer.shadowColor = UIColor.black.cgColor
arrowImg.layer.shadowOpacity = 0.95
arrowImg.layer.shadowRadius = 2
arrowImg.layer.shadowOffset = CGSize(width: 1, height: 1)
cursorView.addSubview(arrowImg)
view.addSubview(cursorView)
}
private func loadFresh(_ urlString: String, into wv: WKWebView) {
wv.stopLoading()
if let url = URL(string: urlString) {
var req = URLRequest(url: url)
req.cachePolicy = .reloadIgnoringLocalCacheData
wv.load(req)
}
}
// MARK: - App Switching & Window Management
@objc func showDesktop() {
pauseAllMediaOnBackground()
currentMode = .desktop
isVideoZoomedFull = false
menuAppTitleLabel.text = "Finder"
desktopView.isHidden = false
appWindowContainer.isHidden = true
dockView.isHidden = false
updateDockIndicators()
view.bringSubviewToFront(desktopView)
view.bringSubviewToFront(menuBar)
view.bringSubviewToFront(dockView)
view.bringSubviewToFront(cursorView)
}
@objc func launchYouTube() {
pauseAllMediaOnBackground()
currentMode = .youtube
isVideoZoomedFull = false
menuAppTitleLabel.text = "YouTube"
windowTitleLabel.text = "YouTube"
windowTitleLabel.isHidden = false
chromeTabScroll.isHidden = true
desktopView.isHidden = true
appWindowContainer.isHidden = false
youtubeWebView.isHidden = false
netflixWebView.isHidden = true
chromeWebView.isHidden = true
updateDockIndicators()
view.setNeedsLayout()
view.layoutIfNeeded()
if youtubeWebView.url == nil {
loadFresh("youtube.com", into: youtubeWebView)
}
}
@objc func launchNetflix() {
pauseAllMediaOnBackground()
currentMode = .netflix
isVideoZoomedFull = false
menuAppTitleLabel.text = "Netflix"
windowTitleLabel.text = "Netflix"
windowTitleLabel.isHidden = false
chromeTabScroll.isHidden = true
desktopView.isHidden = true
appWindowContainer.isHidden = false
youtubeWebView.isHidden = true
netflixWebView.isHidden = false
chromeWebView.isHidden = true
updateDockIndicators()
view.setNeedsLayout()
view.layoutIfNeeded()
if netflixWebView.url == nil {
loadFresh("netflix.com", into: netflixWebView)
}
}
@objc func launchChromeDefault() { openInChrome(urlString: nil) }
func openInChrome(urlString: String?) {
pauseAllMediaOnBackground()
currentMode = .chrome
isVideoZoomedFull = false
menuAppTitleLabel.text = "Google Chrome"
windowTitleLabel.isHidden = true
chromeTabScroll.isHidden = false
desktopView.isHidden = true
appWindowContainer.isHidden = false
youtubeWebView.isHidden = true
netflixWebView.isHidden = true
chromeWebView.isHidden = false
updateDockIndicators()
view.setNeedsLayout()
view.layoutIfNeeded()
if chromeTabURLs.isEmpty {
chromeTabURLs = ["google.com"]
chromeTabTitles = ["Google"]
activeChromeTab = 0
}
if let target = urlString {
chromeTabURLs[activeChromeTab] = target
rebuildMonitorChromeTabs()
loadFresh(target, into: chromeWebView)
} else {
rebuildMonitorChromeTabs()
if chromeWebView.url == nil {
loadFresh(chromeTabURLs[activeChromeTab], into: chromeWebView)
}
}
}
func addChromeTab(urlString: String = "google.com") {
chromeTabURLs.append(urlString)
chromeTabTitles.append("Google")
activeChromeTab = chromeTabURLs.count - 1
openInChrome(urlString: urlString)
}
func switchChromeTab(index: Int) {
guard chromeTabURLs.indices.contains(index) else { return }
activeChromeTab = index
openInChrome(urlString: chromeTabURLs[index])
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
openInChrome(urlString: chromeTabURLs[activeChromeTab])
}
func toggleDock() {
dockView.isHidden.toggle()
view.setNeedsLayout()
view.layoutIfNeeded()
view.bringSubviewToFront(dockView)
view.bringSubviewToFront(cursorView)
}
// MARK: - Cursor Movement & Hit Testing
func moveCursor(dx: CGFloat, dy: CGFloat) {
let newX = min(max(0, cursorView.center.x + dx), view.bounds.width)
let newY = min(max(0, cursorView.center.y + dy), view.bounds.height)
cursorView.center = CGPoint(x: newX, y: newY)
}
func clickAtCursor() {
// Tip of the arrow cursor sits near the top-left of cursorView
let point = CGPoint(x: cursorView.frame.minX + 4, y: cursorView.frame.minY + 3)
UIView.animate(withDuration: 0.08, animations: {
self.cursorView.transform = CGAffineTransform(scaleX: 0.78, y: 0.78)
}) { _ in
UIView.animate(withDuration: 0.08) { self.cursorView.transform = .identity }
}
if !menuBar.isHidden && point.y <= 30 {
let ptInMenu = view.convert(point, to: menuBar.contentView)
for sub in menuBar.contentView.subviews {
if let btn = sub as? UIButton, btn.frame.contains(ptInMenu) {
btn.sendActions(for: .touchUpInside)
return
}
}
return
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
if currentMode == .desktop && !desktopView.isHidden {
let ptInDesktop = view.convert(point, to: desktopView)
for sub in desktopView.subviews {
if let btn = sub as? UIButton, btn.frame.contains(ptInDesktop) {
btn.sendActions(for: .touchUpInside)
return
}
}
return
}
if !appWindowContainer.isHidden {
let ptInTitleBar = view.convert(point, to: windowTitleBar.contentView)
if windowTitleBar.bounds.contains(ptInTitleBar) {
for sub in windowTitleBar.contentView.subviews {
if let btn = sub as? UIButton, btn.frame.contains(ptInTitleBar) {
btn.sendActions(for: .touchUpInside)
return
}
}
if !chromeTabScroll.isHidden {
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
}
return
}
}
guard let webView = activeWebView, currentMode != .desktop else { return }
let webPoint = view.convert(point, to: webView)
WebEngine.clickAt(
point: webPoint,
in: webView,
onFullscreen: { [weak self] in self?.toggleFullscreen() },
onInput: { [weak self] existingText in self?.onInputSelected?(existingText) }
)
}
func toggleFullscreen() {
isVideoZoomedFull.toggle()
WebEngine.toggleWebFullscreen(isFull: isVideoZoomedFull, in: activeWebView)
}
}

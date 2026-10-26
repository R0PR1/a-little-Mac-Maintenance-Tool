import AppKit
import Foundation
import WebKit

enum MmTheme {
    static let sage = NSColor(calibratedRed: 0.51, green: 0.70, blue: 0.60, alpha: 1)
    static let amber = NSColor(calibratedRed: 0.95, green: 0.80, blue: 0.56, alpha: 1)
    static let action = NSColor(calibratedRed: 0.88, green: 0.48, blue: 0.37, alpha: 1)
    static let panel = NSColor(calibratedRed: 0.11, green: 0.16, blue: 0.14, alpha: 1)
    static let text = NSColor(calibratedRed: 0.91, green: 0.94, blue: 0.91, alpha: 1)
    static let muted = NSColor(calibratedRed: 0.61, green: 0.69, blue: 0.64, alpha: 1)
}

enum MmWindows {
    static var guide: NSWindow?
    static var dashboard: NSWindow?
    static var console: NSWindow?
    static var settings: NSWindow?
    static var consoleController: MmConsoleController?
    static var dashboardController: MmDashboardController?
    static var settingsController: MmSettingsController?

    static func present(_ window: NSWindow) {
        // LSUIElement extras stay accessory; force key status so a reopened
        // window is visible after the user closed it once.
        if window.isReleasedWhenClosed {
            window.isReleasedWhenClosed = false
        }
        if !window.isVisible {
            window.center()
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }
}

// MARK: - Guide (in-app WebKit, no browser)

final class MmGuideController: NSObject, WKNavigationDelegate {
    let window: NSWindow
    private let web = WKWebView(frame: .zero)

    init(htmlURL: URL) {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 640),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        super.init()
        window.title = "How mm works"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 480, height: 360)
        web.navigationDelegate = self
        web.setValue(false, forKey: "drawsBackground")
        window.contentView = web
        let dir = htmlURL.deletingLastPathComponent()
        web.loadFileURL(htmlURL, allowingReadAccessTo: dir)
    }
}

// MARK: - Dashboard

final class MmDashboardController: NSObject {
    let window: NSWindow
    private let text = NSTextView()
    private let scroll = NSScrollView()
    private let refreshButton = NSButton(title: "Refresh", target: nil, action: nil)
    private let statusLabel = NSTextField(labelWithString: "")
    var onRefresh: (() -> Void)?

    override init() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 520),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        super.init()
        window.title = "mm dashboard"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 420, height: 320)

        let root = NSView(frame: .zero)
        root.wantsLayer = true
        root.layer?.backgroundColor = MmTheme.panel.cgColor

        statusLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        statusLabel.textColor = MmTheme.muted
        statusLabel.isEditable = false
        statusLabel.isBordered = false
        statusLabel.backgroundColor = .clear
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        refreshButton.target = self
        refreshButton.action = #selector(refreshTapped)
        refreshButton.bezelStyle = .rounded
        refreshButton.translatesAutoresizingMaskIntoConstraints = false

        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        text.isEditable = false
        text.isRichText = true
        text.drawsBackground = false
        text.textContainerInset = NSSize(width: 14, height: 12)
        text.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        scroll.documentView = text

        root.addSubview(statusLabel)
        root.addSubview(refreshButton)
        root.addSubview(scroll)
        window.contentView = root

        NSLayoutConstraint.activate([
            statusLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            statusLabel.topAnchor.constraint(equalTo: root.topAnchor, constant: 12),
            refreshButton.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),
            refreshButton.centerYAnchor.constraint(equalTo: statusLabel.centerYAnchor),
            scroll.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 10),
            scroll.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])
    }

    func render(snapshot: Snapshot?) {
        guard let snap = snapshot else {
            text.string = "Waiting for first check…"
            statusLabel.stringValue = "mm"
            return
        }
        statusLabel.stringValue = "mm · \(snap.overall) · \(MmDashboardController.relative(snap.checkedAt))"
        statusLabel.textColor = color(for: snap.overall)

        let out = NSMutableAttributedString()
        func line(_ s: String, color: NSColor = MmTheme.text, bold: Bool = false) {
            let font = bold
                ? NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold)
                : NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            out.append(NSAttributedString(string: s + "\n", attributes: [
                .font: font,
                .foregroundColor: color,
            ]))
        }

        line("MM \(snap.version)", bold: true)
        line("\(snap.host.model) · macOS \(snap.host.macos) · \(snap.host.arch)", color: MmTheme.muted)
        line("")

        if !snap.issues.isEmpty {
            line("NEEDS ATTENTION", color: MmTheme.amber, bold: true)
            for issue in snap.issues {
                let c = issue.state == "error" ? MmTheme.action : MmTheme.amber
                line("!  \(issue.menuLine)", color: c)
            }
            line("")
        }

        line("SYSTEM", bold: true)
        line("Disk            \(snap.disk?.menuDetail ?? "—")")
        if let battery = snap.battery {
            line("Battery         \(battery.detail)")
        }
        line("Time Machine    \(snap.timeMachine?.detail ?? "—")")
        if let fv = snap.filevault {
            line("FileVault       \(fv.detail)", color: fv.state == "warn" || fv.state == "error" ? MmTheme.amber : MmTheme.text)
        }
        line("")

        if let brew = snap.homebrew {
            line("HOMEBREW", bold: true)
            line("State           \(brew.state)")
            line("Formulae        \(brew.formulaeOutdated) outdated", color: brew.formulaeOutdated > 0 ? MmTheme.amber : MmTheme.text)
            line("Casks           \(brew.casksOutdated) outdated", color: brew.casksOutdated > 0 ? MmTheme.amber : MmTheme.text)
            line("")
        }

        if let settings = snap.settings {
            line("AUTOMATION", bold: true)
            line("Daily           \(settings.dailyEnabled ? "on" : "off") · \(String(format: "%02d:%02d", settings.dailyHour, settings.dailyMinute))")
            line("Weekly          \(settings.weeklyEnabled ? "on" : "off") · upgrades \(settings.weeklyUpgrade ? "opt-in" : "off")")
            line("")
        }

        if !snap.hints.isEmpty {
            line("NEXT", bold: true)
            for hint in snap.hints {
                line("→  \(hint)", color: MmTheme.sage)
            }
        }

        text.textStorage?.setAttributedString(out)
    }

    private func color(for overall: String) -> NSColor {
        switch overall {
        case "healthy": return MmTheme.sage
        case "attention": return MmTheme.amber
        case "action": return MmTheme.action
        default: return MmTheme.muted
        }
    }

    static func relative(_ epoch: Int) -> String {
        let delta = Int(Date().timeIntervalSince1970) - epoch
        if delta < 60 { return "just now" }
        if delta < 3600 { return "\(delta / 60)m ago" }
        if delta < 86400 { return "\(delta / 3600)h ago" }
        return "\(delta / 86400)d ago"
    }

    @objc private func refreshTapped() {
        onRefresh?()
    }
}

// MARK: - Console (update / upgrade output in-app)

final class MmConsoleController: NSObject {
    let window: NSWindow
    private let text = NSTextView()
    private let scroll = NSScrollView()
    private let titleField = NSTextField(labelWithString: "")
    private var process: Process?
    private var outHandle: FileHandle?
    private var errHandle: FileHandle?
    var onFinished: (() -> Void)?

    override init() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 420),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        super.init()
        window.title = "mm"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 420, height: 240)

        let root = NSView(frame: .zero)
        root.wantsLayer = true
        root.layer?.backgroundColor = MmTheme.panel.cgColor

        titleField.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        titleField.textColor = MmTheme.text
        titleField.isEditable = false
        titleField.isBordered = false
        titleField.backgroundColor = .clear
        titleField.translatesAutoresizingMaskIntoConstraints = false

        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        text.isEditable = false
        text.drawsBackground = false
        text.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        text.textColor = MmTheme.text
        text.textContainerInset = NSSize(width: 12, height: 10)
        scroll.documentView = text

        root.addSubview(titleField)
        root.addSubview(scroll)
        window.contentView = root

        NSLayoutConstraint.activate([
            titleField.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            titleField.topAnchor.constraint(equalTo: root.topAnchor, constant: 10),
            titleField.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            scroll.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: titleField.bottomAnchor, constant: 8),
            scroll.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])
    }

    func showText(title: String, body: String) {
        process?.terminate()
        process = nil
        outHandle?.readabilityHandler = nil
        errHandle?.readabilityHandler = nil
        window.title = title
        titleField.stringValue = title
        text.string = ""
        text.textStorage?.setAttributedString(NSAttributedString(
            string: body,
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                .foregroundColor: MmTheme.text,
            ]
        ))
    }

    func run(title: String, executable: String, arguments: [String], environment: [String: String]) {
        process?.terminate()
        process = nil
        text.string = ""
        titleField.stringValue = title
        window.title = title

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = environment

        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        outHandle = out.fileHandleForReading
        errHandle = err.fileHandleForReading

        // Drain continuously to avoid pipe deadlock on verbose brew output.
        out.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.append(data)
        }
        err.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.append(data)
        }

        process.terminationHandler = { [weak self] proc in
            DispatchQueue.main.async {
                self?.outHandle?.readabilityHandler = nil
                self?.errHandle?.readabilityHandler = nil
                self?.append(Data("\n— exit \(proc.terminationStatus) —\n".utf8))
                self?.process = nil
                self?.onFinished?()
            }
        }

        self.process = process
        do {
            try process.run()
            append(Data("\(executable) \(arguments.joined(separator: " "))\n\n".utf8))
        } catch {
            append(Data("failed to start: \(error)\n".utf8))
            onFinished?()
        }
    }

    private func append(_ data: Data) {
        guard let chunk = String(data: data, encoding: .utf8), !chunk.isEmpty else { return }
        DispatchQueue.main.async {
            self.text.textStorage?.append(NSAttributedString(
                string: chunk,
                attributes: [
                    .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: MmTheme.text,
                ]
            ))
            self.text.scrollToEndOfDocument(nil)
        }
    }
}

// MARK: - Settings window

final class MmSettingsController: NSObject {
    let window: NSWindow
    private let daily = NSButton(checkboxWithTitle: "Daily check", target: nil, action: nil)
    private let weekly = NSButton(checkboxWithTitle: "Weekly job", target: nil, action: nil)
    private let weeklyUpgrade = NSButton(checkboxWithTitle: "Allow weekly upgrades", target: nil, action: nil)
    private let upgradeCasks = NSButton(checkboxWithTitle: "Upgrade casks with mm upgrade", target: nil, action: nil)
    private let note = NSTextField(wrappingLabelWithString: "Schedules use launchd (not cron). Weekly upgrades stay off until you opt in.")
    private var applying = false

    var onToggleDaily: ((Bool) -> Void)?
    var onToggleWeekly: ((Bool) -> Void)?
    var onToggleWeeklyUpgrade: ((Bool) -> Void)?
    var onToggleUpgradeCasks: ((Bool) -> Void)?

    override init() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        super.init()
        window.title = "mm parameters"
        window.isReleasedWhenClosed = false

        let root = NSView(frame: .zero)
        root.wantsLayer = true
        root.layer?.backgroundColor = MmTheme.panel.cgColor

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        for btn in [daily, weekly, weeklyUpgrade, upgradeCasks] {
            btn.target = self
            btn.font = NSFont.systemFont(ofSize: 13)
            btn.contentTintColor = MmTheme.text
        }
        daily.action = #selector(dailyChanged)
        weekly.action = #selector(weeklyChanged)
        weeklyUpgrade.action = #selector(weeklyUpgradeChanged)
        upgradeCasks.action = #selector(casksChanged)

        note.textColor = MmTheme.muted
        note.font = NSFont.systemFont(ofSize: 11)
        note.maximumNumberOfLines = 3
        note.preferredMaxLayoutWidth = 360

        stack.addArrangedSubview(daily)
        stack.addArrangedSubview(weekly)
        stack.addArrangedSubview(NSBox.separator())
        stack.addArrangedSubview(weeklyUpgrade)
        stack.addArrangedSubview(upgradeCasks)
        stack.addArrangedSubview(note)
        root.addSubview(stack)
        window.contentView = root

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            stack.topAnchor.constraint(equalTo: root.topAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor),
        ])
    }

    func render(settings: Settings?) {
        applying = true
        defer { applying = false }
        guard let settings else {
            daily.title = "Daily check"
            weekly.title = "Weekly job"
            daily.state = .off
            weekly.state = .off
            weeklyUpgrade.state = .off
            upgradeCasks.state = .off
            return
        }
        daily.title = settings.dailyLabel
        weekly.title = settings.weeklyLabel
        daily.state = settings.dailyEnabled ? .on : .off
        weekly.state = settings.weeklyEnabled ? .on : .off
        weeklyUpgrade.state = settings.weeklyUpgrade ? .on : .off
        upgradeCasks.state = settings.upgradeCasks ? .on : .off
    }

    @objc private func dailyChanged() {
        guard !applying else { return }
        onToggleDaily?(daily.state == .on)
    }

    @objc private func weeklyChanged() {
        guard !applying else { return }
        onToggleWeekly?(weekly.state == .on)
    }

    @objc private func weeklyUpgradeChanged() {
        guard !applying else { return }
        onToggleWeeklyUpgrade?(weeklyUpgrade.state == .on)
    }

    @objc private func casksChanged() {
        guard !applying else { return }
        onToggleUpgradeCasks?(upgradeCasks.state == .on)
    }
}

private extension NSBox {
    static func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        box.translatesAutoresizingMaskIntoConstraints = false
        box.widthAnchor.constraint(equalToConstant: 360).isActive = true
        return box
    }
}

import AppKit
import Foundation

struct Snapshot: Decodable {
    var version: String
    var overall: String
    var exit: Int
    var checkedAt: Int
    var running: Running?
    var host: Host
    var disk: Disk?
    var battery: Battery?
    var timeMachine: Item?
    var homebrew: Homebrew?
    var automation: Automation
    var filevault: Item?
    var issues: [Issue]
    var hints: [String]

    enum CodingKeys: String, CodingKey {
        case version, overall, exit, running, host, disk, battery, homebrew, automation, filevault, issues, hints
        case checkedAt = "checked_at"
        case timeMachine = "time_machine"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decode(String.self, forKey: .version)
        overall = try c.decode(String.self, forKey: .overall)
        exit = try c.decode(Int.self, forKey: .exit)
        checkedAt = try c.decode(Int.self, forKey: .checkedAt)
        running = try c.decodeIfPresent(Running.self, forKey: .running)
        host = try c.decode(Host.self, forKey: .host)
        disk = try c.decodeIfPresent(Disk.self, forKey: .disk)
        battery = try c.decodeIfPresent(Battery.self, forKey: .battery)
        timeMachine = try c.decodeIfPresent(Item.self, forKey: .timeMachine)
        homebrew = try c.decodeIfPresent(Homebrew.self, forKey: .homebrew)
        automation = try c.decode(Automation.self, forKey: .automation)
        filevault = try c.decodeIfPresent(Item.self, forKey: .filevault)
        issues = try c.decodeIfPresent([Issue].self, forKey: .issues) ?? []
        hints = try c.decodeIfPresent([String].self, forKey: .hints) ?? []
    }
}

struct Issue: Decodable {
    var label: String
    var detail: String
    var state: String

    var menuLine: String {
        if detail.isEmpty { return label }
        return "\(label) — \(detail)"
    }
}

struct Running: Decodable {
    var job: String
    var pid: Int
    var startedAt: Int
    enum CodingKeys: String, CodingKey {
        case job, pid
        case startedAt = "started_at"
    }
}

struct Host: Decodable {
    var model: String
    var macos: String
    var arch: String
}

struct Item: Decodable {
    var state: String
    var detail: String
}

struct Disk: Decodable {
    var state: String
    var percent: Int?
    var free: String?
    var detail: String?

    var menuDetail: String {
        if let detail, !detail.isEmpty { return detail }
        if let percent, let free, !free.isEmpty { return "\(percent)% · \(free) free" }
        if let percent { return "\(percent)%" }
        return "—"
    }
}

struct Battery: Decodable {
    var state: String
    var percent: Int?
    var detail: String
}

struct Homebrew: Decodable {
    var state: String
    var formulaeOutdated: Int
    var casksOutdated: Int
    enum CodingKeys: String, CodingKey {
        case state
        case formulaeOutdated = "formulae_outdated"
        case casksOutdated = "casks_outdated"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        state = try c.decode(String.self, forKey: .state)
        formulaeOutdated = try c.decodeIfPresent(Int.self, forKey: .formulaeOutdated) ?? 0
        casksOutdated = try c.decodeIfPresent(Int.self, forKey: .casksOutdated) ?? 0
    }
}

struct Automation: Decodable {
    var daily: Item?
    var weekly: Item?
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var item: NSStatusItem!
    private var snapshot: Snapshot?
    private var refreshTimer: Timer?
    private var pulseTimer: Timer?
    private var pulseOn = true
    private var inflight: [Process] = []
    private var localRunning: Running?
    private var statusInFlight = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold)
        item.menu = NSMenu()
        item.menu?.delegate = self
        refresh(force: true)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            self?.refresh(force: false)
        }
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.pulseOn.toggle()
            self.renderTitle()
        }
        if let t = refreshTimer { RunLoop.main.add(t, forMode: .common) }
        if let t = pulseTimer { RunLoop.main.add(t, forMode: .common) }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu(menu)
    }

    private func extraPath() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/bin").path
        let extras = [
            home,
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
        ]
        let existing = ProcessInfo.processInfo.environment["PATH"] ?? ""
        return (extras + existing.split(separator: ":").map(String.init)).joined(separator: ":")
    }

    private func processEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = extraPath()
        if let bin = mmBin() {
            env["MM_BIN"] = bin
        }
        return env
    }

    private func mmBin() -> String? {
        if let env = ProcessInfo.processInfo.environment["MM_BIN"], FileManager.default.isExecutableFile(atPath: env) {
            return env
        }
        let home = NSHomeDirectory()
        var candidates = [
            "\(home)/.local/bin/mm",
            "/opt/homebrew/bin/mm",
            "/usr/local/bin/mm",
        ]
        let path = extraPath()
        for dir in path.split(separator: ":") {
            candidates.append("\(dir)/mm")
        }
        var seen = Set<String>()
        for path in candidates where seen.insert(path).inserted && FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        return nil
    }

    private func cacheURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Caches/mm/last-status.json")
    }

    private func loadCached() -> Snapshot? {
        guard let data = try? Data(contentsOf: cacheURL()) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }

    private func refresh(force: Bool) {
        // Always paint from cache first. force:true used to skip this, so a hung
        // status --json left the menu on "waiting for first check" forever.
        if let cached = loadCached() {
            snapshot = cached
            renderTitle()
        } else if force {
            renderTitle()
        }
        if statusInFlight { return }
        statusInFlight = true
        // Discard stdout. mm status --json tees JSON into a pipe; reading only in
        // terminationHandler deadlocks once the pipe buffer fills (same class of
        // bug as Run check now / brew update). The snapshot is already on disk.
        runMm(["status", "--json"], captureOutput: false) { [weak self] _, _ in
            self?.statusInFlight = false
            self?.snapshot = self?.loadCached() ?? self?.snapshot
            self?.renderTitle()
        }
    }

    private func runningOverlay() -> Running? {
        localRunning ?? snapshot?.running
    }

    private func pipColor() -> NSColor {
        if runningOverlay() != nil {
            return pulseOn ? NSColor(calibratedRed: 0.51, green: 0.70, blue: 0.60, alpha: 1) : NSColor.secondaryLabelColor
        }
        switch snapshot?.overall {
        case "healthy":
            return NSColor(calibratedRed: 0.51, green: 0.70, blue: 0.60, alpha: 1)
        case "attention":
            return NSColor(calibratedRed: 0.95, green: 0.80, blue: 0.56, alpha: 1)
        case "action":
            return NSColor(calibratedRed: 0.88, green: 0.48, blue: 0.37, alpha: 1)
        default:
            return NSColor.secondaryLabelColor
        }
    }

    private func renderTitle() {
        let base = NSMutableAttributedString(
            string: "mm",
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: NSColor.labelColor,
            ]
        )
        let dot = NSAttributedString(
            string: " ●",
            attributes: [
                .font: NSFont.systemFont(ofSize: 9, weight: .bold),
                .foregroundColor: pipColor(),
            ]
        )
        base.append(dot)
        item.button?.attributedTitle = base
        item.button?.toolTip = tooltip()
    }

    private func tooltip() -> String {
        if let run = runningOverlay() {
            return "mm · running \(run.job)"
        }
        if let snap = snapshot {
            if snap.issues.isEmpty {
                return "mm · \(snap.overall)"
            }
            let head = snap.issues.prefix(3).map(\.menuLine).joined(separator: " · ")
            return "mm · \(snap.overall) · \(head)"
        }
        return "mm"
    }

    private func rebuildMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        let snap = snapshot
        let run = runningOverlay()

        if let run {
            addHeader(menu, "mm · running \(run.job)")
            let elapsed = max(0, Int(Date().timeIntervalSince1970) - run.startedAt)
            addMuted(menu, "Started \(elapsed)s ago")
        } else if let snap {
            addHeader(menu, "mm · \(snap.overall)")
            addMuted(menu, relativeTime(snap.checkedAt))
        } else {
            addHeader(menu, "mm · waiting for first check")
        }

        menu.addItem(.separator())

        let issues = snap?.issues ?? []
        if !issues.isEmpty {
            addHeader(menu, "Needs attention")
            for issue in issues {
                addIssue(menu, issue.menuLine)
            }
            menu.addItem(.separator())
        }

        addRow(menu, "Disk", snap?.disk?.menuDetail ?? "—")
        if let battery = snap?.battery {
            addRow(menu, "Battery", battery.detail)
        }
        if issues.isEmpty {
            addRow(menu, "Time Machine", snap?.timeMachine?.detail ?? "—")
            if let brew = snap?.homebrew {
                var parts: [String] = []
                if brew.formulaeOutdated > 0 { parts.append("\(brew.formulaeOutdated) formulae") }
                if brew.casksOutdated > 0 { parts.append("\(brew.casksOutdated) casks") }
                let detail = parts.isEmpty ? "up to date" : "\(parts.joined(separator: ", ")) outdated"
                addRow(menu, "Homebrew", detail)
            }
            if let fv = snap?.filevault {
                addRow(menu, "FileVault", fv.detail)
            }
        }

        menu.addItem(.separator())
        addAction(menu, "Open Dashboard", #selector(openDashboard))
        let check = addAction(menu, "Run check now", #selector(runCheck))
        if run != nil { check.isEnabled = false }

        let formulaeOutdated = snap?.homebrew?.formulaeOutdated ?? 0
        let casksOutdated = snap?.homebrew?.casksOutdated ?? 0
        let upgrade = addAction(menu, "Upgrade formulae…", #selector(openUpgrade))
        upgrade.isEnabled = formulaeOutdated > 0 && run == nil
        if casksOutdated > 0 && formulaeOutdated == 0 {
            let caskHint = addMutedAction(menu, "Casks outdated — use: mm upgrade --casks")
            caskHint.isEnabled = false
        }

        addAction(menu, "Open logs", #selector(openLogs))
        menu.addItem(.separator())
        addAction(menu, "Quit mm extra", #selector(quitExtra))
    }

    private func addIssue(_ menu: NSMenu, _ title: String) {
        let item = NSMenuItem(title: "!  \(title)", action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    @discardableResult
    private func addMutedAction(_ menu: NSMenu, _ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
        return item
    }

    private func addHeader(_ menu: NSMenu, _ title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    private func addMuted(_ menu: NSMenu, _ title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    private func addRow(_ menu: NSMenu, _ label: String, _ value: String) {
        let padded = label.padding(toLength: 14, withPad: " ", startingAt: 0)
        addMuted(menu, "\(padded)\(value)")
    }

    @discardableResult
    private func addAction(_ menu: NSMenu, _ title: String, _ sel: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: sel, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return item
    }

    private func relativeTime(_ epoch: Int) -> String {
        let delta = Int(Date().timeIntervalSince1970) - epoch
        if delta < 60 { return "Last check just now" }
        if delta < 3600 { return "Last check \(delta / 60)m ago" }
        if delta < 86400 { return "Last check \(delta / 3600)h ago" }
        return "Last check \(delta / 86400)d ago"
    }

    private func logError(_ message: String) {
        FileHandle.standardError.write(Data("mm-extra: \(message)\n".utf8))
    }

    private func runMm(_ args: [String], captureOutput: Bool = true, completion: ((Data?, Int32) -> Void)? = nil) {
        guard let bin = mmBin() else {
            logError("mm executable not found (set MM_BIN); tried ~/.local/bin, Homebrew, PATH")
            DispatchQueue.main.async { completion?(nil, 2) }
            return
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: bin)
        process.arguments = args
        process.environment = processEnvironment()
        let out = Pipe()
        if captureOutput {
            process.standardOutput = out
        } else {
            process.standardOutput = FileHandle.nullDevice
        }
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { [weak self] proc in
            let data = captureOutput ? out.fileHandleForReading.readDataToEndOfFile() : nil
            DispatchQueue.main.async {
                self?.inflight.removeAll { $0 === proc }
                completion?(data, proc.terminationStatus)
            }
        }
        inflight.append(process)
        do {
            try process.run()
        } catch {
            inflight.removeAll { $0 === process }
            logError("failed to spawn \(bin) \(args.joined(separator: " ")): \(error)")
            DispatchQueue.main.async { completion?(nil, 2) }
        }
    }

    private func runInTerminal(_ command: String) {
        let script = "tell application \"Terminal\" to do script \(self.appleScriptQuote(command))"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        try? process.run()
    }

    private func appleScriptQuote(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    @objc private func openDashboard() {
        guard let bin = mmBin() else {
            logError("mm executable not found")
            return
        }
        runInTerminal("\(bin) status")
    }

    @objc private func runCheck() {
        if runningOverlay() != nil { return }
        localRunning = Running(job: "update", pid: Int(ProcessInfo.processInfo.processIdentifier), startedAt: Int(Date().timeIntervalSince1970))
        renderTitle()
        // brew update is verbose. Capturing stdout/stderr in pipes deadlocks once the
        // kernel pipe buffer fills, so Run check now never returned on a real Mac.
        runMm(["update"], captureOutput: false) { [weak self] _, _ in
            self?.localRunning = nil
            self?.refresh(force: true)
        }
    }

    @objc private func openUpgrade() {
        guard let bin = mmBin() else {
            logError("mm executable not found")
            return
        }
        runInTerminal("\(bin) upgrade")
    }

    @objc private func openLogs() {
        let logs = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/mm")
        NSWorkspace.shared.open(logs)
    }

    @objc private func quitExtra() {
        let domain = "gui/\(getuid())/io.mm.menubar"
        let bootout = Process()
        bootout.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        bootout.arguments = ["bootout", domain]
        try? bootout.run()
        bootout.waitUntilExit()
        NSApp.terminate(nil)
    }
}

@main
enum MmExtraMain {
    static var delegate: AppDelegate?

    static func main() {
        let app = NSApplication.shared
        delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

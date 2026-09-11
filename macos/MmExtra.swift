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
    var hints: [String]

    enum CodingKeys: String, CodingKey {
        case version, overall, exit, running, host, disk, battery, homebrew, automation, hints
        case checkedAt = "checked_at"
        case timeMachine = "time_machine"
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
    enum CodingKeys: String, CodingKey {
        case state
        case formulaeOutdated = "formulae_outdated"
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
            return "mm · \(snap.overall)"
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
        addRow(menu, "Disk", snap?.disk?.menuDetail ?? "—")
        if let battery = snap?.battery {
            addRow(menu, "Battery", battery.detail)
        }
        addRow(menu, "Time Machine", snap?.timeMachine?.detail ?? "—")
        if let brew = snap?.homebrew {
            let detail = brew.formulaeOutdated > 0 ? "\(brew.formulaeOutdated) outdated" : "up to date"
            addRow(menu, "Homebrew", detail)
        }

        menu.addItem(.separator())
        addAction(menu, "Open Dashboard", #selector(openDashboard))
        let check = addAction(menu, "Run check now", #selector(runCheck))
        if run != nil { check.isEnabled = false }

        let outdated = snap?.homebrew?.formulaeOutdated ?? 0
        let upgrade = addAction(menu, "Upgrade formulae…", #selector(openUpgrade))
        upgrade.isEnabled = outdated > 0 && run == nil

        addAction(menu, "Open logs", #selector(openLogs))
        menu.addItem(.separator())
        addAction(menu, "Quit mm extra", #selector(quitExtra))
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

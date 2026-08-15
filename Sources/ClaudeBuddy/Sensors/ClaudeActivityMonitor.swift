import Foundation

/// Watches for a running Claude Code session and how hard it is working.
final class ClaudeActivityMonitor {
    struct Activity: Equatable {
        var isRunning = false
        /// True when the matched processes are actively burning CPU.
        var isBusy = false
    }

    private(set) var activity = Activity()
    var onChange: ((Activity) -> Void)?

    private var timer: Timer?
    private let interval: TimeInterval
    /// CPU time per pid at the previous sample, for computing a rate.
    private var cpuSamples: [pid_t: (nanoseconds: UInt64, at: Date)] = [:]
    /// Consecutive scans with no match, to stop the mood flickering when a
    /// process momentarily drops off the list.
    private var missedScans = 0
    private let queue = DispatchQueue(label: "com.claudebuddy.activity", qos: .utility)

    init(interval: TimeInterval = 3) {
        self.interval = interval
    }

    func start() {
        guard timer == nil else { return }
        scan()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.scan()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if activity != Activity() {
            activity = Activity()
            onChange?(activity)
        }
    }

    // MARK: - Private

    private func scan() {
        queue.async { [weak self] in
            guard let self else { return }
            let matches = ProcessScanner.userProcesses().filter(Self.looksLikeClaudeCode)
            let busy = self.sampleBusy(matches)

            DispatchQueue.main.async {
                self.apply(matchCount: matches.count, busy: busy)
            }
        }
    }

    /// Returns true when the matched processes together used a meaningful slice
    /// of a core since the previous sample.
    private func sampleBusy(_ matches: [ScannedProcess]) -> Bool {
        let now = Date()
        var totalRate = 0.0
        var fresh: [pid_t: (nanoseconds: UInt64, at: Date)] = [:]

        for process in matches {
            guard let nanoseconds = ProcessScanner.cpuNanoseconds(for: process.pid) else { continue }
            fresh[process.pid] = (nanoseconds, now)
            guard let previous = cpuSamples[process.pid] else { continue }
            let elapsed = now.timeIntervalSince(previous.at)
            guard elapsed > 0.2, nanoseconds >= previous.nanoseconds else { continue }
            let usedSeconds = Double(nanoseconds - previous.nanoseconds) / 1_000_000_000
            totalRate += usedSeconds / elapsed
        }

        cpuSamples = fresh
        // 12% of a core: enough to separate "thinking" from a session that is
        // just sitting at a prompt.
        return totalRate > 0.12
    }

    private func apply(matchCount: Int, busy: Bool) {
        var next = activity
        if matchCount > 0 {
            missedScans = 0
            next.isRunning = true
            next.isBusy = busy
        } else {
            missedScans += 1
            if missedScans >= 2 {
                next.isRunning = false
                next.isBusy = false
            }
        }

        guard next != activity else { return }
        activity = next
        onChange?(next)
    }

    /// Matches the Claude Code CLI, whether it is the native binary or running
    /// under a JavaScript runtime. Deliberately does not match the Claude
    /// desktop app, whose process is named `Claude`.
    static func looksLikeClaudeCode(_ process: ScannedProcess) -> Bool {
        guard process.pid != getpid() else { return false }
        if process.command == "claude" { return true }

        let runtimes: Set<String> = ["node", "bun", "deno", "npm", "npx"]
        guard runtimes.contains(process.command) else { return false }

        let tokens = process.arguments.split(separator: " ")
        guard !tokens.contains(where: { $0.contains("ClaudeBuddy") }) else { return false }

        return tokens.contains { token in
            let lowercased = token.lowercased()
            if lowercased.contains("claude-code") { return true }
            let lastComponent = lowercased.split(separator: "/").last.map(String.init) ?? lowercased
            return lastComponent == "claude" || lastComponent == "claude.js"
        }
    }

    deinit { timer?.invalidate() }
}

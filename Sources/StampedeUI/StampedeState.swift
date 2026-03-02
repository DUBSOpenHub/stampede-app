import Foundation
import Combine
import SwiftUI

@MainActor
class StampedeState: ObservableObject {
    @Published var agents: [Agent] = []
    @Published var conflicts: [FileConflict] = []
    @Published var totalTasks: Int = 0
    @Published var doneTasks: Int = 0
    @Published var isRunning: Bool = false
    @Published var startTime: Date?
    @Published var isLive: Bool = false
    @Published var runId: String?
    @Published var objective: String?
    @Published var repoPath: String?
    @Published var selectedRunDir: URL?
    private var timer: Timer?
    private var fleet: [String: FleetEntry] = [:]

    var overallProgress: Double { guard totalTasks > 0 else { return 0 }; return Double(doneTasks) / Double(totalTasks) }
    var totalTokens: Int { agents.reduce(0) { $0 + $1.tokensUsed } }
    var totalCost: Double { agents.reduce(0) { $0 + $1.estimatedCost } }
    var activeCount: Int { agents.filter { $0.status == .working || $0.status == .claiming }.count }
    var doneCount: Int { agents.filter { $0.status == .done }.count }
    var failedCount: Int { agents.filter { $0.status == .failed }.count }
    var formattedElapsed: String {
        guard let start = startTime else { return "0:00" }
        let secs = Int(Date().timeIntervalSince(start))
        return String(format: "%d:%02d", secs / 60, secs % 60)
    }

    var stampedeBase: URL {
        let custom = UserDefaults.standard.string(forKey: "stampedeDir") ?? ""
        if !custom.isEmpty { return URL(fileURLWithPath: custom) }
        return URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".copilot/stampede")
    }

    init() {
        if let runDir = discoverLatestRun() {
            selectedRunDir = runDir
            loadRun(runDir)
            startMonitoring()
        } else {
            loadDemo()
        }
    }

    private init(demo: Bool) {
        // private init for demo factory
    }

    // MARK: - Run Discovery

    func discoverLatestRun() -> URL? {
        let fm = FileManager.default
        let base = stampedeBase
        guard let entries = try? fm.contentsOfDirectory(atPath: base.path) else { return nil }
        let runs = entries.filter { $0.hasPrefix("run-") }.sorted().reversed()
        for run in runs {
            let dir = base.appendingPathComponent(run)
            if fm.fileExists(atPath: dir.appendingPathComponent("fleet.json").path) ||
               fm.fileExists(atPath: dir.appendingPathComponent("state.json").path) {
                return dir
            }
        }
        return nil
    }

    func switchToRun(_ dir: URL) {
        stopMonitoring()
        selectedRunDir = dir
        loadRun(dir)
        startMonitoring()
    }

    func availableRuns() -> [(id: String, url: URL)] {
        let fm = FileManager.default
        let base = stampedeBase
        guard let entries = try? fm.contentsOfDirectory(atPath: base.path) else { return [] }
        return entries.filter { $0.hasPrefix("run-") }.sorted().reversed().map { ($0, base.appendingPathComponent($0)) }
    }

    // MARK: - Load Run

    func loadRun(_ dir: URL) {
        isLive = true
        runId = dir.lastPathComponent

        // Parse fleet.json
        let fleetURL = dir.appendingPathComponent("fleet.json")
        if let data = try? Data(contentsOf: fleetURL),
           let parsed = try? JSONDecoder().decode([String: FleetEntry].self, from: data) {
            fleet = parsed
        }

        // Parse state.json
        let stateURL = dir.appendingPathComponent("state.json")
        if let data = try? Data(contentsOf: stateURL),
           let parsed = try? JSONDecoder().decode(RunState.self, from: data) {
            objective = parsed.objective
            repoPath = parsed.repo_path
            totalTasks = parsed.total_tasks ?? 0
            if let ts = parsed.updated_at { startTime = parseISO8601(ts) }
        }

        refresh()
    }

    // MARK: - Monitoring

    func startMonitoring() {
        isRunning = true
        if startTime == nil { startTime = Date() }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stopMonitoring() { timer?.invalidate(); timer = nil; isRunning = false }
    func refresh() { guard let dir = selectedRunDir else { return }; readFileSystemState(dir) }

    // MARK: - Filesystem IPC Reader

    private func readFileSystemState(_ dir: URL) {
        let fm = FileManager.default
        let claimedDir = dir.appendingPathComponent("claimed")
        let resultsDir = dir.appendingPathComponent("results")
        let queueDir = dir.appendingPathComponent("queue")
        let pidsDir = dir.appendingPathComponent("pids")

        var agentMap: [String: Agent] = [:]

        // Read claimed tasks (working agents)
        if let files = try? fm.contentsOfDirectory(atPath: claimedDir.path) {
            for file in files where file.hasSuffix(".json") {
                let taskId = String(file.dropLast(5))
                if let data = try? Data(contentsOf: claimedDir.appendingPathComponent(file)),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let claimedBy = json["claimed_by"] as? String ?? taskId
                    let title = json["title"] as? String ?? json["task"] as? String ?? taskId
                    let branch = json["branch"] as? String ?? "stampede/\(taskId)"
                    let workerId = claimedBy

                    let agent = Agent(
                        id: taskId, name: taskId, status: .working, task: title,
                        branch: branch, progress: 0.5, tokensUsed: 0, elapsedSeconds: 0,
                        activity: "Working on \(taskId)...", pid: readPid(pidsDir, workerId: workerId),
                        model: fleet[workerId]?.model, workerId: workerId
                    )
                    agentMap[taskId] = agent
                } else {
                    // Plain text fallback
                    let task = (try? String(contentsOf: claimedDir.appendingPathComponent(file), encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? taskId
                    agentMap[taskId] = Agent(
                        id: taskId, name: taskId, status: .working, task: task,
                        branch: "stampede/\(taskId)", progress: 0.5, tokensUsed: 0,
                        elapsedSeconds: 0, activity: "Processing..."
                    )
                }
            }
        }

        // Also support .task files (legacy/alternate format)
        if let files = try? fm.contentsOfDirectory(atPath: claimedDir.path) {
            for file in files where file.hasSuffix(".task") {
                let name = String(file.dropLast(5))
                if agentMap[name] != nil { continue }
                let task = (try? String(contentsOf: claimedDir.appendingPathComponent(file), encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? name
                agentMap[name] = Agent(
                    id: name, name: name, status: .working, task: task,
                    branch: "stampede/\(name)", progress: 0.5, tokensUsed: 0,
                    elapsedSeconds: 0, activity: "Processing..."
                )
            }
        }

        // Read completed results
        var fileTracker: [String: [String]] = [:] // filePath -> [taskId] for conflict detection
        var doneAgents: [Agent] = []
        if let files = try? fm.contentsOfDirectory(atPath: resultsDir.path) {
            for file in files where file.hasSuffix(".json") && !file.hasPrefix(".tmp-") {
                let taskId = String(file.dropLast(5))
                if let data = try? Data(contentsOf: resultsDir.appendingPathComponent(file)),
                   let result = try? JSONDecoder().decode(TaskResult.self, from: data) {
                    let status: AgentStatus = (result.status == "failed") ? .failed : .done
                    let elapsed = elapsedFrom(result.completed_at)
                    let agent = Agent(
                        id: result.task_id ?? taskId, name: result.task_id ?? taskId,
                        status: status, task: result.summary?.components(separatedBy: "\n").first ?? taskId,
                        branch: result.branch ?? "stampede/\(taskId)", progress: status == .done ? 1.0 : 0.0,
                        tokensUsed: (result.word_count ?? 0) * 4, // rough token estimate
                        elapsedSeconds: elapsed,
                        activity: status == .done ? "Completed" : "Failed",
                        model: nil, filesChanged: result.files_changed,
                        summary: result.summary, completedAt: result.completed_at,
                        workerId: result.worker_id
                    )
                    doneAgents.append(agent)

                    // Track files for conflict detection
                    for f in result.files_changed ?? [] {
                        fileTracker[f, default: []].append(result.task_id ?? taskId)
                    }
                }
            }
        }

        // Also count .result files (legacy)
        let legacyResultCount: Int
        if let files = try? fm.contentsOfDirectory(atPath: resultsDir.path) {
            legacyResultCount = files.filter { $0.hasSuffix(".result") }.count
        } else {
            legacyResultCount = 0
        }

        // Count queued tasks
        let queueCount: Int
        if let files = try? fm.contentsOfDirectory(atPath: queueDir.path) {
            queueCount = files.filter { $0.hasSuffix(".json") || $0.hasSuffix(".task") }.count
        } else {
            queueCount = 0
        }

        // Build conflict list
        var newConflicts: [FileConflict] = []
        for (path, ids) in fileTracker where ids.count > 1 {
            newConflicts.append(FileConflict(
                filePath: path, agentIds: ids,
                severity: ids.count > 2 ? .critical : .warning
            ))
        }

        // Merge: working agents first, then done/failed
        let working = Array(agentMap.values).sorted { $0.id < $1.id }
        let completed = doneAgents.sorted { $0.id < $1.id }
        self.agents = working + completed
        self.doneTasks = doneAgents.filter { $0.status == .done }.count + legacyResultCount
        self.totalTasks = max(self.totalTasks, queueCount + working.count + self.doneTasks)
        self.conflicts = newConflicts

        // If nothing is working and queue is empty, we're done
        if working.isEmpty && queueCount == 0 && doneTasks > 0 {
            isRunning = false
        }
    }

    // MARK: - Actions

    func retryAgent(_ agent: Agent) {
        guard agent.status == .failed, let dir = selectedRunDir else { return }
        let fm = FileManager.default
        let resultFile = dir.appendingPathComponent("results/\(agent.id).json")
        let queueFile = dir.appendingPathComponent("queue/\(agent.id).json")
        if fm.fileExists(atPath: resultFile.path) {
            try? fm.moveItem(at: resultFile, to: queueFile)
            refresh()
        }
    }

    func openTerminal() {
        guard let path = repoPath else { return }
        let script = "tell application \"Terminal\" to do script \"cd \(path)\""
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }

    func focusAgent(at index: Int) {
        // Focus is handled by the view layer via selectedAgent binding
        // This just provides a way for commands to trigger it
        NotificationCenter.default.post(name: .stampedeFocusAgent, object: index)
    }

    // MARK: - Helpers

    private func readPid(_ pidsDir: URL, workerId: String) -> Int? {
        let pidFile = pidsDir.appendingPathComponent("\(workerId).pid")
        guard let str = try? String(contentsOf: pidFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        return Int(str)
    }

    private func parseISO8601(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s) ?? {
            let f2 = ISO8601DateFormatter()
            f2.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return f2.date(from: s)
        }()
    }

    private func elapsedFrom(_ completedAt: String?) -> Int {
        guard let ts = completedAt, let completed = parseISO8601(ts), let start = startTime else { return 0 }
        return max(0, Int(completed.timeIntervalSince(start)))
    }

    // MARK: - Demo Data

    func loadDemo() {
        isLive = false; isRunning = true; startTime = Date().addingTimeInterval(-312)
        totalTasks = 8; doneTasks = 1; runId = "demo"
        objective = "Demo Mode — No live Stampede run detected"
        agents = [
            Agent(id: "alpha", name: "alpha", status: .working, task: "Implement JWT auth middleware", branch: "stampede/jwt-auth", progress: 0.67, tokensUsed: 142_300, elapsedSeconds: 245, activity: "Writing auth/middleware.ts", model: "claude-sonnet-4.5"),
            Agent(id: "bravo", name: "bravo", status: .working, task: "Build REST API endpoints", branch: "stampede/api-endpoints", progress: 0.45, tokensUsed: 98_700, elapsedSeconds: 187, activity: "Generating POST /api/users", model: "claude-haiku-4.5"),
            Agent(id: "charlie", name: "charlie", status: .done, task: "Add database migrations", branch: "stampede/db-migrations", progress: 1.0, tokensUsed: 187_400, elapsedSeconds: 312, activity: "All 14 migrations created", model: "claude-haiku-4.5"),
            Agent(id: "delta", name: "delta", status: .working, task: "Create React dashboard", branch: "stampede/react-dashboard", progress: 0.23, tokensUsed: 65_200, elapsedSeconds: 134, activity: "Building AgentStatusGrid", model: "gpt-5.1-codex"),
            Agent(id: "echo", name: "echo", status: .claiming, task: "Set up CI/CD pipeline", branch: "stampede/cicd-pipeline", progress: 0.12, tokensUsed: 31_800, elapsedSeconds: 67, activity: "Analyzing GitHub Actions", model: "claude-haiku-4.5"),
            Agent(id: "foxtrot", name: "foxtrot", status: .working, task: "Write integration tests", branch: "stampede/integration-tests", progress: 0.78, tokensUsed: 156_900, elapsedSeconds: 289, activity: "47/62 tests passing", model: "claude-sonnet-4.5"),
            Agent(id: "golf", name: "golf", status: .failed, task: "Configure Docker compose", branch: "stampede/docker-config", progress: 0.0, tokensUsed: 0, elapsedSeconds: 0, activity: "Port 5432 conflict", model: "claude-haiku-4.5"),
            Agent(id: "hotel", name: "hotel", status: .working, task: "Add WebSocket handlers", branch: "stampede/websocket", progress: 0.56, tokensUsed: 112_400, elapsedSeconds: 198, activity: "Implementing event broadcasting", model: "gpt-5.1-codex"),
        ]
        conflicts = [FileConflict(filePath: "src/config/database.ts", agentIds: ["charlie", "foxtrot"], severity: .warning)]
    }

    static func demo() -> StampedeState {
        let s = StampedeState(demo: true)
        s.loadDemo()
        return s
    }
}

extension Notification.Name {
    static let stampedeFocusAgent = Notification.Name("stampedeFocusAgent")
}

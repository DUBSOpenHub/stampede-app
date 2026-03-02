import Foundation
import Combine

@MainActor
class StampedeState: ObservableObject {
    @Published var agents: [Agent] = []
    @Published var conflicts: [FileConflict] = []
    @Published var totalTasks: Int = 0
    @Published var doneTasks: Int = 0
    @Published var isRunning: Bool = false
    @Published var startTime: Date?
    private var timer: Timer?
    private var stampedeDir: URL

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

    init(directory: String = "/tmp/stampede") { self.stampedeDir = URL(fileURLWithPath: directory) }

    func startMonitoring() {
        isRunning = true; startTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }
    func stopMonitoring() { timer?.invalidate(); timer = nil; isRunning = false }
    func refresh() { readFileSystemState() }

    private func readFileSystemState() {
        let fm = FileManager.default
        let claimedDir = stampedeDir.appendingPathComponent("claimed")
        let resultsDir = stampedeDir.appendingPathComponent("results")
        let queueDir = stampedeDir.appendingPathComponent("queue")
        var updated: [Agent] = []
        if let files = try? fm.contentsOfDirectory(atPath: claimedDir.path) {
            for file in files where file.hasSuffix(".task") {
                let name = String(file.dropLast(5))
                let task = (try? String(contentsOf: claimedDir.appendingPathComponent(file), encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? name
                updated.append(Agent(id: name, name: name, status: .working, task: task, branch: "stampede/\(name)", progress: 0.5, tokensUsed: 0, elapsedSeconds: 0, activity: "Processing..."))
            }
        }
        self.agents = updated
        self.doneTasks = (try? fm.contentsOfDirectory(atPath: resultsDir.path))?.filter { $0.hasSuffix(".result") }.count ?? 0
        let qc = (try? fm.contentsOfDirectory(atPath: queueDir.path))?.filter { $0.hasSuffix(".task") }.count ?? 0
        self.totalTasks = qc + updated.count + doneTasks
    }

    static func demo() -> StampedeState {
        let s = StampedeState(); s.isRunning = true; s.startTime = Date().addingTimeInterval(-312); s.totalTasks = 8; s.doneTasks = 1
        s.agents = [
            Agent(id: "alpha", name: "alpha", status: .working, task: "Implement JWT auth middleware", branch: "stampede/jwt-auth", progress: 0.67, tokensUsed: 142_300, elapsedSeconds: 245, activity: "Writing auth/middleware.ts"),
            Agent(id: "bravo", name: "bravo", status: .working, task: "Build REST API endpoints", branch: "stampede/api-endpoints", progress: 0.45, tokensUsed: 98_700, elapsedSeconds: 187, activity: "Generating POST /api/users"),
            Agent(id: "charlie", name: "charlie", status: .done, task: "Add database migrations", branch: "stampede/db-migrations", progress: 1.0, tokensUsed: 187_400, elapsedSeconds: 312, activity: "All 14 migrations created"),
            Agent(id: "delta", name: "delta", status: .working, task: "Create React dashboard", branch: "stampede/react-dashboard", progress: 0.23, tokensUsed: 65_200, elapsedSeconds: 134, activity: "Building AgentStatusGrid"),
            Agent(id: "echo", name: "echo", status: .claiming, task: "Set up CI/CD pipeline", branch: "stampede/cicd-pipeline", progress: 0.12, tokensUsed: 31_800, elapsedSeconds: 67, activity: "Analyzing GitHub Actions"),
            Agent(id: "foxtrot", name: "foxtrot", status: .working, task: "Write integration tests", branch: "stampede/integration-tests", progress: 0.78, tokensUsed: 156_900, elapsedSeconds: 289, activity: "47/62 tests passing"),
            Agent(id: "golf", name: "golf", status: .failed, task: "Configure Docker compose", branch: "stampede/docker-config", progress: 0.0, tokensUsed: 0, elapsedSeconds: 0, activity: "Port 5432 conflict"),
            Agent(id: "hotel", name: "hotel", status: .working, task: "Add WebSocket handlers", branch: "stampede/websocket", progress: 0.56, tokensUsed: 112_400, elapsedSeconds: 198, activity: "Implementing event broadcasting"),
        ]
        s.conflicts = [FileConflict(filePath: "src/config/database.ts", agentIds: ["charlie", "foxtrot"], severity: .warning)]
        return s
    }
}

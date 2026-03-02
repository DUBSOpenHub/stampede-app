import Foundation
import SwiftUI

enum AgentStatus: String, CaseIterable, Codable {
    case idle, claiming, working, done, failed
    var color: Color {
        switch self {
        case .idle: return StampedeColors.gray
        case .claiming: return StampedeColors.purple
        case .working: return StampedeColors.green
        case .done: return StampedeColors.blue
        case .failed: return StampedeColors.red
        }
    }
    var sfSymbol: String {
        switch self {
        case .idle: return "circle"
        case .claiming: return "circle.dotted"
        case .working: return "arrow.trianglehead.2.clockwise"
        case .done: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }
    var label: String { rawValue.uppercased() }
}

struct Agent: Identifiable, Codable {
    let id: String
    var name: String
    var status: AgentStatus
    var task: String
    var branch: String
    var progress: Double
    var tokensUsed: Int
    var elapsedSeconds: Int
    var activity: String
    var pid: Int?
    var model: String?
    var filesChanged: [String]?
    var summary: String?
    var completedAt: String?
    var workerId: String?

    var formattedTokens: String {
        if tokensUsed >= 1_000_000 { return String(format: "%.1fM", Double(tokensUsed) / 1_000_000) }
        if tokensUsed >= 1_000 { return String(format: "%.1fK", Double(tokensUsed) / 1_000) }
        return "\(tokensUsed)"
    }
    var formattedTime: String {
        let h = elapsedSeconds / 3600, m = (elapsedSeconds % 3600) / 60, s = elapsedSeconds % 60
        if h > 0 { return String(format: "%dh%02dm", h, m) }
        if m > 0 { return String(format: "%dm%02ds", m, s) }
        return "\(s)s"
    }
    var estimatedCost: Double { Double(tokensUsed) / 250_000.0 }
}

// JSON shapes from terminal-stampede filesystem IPC

struct FleetEntry: Codable {
    let model: String
    let slot: Int
}

struct TaskResult: Codable {
    let task_id: String?
    let run_id: String?
    let worker_id: String?
    let status: String?
    let branch: String?
    let files_changed: [String]?
    let summary: String?
    let completed_at: String?
    let word_count: Int?
}

struct RunState: Codable {
    let run_id: String?
    let objective: String?
    let repo_path: String?
    let model: String?
    let worker_count: Int?
    let total_tasks: Int?
    let phase: String?
    let updated_at: String?
}

struct FileConflict: Identifiable {
    let id = UUID()
    var filePath: String
    var agentIds: [String]
    var severity: Severity
    enum Severity: String { case warning, critical
        var color: Color { self == .critical ? StampedeColors.red : StampedeColors.orange }
    }
}

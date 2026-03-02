import SwiftUI

@main
struct StampedeApp: App {
    @StateObject private var state = StampedeState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
                .frame(minWidth: 900, minHeight: 600)
                .background(StampedeColors.bgDeep)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands { StampedeCommands(state: state) }

        MenuBarExtra("Stampede", systemImage: "bolt.fill") {
            MenuBarView().environmentObject(state)
        }.menuBarExtraStyle(.window)

        Settings { PreferencesView().environmentObject(state) }
    }
}

struct StampedeCommands: Commands {
    @ObservedObject var state: StampedeState
    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Refresh") { state.refresh() }.keyboardShortcut("r", modifiers: .command)
            Divider()
            Button("Focus Next Agent") {
                state.focusAgent(at: -1)
            }.keyboardShortcut("]", modifiers: .command)
            Button("Focus Previous Agent") {
                state.focusAgent(at: -2)
            }.keyboardShortcut("[", modifiers: .command)
        }
        CommandMenu("Agents") {
            Button("Show All Agents") {
                state.focusAgent(at: 0)
            }.keyboardShortcut("0", modifiers: .command)
            Divider()
            ForEach(1...9, id: \.self) { i in
                Button("Focus Agent \(i)") {
                    state.focusAgent(at: i)
                }.keyboardShortcut(KeyEquivalent(Character(String(i))), modifiers: .command)
            }
            Divider()
            Button("Retry Failed Agents") {
                for agent in state.agents where agent.status == .failed {
                    state.retryAgent(agent)
                }
            }.keyboardShortcut("r", modifiers: [.command, .shift])
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var state: StampedeState
    @State private var selectedAgent: Agent?
    @State private var showConflicts = false
    @State private var viewMode: ViewMode = .dashboard
    enum ViewMode: String, CaseIterable { case dashboard = "Dashboard", grid = "Grid" }

    var body: some View {
        VStack(spacing: 0) {
            ToolbarView(viewMode: $viewMode)
            HSplitView {
                VStack(spacing: 0) {
                    ProgressBarView()
                    switch viewMode {
                    case .dashboard: DashboardView(selectedAgent: $selectedAgent)
                    case .grid: AgentGridView(selectedAgent: $selectedAgent)
                    }
                }.frame(minWidth: 600)
                if let agent = selectedAgent {
                    AgentDetailView(agent: agent).frame(minWidth: 280, idealWidth: 320, maxWidth: 400)
                }
            }
            if !state.conflicts.isEmpty { ConflictBarView(showDetails: $showConflicts) }
        }
        .background(StampedeColors.bgDeep)
        .onReceive(NotificationCenter.default.publisher(for: .stampedeFocusAgent)) { notif in
            guard let index = notif.object as? Int else { return }
            if index == 0 { selectedAgent = nil }
            else if index > 0 && index <= state.agents.count { selectedAgent = state.agents[index - 1] }
            else if index == -1 { // next
                if let current = selectedAgent, let idx = state.agents.firstIndex(where: { $0.id == current.id }) {
                    selectedAgent = state.agents[(idx + 1) % state.agents.count]
                } else { selectedAgent = state.agents.first }
            } else if index == -2 { // previous
                if let current = selectedAgent, let idx = state.agents.firstIndex(where: { $0.id == current.id }) {
                    selectedAgent = state.agents[(idx - 1 + state.agents.count) % state.agents.count]
                } else { selectedAgent = state.agents.last }
            }
        }
    }
}

struct ToolbarView: View {
    @EnvironmentObject var state: StampedeState
    @Binding var viewMode: ContentView.ViewMode

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Text("⚡").font(.system(size: 16))
                Text("STAMPEDE").font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(StampedeColors.goldBright)
            }
            // LIVE / DEMO badge
            Text(state.isLive ? "LIVE" : "DEMO")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(state.isLive ? StampedeColors.green : StampedeColors.orange)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background((state.isLive ? StampedeColors.green : StampedeColors.orange).opacity(0.15))
                .cornerRadius(3)
            if let runId = state.runId, state.isLive {
                Text(runId).font(.system(size: 10, design: .monospaced)).foregroundColor(StampedeColors.textTertiary)
            }
            Divider().frame(height: 16)
            Picker("View", selection: $viewMode) {
                ForEach(ContentView.ViewMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).frame(width: 200)
            Spacer()
            HStack(spacing: 16) {
                StatPill(icon: "bolt.fill", value: "\(state.activeCount)", color: StampedeColors.green)
                StatPill(icon: "checkmark", value: "\(state.doneCount)", color: StampedeColors.blue)
                if state.failedCount > 0 { StatPill(icon: "xmark", value: "\(state.failedCount)", color: StampedeColors.red) }
                Divider().frame(height: 16)
                Text(state.formattedElapsed).font(.system(size: 12, design: .monospaced)).foregroundColor(StampedeColors.textSecondary)
            }
        }.padding(.horizontal, 16).padding(.vertical, 10).background(StampedeColors.bgSurface)
        .overlay(Rectangle().frame(height: 1).foregroundColor(StampedeColors.border), alignment: .bottom)
    }
}

struct StatPill: View {
    let icon: String; let value: String; let color: Color
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10, weight: .semibold)).foregroundColor(color)
            Text(value).font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundColor(StampedeColors.textPrimary)
        }.padding(.horizontal, 8).padding(.vertical, 3).background(color.opacity(0.1)).cornerRadius(4)
    }
}

struct ProgressBarView: View {
    @EnvironmentObject var state: StampedeState
    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(StampedeColors.border).frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(LinearGradient(colors: [StampedeColors.gold, StampedeColors.green], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * state.overallProgress, height: 6).goldGlow()
                        .animation(.easeInOut(duration: 0.5), value: state.overallProgress)
                }
            }.frame(height: 6)
            HStack {
                Text("\(state.doneTasks)/\(state.totalTasks) tasks").font(.system(size: 12, weight: .medium)).foregroundColor(StampedeColors.textPrimary)
                Text("\(Int(state.overallProgress * 100))%").font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(StampedeColors.gold)
                Spacer()
                Text("\(state.totalTokens / 1000)K tokens").font(.system(size: 11, design: .monospaced)).foregroundColor(StampedeColors.textSecondary)
                Text("$\(String(format: "%.2f", state.totalCost))").font(.system(size: 11, design: .monospaced)).foregroundColor(StampedeColors.textSecondary)
            }
        }.padding(.horizontal, 16).padding(.vertical, 10).background(StampedeColors.bgDeep)
        .overlay(Rectangle().frame(height: 1).foregroundColor(StampedeColors.border), alignment: .bottom)
    }
}

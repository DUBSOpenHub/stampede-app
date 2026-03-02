import SwiftUI

@main
struct StampedeApp: App {
    @StateObject private var state = StampedeState.demo()

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
        .commands { StampedeCommands() }

        MenuBarExtra("Stampede", systemImage: "bolt.fill") {
            MenuBarView().environmentObject(state)
        }.menuBarExtraStyle(.window)

        Settings { PreferencesView().environmentObject(state) }
    }
}

struct StampedeCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Stampede Run…") {}.keyboardShortcut("n", modifiers: [.command, .shift])
            Divider()
            Button("Focus Next Agent") {}.keyboardShortcut("]", modifiers: .command)
            Button("Focus Previous Agent") {}.keyboardShortcut("[", modifiers: .command)
        }
        CommandMenu("Agents") {
            Button("Show All Agents") {}.keyboardShortcut("0", modifiers: .command)
            Divider()
            ForEach(1...9, id: \.self) { i in
                Button("Focus Agent \(i)") {}.keyboardShortcut(KeyEquivalent(Character(String(i))), modifiers: .command)
            }
            Divider()
            Button("Retry Failed Agents") {}.keyboardShortcut("r", modifiers: [.command, .shift])
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
        }.background(StampedeColors.bgDeep)
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

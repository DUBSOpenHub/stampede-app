import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var state: StampedeState
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("⚡"); Text("Terminal Stampede").font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(StampedeColors.goldBright)
                Spacer()
                if state.isLive {
                    PulsingDot(color: StampedeColors.green)
                    Text("LIVE").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(StampedeColors.green)
                } else {
                    Text("DEMO").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(StampedeColors.orange)
                }
            }.padding(.horizontal, 12).padding(.vertical, 10)
            if let runId = state.runId, state.isLive {
                Text(runId).font(.system(size: 10, design: .monospaced)).foregroundColor(StampedeColors.textTertiary).padding(.horizontal, 12)
            }
            Divider()
            HStack(spacing: 16) {
                QuickStat(label: "Active", value: "\(state.activeCount)", color: StampedeColors.green)
                QuickStat(label: "Done", value: "\(state.doneCount)", color: StampedeColors.blue)
                QuickStat(label: "Failed", value: "\(state.failedCount)", color: StampedeColors.red)
            }.padding(.horizontal, 12).padding(.vertical, 8)
            VStack(spacing: 4) {
                GeometryReader { geo in ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(StampedeColors.border)
                    RoundedRectangle(cornerRadius: 2).fill(StampedeColors.gold).frame(width: geo.size.width * state.overallProgress)
                }}.frame(height: 4)
                HStack {
                    Text("\(Int(state.overallProgress * 100))%").font(.system(size: 10)).foregroundColor(StampedeColors.textSecondary)
                    Spacer()
                    Text(state.formattedElapsed).font(.system(size: 10, design: .monospaced)).foregroundColor(StampedeColors.textTertiary)
                }
            }.padding(.horizontal, 12).padding(.bottom, 8)
            Divider()
            ForEach(state.agents) { agent in
                HStack(spacing: 8) {
                    Image(systemName: agent.status.sfSymbol).font(.system(size: 10)).foregroundColor(agent.status.color).frame(width: 14)
                    Text(agent.name).font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundColor(StampedeColors.textPrimary)
                    Spacer()
                    Text("\(Int(agent.progress * 100))%").font(.system(size: 10, design: .monospaced)).foregroundColor(StampedeColors.textSecondary)
                }.padding(.horizontal, 12).padding(.vertical, 4)
            }
            Divider().padding(.top, 4)
            Button(action: { NSApplication.shared.terminate(nil) }) {
                HStack { Text("Quit Stampede").font(.system(size: 12)); Spacer(); Text("⌘Q").font(.system(size: 11)).foregroundColor(StampedeColors.textTertiary) }
                    .padding(.horizontal, 12).padding(.vertical, 6)
            }.buttonStyle(.borderless)
        }.frame(width: 280).background(StampedeColors.bgSurface)
    }
}

struct QuickStat: View {
    let label: String; let value: String; let color: Color
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 18, weight: .bold, design: .monospaced)).foregroundColor(color)
            Text(label).font(.system(size: 9, weight: .medium)).foregroundColor(StampedeColors.textTertiary)
        }.frame(maxWidth: .infinity)
    }
}

struct PulsingDot: View {
    let color: Color; @State private var isPulsing = false
    var body: some View {
        Circle().fill(color).frame(width: 6, height: 6).scaleEffect(isPulsing ? 1.3 : 1.0).opacity(isPulsing ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isPulsing).onAppear { isPulsing = true }
    }
}

struct PreferencesView: View {
    @EnvironmentObject var state: StampedeState
    @AppStorage("stampedeDir") private var stampedeDir = ""
    @AppStorage("refreshRate") private var refreshRate = 1.0
    @AppStorage("maxAgents") private var maxAgents = 8
    @AppStorage("showNotifications") private var showNotifications = true

    var body: some View {
        TabView {
            Form {
                Section("Directory") {
                    TextField("Path (empty = ~/.copilot/stampede)", text: $stampedeDir).font(.system(.body, design: .monospaced))
                    Button("Reconnect") {
                        state.stopMonitoring()
                        if let dir = state.discoverLatestRun() {
                            state.switchToRun(dir)
                        } else {
                            state.loadDemo()
                        }
                    }
                }
                Section("Recent Runs") {
                    ForEach(state.availableRuns(), id: \.id) { run in
                        Button(action: { state.switchToRun(run.url) }) {
                            HStack {
                                Text(run.id).font(.system(size: 11, design: .monospaced))
                                Spacer()
                                if state.runId == run.id {
                                    Image(systemName: "checkmark").foregroundColor(StampedeColors.green)
                                }
                            }
                        }.buttonStyle(.borderless)
                    }
                }
                Section("Agents") {
                    Stepper("Max agents: \(maxAgents)", value: $maxAgents, in: 1...20)
                    Slider(value: $refreshRate, in: 0.5...5.0, step: 0.5) { Text("Refresh: \(refreshRate, specifier: "%.1f")s") }
                }
                Section("Notifications") { Toggle("Show notifications", isOn: $showNotifications) }
            }.tabItem { Label("General", systemImage: "gear") }.padding(20)
            VStack(alignment: .leading, spacing: 12) {
                Text("Keyboard Shortcuts").font(.headline)
                ShortcutRow(keys: "⌘1–9", action: "Focus agent")
                ShortcutRow(keys: "⌘0", action: "Show all agents")
                ShortcutRow(keys: "⌘]", action: "Next agent")
                ShortcutRow(keys: "⌘[", action: "Previous agent")
                ShortcutRow(keys: "⇧⌘R", action: "Retry failed agents")
                ShortcutRow(keys: "⇧⌘N", action: "New stampede run")
                Spacer()
            }.tabItem { Label("Shortcuts", systemImage: "keyboard") }.padding(20)
        }.frame(width: 400, height: 300)
    }
}

struct ShortcutRow: View {
    let keys: String; let action: String
    var body: some View {
        HStack {
            Text(keys).font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundColor(StampedeColors.gold).frame(width: 80, alignment: .trailing)
            Text(action).font(.system(size: 12)).foregroundColor(StampedeColors.textSecondary)
        }
    }
}

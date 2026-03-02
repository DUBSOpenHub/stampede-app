import SwiftUI

struct AgentDetailView: View {
    @EnvironmentObject var state: StampedeState
    let agent: Agent
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: agent.status.sfSymbol).font(.system(size: 18)).foregroundColor(agent.status.color)
                    Text(agent.name.uppercased()).font(.system(size: 18, weight: .bold, design: .monospaced)).foregroundColor(StampedeColors.goldBright)
                }
                HStack(spacing: 8) {
                    Text(agent.status.label).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(agent.status.color)
                        .padding(.horizontal, 8).padding(.vertical, 3).background(agent.status.color.opacity(0.12)).cornerRadius(4)
                    if let model = agent.model {
                        Text(model).font(.system(size: 10, design: .monospaced)).foregroundColor(StampedeColors.textTertiary)
                            .padding(.horizontal, 6).padding(.vertical, 2).background(StampedeColors.bgElevated).cornerRadius(3)
                    }
                }
                Divider().background(StampedeColors.border)
                DetailSection(title: "TASK") { Text(agent.task).font(.system(size: 12)).foregroundColor(StampedeColors.textPrimary) }
                DetailSection(title: "BRANCH") {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.branch").font(.system(size: 10)).foregroundColor(StampedeColors.cyan)
                        Text(agent.branch).font(.system(size: 11, design: .monospaced)).foregroundColor(StampedeColors.cyan)
                    }
                }
                DetailSection(title: "PROGRESS") {
                    VStack(spacing: 6) {
                        GeometryReader { geo in ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3).fill(StampedeColors.border)
                            RoundedRectangle(cornerRadius: 3).fill(agent.status.color).frame(width: geo.size.width * agent.progress)
                        }}.frame(height: 8)
                        Text("\(Int(agent.progress * 100))%").font(.system(size: 20, weight: .bold, design: .monospaced)).foregroundColor(agent.status.color).frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                DetailSection(title: "METRICS") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        MetricBox(label: "TOKENS", value: agent.formattedTokens, color: StampedeColors.gold)
                        MetricBox(label: "TIME", value: agent.formattedTime, color: StampedeColors.blue)
                        MetricBox(label: "COST", value: String(format: "$%.2f", agent.estimatedCost), color: StampedeColors.green)
                        MetricBox(label: "PID", value: agent.pid.map(String.init) ?? "—", color: StampedeColors.gray)
                    }
                }
                if let files = agent.filesChanged, !files.isEmpty {
                    DetailSection(title: "FILES CHANGED (\(files.count))") {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(files, id: \.self) { file in
                                Text(file).font(.system(size: 10, design: .monospaced)).foregroundColor(StampedeColors.cyan)
                            }
                        }.padding(8).frame(maxWidth: .infinity, alignment: .leading).background(StampedeColors.bgElevated).cornerRadius(4)
                    }
                }
                DetailSection(title: agent.summary != nil ? "SUMMARY" : "ACTIVITY") {
                    Text(agent.summary ?? agent.activity).font(.system(size: 11, design: .monospaced)).foregroundColor(StampedeColors.textSecondary)
                        .padding(8).frame(maxWidth: .infinity, alignment: .leading).background(StampedeColors.bgElevated).cornerRadius(4)
                }
                Button(action: { state.openTerminal() }) {
                    HStack { Image(systemName: "terminal"); Text("Open Terminal") }.frame(maxWidth: .infinity)
                }.buttonStyle(.bordered)
                if agent.status == .failed {
                    Button(action: { state.retryAgent(agent) }) {
                        HStack { Image(systemName: "arrow.clockwise"); Text("Retry Agent") }.frame(maxWidth: .infinity)
                    }.buttonStyle(.borderedProminent).tint(StampedeColors.orange)
                }
            }.padding(16)
        }.background(StampedeColors.bgSurface)
        .overlay(Rectangle().frame(width: 1).foregroundColor(StampedeColors.border), alignment: .leading)
    }
}

struct DetailSection<Content: View>: View {
    let title: String; @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(StampedeColors.textTertiary)
            content
        }
    }
}

struct MetricBox: View {
    let label: String; let value: String; let color: Color
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(color)
            Text(label).font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundColor(StampedeColors.textTertiary)
        }.frame(maxWidth: .infinity).padding(.vertical, 8).background(StampedeColors.bgElevated).cornerRadius(4)
    }
}

struct ConflictBarView: View {
    @EnvironmentObject var state: StampedeState
    @Binding var showDetails: Bool
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(StampedeColors.orange).font(.system(size: 12))
            Text("\(state.conflicts.count) conflict\(state.conflicts.count == 1 ? "" : "s")").font(.system(size: 12, weight: .medium)).foregroundColor(StampedeColors.orange)
            if let f = state.conflicts.first { Text("— \(f.filePath)").font(.system(size: 11, design: .monospaced)).foregroundColor(StampedeColors.textSecondary) }
            Spacer()
            Button(action: { showDetails.toggle() }) { Text(showDetails ? "Hide" : "Details").font(.system(size: 11)) }.buttonStyle(.borderless)
        }.padding(.horizontal, 16).padding(.vertical, 8).background(StampedeColors.orange.opacity(0.05))
        .overlay(Rectangle().frame(height: 1).foregroundColor(StampedeColors.orange.opacity(0.3)), alignment: .top)
    }
}

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var state: StampedeState
    @Binding var selectedAgent: Agent?
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                HStack(spacing: 0) {
                    Text("AGENT").frame(width: 80, alignment: .leading)
                    Text("STATUS").frame(width: 80, alignment: .leading)
                    Text("TASK").frame(minWidth: 200, alignment: .leading)
                    Text("PROGRESS").frame(width: 140, alignment: .leading)
                    Text("TOKENS").frame(width: 80, alignment: .trailing)
                    Text("TIME").frame(width: 60, alignment: .trailing)
                }.font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(StampedeColors.textTertiary)
                .padding(.horizontal, 16).padding(.vertical, 6).background(StampedeColors.bgSurface)

                ForEach(state.agents) { agent in
                    AgentRowView(agent: agent, isSelected: selectedAgent?.id == agent.id)
                        .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { selectedAgent = selectedAgent?.id == agent.id ? nil : agent } }
                }
            }
        }.background(StampedeColors.bgDeep)
    }
}

struct AgentRowView: View {
    let agent: Agent; let isSelected: Bool
    @State private var isHovered = false
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: agent.status.sfSymbol).font(.system(size: 11)).foregroundColor(agent.status.color).frame(width: 14)
                    Text(agent.name).font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundColor(StampedeColors.textPrimary)
                }.frame(width: 80, alignment: .leading)
                Text(agent.status.label).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(agent.status.color)
                    .padding(.horizontal, 6).padding(.vertical, 2).background(agent.status.color.opacity(0.12)).cornerRadius(3)
                    .frame(width: 80, alignment: .leading)
                Text(agent.task).font(.system(size: 12)).foregroundColor(StampedeColors.textPrimary).lineLimit(1).frame(minWidth: 200, alignment: .leading)
                HStack(spacing: 6) {
                    GeometryReader { geo in ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2).fill(StampedeColors.border).frame(height: 4)
                        RoundedRectangle(cornerRadius: 2).fill(agent.status.color).frame(width: geo.size.width * agent.progress, height: 4)
                    }}.frame(height: 4)
                    Text("\(Int(agent.progress * 100))%").font(.system(size: 10, design: .monospaced)).foregroundColor(StampedeColors.textSecondary).frame(width: 32, alignment: .trailing)
                }.frame(width: 140)
                Text(agent.formattedTokens).font(.system(size: 11, design: .monospaced)).foregroundColor(StampedeColors.textSecondary).frame(width: 80, alignment: .trailing)
                Text(agent.formattedTime).font(.system(size: 11, design: .monospaced)).foregroundColor(StampedeColors.textSecondary).frame(width: 60, alignment: .trailing)
            }
            Text(agent.activity).font(.system(size: 11, design: .monospaced)).foregroundColor(StampedeColors.textTertiary).lineLimit(1).padding(.leading, 20)
        }.padding(.horizontal, 16).padding(.vertical, 8)
        .background(isSelected ? StampedeColors.gold.opacity(0.08) : isHovered ? StampedeColors.bgHover : Color.clear)
        .overlay(Rectangle().frame(width: 2).foregroundColor(isSelected ? StampedeColors.gold : Color.clear), alignment: .leading)
        .overlay(Rectangle().frame(height: 1).foregroundColor(StampedeColors.border.opacity(0.5)), alignment: .bottom)
        .onHover { isHovered = $0 }
    }
}

struct AgentGridView: View {
    @EnvironmentObject var state: StampedeState
    @Binding var selectedAgent: Agent?
    let columns = [GridItem(.adaptive(minimum: 260, maximum: 400), spacing: 12)]
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(state.agents) { agent in
                    AgentCardView(agent: agent, isSelected: selectedAgent?.id == agent.id)
                        .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { selectedAgent = selectedAgent?.id == agent.id ? nil : agent } }
                }
            }.padding(16)
        }.background(StampedeColors.bgDeep)
    }
}

struct AgentCardView: View {
    let agent: Agent; let isSelected: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: agent.status.sfSymbol).foregroundColor(agent.status.color)
                Text(agent.name).font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(StampedeColors.textPrimary)
                Spacer()
                Text(agent.status.label).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(agent.status.color)
                    .padding(.horizontal, 6).padding(.vertical, 2).background(agent.status.color.opacity(0.12)).cornerRadius(3)
            }
            Text(agent.task).font(.system(size: 12)).foregroundColor(StampedeColors.textPrimary).lineLimit(2)
            VStack(spacing: 4) {
                GeometryReader { geo in ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(StampedeColors.border)
                    RoundedRectangle(cornerRadius: 2).fill(agent.status.color).frame(width: geo.size.width * agent.progress)
                }}.frame(height: 4)
                HStack {
                    Text("\(Int(agent.progress * 100))%").font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundColor(agent.status.color)
                    Spacer()
                    Text(agent.formattedTokens + " tokens").font(.system(size: 10, design: .monospaced)).foregroundColor(StampedeColors.textTertiary)
                }
            }
            Text(agent.activity).font(.system(size: 10, design: .monospaced)).foregroundColor(StampedeColors.textTertiary).lineLimit(1)
        }.padding(12).background(StampedeColors.bgSurface).cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? StampedeColors.gold : StampedeColors.border, lineWidth: isSelected ? 2 : 1))
    }
}

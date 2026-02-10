import SwiftUI

struct HoverButtonStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        HoverButtonLabel(configuration: configuration)
    }
}

private struct HoverButtonLabel: View {
    let configuration: ButtonStyleConfiguration
    @State private var isHovered = false

    var body: some View {
        configuration.label
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(configuration.isPressed ? Color.primary.opacity(0.15) : isHovered ? Color.primary.opacity(0.08) : Color.clear)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .onHover { isHovered = $0 }
    }
}

struct MenuWithHover<MenuContent: View, Label: View>: View {
    @ViewBuilder let content: () -> MenuContent
    @ViewBuilder let label: () -> Label
    @State private var isHovered = false

    var body: some View {
        Menu(content: content, label: label)
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
            )
            .onHover { isHovered = $0 }
    }
}

struct FooterView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack {
            Button {
                appState.showingAddWorkflow = true
            } label: {
                Image(systemName: "plus.circle")
            }
            .help("Add workflow")

            Button {
                Task { await appState.refreshNow() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Refresh now")

            Spacer()
        }
        .buttonStyle(HoverButtonStyle())
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

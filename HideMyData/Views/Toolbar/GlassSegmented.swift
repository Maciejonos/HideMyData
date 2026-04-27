import SwiftUI

struct GlassSegmented<T: Hashable>: View {
    struct Item: Identifiable {
        let value: T
        let image: String
        let label: String
        let help: String
        var id: T { value }
    }

    @Binding var selection: T
    let items: [Item]
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                Segment(
                    item: item,
                    isSelected: selection == item.value,
                    namespace: ns,
                    action: { select(item.value) }
                )
            }
        }
        .padding(3)
        .glassEffect(.regular, in: .capsule)
    }

    private func select(_ value: T) {
        withAnimation(.smooth(duration: 0.28)) {
            selection = value
        }
    }
}

private struct Segment<T: Hashable>: View {
    let item: GlassSegmented<T>.Item
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(item.label, systemImage: item.image)
                .labelStyle(.titleAndIcon)
                .font(.subheadline)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .foregroundStyle(isSelected ? Color.white : Color.secondary)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(Color.accentColor)
                            .shadow(color: Color.accentColor.opacity(0.35), radius: 6, y: 1)
                            .matchedGeometryEffect(id: "selection", in: namespace)
                    }
                }
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .help(item.help)
    }
}

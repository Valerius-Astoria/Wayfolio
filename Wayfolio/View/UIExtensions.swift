//
//  UIExtensions.swift
//  Wayfolio
//
//  Created by ZAKA on 11/24/26.
//

import SwiftUI

extension Image {
    func thumbnailStyle(width: CGFloat = 54, height: CGFloat = 72, cornerRadius: CGFloat = 8) -> some View {
        self
            .resizable()
            .scaledToFill()
            .frame(width: width, height: height)
            .clipShape(.rect(cornerRadius: cornerRadius))
            .accessibilityHidden(true)
    }
}

/// A menu for picking an SF Symbol, labeled with the current one.
struct IconMenu: View {
    @Binding var selection: String
    let choices: [String]

    var body: some View {
        Menu {
            Picker("Icon", selection: $selection) {
                ForEach(choices, id: \.self) { icon in
                    Label(icon, systemImage: icon)
                }
            }
        } label: {
            Image(systemName: selection)
                .frame(width: 24)
        }
        .accessibilityLabel("Icon")
        .accessibilityValue(selection)
    }
}

/// A "+ Add …" row at the end of a list section, shown in edit mode.
struct AddItemButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    init(_ title: LocalizedStringKey, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: "plus.circle.fill")
                .font(.subheadline)
        }
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .moveDisabled(true)
        .deleteDisabled(true)
    }
}

/// A capsule that toggles a filter or option on and off, filled with `color` when selected.
struct ChipToggle: View {
    let title: LocalizedStringKey
    var icon: String?
    var color: Color = .accentColor
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.snappy) { isOn.toggle() }
        } label: {
            // An `HStack` rather than a `Label`: inside a `Form` row, `Label` takes the form's layout,
            // which hides the title and wraps it into a tall, narrow chip.
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .lineLimit(1)
            }
            .fixedSize()
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(isOn ? .white : color)
            .background(isOn ? color : color.opacity(0.12), in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

extension Binding where Value: SetAlgebra {
    /// Whether `element` is in the set. Setting it inserts or removes the element.
    func contains(_ element: Value.Element) -> Binding<Bool> {
        Binding<Bool>(
            get: { wrappedValue.contains(element) },
            set: { isOn in
                if isOn {
                    wrappedValue.insert(element)
                } else {
                    wrappedValue.remove(element)
                }
            }
        )
    }
}

/// Chips that toggle each `AdventureType` on or off.
struct AdventureTypePicker: View {
    @Binding var selection: [AdventureType]

    var body: some View {
        FlowLayout {
            ForEach(AdventureType.allCases, id: \.self) { type in
                ChipToggle(title: LocalizedStringKey(type.label.name), icon: type.label.icon,
                           color: type.label.color, isOn: isSelected(type))
            }
        }
    }

    private func isSelected(_ type: AdventureType) -> Binding<Bool> {
        Binding(
            get: { selection.contains(type) },
            set: { isOn in
                if isOn {
                    selection.append(type)
                    selection.sort()
                } else {
                    selection.removeAll { $0 == type }
                }
            }
        )
    }
}

/// Places its subviews in rows, wrapping to a new row when one is full.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(for: subviews, width: proposal.width ?? .infinity)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(for: subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                                      proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(for subviews: Subviews, width maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let neededWidth = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if neededWidth > maxWidth, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty {
            rows.append(current)
        }
        return rows
    }
}

/// Puts the icon after the title, such as for a tag with a remove mark.
struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.title
            configuration.icon
                .imageScale(.small)
        }
    }
}

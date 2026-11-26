//
//  AdventureActionButton.swift
//  Wayfolio
//
//  Created by ZAKA on 11/26/26.
//

import SwiftUI

/// The button that runs an adventure: Start, Pause, Resume, Check, and Restart.
///
/// Start, Resume, and Pause take a tap. Start and Resume also open the waypoint to go to.
/// Ending the adventure (holding Pause), checking it, and restarting it take a hold of `holdDuration`.
/// While held, a fill sweeps across the button; letting go early drains it back.
struct AdventureActionButton: View {
    static let holdDuration: TimeInterval = 2
    /// Presses shorter than this count as taps, so a tap on Pause doesn't flash the hold fill.
    static let tapThreshold: TimeInterval = 0.3

    @Environment(MapModel.self) private var map
    @Bindable var adventure: Adventure
    /// How far the current hold has filled the button, from `0` to `1`.
    @State private var progress: CGFloat = 0
    @State private var isPressing = false
    /// Whether the current press has lasted past `tapThreshold` and become a hold.
    @State private var isHolding = false
    @State private var holdTask: Task<Void, Never>?

    var body: some View {
        Group {
            if action.hasHold {
                holdButton(for: action)
            } else {
                tapButton(for: action)
            }
        }
        .frame(height: 60)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: isHolding) { _, isHolding in isHolding }
        .sensoryFeedback(.success, trigger: adventure.status)
    }

    // MARK: - Actions

    private enum Action {
        case start, resume, pause, check, restart

        var hasTap: Bool { self == .start || self == .resume || self == .pause }
        var hasHold: Bool { self == .pause || self == .check || self == .restart }
    }

    private var action: Action {
        switch adventure.status {
        case .notStarted: .start
        case .paused: .resume
        case .started:
            adventure.checkedWaypointCount == adventure.waypointCount ? .check : .pause
        case .checked, .ended: .restart
        }
    }

    private func tap(_ action: Action) {
        switch action {
        case .start:
            update { adventure.status = .started }
            adventure.currentWaypoint = adventure.firstWaypoint
            open(adventure.firstWaypoint)
        case .resume:
            update { adventure.status = .started }
            open(adventure.resumeWaypoint)
        case .pause:
            update { adventure.status = .paused }
        case .check, .restart:
            break
        }
    }

    private func hold(_ action: Action) {
        switch action {
        case .pause:
            update { adventure.status = .ended }
        case .check:
            update { adventure.status = .checked }
        case .restart:
            update { adventure.restart() }
            open(adventure.firstWaypoint)
        case .start, .resume:
            break
        }
    }

    /// Applies a status change with the button's spring, and drains the fill.
    private func update(_ change: () -> Void) {
        withAnimation(.spring(duration: 0.5, bounce: 0.3)) {
            change()
            progress = 0
        }
    }

    /// Opens `waypoint` in the sheet and on the map. Does nothing if the adventure has no waypoints.
    private func open(_ waypoint: Waypoint?) {
        guard let waypoint else { return }
        map.showWaypoint(waypoint)
    }

    // MARK: - Tap Button

    private func tapButton(for action: Action) -> some View {
        let style = style(for: action)
        return Button {
            tap(action)
        } label: {
            label(for: action, style: style)
                .foregroundStyle(style.color)
                .glassEffect(.regular.tint(style.color.opacity(0.15)), in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(PressScaleButtonStyle())
    }

    // MARK: - Hold Button

    private func holdButton(for action: Action) -> some View {
        let style = style(for: action)
        let content = label(for: action, style: style)

        return content
            .foregroundStyle(style.color)
            // The filled part is the same label in white on a solid color, revealed from the leading edge.
            .overlay {
                content
                    .foregroundStyle(.white)
                    .background(style.fillColor.gradient)
                    .mask(alignment: .leading) {
                        GeometryReader { proxy in
                            Rectangle().frame(width: proxy.size.width * progress)
                        }
                    }
            }
            .clipShape(.capsule)
            .glassEffect(.regular.tint(style.color.opacity(0.15)), in: .capsule)
            .scaleEffect(isPressing ? 0.96 : 1)
            .animation(.spring(duration: 0.3), value: isPressing)
            .contentShape(.capsule)
            .onLongPressGesture(minimumDuration: Self.holdDuration, maximumDistance: 40) {
                hold(action)
            } onPressingChanged: { pressing in
                pressingChanged(pressing, for: action)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(style.title)
            .accessibilityHint(style.hint ?? "")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                if action.hasTap {
                    tap(action)
                } else {
                    hold(action)
                }
            }
            .accessibilityActions {
                if action.hasTap, let holdTitle = style.holdTitle {
                    Button(holdTitle) { hold(action) }
                }
            }
    }

    /// Starts the fill once a press outlasts `tapThreshold`, and treats shorter presses as taps.
    private func pressingChanged(_ pressing: Bool, for action: Action) {
        isPressing = pressing
        holdTask?.cancel()

        if pressing {
            holdTask = Task {
                try? await Task.sleep(for: .seconds(Self.tapThreshold))
                guard !Task.isCancelled else { return }
                isHolding = true
                // The gesture's clock started at the press, so the fill only has the remaining time.
                withAnimation(.linear(duration: Self.holdDuration - Self.tapThreshold)) { progress = 1 }
            }
        } else {
            if !isHolding, action.hasTap {
                tap(action)
            }
            isHolding = false
            withAnimation(.spring(duration: 0.35)) { progress = 0 }
        }
    }

    private func label(for action: Action, style: ActionStyle) -> some View {
        HStack(spacing: 12) {
            Image(systemName: isHolding ? style.holdIcon : style.icon)
                .font(.title2)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.breathe, isActive: action == .check && !isPressing)
            VStack(alignment: .leading, spacing: 2) {
                Text(style.title)
                    .font(.headline)
                    .contentTransition(.numericText())
                if let hint = isHolding ? "Keep holding…" : style.hint {
                    Text(hint)
                        .font(.caption2)
                        .opacity(0.8)
                        .contentTransition(.opacity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Style

    private struct ActionStyle {
        var title: String
        /// The line under the title, such as "Hold to end".
        var hint: String?
        var icon: String
        /// The icon shown while the button is held.
        var holdIcon: String
        /// The name of the hold action, for VoiceOver, when the button also has a tap.
        var holdTitle: String?
        var color: Color
        /// The color the hold fills the button with.
        var fillColor: Color
    }

    private func style(for action: Action) -> ActionStyle {
        switch action {
        case .start:
            ActionStyle(title: "Start", icon: "play.fill", holdIcon: "play.fill",
                        color: .green, fillColor: .green)
        case .resume:
            ActionStyle(title: "Resume", icon: "play.fill", holdIcon: "play.fill",
                        color: .green, fillColor: .green)
        case .pause:
            ActionStyle(title: "Pause \(adventure.checkedWaypointCount)/\(adventure.waypointCount)",
                        hint: "Hold to end", icon: "pause.fill", holdIcon: "stop.fill",
                        holdTitle: "End Adventure", color: .orange, fillColor: .red)
        case .check:
            ActionStyle(title: "Check", hint: "Hold to check",
                        icon: "checkmark.seal.fill", holdIcon: "checkmark.seal.fill",
                        color: .blue, fillColor: .blue)
        case .restart:
            adventure.status == .checked
                ? ActionStyle(title: "Adventure Checked", hint: "Hold to restart",
                              icon: "checkmark.seal.fill", holdIcon: "arrow.counterclockwise",
                              color: .green, fillColor: .indigo)
                : ActionStyle(title: "Adventure Ended", hint: "Hold to restart",
                              icon: "flag.checkered", holdIcon: "arrow.counterclockwise",
                              color: .gray, fillColor: .indigo)
        }
    }
}

/// Shrinks the label slightly while pressed.
private struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(duration: 0.3), value: configuration.isPressed)
    }
}

#Preview {
    let statuses: [AdventureStatus] = [.notStarted, .started, .paused, .checked, .ended]
    VStack(spacing: 16) {
        ForEach(statuses, id: \.self) { status in
            let adventure = Adventure.createSampleAdventure()
            let _ = adventure.status = status
            AdventureActionButton(adventure: adventure)
        }
    }
    .padding()
    .environment(MapModel())
}

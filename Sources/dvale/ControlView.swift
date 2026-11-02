import SwiftUI

struct ControlView: View {
    @ObservedObject var model: AppModel
    private let accent = Color(red: 0.38, green: 0.36, blue: 0.85)

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header
            displayCard
            VStack(spacing: 15) {
                shortcutRow
                Divider()
                loginRow
            }.font(.system(size: 13))

            if model.competingApp {
                Label("Quit Hide My Bar before testing so the two apps don’t compete.", systemImage: "info.circle")
                    .font(.system(size: 11)).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let error = model.error {
                Text(error).font(.system(size: 11)).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("Software sleep can reduce flicker, but cannot guarantee zero flashes from a faulty panel or during startup and wake. Touch Bar keys, including Escape on older models, may be unavailable while off.")
                .font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Text("Lives in your menu bar").font(.system(size: 10)).foregroundStyle(.tertiary)
                Spacer()
                Button("Quit & Restore") { NSApp.terminate(nil) }.buttonStyle(.link).font(.system(size: 11))
            }
        }
        .padding(28).frame(width: 490)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 26))
                .foregroundStyle(accent)
                .frame(width: 48, height: 48)
                .background(accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 3) {
                Text("dvale").font(.system(size: 24, weight: .semibold))
                Text("A quieter Touch Bar.").foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var displayCard: some View {
        VStack(spacing: 18) {
            touchBarIllustration
            VStack(spacing: 5) {
                Text(!model.available ? "Let’s find your Touch Bar" : model.keepOff ? "Let it rest." : "Quiet is a double-tap away.")
                    .font(.system(size: 21, weight: .medium))
                Text(model.keepOff ? "dvale requests sleep and reapplies it after wake." : "Turn it off here, or tap Command twice.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Button(action: model.toggle) {
                Text(model.keepOff ? "Turn Touch Bar On" : "Turn Touch Bar Off")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 210, height: 30)
            }
            .buttonStyle(.borderedProminent).tint(accent).controlSize(.large)
            .disabled(!model.available)
            Text(!model.available ? "A supported MacBook with a Touch Bar is required." : model.reportsDark ? "macOS reports: display asleep" : "macOS reports: display awake")
                .font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 24)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.primary.opacity(0.07)))
    }

    private var touchBarIllustration: some View {
        ZStack {
            Capsule().fill(Color.black.opacity(0.9)).frame(height: 30)
            if !model.keepOff {
                HStack {
                    Text("esc")
                    Spacer()
                    Image(systemName: "sun.max")
                    Image(systemName: "speaker.wave.2")
                    Image(systemName: "speaker.slash")
                }
                .font(.system(size: 10)).foregroundStyle(.white.opacity(0.75))
                .padding(.horizontal, 15)
            }
        }
        .padding(.horizontal, 20)
        .accessibilityHidden(true)
    }

    private var shortcutRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Double Command").fontWeight(.medium)
                Text(model.shortcutMessage)
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if model.shortcutActive {
                Text("⌘  ⌘").font(.system(size: 18)).foregroundStyle(accent)
            } else {
                Button("Enable…", action: model.enableShortcut).controlSize(.small)
            }
        }
    }

    private var loginRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Start at login").fontWeight(.medium)
                Text("Remembers your last on/off choice")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("Start at login", isOn: Binding(get: { model.launchAtLogin }, set: model.setLaunchAtLogin))
                .labelsHidden().toggleStyle(.switch).tint(accent)
        }
    }
}

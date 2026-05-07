import SwiftUI
import AppKit

struct PreferencesView: View {
    @AppStorage("BentoPanelOpacity") private var opacity: Double = 1.0
    @AppStorage("BentoSoundOnPress") private var soundOnPress: Bool = false

    var body: some View {
        Form {
            Section("Appearance") {
                HStack {
                    Text("Panel transparency")
                        .frame(width: 150, alignment: .leading)
                    Slider(value: $opacity, in: 0.4...1.0, step: 0.05)
                        .onChange(of: opacity) { _, newValue in
                            NotificationCenter.default.post(name: .bentoOpacityChanged, object: newValue)
                        }
                    Text("\(Int(opacity * 100))%")
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 44, alignment: .trailing)
                }

                if opacity < 1.0 {
                    Text("Heads up: when the panel is transparent, you can't drag it by its background — the click passes through to whatever's behind. Use **View → Reset Panel Position** in the menu bar to recenter, or bump opacity back to 100% to move it.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack {
                    Button("Reset Panel Position") {
                        NotificationCenter.default.post(name: .bentoResetPosition, object: nil)
                    }
                    Spacer()
                }
            }

            Section("Behavior") {
                Toggle("Play sound when a tile is pressed", isOn: $soundOnPress)
            }

            Section {
                Text("Other settings (configurable hotkey, dark / light auto-themes, custom accent color) are queued for v0.2.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } header: {
                Text("Coming later")
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 380)
        .padding(.bottom, 4)
    }
}

extension Notification.Name {
    static let bentoOpacityChanged = Notification.Name("bento.opacityChanged")
    static let bentoResetPosition = Notification.Name("bento.resetPosition")
}

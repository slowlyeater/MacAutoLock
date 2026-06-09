import SwiftUI
import UIKit

struct iOSContentView: View {
    @EnvironmentObject private var model: iOSAppModel
    @AppStorage("macAutoLock.language") private var languageCode = InterfaceLanguage.chinese.rawValue
    @AppStorage("macAutoLock.theme") private var themeCode = ThemePreference.system.rawValue
    @State private var isSettingsPresented = false

    private var language: InterfaceLanguage {
        InterfaceLanguage(rawValue: languageCode) ?? .chinese
    }

    private var theme: ThemePreference {
        ThemePreference(rawValue: themeCode) ?? .system
    }

    private var copy: iOSCopy {
        iOSCopy(language: language)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    titleBlock
                    identityCard
                    pairingAction
                    macStatusCard
                    calibrationCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 96)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    settingsMenu
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomTabs
            }
            .preferredColorScheme(theme.colorScheme)
        }
    }

    private var settingsMenu: some View {
        Button {
            isSettingsPresented.toggle()
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 32, height: 32)
                .background(Color.settingsButtonBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsSheet(
                languageCode: $languageCode,
                themeCode: $themeCode,
                copy: copy
            )
            .preferredColorScheme(theme.colorScheme)
            .presentationDetents([.height(260)])
        }
        .accessibilityLabel(copy.settings)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(copy.title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.primary)
            Text(copy.subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var identityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                RoundedIcon(systemName: "iphone", color: .appGreen)
                VStack(alignment: .leading, spacing: 2) {
                    Text(copy.broadcastName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField(copy.broadcastName, text: $model.broadcastName)
                        .font(.subheadline.weight(.semibold))
                        .textInputAutocapitalization(.words)
                        .onChange(of: model.broadcastName) { _, _ in
                            model.refreshBluetoothPayload()
                        }
                }
                Spacer()
                StatusPill(text: shortId, color: .appGreen)
            }

            Divider()

            KeyValueRow(label: copy.bluetooth, value: model.bluetoothStatus, valueColor: .appGreen)
            KeyValueRow(label: copy.codeSource, value: copy.shownOnMac)
            KeyValueRow(
                label: copy.trustedMac,
                value: model.isPairingCodeConfirmed ? copy.waitingForMac : copy.notPaired,
                valueColor: model.isPairingCodeConfirmed ? .appGreen : .appAmber
            )

            VStack(alignment: .leading, spacing: 7) {
                Text(copy.enterCode)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack {
                    TextField("123456", text: Binding(
                        get: { model.pairingCode },
                        set: { model.updatePairingCode($0) }
                    ))
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)

                    Image(systemName: model.isPairingCodeConfirmed ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(model.isPairingCodeConfirmed ? Color.appGreen : Color.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.cardBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(model.isPairingCodeConfirmed ? Color.appGreen : Color.appBorder, lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .cardStyle()
    }

    private var pairingAction: some View {
        Button {
            model.confirmPairing()
        } label: {
            Label(copy.confirmPairing, systemImage: "checkmark")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(model.pairingCode.count != 6)
        .opacity(model.pairingCode.count == 6 ? 1 : 0.5)
    }

    private var macStatusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(copy.macShouldShow)
            HStack(spacing: 12) {
                RoundedIcon(systemName: "display", color: .primary)
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(model.broadcastName.isEmpty ? "iPhone" : model.broadcastName) · \(shortId)")
                        .font(.subheadline.weight(.semibold))
                    Text(copy.codeAndIdMustMatch)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusPill(text: copy.check, color: .appAmber)
            }
        }
        .cardStyle()
    }

    private var calibrationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(copy.calibration)
                .font(.headline)
            Text(copy.calibrationHint)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                SampleChip(text: copy.nearSample)
                SampleChip(text: copy.doorSample)
                SampleChip(text: copy.lostSample)
            }
        }
        .cardStyle()
    }

    private var bottomTabs: some View {
        HStack {
            HStack(spacing: 6) {
                TabItem(systemName: "waveform.path.ecg", title: copy.status, isSelected: false)
                TabItem(systemName: "dot.radiowaves.left.and.right", title: copy.pair, isSelected: true)
                TabItem(systemName: "gearshape", title: copy.rules, isSelected: false)
            }
            .padding(6)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 28)
                    .stroke(Color.appBorder, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 28))
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity)
    }

    private var shortId: String {
        String(model.deviceId.uuidString.prefix(4))
    }
}

private enum InterfaceLanguage: String {
    case chinese
    case english
}

private enum ThemePreference: String {
    case system
    case light
    case dark

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .light:
            .light
        case .dark:
            .dark
        }
    }
}

private struct iOSCopy {
    let language: InterfaceLanguage

    var title: String { language == .chinese ? "配对此 iPhone" : "Pair this iPhone" }
    var subtitle: String { language == .chinese ? "输入 Mac 上显示的配对码，然后确认。" : "Enter the code shown on your Mac, then confirm." }
    var broadcastName: String { language == .chinese ? "广播名称" : "Broadcast name" }
    var bluetooth: String { language == .chinese ? "蓝牙" : "Bluetooth" }
    var codeSource: String { language == .chinese ? "配对码来源" : "Code source" }
    var shownOnMac: String { language == .chinese ? "Mac 显示" : "Shown on Mac" }
    var trustedMac: String { language == .chinese ? "可信 Mac" : "Trusted Mac" }
    var waitingForMac: String { language == .chinese ? "等待 Mac 信任" : "Waiting for Mac" }
    var notPaired: String { language == .chinese ? "未配对" : "Not paired" }
    var enterCode: String { language == .chinese ? "输入配对码" : "Enter pairing code" }
    var confirmPairing: String { language == .chinese ? "确认配对" : "Confirm Pairing" }
    var macShouldShow: String { language == .chinese ? "Mac 端应显示" : "Mac should show" }
    var codeAndIdMustMatch: String { language == .chinese ? "配对码 + ID 必须一致" : "Code + ID must match" }
    var check: String { language == .chinese ? "核对" : "Check" }
    var calibration: String { language == .chinese ? "阈值校准" : "Calibration" }
    var calibrationHint: String { language == .chinese ? "走到离开距离，记录弱信号，再设置 Mac 阈值。" : "Walk away, note weak RSSI, then set the Mac threshold." }
    var nearSample: String { language == .chinese ? "近 -55" : "Near -55" }
    var doorSample: String { language == .chinese ? "远 -72" : "Door -72" }
    var lostSample: String { language == .chinese ? "断开 -91" : "Lost -91" }
    var settings: String { language == .chinese ? "设置" : "Settings" }
    var settingsSubtitle: String { language == .chinese ? "从右上角齿轮打开。" : "Opened from the top-right gear." }
    var languageTitle: String { language == .chinese ? "语言" : "Language" }
    var appearance: String { language == .chinese ? "外观" : "Appearance" }
    var themeSystem: String { language == .chinese ? "跟随系统" : "System" }
    var themeLight: String { language == .chinese ? "浅色" : "Light" }
    var themeDark: String { language == .chinese ? "深色" : "Dark" }
    var status: String { language == .chinese ? "状态" : "Status" }
    var pair: String { language == .chinese ? "配对" : "Pair" }
    var rules: String { language == .chinese ? "规则" : "Rules" }
}

private struct SettingsSheet: View {
    @Binding var languageCode: String
    @Binding var themeCode: String
    var copy: iOSCopy

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(copy.settings)
                        .font(.headline.weight(.bold))
                    Text(copy.settingsSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "gearshape")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 32, height: 32)
                    .background(Color.settingsButtonBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            HStack {
                Text(copy.languageTitle)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Picker("", selection: $languageCode) {
                    Text("中文").tag(InterfaceLanguage.chinese.rawValue)
                    Text("EN").tag(InterfaceLanguage.english.rawValue)
                }
                .pickerStyle(.segmented)
                .frame(width: 118)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(copy.appearance)
                    .font(.subheadline.weight(.semibold))
                Picker("", selection: $themeCode) {
                    Text(copy.themeSystem).tag(ThemePreference.system.rawValue)
                    Text(copy.themeLight).tag(ThemePreference.light.rawValue)
                    Text(copy.themeDark).tag(ThemePreference.dark.rawValue)
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.appBackground)
    }
}

private struct RoundedIcon: View {
    var systemName: String
    var color: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 38, height: 38)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct KeyValueRow: View {
    var label: String
    var value: String
    var valueColor: Color = .primary

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(valueColor)
                .fontWeight(.medium)
        }
        .font(.footnote)
    }
}

private struct StatusPill: View {
    var text: String
    var color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.caption2.weight(.bold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(color.opacity(0.14))
        .clipShape(Capsule())
    }
}

private struct SectionHeader: View {
    var title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}

private struct SampleChip: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct TabItem: View {
    var systemName: String
    var title: String
    var isSelected: Bool

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .medium))
            Text(title)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(isSelected ? Color.appGreen : Color.secondary)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(isSelected ? Color.appGreen.opacity(0.12) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .background(Color.appGreen.opacity(configuration.isPressed ? 0.82 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private extension View {
    func cardStyle() -> some View {
        padding(16)
            .background(Color.cardBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.appBorder, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private extension Color {
    static let appBackground = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.09, green: 0.10, blue: 0.09, alpha: 1)
            : UIColor(red: 0.98, green: 0.98, blue: 0.96, alpha: 1)
    })
    static let cardBackground = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.14, green: 0.15, blue: 0.14, alpha: 1)
            : .white
    })
    static let settingsButtonBackground = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.18, green: 0.19, blue: 0.18, alpha: 1)
            : UIColor(red: 0.95, green: 0.95, blue: 0.93, alpha: 1)
    })
    static let appBorder = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.24, green: 0.26, blue: 0.24, alpha: 1)
            : UIColor(red: 0.84, green: 0.87, blue: 0.84, alpha: 1)
    })
    static let appGreen = Color(red: 0.18, green: 0.49, blue: 0.41)
    static let appAmber = Color(red: 0.71, green: 0.42, blue: 0.09)
}

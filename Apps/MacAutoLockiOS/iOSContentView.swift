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
                VStack(alignment: .leading, spacing: 24) {
                    headerBlock
                    if model.isEnabled {
                        enabledCard
                    } else {
                        pairingCard
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 52)
                .padding(.bottom, 34)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    settingsButton
                }
            }
            .preferredColorScheme(theme.colorScheme)
        }
    }

    private var settingsButton: some View {
        Button {
            isSettingsPresented.toggle()
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .background(Color.settingsButtonBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsSheet(
                languageCode: $languageCode,
                themeCode: $themeCode,
                copy: copy
            )
            .preferredColorScheme(theme.colorScheme)
            .presentationDetents([.height(310)])
        }
        .accessibilityLabel(copy.settings)
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(copy.title)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text(copy.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var pairingCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                RoundedIcon(systemName: "iphone", color: .appGreen)
                VStack(alignment: .leading, spacing: 3) {
                    Text(copy.broadcastName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField(copy.broadcastName, text: $model.broadcastName)
                        .font(.headline.weight(.semibold))
                        .textInputAutocapitalization(.words)
                        .onChange(of: model.broadcastName) { _, _ in
                            model.refreshBluetoothPayload()
                        }
                }
                Spacer()
                StatusPill(text: shortId, color: .appGreen)
            }

            HStack(spacing: 10) {
                PairingCodeBoxes(
                    code: Binding(
                        get: { model.pairingCode },
                        set: { model.updatePairingCode($0) }
                    ),
                    digits: model.pairingCodeDigits,
                    accessibilityLabel: copy.enterCode
                )

                Button(copy.confirmPairing) {
                    model.confirmPairing()
                }
                .buttonStyle(ConfirmButtonStyle())
                .disabled(!model.canConfirmPairing)
                .opacity(model.canConfirmPairing ? 1 : 0.45)
                .frame(width: 88)
            }

            Text(copy.pairingHint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .cardStyle()
    }

    private var enabledCard: some View {
        VStack(spacing: 18) {
            RoundedIcon(systemName: "checkmark.shield.fill", color: .appGreen)
                .frame(maxWidth: .infinity)

            VStack(spacing: 8) {
                Text(copy.enabledTitle)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(copy.enabledSubtitle)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Button(copy.testLock) {
                    model.lockNow()
                }
                .buttonStyle(SecondaryButtonStyle())

                Button(copy.rePair) {
                    model.updatePairingCode("")
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(.vertical, 8)
        .cardStyle()
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

    var title: String { language == .chinese ? "启用自动锁屏" : "Enable Auto-Lock" }
    var subtitle: String { language == .chinese ? "输入 Mac 上显示的 4 位配对码。完成后后台自动工作。" : "Enter the 4-digit code shown on your Mac. It works quietly after pairing." }
    var broadcastName: String { language == .chinese ? "本机蓝牙名称" : "Bluetooth name" }
    var enterCode: String { language == .chinese ? "输入配对码" : "Enter pairing code" }
    var pairingHint: String { language == .chinese ? "Mac 菜单栏弹窗会显示这 4 位数字。确认后，这台 iPhone 会作为可信设备广播。" : "The Mac menu bar popover shows these 4 digits. After confirmation, this iPhone advertises as a trusted device." }
    var confirmPairing: String { language == .chinese ? "确认" : "Confirm" }
    var enabledTitle: String { language == .chinese ? "已启用" : "Enabled" }
    var enabledSubtitle: String { language == .chinese ? "配对完成后无需常开 App。Mac 会在距离变远后自动锁屏。" : "You do not need to keep this app open. Your Mac locks when the iPhone moves away." }
    var testLock: String { language == .chinese ? "测试锁屏" : "Test Lock" }
    var rePair: String { language == .chinese ? "重新配对" : "Re-pair" }
    var settings: String { language == .chinese ? "设置" : "Settings" }
    var settingsSubtitle: String { language == .chinese ? "维护与外观设置。" : "Maintenance and appearance." }
    var languageTitle: String { language == .chinese ? "语言" : "Language" }
    var appearance: String { language == .chinese ? "外观" : "Appearance" }
    var themeSystem: String { language == .chinese ? "跟随系统" : "System" }
    var themeLight: String { language == .chinese ? "浅色" : "Light" }
    var themeDark: String { language == .chinese ? "深色" : "Dark" }
}

private struct SettingsSheet: View {
    @Binding var languageCode: String
    @Binding var themeCode: String
    var copy: iOSCopy

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
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
                    .frame(width: 34, height: 34)
                    .background(Color.settingsButtonBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
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
                .frame(width: 128)
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
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.appBackground)
    }
}

private struct PairingCodeBoxes: View {
    @Binding var code: String
    var digits: [String]
    var accessibilityLabel: String

    var body: some View {
        ZStack {
            HStack(spacing: 8) {
                ForEach(0..<PairingCodeValidator.requiredLength, id: \.self) { index in
                    Text(digits[index].isEmpty ? " " : digits[index])
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.cardBackground)
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(digits[index].isEmpty ? Color.appBorder : Color.appGreen, lineWidth: 1)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }

            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .foregroundStyle(.clear)
                .tint(.clear)
                .background(Color.clear)
                .opacity(0.01)
                .accessibilityLabel(accessibilityLabel)
        }
    }
}

private struct RoundedIcon: View {
    var systemName: String
    var color: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 54, height: 54)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

private struct StatusPill: View {
    var text: String
    var color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(text)
                .font(.caption.weight(.bold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(color.opacity(0.14))
        .clipShape(Capsule())
    }
}

private struct ConfirmButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.appGreen.opacity(configuration.isPressed ? 0.82 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 17))
    }
}

private struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Color.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Color.settingsButtonBackground.opacity(configuration.isPressed ? 0.7 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private extension View {
    func cardStyle() -> some View {
        padding(18)
            .background(Color.cardBackground.opacity(0.78))
            .overlay {
                RoundedRectangle(cornerRadius: 26)
                    .stroke(Color.appBorder, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 26))
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
}

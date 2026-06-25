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
            GeometryReader { proxy in
                let metrics = iPhoneLayoutMetrics(width: proxy.size.width, safeAreaInsets: proxy.safeAreaInsets)

                ScrollView {
                    VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                        headerBlock(metrics)
                        if model.isEnabled {
                            enabledCard(metrics)
                        } else {
                            pairingCard(metrics)
                        }
                    }
                    .frame(maxWidth: metrics.contentMaxWidth, alignment: .leading)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, metrics.horizontalPadding)
                    .padding(.top, metrics.topPadding)
                    .padding(.bottom, metrics.bottomPadding)
                }
                .scrollIndicators(.hidden)
                .background(Color.appBackground.ignoresSafeArea())
            }
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
            .presentationDetents([.medium, .large])
        }
        .accessibilityLabel(copy.settings)
    }

    private func headerBlock(_ metrics: iPhoneLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(copy.title)
                .font(.system(size: metrics.titleFontSize, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text(copy.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func pairingCard(_ metrics: iPhoneLayoutMetrics) -> some View {
        VStack(alignment: .leading, spacing: metrics.cardSpacing) {
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

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    pairingCodeBoxes(metrics)
                        .frame(minWidth: metrics.codeBoxesMinWidth)
                    confirmPairingButton
                        .frame(width: metrics.confirmButtonWidth)
                }

                VStack(spacing: 10) {
                    pairingCodeBoxes(metrics)
                    confirmPairingButton
                }
            }

            Text(copy.pairingHint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .cardStyle(padding: metrics.cardPadding, cornerRadius: metrics.cardCornerRadius)
    }

    private func enabledCard(_ metrics: iPhoneLayoutMetrics) -> some View {
        VStack(spacing: metrics.cardSpacing) {
            RoundedIcon(systemName: "checkmark.shield.fill", color: .appGreen)
                .frame(maxWidth: .infinity)

            VStack(spacing: 8) {
                Text(copy.enabledTitle)
                    .font(.system(size: metrics.enabledTitleFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(copy.enabledSubtitle)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    enabledActions
                }

                VStack(spacing: 10) {
                    enabledActions
                }
            }
        }
        .padding(.vertical, 8)
        .cardStyle(padding: metrics.cardPadding, cornerRadius: metrics.cardCornerRadius)
    }

    private func pairingCodeBoxes(_ metrics: iPhoneLayoutMetrics) -> some View {
        PairingCodeBoxes(
            code: Binding(
                get: { model.pairingCode },
                set: { model.updatePairingCode($0) }
            ),
            digits: model.pairingCodeDigits,
            accessibilityLabel: copy.enterCode,
            boxHeight: metrics.codeBoxHeight,
            boxSpacing: metrics.codeBoxSpacing,
            fontSize: metrics.codeFontSize,
            cornerRadius: metrics.codeBoxCornerRadius
        )
    }

    private var confirmPairingButton: some View {
        Button(copy.confirmPairing) {
            model.confirmPairing()
        }
        .buttonStyle(ConfirmButtonStyle(height: 52))
        .disabled(!model.canConfirmPairing)
        .opacity(model.canConfirmPairing ? 1 : 0.45)
    }

    private var enabledActions: some View {
        Group {
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

private struct iPhoneLayoutMetrics {
    let width: CGFloat
    let safeAreaInsets: EdgeInsets

    var isNarrow: Bool { width < 390 }
    var isWide: Bool { width >= 428 }

    var contentMaxWidth: CGFloat { isWide ? 440 : .infinity }
    var horizontalPadding: CGFloat { isNarrow ? 18 : 24 }
    var topPadding: CGFloat { max(24, safeAreaInsets.top + (isNarrow ? 18 : 28)) }
    var bottomPadding: CGFloat { max(30, safeAreaInsets.bottom + 24) }
    var sectionSpacing: CGFloat { isNarrow ? 18 : 24 }
    var cardPadding: CGFloat { isNarrow ? 16 : 18 }
    var cardSpacing: CGFloat { isNarrow ? 14 : 18 }
    var cardCornerRadius: CGFloat { isNarrow ? 22 : 26 }
    var titleFontSize: CGFloat { isNarrow ? 30 : 34 }
    var enabledTitleFontSize: CGFloat { isNarrow ? 34 : 40 }
    var confirmButtonWidth: CGFloat { isNarrow ? 82 : 92 }
    var codeBoxesMinWidth: CGFloat { isNarrow ? 214 : 224 }
    var codeBoxHeight: CGFloat { isNarrow ? 48 : 52 }
    var codeBoxSpacing: CGFloat { isNarrow ? 6 : 8 }
    var codeFontSize: CGFloat { isNarrow ? 20 : 22 }
    var codeBoxCornerRadius: CGFloat { isNarrow ? 14 : 16 }
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
    var boxHeight: CGFloat
    var boxSpacing: CGFloat
    var fontSize: CGFloat
    var cornerRadius: CGFloat

    var body: some View {
        ZStack {
            HStack(spacing: boxSpacing) {
                ForEach(0..<PairingCodeValidator.requiredLength, id: \.self) { index in
                    Text(digits[index].isEmpty ? " " : digits[index])
                        .font(.system(size: fontSize, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .frame(height: boxHeight)
                        .background(Color.cardBackground)
                        .overlay {
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(digits[index].isEmpty ? Color.appBorder : Color.appGreen, lineWidth: 1)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
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
    var height: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: height)
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
    func cardStyle(padding: CGFloat = 18, cornerRadius: CGFloat = 26) -> some View {
        self.padding(padding)
            .background(Color.cardBackground.opacity(0.78))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.appBorder, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
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

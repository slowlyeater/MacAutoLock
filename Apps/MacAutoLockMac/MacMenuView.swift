#if SWIFT_PACKAGE
import MacAutoLockShared
#endif
import AppKit
import SwiftUI

struct MacMenuView: View {
    @EnvironmentObject private var model: MacAppModel
    @AppStorage("macAutoLock.language") private var languageCode = InterfaceLanguage.chinese.rawValue
    @AppStorage("macAutoLock.theme") private var themeCode = ThemePreference.system.rawValue
    @State private var isSettingsPresented = false

    private var language: InterfaceLanguage {
        InterfaceLanguage(rawValue: languageCode) ?? .chinese
    }

    private var theme: ThemePreference {
        ThemePreference(rawValue: themeCode) ?? .system
    }

    private var copy: MacCopy {
        MacCopy(language: language)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                primaryStatusCard
                if trustedPeers.isEmpty == false {
                    trustedDeviceCard
                }
                thresholdCard
                actionRow
                debugControlsCard
                if model.isDebugMode {
                    scanStatusCard
                    debugDeviceListCard
                    debugLogCard
                }
                if trustedPeers.isEmpty {
                    pairingCodeCard
                    discoveredDevicesCard
                }
            }
            .padding(18)
        }
        .frame(width: 520)
        .frame(maxHeight: 720)
        .background(Color.darkPanel)
        .preferredColorScheme(theme.colorScheme)
    }

    private var header: some View {
        HStack(spacing: 10) {
            RoundedIcon(systemName: "lock.shield", color: .mintText)
            VStack(alignment: .leading, spacing: 2) {
                Text("Mac AutoLock")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.darkText)
                Text(model.lockState == .locked ? copy.lockedSubtitle : copy.unlockedSubtitle)
                    .font(.caption)
                    .foregroundStyle(Color.darkMuted)
            }
            Spacer()
            settingsButton
        }
    }

    private var settingsButton: some View {
        Button {
            isSettingsPresented.toggle()
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.darkMuted)
                .frame(width: 30, height: 30)
                .background(Color.darkCard)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isSettingsPresented, arrowEdge: .top) {
            SettingsPopover(
                languageCode: $languageCode,
                themeCode: $themeCode,
                copy: copy
            )
            .preferredColorScheme(theme.colorScheme)
        }
        .help(copy.settings)
    }

    private var trustedDeviceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(copy.trustedIPhone)
            if let peer = trustedPeers.first {
                DeviceRow(
                    name: peer.deviceName,
                    detail: peerDetail(peer),
                    status: copy.untrust,
                    statusColor: .orangeText,
                    actionTitle: copy.untrust,
                    action: { model.untrust(peer) }
                )
            } else {
                Text(copy.noTrustedDevice)
                    .font(.caption)
                    .foregroundStyle(Color.darkMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.darkCard)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var primaryStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                RoundedIcon(systemName: trustedPeers.isEmpty ? "iphone.slash" : "iphone.radiowaves.left.and.right", color: proximityStatus.color)
                VStack(alignment: .leading, spacing: 4) {
                    Text(primaryTitle)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.darkText)
                    Text(model.autoLockStatus)
                        .font(.caption)
                        .foregroundStyle(Color.darkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                StatusPill(text: proximityStatus.title(copy: copy), color: proximityStatus.color)
            }

            if let peer = trustedPeers.first {
                HStack {
                    SettingRow(label: copy.trustedIPhone, value: peer.deviceName, color: .darkText)
                    Divider()
                        .frame(height: 18)
                    SettingRow(label: "RSSI", value: peer.lastRSSI.map { "\($0) dBm" } ?? "-- dBm", color: proximityStatus.color)
                }
            }
        }
        .panelCard()
    }

    private var thresholdCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(copy.distanceThreshold)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.darkText)
                Spacer()
                Text("\(model.rule.minimumNearbyRSSI) dBm")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.amberText)
            }

            RSSIMeter(
                currentRSSI: trustedPeers.first?.lastRSSI ?? model.lastBluetoothRSSI,
                threshold: model.rule.minimumNearbyRSSI
            )

            Picker("", selection: Binding(
                get: { model.rule.minimumNearbyRSSI },
                set: { model.setMinimumNearbyRSSI($0) }
            )) {
                ForEach([-65, -70, -75, -80, -85, -90], id: \.self) { value in
                    Text("\(value) dBm").tag(value)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Text(copy.near)
                Spacer()
                Text(copy.lockBelow)
                Spacer()
                Text(copy.lost)
            }
            .font(.caption2)
            .foregroundStyle(Color.darkMuted)
        }
        .panelCard()
    }

    private var debugControlsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(copy.debugMode)
            Toggle(copy.debugMode, isOn: Binding(
                get: { model.isDebugMode },
                set: { model.setDebugMode($0) }
            ))
            .toggleStyle(.switch)
            .foregroundStyle(Color.darkText)

            Toggle(copy.dryRun, isOn: Binding(
                get: { model.isDryRun },
                set: { model.setDryRun($0) }
            ))
            .toggleStyle(.switch)
            .foregroundStyle(Color.darkText)

            SettingRow(
                label: copy.autoLock,
                value: model.rule.isAutoLockEnabled ? copy.on : copy.off,
                color: model.rule.isAutoLockEnabled ? .mintText : .orangeText
            )
        }
        .panelCard()
    }

    private var scanStatusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(copy.scanStatus)
            SettingRow(label: copy.bluetoothState, value: model.bluetoothState, color: .darkText)
            SettingRow(label: copy.scanningState, value: model.isScanning ? copy.on : copy.off, color: model.isScanning ? .mintText : .orangeText)
            SettingRow(label: copy.lastScan, value: model.lastScanAt.map(timeAgo) ?? "--", color: .darkText)
            SettingRow(label: copy.trustedCount, value: "\(trustedPeers.count)", color: .darkText)
        }
        .panelCard()
    }

    private var debugDeviceListCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(copy.recentIPhones)
            if model.debugDevices.isEmpty {
                Text(copy.scanning)
                    .font(.caption)
                    .foregroundStyle(Color.darkMuted)
            } else {
                ForEach(model.debugDevices) { device in
                    DebugDeviceRow(device: device, lastSeenText: timeAgo(device.lastSeen))
                }
            }
        }
        .panelCard()
    }

    private var debugLogCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(copy.debugLog)
            if model.logLines.isEmpty {
                Text("--")
                    .font(.caption)
                    .foregroundStyle(Color.darkMuted)
            } else {
                ForEach(Array(model.logLines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Color.darkText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .panelCard()
    }

    private var controlsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingRow(label: copy.autoLock, value: model.rule.isAutoLockEnabled ? copy.on : copy.off, color: .mintText)
            SettingRow(label: copy.weakSignalAction, value: copy.lockImmediately, color: .amberText)
            SettingRow(label: copy.missingFallback, value: "\(Int(model.rule.offlineGraceSeconds)) \(copy.seconds)", color: .darkText)

            Toggle(copy.enableAutoLock, isOn: Binding(
                get: { model.rule.isAutoLockEnabled },
                set: { _ in model.toggleAutoLock() }
            ))
            .toggleStyle(.switch)
            .foregroundStyle(Color.darkText)

            Button {
                model.lockNow()
            } label: {
                Label(copy.lockNow, systemImage: "lock.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .panelCard()
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            Toggle(copy.enableAutoLock, isOn: Binding(
                get: { model.rule.isAutoLockEnabled },
                set: { _ in model.toggleAutoLock() }
            ))
            .toggleStyle(.switch)
            .foregroundStyle(Color.darkText)
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                model.lockNow()
            } label: {
                Label(copy.lockNow, systemImage: "lock.fill")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(14)
        .background(Color.darkCard)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var pairingCodeCard: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(copy.pairingCode)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.darkMuted)
                Text(model.pairingCode)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.darkText)
            }
            Spacer()
            Button {
                model.regeneratePairingCode()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.bordered)
            .help(copy.refreshPairingCode)
        }
        .panelCard()
    }

    private var discoveredDevicesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(copy.discoveredNearby)
            if model.peers.isEmpty {
                Text(copy.scanning)
                    .font(.caption)
                    .foregroundStyle(Color.darkMuted)
            } else {
                ForEach(model.peers) { peer in
                    DeviceRow(
                        name: peer.deviceName,
                        detail: peerDetail(peer),
                        status: peer.isTrusted ? copy.trusted : copy.waitingForCode,
                        statusColor: peer.isTrusted ? .mintText : .darkMuted,
                        actionTitle: peer.isTrusted ? copy.untrust : nil,
                        action: peer.isTrusted ? { model.untrust(peer) } : nil
                    )
                }
            }
        }
    }

    private var decisionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(copy.lastDecision)
            Text(model.autoLockStatus)
                .font(.caption)
                .foregroundStyle(Color.darkText)
            HStack {
                Text(copy.pairingCode)
                    .foregroundStyle(Color.darkMuted)
                Spacer()
                Text(model.pairingCode)
                    .font(.system(.body, design: .monospaced).weight(.bold))
                    .foregroundStyle(Color.darkText)
            }
            .font(.caption)
        }
        .padding(12)
        .background(Color.black.opacity(0.24))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.darkBorder, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var trustedPeers: [PeerState] {
        model.peers.filter(\.isTrusted)
    }

    private var primaryTitle: String {
        guard let peer = trustedPeers.first else {
            return copy.waitingForPairing
        }
        return peer.lastRSSI.map { $0 >= model.rule.minimumNearbyRSSI ? copy.autoLockReady : copy.lockingOnWeakSignal } ?? copy.autoLockReady
    }

    private var proximityStatus: ProximityStatus {
        guard let peer = trustedPeers.first else {
            return .unknown
        }
        guard let rssi = peer.lastRSSI else {
            return .unknown
        }
        return rssi >= model.rule.minimumNearbyRSSI ? .nearby : .weak
    }

    private func peerDetail(_ peer: PeerState) -> String {
        let rssi = peer.lastRSSI.map { "\($0) dBm" } ?? "-- dBm"
        let shortId = peer.id.uuidString.prefix(4)
        return "\(shortId) · \(rssi)"
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = max(0, Int(Date().timeIntervalSince(date)))
        if seconds < 60 { return "\(seconds)s ago" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        return "\(minutes / 60)h ago"
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

private enum ProximityStatus {
    case nearby
    case weak
    case unknown

    var color: Color {
        switch self {
        case .nearby:
            .mintText
        case .weak:
            .orangeText
        case .unknown:
            .darkMuted
        }
    }

    func title(copy: MacCopy) -> String {
        switch self {
        case .nearby:
            copy.nearbyStatus
        case .weak:
            copy.weakStatus
        case .unknown:
            copy.unknownStatus
        }
    }
}

private struct MacCopy {
    let language: InterfaceLanguage

    var unlockedSubtitle: String { language == .chinese ? "未锁定 · 等待可信 iPhone" : "Unlocked · waiting for trusted iPhone" }
    var lockedSubtitle: String { language == .chinese ? "已锁定" : "Locked" }
    var trustedIPhone: String { language == .chinese ? "可信 iPhone" : "Trusted iPhone" }
    var noTrustedDevice: String { language == .chinese ? "先在 iPhone 输入 Mac 配对码并确认。" : "Enter and confirm the Mac pairing code on iPhone first." }
    var distanceThreshold: String { language == .chinese ? "距离阈值" : "Distance threshold" }
    var near: String { language == .chinese ? "近 -45" : "near -45" }
    var lockBelow: String { language == .chinese ? "低于阈值锁屏" : "lock below threshold" }
    var lost: String { language == .chinese ? "丢失 -95" : "lost -95" }
    var autoLock: String { language == .chinese ? "自动锁屏" : "Auto lock" }
    var on: String { language == .chinese ? "开启" : "On" }
    var off: String { language == .chinese ? "关闭" : "Off" }
    var weakSignalAction: String { language == .chinese ? "弱信号动作" : "Weak signal action" }
    var lockImmediately: String { language == .chinese ? "立即锁屏" : "Lock immediately" }
    var missingFallback: String { language == .chinese ? "丢失兜底" : "Missing fallback" }
    var seconds: String { language == .chinese ? "秒" : "sec" }
    var enableAutoLock: String { language == .chinese ? "启用自动锁屏" : "Enable auto lock" }
    var lockNow: String { language == .chinese ? "立即锁定 Mac" : "Lock Mac Now" }
    var settings: String { language == .chinese ? "设置" : "Settings" }
    var settingsSubtitle: String { language == .chinese ? "从右上角齿轮打开。" : "Opened from the top-right gear." }
    var languageTitle: String { language == .chinese ? "语言" : "Language" }
    var themeTitle: String { language == .chinese ? "外观" : "Appearance" }
    var themeSystem: String { language == .chinese ? "跟随系统" : "System" }
    var themeLight: String { language == .chinese ? "浅色" : "Light" }
    var themeDark: String { language == .chinese ? "深色" : "Dark" }
    var discoveredNearby: String { language == .chinese ? "附近发现" : "Discovered nearby" }
    var scanning: String { language == .chinese ? "正在扫描附近 iPhone。" : "Scanning for nearby iPhone." }
    var trusted: String { language == .chinese ? "已信任" : "Trusted" }
    var trust: String { language == .chinese ? "信任" : "Trust" }
    var untrust: String { language == .chinese ? "解除" : "Unpair" }
    var waitingForCode: String { language == .chinese ? "等待配对码" : "Waiting for code" }
    var lastDecision: String { language == .chinese ? "上次判定" : "Last decision" }
    var pairingCode: String { language == .chinese ? "Mac 配对码" : "Mac pairing code" }
    var nearbyStatus: String { language == .chinese ? "附近" : "Nearby" }
    var weakStatus: String { language == .chinese ? "信号弱" : "Weak" }
    var unknownStatus: String { language == .chinese ? "未知" : "Unknown" }
    var waitingForPairing: String { language == .chinese ? "等待配对 iPhone" : "Waiting for iPhone" }
    var autoLockReady: String { language == .chinese ? "自动锁屏已就绪" : "Auto-Lock Ready" }
    var lockingOnWeakSignal: String { language == .chinese ? "信号低于阈值" : "Below Threshold" }
    var refreshPairingCode: String { language == .chinese ? "刷新配对码" : "Refresh pairing code" }
    var debugMode: String { language == .chinese ? "调试模式" : "Debug Mode" }
    var dryRun: String { language == .chinese ? "Dry Run（不真实锁屏）" : "Dry Run (no real lock)" }
    var scanStatus: String { language == .chinese ? "扫描状态" : "Scan Status" }
    var bluetoothState: String { language == .chinese ? "Bluetooth state" : "Bluetooth state" }
    var scanningState: String { language == .chinese ? "Scanning" : "Scanning" }
    var lastScan: String { language == .chinese ? "最近扫描" : "Last scan" }
    var trustedCount: String { language == .chinese ? "可信设备数量" : "Trusted devices" }
    var recentIPhones: String { language == .chinese ? "最近发现的 iPhone" : "Recent iPhones" }
    var debugLog: String { language == .chinese ? "BLE / Lock 日志" : "BLE / Lock Log" }
}

private struct SettingsPopover: View {
    @Binding var languageCode: String
    @Binding var themeCode: String
    var copy: MacCopy

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(copy.settings)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.darkText)
                    Text(copy.settingsSubtitle)
                        .font(.caption)
                        .foregroundStyle(Color.darkMuted)
                }
                Spacer()
                Image(systemName: "gearshape")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.darkText)
                    .frame(width: 32, height: 32)
                    .background(Color.settingsButtonBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            HStack {
                Text(copy.languageTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.darkText)
                Spacer()
                Picker("", selection: $languageCode) {
                    Text("中文").tag(InterfaceLanguage.chinese.rawValue)
                    Text("EN").tag(InterfaceLanguage.english.rawValue)
                }
                .pickerStyle(.segmented)
                .frame(width: 118)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(copy.themeTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.darkText)
                Picker("", selection: $themeCode) {
                    Text(copy.themeSystem).tag(ThemePreference.system.rawValue)
                    Text(copy.themeLight).tag(ThemePreference.light.rawValue)
                    Text(copy.themeDark).tag(ThemePreference.dark.rawValue)
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(16)
        .frame(width: 390)
        .background(Color.darkCard)
    }
}

private struct RoundedIcon: View {
    var systemName: String
    var color: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 36, height: 36)
            .background(Color.darkCard)
            .clipShape(RoundedRectangle(cornerRadius: 8))
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
        .background(color.opacity(0.18))
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
            .foregroundStyle(Color.darkMuted)
    }
}

private struct SettingRow: View {
    var label: String
    var value: String
    var color: Color

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(Color.darkMuted)
            Spacer()
            Text(value)
                .foregroundStyle(color)
                .fontWeight(.semibold)
        }
        .font(.caption)
    }
}

private struct DeviceRow: View {
    var name: String
    var detail: String
    var status: String
    var statusColor: Color
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            RoundedIcon(systemName: "iphone", color: .darkText)
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.darkText)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Color.darkMuted)
            }
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            } else {
                StatusPill(text: status, color: statusColor)
            }
        }
        .padding(12)
        .background(Color.darkCard)
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.darkBorder, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct DebugDeviceRow: View {
    var device: MacDebugDeviceState
    var lastSeenText: String

    private var statusColor: Color {
        switch device.status {
        case "near":
            .mintText
        case "wouldLock":
            .amberText
        case "weak", "missing":
            .orangeText
        default:
            .darkMuted
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                RoundedIcon(systemName: "iphone.radiowaves.left.and.right", color: statusColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.deviceName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.darkText)
                    Text(device.shortDeviceId)
                        .font(.caption2.monospaced())
                        .foregroundStyle(Color.darkMuted)
                }
                Spacer()
                StatusPill(text: device.status, color: statusColor)
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 5) {
                GridRow {
                    DebugMetric(label: "raw", value: "\(device.rawRSSI)")
                    DebugMetric(label: "smooth", value: "\(device.smoothedRSSI)")
                    DebugMetric(label: "threshold", value: "\(device.threshold)")
                }
                GridRow {
                    DebugMetric(label: "lastSeen", value: lastSeenText)
                    DebugMetric(label: "trusted", value: device.isTrusted ? "true" : "false")
                    DebugMetric(label: "state", value: device.status)
                }
            }
        }
        .padding(12)
        .background(Color.darkCard)
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.darkBorder, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct DebugMetric: View {
    var label: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.darkMuted)
            Text(value)
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(Color.darkText)
                .lineLimit(1)
        }
        .frame(minWidth: 96, alignment: .leading)
    }
}

private struct RSSIMeter: View {
    var currentRSSI: Int?
    var threshold: Int

    private var markerOffset: CGFloat {
        let rssi = currentRSSI ?? -95
        let clamped = min(-45, max(-95, rssi))
        let progress = CGFloat(clamped + 95) / 50
        return progress
    }

    private var thresholdOffset: CGFloat {
        CGFloat(min(-45, max(-95, threshold)) + 95) / 50
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.darkBorder)
                    .frame(height: 10)
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.appGreen)
                    .frame(width: width * thresholdOffset, height: 10)
                Rectangle()
                    .fill(Color.amberText)
                    .frame(width: 3, height: 24)
                    .offset(x: width * thresholdOffset)
                Circle()
                    .fill(currentRSSI.map { $0 >= threshold ? Color.mintText : Color.orangeText } ?? Color.darkMuted)
                    .frame(width: 24, height: 24)
                    .overlay(Circle().stroke(Color.darkPanel, lineWidth: 3))
                    .offset(x: max(0, min(width - 24, width * markerOffset - 12)))
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: 34)
    }
}

private extension View {
    func panelCard() -> some View {
        padding(14)
            .background(Color.darkCard)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.darkBorder, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private extension Color {
    static let darkPanel = adaptiveColor(
        light: NSColor(calibratedRed: 0.98, green: 0.98, blue: 0.96, alpha: 1),
        dark: NSColor(calibratedRed: 0.09, green: 0.10, blue: 0.09, alpha: 1)
    )
    static let darkCard = adaptiveColor(
        light: NSColor(calibratedRed: 1.00, green: 1.00, blue: 1.00, alpha: 1),
        dark: NSColor(calibratedRed: 0.14, green: 0.15, blue: 0.14, alpha: 1)
    )
    static let darkBorder = adaptiveColor(
        light: NSColor(calibratedRed: 0.84, green: 0.87, blue: 0.84, alpha: 1),
        dark: NSColor(calibratedRed: 0.20, green: 0.23, blue: 0.21, alpha: 1)
    )
    static let darkText = adaptiveColor(
        light: NSColor(calibratedRed: 0.08, green: 0.09, blue: 0.08, alpha: 1),
        dark: NSColor(calibratedRed: 0.96, green: 0.97, blue: 0.95, alpha: 1)
    )
    static let darkMuted = adaptiveColor(
        light: NSColor(calibratedRed: 0.42, green: 0.45, blue: 0.43, alpha: 1),
        dark: NSColor(calibratedRed: 0.66, green: 0.69, blue: 0.67, alpha: 1)
    )
    static let mintText = Color(red: 0.55, green: 0.86, blue: 0.69)
    static let orangeText = Color(red: 1.00, green: 0.61, blue: 0.48)
    static let amberText = Color(red: 0.94, green: 0.78, blue: 0.51)
    static let appGreen = Color(red: 0.18, green: 0.49, blue: 0.41)
    static let settingsButtonBackground = adaptiveColor(
        light: NSColor(calibratedRed: 0.95, green: 0.95, blue: 0.93, alpha: 1),
        dark: NSColor(calibratedRed: 0.18, green: 0.19, blue: 0.18, alpha: 1)
    )

    private static func adaptiveColor(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [.darkAqua, .aqua])
            return match == .darkAqua ? dark : light
        })
    }
}

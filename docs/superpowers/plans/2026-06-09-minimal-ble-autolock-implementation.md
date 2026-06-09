# Minimal BLE Auto-Lock Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the approved minimal Mac+iPhone BLE auto-lock path: 4-digit pairing, quiet iPhone enabled UI, menu-bar-only Mac UI, RSSI smoothing, and immediate lock when distance crosses threshold.

**Architecture:** The Mac remains the decision maker and scanner. The iPhone advertises a stable BLE identity payload with an optional 4-digit pairing code and lock request ID. Shared code owns pairing validation and RSSI smoothing so both app models and unit tests use the same rules.

**Tech Stack:** Swift 6.3.2, SwiftUI, CoreBluetooth, Swift Testing, Xcode project generated from `project.yml`.

---

## File Structure

- Modify `Sources/MacAutoLockShared/BluetoothPresence.swift`
  - Add shared pairing-code validation and normalize identity payload handling.
- Create `Sources/MacAutoLockShared/RSSISmoother.swift`
  - Small testable helper for smoothing BLE RSSI samples.
- Modify `Sources/MacAutoLockShared/AutoLockEngine.swift`
  - Keep decisions simple, but use smoothed RSSI values supplied by `PeerState.lastRSSI`.
- Modify `Sources/MacAutoLockShared/Models.swift`
  - Keep `PeerState.lastRSSI` as the current effective/smoothed RSSI. Add no new persistence-heavy model unless required.
- Modify `Tests/MacAutoLockSharedTests/AutoLockEngineTests.swift`
  - Add threshold and missing-device regression coverage.
- Create `Tests/MacAutoLockSharedTests/PairingCodeTests.swift`
  - Cover 4-digit generation and validation.
- Create `Tests/MacAutoLockSharedTests/RSSISmootherTests.swift`
  - Cover stable smoothing and spike dampening.
- Modify `Apps/MacAutoLockiOS/iOSAppModel.swift`
  - Change pairing input to 4 digits and expose a minimal paired/unpaired state.
- Replace most of `Apps/MacAutoLockiOS/iOSContentView.swift`
  - Remove bottom tabs and dashboard sections. Implement first-run pairing, enabled state, settings sheet, and 4 boxes.
- Modify `Apps/MacAutoLockMac/MacAppModel.swift`
  - Generate 4-digit pairing codes, use `RSSISmoother`, and keep lock-trigger behavior immediate.
- Replace most of `Apps/MacAutoLockMac/MacMenuView.swift`
  - Make the popover minimal and move diagnostics into calibration/settings.
- Modify `README.md`
  - Update 6-digit pairing references to 4-digit and mark Watch as deferred.

---

### Task 1: Shared 4-Digit Pairing Utilities

**Files:**
- Modify: `Sources/MacAutoLockShared/BluetoothPresence.swift`
- Create: `Tests/MacAutoLockSharedTests/PairingCodeTests.swift`
- Modify: `Tests/MacAutoLockSharedTests/CommandCodecTests.swift`

- [ ] **Step 1: Write failing pairing-code tests**

Create `Tests/MacAutoLockSharedTests/PairingCodeTests.swift`:

```swift
import Foundation
import Testing
@testable import MacAutoLockShared

@Test
func pairingCodeAcceptsExactlyFourDigits() {
    #expect(PairingCodeValidator.normalized("1234") == "1234")
    #expect(PairingCodeValidator.normalized(" 9876 ") == "9876")
}

@Test
func pairingCodeRejectsNonFourDigitInputs() {
    #expect(PairingCodeValidator.normalized("123") == nil)
    #expect(PairingCodeValidator.normalized("12345") == nil)
    #expect(PairingCodeValidator.normalized("12A4") == nil)
    #expect(PairingCodeValidator.normalized("") == nil)
}

@Test
func generatedPairingCodeIsFourDigits() {
    for _ in 0..<50 {
        let code = PairingCodeValidator.generate()
        #expect(code.count == 4)
        #expect(PairingCodeValidator.normalized(code) == code)
    }
}
```

Update `Tests/MacAutoLockSharedTests/CommandCodecTests.swift` so the sample command uses `pairingCode: "1234"` instead of `"123456"`.

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
swift test --filter PairingCode
```

Expected: fails because `PairingCodeValidator` does not exist.

- [ ] **Step 3: Add pairing utility**

Append this to `Sources/MacAutoLockShared/BluetoothPresence.swift`:

```swift
public enum PairingCodeValidator {
    public static let requiredLength = 4

    public static func normalized(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == requiredLength else { return nil }
        guard trimmed.allSatisfy(\.isNumber) else { return nil }
        return trimmed
    }

    public static func digitsOnlyPrefix(_ value: String) -> String {
        String(value.filter(\.isNumber).prefix(requiredLength))
    }

    public static func generate() -> String {
        String(format: "%04d", Int.random(in: 0...9_999))
    }
}
```

- [ ] **Step 4: Run tests and verify pass**

Run:

```bash
swift test --filter PairingCode
swift test
```

Expected: all package tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/MacAutoLockShared/BluetoothPresence.swift Tests/MacAutoLockSharedTests/PairingCodeTests.swift Tests/MacAutoLockSharedTests/CommandCodecTests.swift
git commit -m "feat: add four digit pairing validation"
```

---

### Task 2: RSSI Smoothing Helper And Decision Tests

**Files:**
- Create: `Sources/MacAutoLockShared/RSSISmoother.swift`
- Create: `Tests/MacAutoLockSharedTests/RSSISmootherTests.swift`
- Modify: `Tests/MacAutoLockSharedTests/AutoLockEngineTests.swift`

- [ ] **Step 1: Write failing RSSI smoother tests**

Create `Tests/MacAutoLockSharedTests/RSSISmootherTests.swift`:

```swift
import Testing
@testable import MacAutoLockShared

@Test
func rssiSmootherStartsWithFirstSample() {
    var smoother = RSSISmoother()
    #expect(smoother.addSample(-60) == -60)
    #expect(smoother.current == -60)
}

@Test
func rssiSmootherDampensSingleWeakSpike() {
    var smoother = RSSISmoother()
    _ = smoother.addSample(-60)
    _ = smoother.addSample(-62)
    let smoothed = smoother.addSample(-95)

    #expect(smoothed > -95)
    #expect(smoothed >= -78)
}

@Test
func rssiSmootherEventuallyFollowsSustainedWeakSignal() {
    var smoother = RSSISmoother()
    _ = smoother.addSample(-60)
    _ = smoother.addSample(-88)
    _ = smoother.addSample(-88)
    _ = smoother.addSample(-88)
    let smoothed = smoother.addSample(-88)

    #expect(smoothed <= -78)
}
```

- [ ] **Step 2: Add decision regression test**

Append to `Tests/MacAutoLockSharedTests/AutoLockEngineTests.swift`:

```swift
@Test
func autoLockStaysUnlockedForSmoothedNearbyRSSI() {
    let engine = AutoLockEngine()
    let now = Date(timeIntervalSince1970: 100)
    let rule = AutoLockRule(offlineGraceSeconds: 45, minimumNearbyRSSI: -78)
    let peer = PeerState(
        deviceName: "Eric iPhone",
        role: .iphone,
        lastHeartbeat: now,
        lastNearbyHeartbeat: now,
        lastRSSI: -72,
        isConnected: true,
        isTrusted: true
    )

    let decision = engine.evaluate(rule: rule, trustedPeers: [peer], now: now)

    #expect(decision.shouldLock == false)
}

@Test
func autoLockLocksForSmoothedWeakRSSI() {
    let engine = AutoLockEngine()
    let now = Date(timeIntervalSince1970: 100)
    let rule = AutoLockRule(offlineGraceSeconds: 45, minimumNearbyRSSI: -78)
    let peer = PeerState(
        deviceName: "Eric iPhone",
        role: .iphone,
        lastHeartbeat: now,
        lastNearbyHeartbeat: now.addingTimeInterval(-20),
        lastRSSI: -84,
        isConnected: false,
        isTrusted: true
    )

    let decision = engine.evaluate(rule: rule, trustedPeers: [peer], now: now)

    #expect(decision.shouldLock == true)
}
```

- [ ] **Step 3: Run tests and verify failure**

Run:

```bash
swift test --filter RSSISmoother
```

Expected: fails because `RSSISmoother` does not exist.

- [ ] **Step 4: Implement RSSI smoother**

Create `Sources/MacAutoLockShared/RSSISmoother.swift`:

```swift
import Foundation

public struct RSSISmoother: Equatable, Sendable {
    public private(set) var current: Int?
    public var alpha: Double

    public init(current: Int? = nil, alpha: Double = 0.35) {
        self.current = current
        self.alpha = alpha
    }

    public mutating func addSample(_ sample: Int) -> Int {
        guard let current else {
            self.current = sample
            return sample
        }

        let blended = (Double(sample) * alpha) + (Double(current) * (1 - alpha))
        let rounded = Int(blended.rounded())
        self.current = rounded
        return rounded
    }

    public mutating func reset() {
        current = nil
    }
}
```

- [ ] **Step 5: Run tests and verify pass**

Run:

```bash
swift test --filter RSSISmoother
swift test --filter AutoLockEngine
swift test
```

Expected: all package tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/MacAutoLockShared/RSSISmoother.swift Tests/MacAutoLockSharedTests/RSSISmootherTests.swift Tests/MacAutoLockSharedTests/AutoLockEngineTests.swift
git commit -m "feat: add rssi smoothing"
```

---

### Task 3: iPhone Model Uses 4 Digits And Minimal Pairing State

**Files:**
- Modify: `Apps/MacAutoLockiOS/iOSAppModel.swift`

- [ ] **Step 1: Update model state**

In `Apps/MacAutoLockiOS/iOSAppModel.swift`, keep `isPairingCodeConfirmed`, but add public derived properties:

```swift
var pairingCodeDigits: [String] {
    let digits = Array(pairingCode)
    return (0..<PairingCodeValidator.requiredLength).map { index in
        index < digits.count ? String(digits[index]) : ""
    }
}

var canConfirmPairing: Bool {
    PairingCodeValidator.normalized(pairingCode) != nil
}

var isEnabled: Bool {
    isPairingCodeConfirmed
}
```

- [ ] **Step 2: Change input length and confirm behavior**

Replace `updatePairingCode(_:)` and `confirmPairing()` with:

```swift
func updatePairingCode(_ code: String) {
    pairingCode = PairingCodeValidator.digitsOnlyPrefix(code)
    isPairingCodeConfirmed = false
    refreshBluetoothPayload()
}

func confirmPairing() {
    guard PairingCodeValidator.normalized(pairingCode) != nil else { return }
    isPairingCodeConfirmed = true
    refreshBluetoothPayload()
}
```

- [ ] **Step 3: Change BLE payload pairing check**

In `bluetoothPayload()`, replace the `trimmedPairingCode.count == 6` logic with:

```swift
let normalizedPairingCode = PairingCodeValidator.normalized(trimmedPairingCode)
return BluetoothIdentityPayload(
    deviceId: deviceId,
    deviceName: broadcastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? UIDevice.current.name : broadcastName,
    role: .iphone,
    pairingCode: isPairingCodeConfirmed ? normalizedPairingCode : nil,
    lockRequestId: lastLockRequestId
)
```

- [ ] **Step 4: Build iOS target**

Run:

```bash
xcodebuild -project MacAutoLock.xcodeproj -scheme MacAutoLockiOS -configuration Debug -destination 'generic/platform=iOS' build
```

Expected: build succeeds.

- [ ] **Step 5: Commit**

```bash
git add Apps/MacAutoLockiOS/iOSAppModel.swift
git commit -m "feat: use four digit iphone pairing"
```

---

### Task 4: Minimal iPhone UI With Four Code Boxes

**Files:**
- Modify: `Apps/MacAutoLockiOS/iOSContentView.swift`

- [ ] **Step 1: Remove bottom navigation and dashboard cards**

Delete these old sections from `body`:

```swift
titleBlock
identityCard
pairingAction
macStatusCard
calibrationCard
```

Remove:

```swift
.safeAreaInset(edge: .bottom) {
    bottomTabs
}
```

Delete `bottomTabs`, `TabItem`, `macStatusCard`, and `calibrationCard`.

- [ ] **Step 2: Add minimal screen routing**

Inside the scroll content, render:

```swift
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
```

- [ ] **Step 3: Add header copy**

Change `iOSCopy` title/subtitle values to:

```swift
var title: String { language == .chinese ? "启用自动锁屏" : "Enable Auto-Lock" }
var subtitle: String { language == .chinese ? "输入 Mac 上显示的 4 位配对码。完成后后台自动工作。" : "Enter the 4-digit code shown on your Mac. It works quietly after pairing." }
var enabledTitle: String { language == .chinese ? "已启用" : "Enabled" }
var enabledSubtitle: String { language == .chinese ? "配对完成后无需常开 App。Mac 会在距离变远后自动锁屏。" : "You do not need to keep this app open. Your Mac locks when the iPhone moves away." }
var testLock: String { language == .chinese ? "测试锁屏" : "Test Lock" }
var rePair: String { language == .chinese ? "重新配对" : "Re-pair" }
```

- [ ] **Step 4: Add four-box pairing input view**

Add this view in `iOSContentView.swift`:

```swift
private struct PairingCodeBoxes: View {
    @Binding var code: String
    var digits: [String]

    var body: some View {
        ZStack {
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .foregroundStyle(.clear)
                .tint(.clear)
                .frame(width: 1, height: 1)
                .accessibilityLabel("Pairing code")

            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { index in
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
        }
    }
}
```

- [ ] **Step 5: Use four-box input and confirm button**

In `pairingCard`, use:

```swift
HStack(spacing: 10) {
    PairingCodeBoxes(
        code: Binding(
            get: { model.pairingCode },
            set: { model.updatePairingCode($0) }
        ),
        digits: model.pairingCodeDigits
    )

    Button(copy.confirmPairing) {
        model.confirmPairing()
    }
    .buttonStyle(PrimaryButtonStyle())
    .disabled(!model.canConfirmPairing)
    .opacity(model.canConfirmPairing ? 1 : 0.45)
    .frame(width: 88)
}
```

- [ ] **Step 6: Add enabled card actions**

In `enabledCard`, wire actions:

```swift
Button(copy.testLock) {
    model.lockNow()
}
.buttonStyle(SecondaryButtonStyle())

Button(copy.rePair) {
    model.updatePairingCode("")
}
.buttonStyle(SecondaryButtonStyle())
```

Then add a simple `SecondaryButtonStyle`:

```swift
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
```

- [ ] **Step 7: Build iOS target**

Run:

```bash
xcodebuild -project MacAutoLock.xcodeproj -scheme MacAutoLockiOS -configuration Debug -destination 'generic/platform=iOS' build
```

Expected: build succeeds and no layout-related compile errors remain.

- [ ] **Step 8: Commit**

```bash
git add Apps/MacAutoLockiOS/iOSContentView.swift
git commit -m "feat: simplify iphone pairing ui"
```

---

### Task 5: Mac Model Uses 4-Digit Pairing And Smoothed RSSI

**Files:**
- Modify: `Apps/MacAutoLockMac/MacAppModel.swift`

- [ ] **Step 1: Replace Mac-local pairing generator**

Remove the private `PairingCode` enum at the bottom of `MacAppModel.swift`.

Change:

```swift
@Published var pairingCode = "123456"
```

to:

```swift
@Published var pairingCode = PairingCodeValidator.generate()
```

Change `regeneratePairingCode()` to:

```swift
func regeneratePairingCode() {
    pairingCode = PairingCodeValidator.generate()
    appendLog("Pairing code refreshed.")
}
```

- [ ] **Step 2: Add RSSI smoother state**

Add:

```swift
private var rssiSmoothers: [UUID: RSSISmoother] = [:]
```

- [ ] **Step 3: Smooth RSSI in BLE presence handler**

At the top of `handleBluetoothPresence(_:)`, replace:

```swift
lastBluetoothRSSI = event.rssi
let isNearby = event.rssi >= rule.minimumNearbyRSSI
```

with:

```swift
var smoother = rssiSmoothers[event.deviceId] ?? RSSISmoother()
let smoothedRSSI = smoother.addSample(event.rssi)
rssiSmoothers[event.deviceId] = smoother
lastBluetoothRSSI = smoothedRSSI
let isNearby = smoothedRSSI >= rule.minimumNearbyRSSI
```

Use `smoothedRSSI` everywhere the peer stores/display RSSI:

```swift
lastRSSI: smoothedRSSI
```

and:

```swift
bluetoothStatus = isNearby ? "Bluetooth nearby, RSSI \(smoothedRSSI)" : "Bluetooth weak, RSSI \(smoothedRSSI)"
```

- [ ] **Step 4: Keep lock immediate but one-shot per away event**

Retain the existing `didAutoLockForCurrentAway` behavior. Confirm this still resets when a trusted peer reports `lastRSSI >= rule.minimumNearbyRSSI`.

- [ ] **Step 5: Build Mac target**

Run:

```bash
xcodebuild -project MacAutoLock.xcodeproj -scheme MacAutoLockMac -configuration Debug -destination 'platform=macOS' build
```

Expected: build succeeds.

- [ ] **Step 6: Commit**

```bash
git add Apps/MacAutoLockMac/MacAppModel.swift
git commit -m "feat: smooth mac bluetooth rssi"
```

---

### Task 6: Minimal Mac Menu Bar Popover

**Files:**
- Modify: `Apps/MacAutoLockMac/MacMenuView.swift`

- [ ] **Step 1: Simplify body**

Replace the body content with:

```swift
VStack(alignment: .leading, spacing: 14) {
    header
    primaryStatusCard
    actionRow
    if trustedPeers.isEmpty {
        pairingCodeCard
        discoveredDevicesCard
    }
}
.padding(18)
.frame(width: 420)
.background(Color.darkPanel)
.preferredColorScheme(theme.colorScheme)
```

- [ ] **Step 2: Move gear to upper-right**

Keep `settingsButton` in the trailing side of `header`. The header should show title, state subtitle, spacer, status pill, and gear.

- [ ] **Step 3: Add primary status card**

Add:

```swift
private var primaryStatusCard: some View {
    VStack(alignment: .leading, spacing: 10) {
        if let peer = trustedPeers.first {
            DeviceRow(
                name: peer.deviceName,
                detail: peerDetail(peer),
                status: proximityStatus.title(copy: copy),
                statusColor: proximityStatus.color,
                actionTitle: nil,
                action: nil
            )
            Text(model.autoLockStatus)
                .font(.caption)
                .foregroundStyle(Color.darkMuted)
        } else {
            Text(copy.noTrustedDevice)
                .font(.caption)
                .foregroundStyle(Color.darkMuted)
        }
    }
    .panelCard()
}
```

- [ ] **Step 4: Add simple action row**

Add:

```swift
private var actionRow: some View {
    HStack(spacing: 10) {
        Button {
            model.lockNow()
        } label: {
            Label(copy.lockNow, systemImage: "lock.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)

        Button {
            model.regeneratePairingCode()
        } label: {
            Label(copy.calibrate, systemImage: "dot.radiowaves.left.and.right")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }
}
```

Add `calibrate` to `MacCopy`:

```swift
var calibrate: String { language == .chinese ? "校准距离" : "Calibrate" }
```

- [ ] **Step 5: Add 4-digit pairing code card**

Add:

```swift
private var pairingCodeCard: some View {
    VStack(alignment: .leading, spacing: 8) {
        SectionHeader(copy.pairingCode)
        Text(model.pairingCode)
            .font(.system(size: 30, weight: .bold, design: .monospaced))
            .foregroundStyle(Color.darkText)
            .tracking(8)
        Text(copy.enterThisCode)
            .font(.caption)
            .foregroundStyle(Color.darkMuted)
    }
    .panelCard()
}
```

Add copy:

```swift
var enterThisCode: String { language == .chinese ? "在 iPhone 上输入这 4 位数字。" : "Enter these 4 digits on your iPhone." }
```

- [ ] **Step 6: Build Mac target**

Run:

```bash
xcodebuild -project MacAutoLock.xcodeproj -scheme MacAutoLockMac -configuration Debug -destination 'platform=macOS' build
```

Expected: build succeeds.

- [ ] **Step 7: Commit**

```bash
git add Apps/MacAutoLockMac/MacMenuView.swift
git commit -m "feat: simplify mac menu popover"
```

---

### Task 7: README And Project Verification

**Files:**
- Modify: `README.md`
- Modify: `docs/superpowers/plans/2026-06-09-minimal-ble-autolock-implementation.md` only if execution notes are needed.

- [ ] **Step 1: Update README pairing section**

Replace the current pairing section with:

```markdown
## Pairing

1. Run the Mac menu bar app.
2. Open the menu bar popover and note the 4-digit Bluetooth pairing code.
3. Run the iPhone app.
4. Enter the 4-digit code in the four code boxes and tap Confirm.
5. After pairing, the iPhone app can stay quiet while the Mac scans BLE RSSI and locks when the trusted iPhone moves away.
```

Add a note under Targets:

```markdown
Apple Watch support exists in the project scaffold but is deferred until the Mac+iPhone BLE auto-lock path is reliable on real devices.
```

- [ ] **Step 2: Run package tests**

Run:

```bash
swift test
```

Expected: all tests pass.

- [ ] **Step 3: Build Mac target**

Run:

```bash
xcodebuild -project MacAutoLock.xcodeproj -scheme MacAutoLockMac -configuration Debug -destination 'platform=macOS' build
```

Expected: build succeeds.

- [ ] **Step 4: Build iOS target**

Run:

```bash
xcodebuild -project MacAutoLock.xcodeproj -scheme MacAutoLockiOS -configuration Debug -destination 'generic/platform=iOS' build
```

Expected: build succeeds.

- [ ] **Step 5: Commit and push**

```bash
git add README.md
git commit -m "docs: update minimal autolock workflow"
git push
```

Expected: GitHub repo `slowlyeater/MacAutoLock` receives all commits.

---

## Self-Review

- Spec coverage:
  - 4-digit pairing: Tasks 1, 3, 4, 5, 6, 7.
  - Minimal iPhone UI and no bottom tabs: Task 4.
  - Menu-bar-only Mac UI: Task 6.
  - RSSI smoothing and immediate lock: Tasks 2 and 5.
  - Bluetooth identity and trusted pairing: Tasks 1, 3, 5.
  - README update and Watch deferred note: Task 7.
- Placeholder scan:
  - No placeholder instructions are present.
- Type consistency:
  - `PairingCodeValidator` is introduced in Task 1 and used in Tasks 3 and 5.
  - `RSSISmoother` is introduced in Task 2 and used in Task 5.
  - `PairingCodeBoxes` consumes `model.pairingCodeDigits`, introduced in Task 3.

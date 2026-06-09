# Mac AutoLock Minimal BLE Auto-Lock Design

Date: 2026-06-09

## Summary

Mac AutoLock is a small native Apple-platform utility whose main job is to lock the Mac when a trusted iPhone moves far enough away over Bluetooth. The product should not feel like a status dashboard that the user checks every day. The iPhone app is mainly a first-run pairing tool; after pairing, it should stay quiet while the Mac menu bar app performs the continuous Bluetooth scan and lock decision.

This redesign narrows the MVP to reliable Mac+iPhone BLE auto-lock. Apple Watch support remains out of scope for this pass. Automatic unlock remains out of scope because the app must not store, transmit, type, or bypass the Mac password.

## Goals

- Pair one trusted iPhone with one Mac using a simple 4-digit pairing code.
- Keep the iPhone UI minimal: pair once, show that auto-lock is enabled, and expose only test/re-pair/settings actions.
- Keep the Mac UI menu-bar only: no standalone Mac window for the MVP.
- Prioritize Bluetooth stability, RSSI smoothing, distance calibration, and immediate lock when the trusted iPhone crosses the configured weak-signal threshold.
- Make failures diagnosable during testing without making diagnostics the everyday UI.

## Non-Goals

- No always-visible iPhone status dashboard.
- No bottom tab navigation such as Status, Pair, Rules.
- No countdown before locking. When the lock condition is met, the Mac locks immediately.
- No full automatic unlock path.
- No Apple Watch behavior in this implementation pass.
- No App Store or TestFlight flow.

## User Experience

### iPhone First Run

The iPhone app opens to a single pairing screen:

- Title: Enable Auto-Lock / 启用自动锁屏, localized.
- Shows the iPhone Bluetooth broadcast name and short device ID, such as `AC49`.
- Shows a 4-cell pairing code input instead of a normal text field.
- Uses the numeric keyboard.
- Advances focus automatically as digits are typed.
- Deletes backward naturally.
- Enables the Confirm button only when all 4 digits are present.

The pairing code is shown on the Mac menu bar popover. The iPhone user types the 4 digits and taps Confirm.

### iPhone Paired State

After successful pairing, the iPhone app switches to a quiet enabled state:

- Large enabled status: `已启用`.
- Short explanation: pairing is complete and the Mac will auto-lock when the iPhone moves away.
- Primary utility actions:
  - Test Lock / 测试锁屏
  - Re-pair / 重新配对
- A gear button opens settings.

There is no bottom navigation. The user should not need to keep this screen open in daily use.

### iPhone Settings

Settings are hidden behind the gear button. They contain maintenance and testing controls only:

- Appearance: system, light, dark.
- Re-pair trusted Mac.
- Reset local pairing.
- Calibration/testing entry.
- Bluetooth permission recovery prompt when permission is denied.

Settings are not a rules dashboard. The default path is pair once and leave the app alone.

### Mac Menu Bar Popover

The Mac app remains a menu bar app. The popover shows the operational minimum:

- Auto-lock enabled/disabled state.
- Trusted iPhone name and short ID.
- Current RSSI when available.
- Pairing code when not paired.
- Immediate Lock button.
- Calibrate Distance button.
- Gear/settings button in the upper-right.

Detailed diagnostics are available from calibration/settings, not on the main daily surface.

## BLE Pairing And Identity

The BLE payload must make nearby devices identifiable without requiring a long UI:

- Device role: iPhone.
- User-facing broadcast name, ideally based on `UIDevice.current.name`.
- Short device ID, such as 4 hexadecimal characters.
- Pairing code claim during first pairing.
- Stable local pairing identifier after trust is established.

The pairing code changes from the previous 6-digit design to a 4-digit numeric code. This is enough for local, user-confirmed, same-room pairing and keeps first-run friction low.

The Mac must not trust control messages only because a device name matches. Trust is established by matching the 4-digit code and then saving the trusted local identity.

## Auto-Lock Logic

The Mac is the decision maker. The iPhone advertises; the Mac scans.

The lock decision uses:

- Trusted device match.
- Current RSSI.
- A smoothed RSSI value to avoid one-sample spikes.
- A weak-signal threshold configured by calibration.
- A missing-device timeout for complete disappearance.

When the smoothed trusted-device RSSI crosses below the threshold, the Mac locks immediately. When the trusted device disappears completely, the Mac also locks after a short missing-device grace period to avoid reacting to one missed scan.

No countdown UI is shown.

## Calibration

Calibration exists to make real-world testing practical:

- Near sample: user keeps the iPhone near the Mac and records typical RSSI.
- Away sample: user walks to the desired lock distance and records typical RSSI.
- Suggested threshold is derived from those samples.
- The user can accept the suggested threshold.

Calibration can show diagnostic values because it is a testing workflow. The normal iPhone screen and normal Mac popover should stay simple.

## Visual Direction

Use a restrained, native Apple style:

- iPhone screen adapts to iPhone 14 Pro Max and smaller iPhones.
- No centered white app card with large black unused areas.
- Respect Dynamic Island/status bar and bottom safe area.
- Use Liquid Glass APIs where available on newer OS versions.
- Fall back to SwiftUI material backgrounds and light system-like surfaces on older targets.
- Keep text short and localized.
- Use 4 fixed-size code boxes for the pairing code.

The visual companion approved direction is `simple-autolock-style-v4-codeboxes.html`.

## Localization

The app should support Chinese and English. User-facing strings must not mix languages inside the same locale. In Chinese mode, avoid English phrases like `Bluetooth advertising`; use clear Chinese strings such as `蓝牙广播已开启`.

Appearance labels should use Apple-like terms:

- 跟随系统
- 浅色
- 深色

## Testing Requirements

### Unit Tests

- 4-digit pairing code validation.
- Pairing payload encode/decode.
- Trusted identity match and mismatch.
- RSSI smoothing.
- Lock decision when RSSI crosses the weak threshold.
- Missing-device grace behavior.
- Auto-lock disabled behavior.

### Device Tests

- iPhone 14 Pro Max layout fits without clipping, black dead space, or bottom overlap.
- iPhone can enter a 4-digit code with numeric keyboard and confirm pairing.
- Mac menu bar popover shows a 4-digit code before pairing.
- Mac identifies the iPhone by broadcast name and short ID.
- Mac trusts the iPhone after correct pairing.
- Mac keeps scanning when the iPhone app is in the expected test state.
- Moving the iPhone away beyond the calibrated threshold locks the Mac.
- Bluetooth permission denied states show recoverable prompts.

### Manual Bluetooth Stability Test

The main acceptance test is physical:

1. Start the Mac menu bar app.
2. Pair the iPhone using the 4-digit code.
3. Calibrate near and away RSSI.
4. Keep the iPhone near the Mac and confirm the Mac does not lock.
5. Walk away past the threshold and confirm the Mac locks without a countdown.
6. Repeat several times to check RSSI stability and false positives.

## Implementation Scope

This spec should be implemented in a focused Mac+iPhone pass:

- Update shared pairing models for 4-digit codes.
- Update iPhone UI to the minimal first-run/paired/settings structure.
- Update Mac menu bar popover to the minimal paired/unpaired/calibration structure.
- Update BLE scanner/advertiser flow around stable identity and RSSI threshold behavior.
- Update tests around pairing and auto-lock decisions.

Watch support and automatic unlock research should wait until this Mac+iPhone BLE auto-lock path works reliably on real devices.

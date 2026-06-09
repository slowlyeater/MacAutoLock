# Mac AutoLock

Mac AutoLock is a native Apple-platform MVP for locking a Mac when a trusted iPhone stops being visible over Bluetooth.

## Targets

- `MacAutoLockMac`: macOS menu bar app. Scans BLE for a paired iPhone and locks the Mac when the trusted device leaves.
- `MacAutoLockiOS`: iPhone app. Advertises a BLE identity payload with an optional Mac pairing code and lock request.
- `MacAutoLockWatch`: Apple Watch app. Sends quick lock requests to the iPhone, which updates the BLE payload.
- `MacAutoLockShared`: shared protocol models, command codec, and auto-lock decision engine.

## Local development

```sh
swift test
xcodegen generate
open MacAutoLock.xcodeproj
```

The BLE service UUID is `B6F4AB9A-FA8B-4D1F-A578-4DBF4660882B`.

## Pairing

1. Run the Mac menu bar app.
2. Open the menu bar panel and copy the 6-digit Bluetooth pairing code.
3. Run the iPhone app and enter that code.
4. Keep the iPhone app open while testing; the Mac will mark the iPhone trusted after reading the BLE payload.

## Security boundary

This MVP does not store, transmit, or type the Mac password. Unlock research mode only sends an `unlockProbe` style signal and intentionally falls back to user-visible confirmation or standard macOS unlock behavior.

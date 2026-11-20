# Local changes vs flutter_bluetooth_serial 0.4.0 (pub.dev)

This copy is vendored because the app depends on Android-side changes that the
published package does not have. Re-apply them if the package is ever replaced.

- `BluetoothConnection.connect`: tries raw RFCOMM channel 1 (reflection), then
  secure SDP, then insecure SDP. Upstream only tries secure SDP, which many cheap
  ELM327 clones reject. Worst case is three blocking connects, so Dart callers
  must allow for a long native connect (see `ObdService`).
- `ensurePermissions`: API 31+ checks BLUETOOTH_CONNECT (plus BLUETOOTH_SCAN for
  discovery); API <= 30 asks for location only for discovery. Upstream demanded
  location for the bonded list on every Android version. The permission result
  handler requires every requested permission to be granted.
- Discovery `ACTION_FOUND`: falls back to `EXTRA_NAME` when `getName()` is null.

import 'dart:ffi';

/// The processor architecture this build is running on, as the release assets
/// and the runtime manifest spell it.
String? hostArchitecture() {
  return Abi.current().toString().toLowerCase().contains('arm64')
      ? 'arm64'
      : 'x64';
}

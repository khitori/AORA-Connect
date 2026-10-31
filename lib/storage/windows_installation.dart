// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:ffi';
import 'dart:io';

class WindowsInstallation {
  static final Directory root = _resolve();

  static Directory _resolve() {
    if (!Platform.isWindows) {
      throw UnsupportedError('Windows installation storage is required.');
    }
    final ole = DynamicLibrary.open('ole32.dll');
    final allocate = ole
        .lookupFunction<
          Pointer<Void> Function(IntPtr),
          Pointer<Void> Function(int)
        >('CoTaskMemAlloc');
    final free = ole
        .lookupFunction<
          Void Function(Pointer<Void>),
          void Function(Pointer<Void>)
        >('CoTaskMemFree');
    final folder = DynamicLibrary.open('shell32.dll')
        .lookupFunction<
          Int32 Function(
            Pointer<Void>,
            Uint32,
            Pointer<Void>,
            Pointer<Pointer<Uint16>>,
          ),
          int Function(
            Pointer<Void>,
            int,
            Pointer<Void>,
            Pointer<Pointer<Uint16>>,
          )
        >('SHGetKnownFolderPath');
    final guid = allocate(16);
    final output = allocate(sizeOf<IntPtr>()).cast<Pointer<Uint16>>();
    if (guid == nullptr || output == nullptr) {
      if (guid != nullptr) free(guid);
      if (output != nullptr) free(output.cast());
      throw StateError('Could not allocate Windows folder query.');
    }
    output.value = nullptr;
    try {
      guid.cast<Uint8>().asTypedList(16).setAll(0, const [
        0xb6,
        0x63,
        0x5e,
        0x90,
        0xbf,
        0xc1,
        0x4e,
        0x49,
        0xb2,
        0x9c,
        0x65,
        0xb7,
        0x32,
        0xd3,
        0xd2,
        0x1a,
      ]);
      final result = folder(guid, 0, nullptr, output);
      if (result < 0 || output.value == nullptr) {
        throw StateError('Could not locate Windows Program Files ($result).');
      }
      var length = 0;
      while (length < 32768 && output.value[length] != 0) {
        length++;
      }
      if (length == 0 || length == 32768) {
        throw StateError('Windows returned an invalid Program Files path.');
      }
      return Directory(
        '${String.fromCharCodes(output.value.asTypedList(length))}/AORAConnect',
      );
    } finally {
      if (output.value != nullptr) free(output.value.cast());
      free(output.cast());
      free(guid);
    }
  }
}

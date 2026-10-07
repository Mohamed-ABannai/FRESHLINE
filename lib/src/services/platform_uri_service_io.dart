import 'dart:io';

Future<bool> launchExternalUriImpl(Uri uri) async {
  try {
    if (Platform.isWindows) {
      await Process.run('cmd', <String>['/c', 'start', '', uri.toString()]);
      return true;
    }
    if (Platform.isMacOS) {
      await Process.run('open', <String>[uri.toString()]);
      return true;
    }
    if (Platform.isLinux) {
      await Process.run('xdg-open', <String>[uri.toString()]);
      return true;
    }
  } catch (_) {
    return false;
  }

  return false;
}

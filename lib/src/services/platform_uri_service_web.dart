// ignore_for_file: deprecated_member_use

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<bool> launchExternalUriImpl(Uri uri) async {
  html.window.open(uri.toString(), '_blank');
  return true;
}

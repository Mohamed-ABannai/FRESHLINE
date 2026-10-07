import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

const Duration freshlineRequestTimeout = Duration(seconds: 20);

Future<http.Response> performFreshlineHttpRequest(
  Future<http.Response> Function() request, {
  required String fallback,
  Duration timeout = freshlineRequestTimeout,
}) async {
  try {
    return await request().timeout(timeout);
  } on TimeoutException {
    throw StateError(
      'Freshline timed out while waiting for the server. Please try again.',
    );
  } on SocketException {
    throw StateError(
      'No internet connection. Check your internet and try again.',
    );
  } on http.ClientException catch (error) {
    final String message = error.message.toLowerCase();
    if (message.contains('connection') ||
        message.contains('socket') ||
        message.contains('network') ||
        message.contains('host') ||
        message.contains('timed out')) {
      throw StateError(
        'No internet connection. Check your internet and try again.',
      );
    }
    throw StateError(fallback);
  }
}

String? freshlineTransientHttpErrorMessage(int statusCode) {
  switch (statusCode) {
    case 408:
    case 504:
      return 'Freshline timed out while waiting for the server. Please try again.';
    case 502:
    case 503:
      return 'Freshline could not reach the server right now. Please try again in a moment.';
    default:
      return null;
  }
}

import 'dart:io';
import 'dart:async';

/// Turns a raw exception into a message a normal person (not a developer)
/// can actually act on. Falls back to the exception's own text, cleaned
/// up a bit, when it doesn't recognize the specific case.
String friendlyErrorMessage(Object error) {
  final raw = error.toString().replaceFirst('Exception: ', '');

  if (error is SocketException) {
    return 'No internet connection. Check your network and try again.';
  }
  if (error is TimeoutException) {
    return 'That took too long to respond. Please try again.';
  }

  final lower = raw.toLowerCase();

  if (lower.contains('could not compute a route') || lower.contains('could not draw a route')) {
    return 'We couldn\'t find a road route between one or more of your places. '
        'This can happen when a location isn\'t reachable by road (for example, '
        'across water or in a restricted area). Try removing that destination.';
  }

  if (lower.contains('failed host lookup') ||
      lower.contains('network is unreachable') ||
      lower.contains('connection failed')) {
    return 'No internet connection. Check your network and try again.';
  }

  if (lower.contains('permission') && lower.contains('location')) {
    return raw; // LocationService already writes a clear, specific message
  }

  return raw.isEmpty ? 'Something went wrong. Please try again.' : raw;
}
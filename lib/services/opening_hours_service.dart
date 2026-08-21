enum OpenStatus { open, closed, unknown }

class _Rule {
  final Set<int> days; // Dart weekday: 1=Mon .. 7=Sun
  final bool isOff;
  final List<List<int>> timeRangesMinutes; // each: [startMin, endMin]

  _Rule({required this.days, required this.isOff, required this.timeRangesMinutes});
}

/// A deliberately simplified parser for OSM's `opening_hours` tag syntax.
/// Covers the common real-world patterns (day ranges, comma lists, time
/// ranges, "off", "24/7") — not the full OSM opening_hours spec, which is
/// extensive. Anything it can't confidently parse returns `unknown` rather
/// than guessing, since a wrong "closed" warning is worse than no warning.
class OpeningHoursService {
  static const _dayAbbrev = {
    'Mo': 1, 'Tu': 2, 'We': 3, 'Th': 4, 'Fr': 5, 'Sa': 6, 'Su': 7,
  };

  OpenStatus isOpenAt(String? rawOpeningHours, DateTime dateTime) {
    if (rawOpeningHours == null || rawOpeningHours.trim().isEmpty) {
      return OpenStatus.unknown;
    }

    final raw = rawOpeningHours.trim();
    if (raw == '24/7') return OpenStatus.open;

    List<_Rule> rules;
    try {
      rules = _parseRules(raw);
    } catch (_) {
      return OpenStatus.unknown;
    }

    if (rules.isEmpty) return OpenStatus.unknown;

    final weekday = dateTime.weekday;
    final minutesOfDay = dateTime.hour * 60 + dateTime.minute;

    // Later rules override earlier ones for the same day, matching how
    // OSM opening_hours rules are conventionally applied.
    _Rule? applicable;
    for (final rule in rules) {
      if (rule.days.contains(weekday)) applicable = rule;
    }

    if (applicable == null) return OpenStatus.unknown;
    if (applicable.isOff) return OpenStatus.closed;

    for (final range in applicable.timeRangesMinutes) {
      if (minutesOfDay >= range[0] && minutesOfDay <= range[1]) {
        return OpenStatus.open;
      }
    }
    return OpenStatus.closed;
  }

  List<_Rule> _parseRules(String raw) {
    final rules = <_Rule>[];
    final segments = raw.split(';').map((s) => s.trim()).where((s) => s.isNotEmpty);

    for (final segment in segments) {
      final parts = segment.split(RegExp(r'\s+'));
      if (parts.isEmpty) continue;

      final dayToken = parts[0];
      final timeToken = parts.length > 1 ? parts.sublist(1).join(' ') : '';

      final days = _parseDays(dayToken);
      if (days.isEmpty) continue;

      if (timeToken.toLowerCase() == 'off' || timeToken.toLowerCase() == 'closed') {
        rules.add(_Rule(days: days, isOff: true, timeRangesMinutes: []));
        continue;
      }

      final ranges = <List<int>>[];
      for (final part in timeToken.split(',')) {
        final match = RegExp(r'^(\d{1,2}):(\d{2})-(\d{1,2}):(\d{2})$').firstMatch(part.trim());
        if (match == null) continue;
        final startMin = int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
        final endMin = int.parse(match.group(3)!) * 60 + int.parse(match.group(4)!);
        ranges.add([startMin, endMin]);
      }

      if (ranges.isNotEmpty) {
        rules.add(_Rule(days: days, isOff: false, timeRangesMinutes: ranges));
      }
    }
    return rules;
  }

  Set<int> _parseDays(String token) {
    final days = <int>{};
    for (final piece in token.split(',')) {
      if (piece.contains('-')) {
        final range = piece.split('-');
        if (range.length != 2) continue;
        final start = _dayAbbrev[range[0]];
        final end = _dayAbbrev[range[1]];
        if (start == null || end == null) continue;
        int d = start;
        while (true) {
          days.add(d);
          if (d == end) break;
          d = d == 7 ? 1 : d + 1;
          if (days.length > 7) break; // safety
        }
      } else {
        final d = _dayAbbrev[piece];
        if (d != null) days.add(d);
      }
    }
    return days;
  }
}
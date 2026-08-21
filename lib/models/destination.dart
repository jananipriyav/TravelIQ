class Destination {
  final String name;
  final double lat;
  final double lon;
  final int dwellMinutes; // how long the user plans to spend at this stop
  final String? openingHours; // raw OSM opening_hours tag, if available

  Destination({
    required this.name,
    required this.lat,
    required this.lon,
    this.dwellMinutes = 30,
    this.openingHours,
  });

  Destination copyWith({int? dwellMinutes}) {
    return Destination(
      name: name,
      lat: lat,
      lon: lon,
      dwellMinutes: dwellMinutes ?? this.dwellMinutes,
      openingHours: openingHours,
    );
  }
}
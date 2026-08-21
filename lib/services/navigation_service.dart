import 'package:url_launcher/url_launcher.dart';

class NavigationService {
  Future<void> openDirectionsTo(
    double lat,
    double lon,
  ) async {
    final googleMapsUrl = Uri.https(
      'www.google.com',
      '/maps/dir/',
      {
        'api': '1',
        'destination': '$lat,$lon',
        'travelmode': 'driving',
      },
    );

    final launched = await launchUrl(
      googleMapsUrl,
      mode: LaunchMode.externalApplication,
    );

    if (!launched) {
      final geoUri = Uri.parse(
        'geo:$lat,$lon?q=$lat,$lon',
      );

      final geoLaunched = await launchUrl(
        geoUri,
        mode: LaunchMode.externalApplication,
      );

      if (!geoLaunched) {
        throw Exception('Could not open a maps application.');
      }
    }
  }
}
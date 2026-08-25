import 'package:latlong2/latlong.dart';

/// Post categories for the Create Flare flow.
enum PostType { lost, spotted, general }

extension PostTypeLabel on PostType {
  String get label {
    switch (this) {
      case PostType.lost:
        return 'Lost';
      case PostType.spotted:
        return 'Spotted';
      case PostType.general:
        return 'General';
    }
  }
}

/// Result returned from the full-screen location picker.
class MapSelection {
  final LatLng location;
  final String label;

  const MapSelection({required this.location, required this.label});
}

/// Formats coordinates for display when no address is available.
String formatCoordinates(LatLng point) {
  return '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
}

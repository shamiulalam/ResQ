import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_colors.dart';
import 'flare_models.dart';

/// Full-screen OpenStreetMap picker. Tap anywhere to move the pin,
/// then confirm to return a [MapSelection] to the caller.
class LocationPickerScreen extends StatefulWidget {
  final LatLng initialLocation;

  const LocationPickerScreen({
    super.key,
    required this.initialLocation,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late LatLng _picked;

  @override
  void initState() {
    super.initState();
    _picked = widget.initialLocation;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.flarePickerBackground,
      appBar: AppBar(
        title: const Text('Pick location'),
        backgroundColor: AppColors.flarePickerAppBar,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: _picked,
              initialZoom: 15,
              onTap: (_, point) => setState(() => _picked = point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.resq',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    width: 40,
                    height: 40,
                    point: _picked,
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: AppColors.flareMapPin,
                      size: 36,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 18,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  MapSelection(
                    location: _picked,
                    label: formatCoordinates(_picked),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.flarePublishStart,
                foregroundColor: AppColors.flarePublishText,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Use this location',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

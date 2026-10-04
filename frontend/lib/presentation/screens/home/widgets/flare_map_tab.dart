import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../database/models/flare_model.dart';

/// Live OpenStreetMap view of every geocoded lost/spotted Flare in Firestore.
class FlareMapTab extends StatefulWidget {
  const FlareMapTab({super.key});

  @override
  State<FlareMapTab> createState() => _FlareMapTabState();
}

class _FlareMapTabState extends State<FlareMapTab>
    with AutomaticKeepAliveClientMixin {
  final MapController _mapController = MapController();
  late final Stream<List<FlareModel>> _flaresStream;

  static const _dhaka = LatLng(23.8103, 90.4125);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Keep one subscription for the lifetime of the tab. Recreating this in
    // build caused Firestore to resubscribe during parent rebuilds.
    _flaresStream = FirebaseFirestore.instance
        .collection('flares')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => FlareModel.fromMap(doc.id, doc.data()))
              .toList(growable: false),
        );
  }

  void _changeZoom(double delta) {
    final camera = _mapController.camera;
    final zoom = (camera.zoom + delta).clamp(3.0, 19.0);
    _mapController.move(camera.center, zoom);
  }

  bool _hasValidCoordinates(FlareModel flare) {
    return flare.latitude >= -90 &&
        flare.latitude <= 90 &&
        flare.longitude >= -180 &&
        flare.longitude <= 180 &&
        !(flare.latitude == 0 && flare.longitude == 0);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<List<FlareModel>>(
      stream: _flaresStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Could not load Flare locations.\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final flares = (snapshot.data ?? const <FlareModel>[])
            .where((flare) =>
                (flare.postType == 'lost' || flare.postType == 'spotted') &&
                _hasValidCoordinates(flare))
            .toList(growable: false);

        return Stack(
          children: [
            RepaintBoundary(
              child: FlutterMap(
                mapController: _mapController,
                options: const MapOptions(
                  initialCenter: _dhaka,
                  initialZoom: 11,
                  minZoom: 3,
                  maxZoom: 19,
                  interactionOptions: InteractionOptions(
                    flags: InteractiveFlag.all,
                    enableMultiFingerGestureRace: true,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.resq',
                  ),
                  MarkerLayer(
                    markers: flares.map((flare) {
                      final isLost = flare.postType == 'lost';
                      return Marker(
                        width: 44,
                        height: 44,
                        point: LatLng(flare.latitude, flare.longitude),
                        child: Tooltip(
                          message:
                              '${isLost ? 'Lost' : 'Spotted'}: ${flare.petName.isEmpty ? flare.petType : flare.petName}\n${flare.locationLabel}',
                          triggerMode: TooltipTriggerMode.tap,
                          child: Icon(
                            Icons.location_on_rounded,
                            color: isLost ? Colors.red : Colors.blue,
                            size: 38,
                          ),
                        ),
                      );
                    }).toList(growable: false),
                  ),
                ],
              ),
            ),
            const Positioned(
              top: 12,
              left: 12,
              child: SafeArea(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _LegendDot(color: Colors.red, label: 'Lost'),
                        SizedBox(width: 12),
                        _LegendDot(color: Colors.blue, label: 'Spotted'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: CircularProgressIndicator()),
            Positioned(
              right: 12,
              top: 12,
              child: SafeArea(
                child: Column(
                  children: [
                    _MapButton(
                      icon: Icons.add_rounded,
                      tooltip: 'Zoom in',
                      onPressed: () => _changeZoom(1),
                    ),
                    const SizedBox(height: 8),
                    _MapButton(
                      icon: Icons.remove_rounded,
                      tooltip: 'Zoom out',
                      onPressed: () => _changeZoom(-1),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 3,
      borderRadius: BorderRadius.circular(12),
      child: IconButton(
        icon: Icon(icon),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.location_on_rounded, color: color, size: 20),
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';

import 'telemetry_provider.dart';

class TelemetryScreen extends StatefulWidget {
  const TelemetryScreen({super.key});

  @override
  State<TelemetryScreen> createState() => _TelemetryScreenState();
}

class _TelemetryScreenState extends State<TelemetryScreen> {
  GoogleMapController? _mapController;
  final LatLng _fallback = const LatLng(-15.793889, -47.882778);
  final _number = intl.NumberFormat("#,##0.0");
  LatLng? _lastTarget;
  bool _darkMap = false;

  static const String _darkStyle = '[{"elementType":"geometry","stylers":[{"color":"#242f3e"}]},{"elementType":"labels.text.fill","stylers":[{"color":"#746855"}]},{"elementType":"labels.text.stroke","stylers":[{"color":"#242f3e"}]},{"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#d59563"}]},{"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#d59563"}]},{"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#263c3f"}]},{"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#6b9a76"}]},{"featureType":"road","elementType":"geometry","stylers":[{"color":"#38414e"}]},{"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#212a37"}]},{"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#9ca5b3"}]},{"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#746855"}]},{"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#1f2835"}]},{"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#f3d19c"}]},{"featureType":"transit","elementType":"geometry","stylers":[{"color":"#2f3948"}]},{"featureType":"transit.station","elementType":"labels.text.fill","stylers":[{"color":"#d59563"}]},{"featureType":"water","elementType":"geometry","stylers":[{"color":"#17263c"}]},{"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#515c6d"}]},{"featureType":"water","elementType":"labels.text.stroke","stylers":[{"color":"#17263c"}]}]';

  Future<void> _applyMapStyle() async {
    if (_mapController == null) return;
    await _mapController!.setMapStyle(_darkMap ? _darkStyle : null);
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  CameraPosition _cameraFor(LatLng target) => CameraPosition(target: target, zoom: 16);

  @override
  Widget build(BuildContext context) {
    return Consumer<TelemetryProvider>(
      builder: (context, t, _) {
        final pos = t.position;
        final hasPos = pos != null && pos.latitude.isFinite && pos.longitude.isFinite;
        final target = hasPos ? LatLng(pos!.latitude, pos.longitude) : _fallback;
        final marker = hasPos
            ? {
                Marker(
                  markerId: const MarkerId('me'),
                  position: target,
                )
              }
            : <Marker>{};
        final polyline = t.trail.isNotEmpty
            ? {
                Polyline(
                  polylineId: const PolylineId('trail'),
                  width: 4,
                  color: Colors.blue,
                  points: t.trail,
                )
              }
            : <Polyline>{};

        // Se recebermos uma nova posição, animar a câmera para ela
        if (_mapController != null && hasPos && (_lastTarget == null || _lastTarget != target)) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await _mapController?.animateCamera(
              CameraUpdate.newCameraPosition(_cameraFor(target)),
            );
          });
          _lastTarget = target;
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Telemetry'),
            actions: [
              IconButton(
                icon: Icon(_darkMap ? Icons.dark_mode : Icons.light_mode),
                onPressed: () async {
                  setState(() {
                    _darkMap = !_darkMap;
                  });
                  await _applyMapStyle();
                },
                tooltip: 'Alternar mapa claro/escuro',
              ),
            ],
          ),
          body: Column(
            children: [
              SizedBox(
                height: 300,
                child: GoogleMap(
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: false,
                  markers: marker,
                  polylines: polyline,
                  onMapCreated: (c) async {
                    _mapController = c;
                    await _applyMapStyle();
                  },
                  initialCameraPosition: _cameraFor(target),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    _buildCard(
                      title: 'Velocidade',
                      value: t.speedKmh != null && t.speedKmh!.isFinite
                          ? '${_number.format(t.speedKmh)} km/h'
                          : '-',
                    ),
                    _buildCard(
                      title: 'Aceleração',
                      value: t.acceleration != null
                          ? 'x: ${_number.format(t.acceleration!.x)} | y: ${_number.format(t.acceleration!.y)} | z: ${_number.format(t.acceleration!.z)}'
                          : '-',
                    ),
                    _buildCard(
                      title: 'Direção',
                      value: t.headingDegrees != null && t.headingDegrees!.isFinite
                          ? '${_number.format(t.headingDegrees)}° (${t.headingText})'
                          : '-',
                    ),
                    _buildCard(
                      title: 'Atualizado',
                      value: t.lastUpdate != null
                          ? intl.DateFormat('yyyy-MM-dd HH:mm:ss').format(t.lastUpdate!.toLocal())
                          : '-',
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'by Junior Santos · ${DateTime.now().year}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              if (t.isRunning) {
                await t.stop();
              } else {
                await t.start();
                if (hasPos) {
                  await _mapController?.animateCamera(
                    CameraUpdate.newCameraPosition(_cameraFor(target)),
                  );
                }
              }
              setState(() {});
            },
            icon: Icon(t.isRunning ? Icons.stop : Icons.play_arrow),
            label: Text(t.isRunning ? 'Parar Coleta' : 'Iniciar Coleta'),
          ),
        );
      },
    );
  }

  Widget _buildCard({required String title, required String value}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(value, style: const TextStyle(fontFeatures: [])),
          ],
        ),
      ),
    );
  }
}

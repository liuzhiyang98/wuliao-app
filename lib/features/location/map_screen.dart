import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'location_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final LocationService _svc = LocationService();
  LatLng? _me;
  LatLng? _partner;
  String _distance = '';

  @override
  void initState() {
    super.initState();
    _svc.startSharing();
    _svc.partnerStream().listen((rows) {
      if (rows.isNotEmpty) {
        final p = rows.first;
        setState(() {
          _partner = LatLng(
            (p['lat'] as num?)?.toDouble() ?? 0,
            (p['lng'] as num?)?.toDouble() ?? 0,
          );
          _updateDistance();
        });
      }
    });
    Geolocator.getLastKnownPosition().then((p) {
      if (p != null && mounted) {
        setState(() => _me = LatLng(p.latitude, p.longitude));
      }
    });
  }

  void _updateDistance() {
    if (_me == null || _partner == null) return;
    // 内联 Haversine 公式（避免 Distance 类 Web 兼容问题）
    const R = 6371; // 地球半径 km
    final lat1 = _me!.latitude * pi / 180;
    final lat2 = _partner!.latitude * pi / 180;
    final dLat = (_partner!.latitude - _me!.latitude) * pi / 180;
    final dLng = (_partner!.longitude - _me!.longitude) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final d = R * c;
    setState(() => _distance = '你们现在相距约 ${d.toStringAsFixed(2)} km');
  }

  @override
  void dispose() {
    _svc.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              center: _me ?? const LatLng(39.9042, 116.4074),
              zoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.wuliao',
              ),
              MarkerLayer(
                markers: [
                  if (_me != null)
                    Marker(
                      point: _me!,
                      width: 44,
                      height: 44,
                      child: const Icon(Icons.person_pin_circle,
                          color: Colors.blue, size: 40),
                    ),
                  if (_partner != null)
                    Marker(
                      point: _partner!,
                      width: 44,
                      height: 44,
                      child: const Icon(Icons.favorite,
                          color: Color(0xFFE96A8B), size: 36),
                    ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _distance.isEmpty ? '正在定位你们的位置…' : _distance,
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

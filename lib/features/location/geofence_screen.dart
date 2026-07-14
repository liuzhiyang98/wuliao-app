import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'background_location_service.dart';
import 'geofence_repository.dart';
import 'place_emoji.dart';

/// 管理自动报备地点（家 / 公司 / 自定义）。
class GeofenceScreen extends StatefulWidget {
  const GeofenceScreen({super.key});

  @override
  State<GeofenceScreen> createState() => _GeofenceScreenState();
}

class _GeofenceScreenState extends State<GeofenceScreen> {
  final _repo = GeofenceRepository();
  final _nameCtl = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  double _radius = 150;
  double? _lat;
  double? _lng;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _items = await _repo.list();
    } catch (e) {
      _toast('读取失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickHere() async {
    setState(() => _picking = true);
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied ||
          p == LocationPermission.deniedForever) {
        p = await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition();
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
      _toast('已定位当前位置 ✅');
    } catch (e) {
      _toast('定位失败：$e');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _add() async {
    final name = _nameCtl.text.trim();
    if (name.isEmpty) return _toast('先给地点起个名字（家 / 公司 …）');
    if (_lat == null || _lng == null) return _toast('请先点「用当前位置」');
    try {
      await _repo.add(
        name: name,
        lat: _lat!,
        lng: _lng!,
        radiusM: _radius,
      );
      await BackgroundLocationService().refreshGeofences();
      _nameCtl.clear();
      setState(() {
        _lat = null;
        _lng = null;
        _radius = 150;
      });
      _toast('已添加「$name」📍');
      await _load();
    } catch (e) {
      _toast('添加失败：$e');
    }
  }

  Future<void> _delete(String id) async {
    try {
      await _repo.remove(id);
      await BackgroundLocationService().refreshGeofences();
      await _load();
    } catch (e) {
      _toast('删除失败：$e');
    }
  }

  void _toast(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('自动报备地点')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('设置一个地点，进出时就会自动给彼此报备 💌',
              style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nameCtl,
                    decoration: const InputDecoration(
                      labelText: '地点名称',
                      hintText: '家 / 公司 / 健身房 …',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton.tonal(
                        onPressed: _picking ? null : _pickHere,
                        child: _picking
                            ? const Text('定位中…')
                            : const Text('用当前位置'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _lat == null
                              ? '尚未选择位置'
                              : '已选：${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('提醒半径：${_radius.round()} 米'),
                  Slider(
                    value: _radius,
                    min: 50,
                    max: 1000,
                    divisions: 19,
                    label: '${_radius.round()} 米',
                    onChanged: (v) => setState(() => _radius = v),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _add,
                      child: const Text('添加地点'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_items.isEmpty)
            const Center(child: Text('还没有设置地点'))
          else
            ..._items.map((g) => ListTile(
                  leading: Text(placeEmoji(g['name']),
                      style: const TextStyle(fontSize: 28)),
                  title: Text(g['name']),
                  subtitle: Text('半径 ${((g['radius_m'] as num)).round()} 米'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(g['id']),
                  ),
                )),
        ],
      ),
    );
  }
}

// lib/screens/admin_dashboard_screen.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../widgets/curved_header.dart';
import '../widgets/metric_card.dart';

/// Backend base URL
const String _apiBaseUrl = "http://192.168.1.2:8080";

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _loadingNodes = true;
  bool _loadingForecast = false;

  String? _nodeError;
  String? _forecastError;

  List<NodeLocation> _nodes = [];
  NodeLocation? _selected;

  // Shared value for 1hr + 1mth forecasts
  double? _forecastValue;
  DateTime? _forecastTimestamp;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchNodes();

    // Auto-refresh every 15 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _refreshNodesSilently();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // --------------------------------------------------------------------------
  // FETCH NODE LIST
  // --------------------------------------------------------------------------

  Future<void> _fetchNodes() async {
    setState(() {
      _loadingNodes = true;
      _nodeError = null;
    });

    try {
      final uri = Uri.parse("$_apiBaseUrl/node/locations");
      final res = await http.get(uri);

      if (res.statusCode != 200) {
        throw Exception("Node API returned ${res.statusCode}");
      }

      final decoded = json.decode(res.body);
      final list = (decoded["nodes"] as List)
          .map((e) => NodeLocation.fromJson(e as Map<String, dynamic>))
          .toList();

      setState(() {
        _nodes = list;
        _selected = list.isNotEmpty ? list.first : null;
        _loadingNodes = false;
      });

      if (_selected != null) {
        await _fetchForecast(_selected!.nodeName);
      }
    } catch (e) {
      setState(() {
        _loadingNodes = false;
        _nodeError = e.toString();
      });
    }
  }

  Future<void> _refreshNodesSilently() async {
    try {
      final uri = Uri.parse("$_apiBaseUrl/node/locations");
      final res = await http.get(uri);

      if (res.statusCode != 200) return;

      final decoded = json.decode(res.body);
      final list = (decoded["nodes"] as List)
          .map((e) => NodeLocation.fromJson(e as Map<String, dynamic>))
          .toList();

      if (list.isEmpty) return;

      setState(() {
        _nodes = list;
        if (_selected != null) {
          final match = list.firstWhere(
            (n) => n.nodeId == _selected!.nodeId,
            orElse: () => list.first,
          );
          _selected = match;
        } else {
          _selected = list.first;
        }
      });

      if (_selected != null) {
        await _fetchForecast(_selected!.nodeName);
      }
    } catch (_) {
      // silent fail
    }
  }

  // --------------------------------------------------------------------------
  // FETCH FORECAST (1hr + 1mth share same value)
  // --------------------------------------------------------------------------

  Future<void> _fetchForecast(String nodeName) async {
    setState(() {
      _loadingForecast = true;
      _forecastError = null;
    });

    try {
      final uri = Uri.parse(
        "$_apiBaseUrl/node/${Uri.encodeComponent(nodeName)}/prediction",
      );
      final res = await http.get(uri);

      if (res.statusCode == 404) {
        setState(() {
          _forecastValue = null;
          _forecastTimestamp = null;
          _loadingForecast = false;
          _forecastError = "No prediction available";
        });
        return;
      }

      if (res.statusCode != 200) {
        throw Exception("Prediction API returned ${res.statusCode}");
      }

      final decoded = json.decode(res.body) as Map<String, dynamic>;

      final dynamic tRaw = decoded["predicted_temperature"];
      double? temperature =
          tRaw is num ? tRaw.toDouble() : double.tryParse(tRaw.toString());

      final dynamic tsRaw = decoded["predicted_timestamp"];
      final DateTime? timestamp =
          tsRaw != null ? DateTime.tryParse(tsRaw.toString()) : null;

      setState(() {
        _forecastValue = temperature;
        _forecastTimestamp = timestamp;
        _loadingForecast = false;
      });
    } catch (e) {
      setState(() {
        _loadingForecast = false;
        _forecastError = e.toString();
      });
    }
  }

  // 🔹 Only logic change here previously was MapController.
  // Now we just update selection & forecast; map will refocus via key in _buildMap.
  void _onNodeSelected(NodeLocation node) async {
    setState(() {
      _selected = node;
    });
    await _fetchForecast(node.nodeName);
  }

  // ==========================================================================
  // BUILD UI WITH FIXED MAX WIDTH
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final selected = _selected;

    // FALLBACKS
    double? current = selected?.temperature;
    double? forecast1h = _forecastValue;
    double? forecast1m = _forecastValue;

    // 🔹 Use loading + error flags so they aren’t “unused”
    if (_loadingNodes) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_nodeError != null) {
      return Center(
        child: Text(
          'Failed to load nodes:\n$_nodeError',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    return Column(
      children: [
        const CurvedHeader(
          title: 'DASHBOARD',
          subtitle: 'Overview of water level, environment, and risk',
          icon: Icons.insert_chart_outlined,
          compact: true,
        ),

        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1600),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: [
                          _buildWaterLevelOverview(
                            current: current,
                            h1: forecast1h,
                            m1: forecast1m,
                          ),
                          _buildEnvironmentStatus(selected),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(flex: 5, child: _buildRiskAndMapSection()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // WATER LEVEL OVERVIEW  — CORRECT TREND CALCULATION
  // ==========================================================================

  Widget _buildWaterLevelOverview({
    required double? current,
    required double? h1,
    required double? m1,
  }) {
    return _SectionContainer(
      title: "Water Level Overview",
      child: Row(
        children: [
          if (_loadingForecast)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Updating forecast…',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            )
          else if (_forecastError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _forecastError!,
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
            ),
          Expanded(
            child: MetricCard(
              title: "Current Water Level",
              value: current != null ? "${current.toStringAsFixed(2)} m" : "--",
              icon: Icons.water_outlined,
              showTrend: false,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: MetricCard(
              title: "Water Level (1hr Forecast)",
              value: h1 != null ? "${h1.toStringAsFixed(2)} m" : "--",
              icon: Icons.show_chart_outlined,
              showTrend: true,
              current: current,
              forecast: h1,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: MetricCard(
              title: "Water Level (1mth Forecast)",
              value: m1 != null ? "${m1.toStringAsFixed(2)} m" : "--",
              icon: Icons.timeline_outlined,
              showTrend: true,
              current: current,
              forecast: m1,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // ENVIRONMENT STATUS
  // ==========================================================================

  Widget _buildEnvironmentStatus(NodeLocation? node) {
    return _SectionContainer(
      title: "Environment Status",
      child: GridView.count(
        crossAxisCount: 2,
        childAspectRatio: 2.0,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          MetricCard(
            title: "Temperature",
            value: node?.temperature != null
                ? "${node!.temperature!.toStringAsFixed(1)}°C"
                : "--",
            icon: Icons.thermostat_outlined,
            showTrend: false,
          ),
          MetricCard(
            title: "Humidity",
            value: node?.humidity != null
                ? "${node!.humidity!.toStringAsFixed(1)}%"
                : "--",
            icon: Icons.water_drop_outlined,
            showTrend: false,
          ),
          const MetricCard(
            title: "Air Pressure",
            value: "--",
            icon: Icons.air_outlined,
            showTrend: false,
          ),
          const MetricCard(
            title: "Rain (1 min)",
            value: "--",
            icon: Icons.cloudy_snowing,
            showTrend: false,
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // RISK + MAP SECTION
  // ==========================================================================

  Widget _buildRiskAndMapSection() {
    final selected = _selected;

    const highColor = Color(0xFFEF4444);
    const moderateColor = Color(0xFFFACC15);
    const lowColor = Color(0xFF22C55E);

    final double gauge = selected == null
        ? 0.2
        : (selected.nodeId % 3 == 0
            ? 0.8
            : selected.nodeId % 3 == 1
                ? 0.28
                : 0.52);

    late final Color riskColor;
    late final String riskLabel;

    if (gauge >= 0.7) {
      riskColor = highColor;
      riskLabel = "High";
    } else if (gauge >= 0.4) {
      riskColor = moderateColor;
      riskLabel = "Moderate";
    } else {
      riskColor = lowColor;
      riskLabel = "Low";
    }

    return _SectionContainer(
      title: "Risk in your area",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "Select Location:",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 12),
              Theme(
                data: Theme.of(context).copyWith(
                  hoverColor: Colors.transparent,
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                ),
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceVariant
                        .withOpacity(0.35),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<NodeLocation>(
                      value: _selected,
                      isDense: true,
                      iconSize: 18,
                      borderRadius: BorderRadius.circular(12),
                      items: _nodes
                          .map(
                            (n) => DropdownMenuItem<NodeLocation>(
                              value: n,
                              child: Text(
                                '${n.siteName} – ${n.nodeName}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) _onNodeSelected(value);
                      },
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: riskColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  riskLabel,
                  style: TextStyle(
                    color: riskColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 25),

          AspectRatio(
            aspectRatio: 12.5 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _buildMap(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    if (_selected == null) {
      return const Center(child: Text("No nodes available"));
    }

    final center = LatLng(_selected!.lat, _selected!.lng);

    return FlutterMap(
      // 🔹 Key forces FlutterMap to fully rebuild
      key: ValueKey('${_selected!.nodeId}_${_selected!.lat}_${_selected!.lng}'),
      options: MapOptions(
        initialCenter: center,
        initialZoom: 16,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.floodwatch_desktop',
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: center,
              width: 40,
              height: 40,
              child: const Icon(
                Icons.location_on,
                size: 36,
                color: Colors.red,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ===========================================================================
// NODE MODEL
// ===========================================================================

class NodeLocation {
  final int nodeId;
  final String nodeName;
  final int siteId;
  final String siteName;
  final double lat;
  final double lng;
  final double? temperature;
  final double? humidity;
  final DateTime? lastTimestamp;

  NodeLocation({
    required this.nodeId,
    required this.nodeName,
    required this.siteId,
    required this.siteName,
    required this.lat,
    required this.lng,
    this.temperature,
    this.humidity,
    this.lastTimestamp,
  });

  factory NodeLocation.fromJson(Map<String, dynamic> json) {
    double? _d(dynamic v) =>
        v == null ? null : (v is num ? v.toDouble() : double.tryParse("$v"));
    DateTime? _ts(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());

    return NodeLocation(
      nodeId: json["node_id"] ?? 0,
      nodeName: json["node_name"] ?? "",
      siteId: json["site_id"] ?? 0,
      siteName: json["site_name"] ?? "",
      lat: _d(json["latitude"]) ?? 0,
      lng: _d(json["longitude"]) ?? 0,
      temperature: _d(json["temperature"]),
      humidity: _d(json["humidity"]),
      lastTimestamp: _ts(json["last_timestamp"]),
    );
  }
}

// ===========================================================================
// SECTION CONTAINER
// ===========================================================================

class _SectionContainer extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionContainer({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // OUTER CARD COLOR
    final Color outerColor = isDark
        ? const Color(0xFF181818) // darker outer
        : const Color(0xFFFFFDEB); // same light cream

    return Card(
      color: outerColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

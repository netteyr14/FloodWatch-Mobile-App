import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/curved_header.dart';
import '../widgets/action_button.dart';
import '../widgets/risk_gauge.dart';
import '../screens/sign_in_screen.dart';
import '../screens/register_screen.dart';
import 'dart:async';


/// Your backend URL (no trailing slash)
const String _apiBaseUrl = 'https://8cf42521409e.ngrok-free.app';

class HomeTab extends StatefulWidget {
  final bool isGuest;

  const HomeTab({super.key, this.isGuest = false});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  bool _loading = true;
  String? _error;

  List<NodeLocation> _nodes = [];
  NodeLocation? _selected;

  // ── NEW: prediction state ──────────────────────────────
  bool _loadingPrediction = false;
  String? _predictionError;
  double? _predictedTemp;
  DateTime? _predictedAt;

  Timer? _pollTimer;

  @override
void initState() {
  super.initState();
  _fetchNodes(); // initial load

  //repeat refresh every 15 seconds (adjust if you like)
  _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
    _refreshNodesSilently();
  });
}

Future<void> _refreshNodesSilently() async {
  try {
    final uri = Uri.parse('$_apiBaseUrl/node/locations');
    final res = await http.get(uri);

    if (res.statusCode != 200) return; // just ignore failures silently

    final decoded = json.decode(res.body) as Map<String, dynamic>;
    final list = (decoded['nodes'] as List<dynamic>)
        .map((e) => NodeLocation.fromJson(e as Map<String, dynamic>))
        .toList();

    if (list.isEmpty) return;

    setState(() {
      _nodes = list;

      // keep same selected node if it still exists
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

    // also refresh prediction for current node
    await _fetchPredictionForSelected();
  } catch (_) {
    // ignore errors for silent refresh
  }
}

@override
void dispose() {
  _pollTimer?.cancel(); // 👈 important so it stops when tab is gone
  super.dispose();
}

  Future<void> _fetchNodes() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse('$_apiBaseUrl/node/locations');
      final res = await http.get(uri);

      if (res.statusCode != 200) {
        throw Exception('Server responded with ${res.statusCode}');
      }

      final decoded = json.decode(res.body) as Map<String, dynamic>;
      final list = (decoded['nodes'] as List<dynamic>)
          .map((e) => NodeLocation.fromJson(e as Map<String, dynamic>))
          .toList();

      if (list.isEmpty) {
        throw Exception('No nodes returned from API.');
      }

      setState(() {
        _nodes = list;
        _selected = list.first;
        _loading = false;
      });

      // fetch prediction for initial node
      await _fetchPredictionForSelected();
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _fetchPredictionForSelected() async {
    final sel = _selected;
    if (sel == null) return;

    setState(() {
      _loadingPrediction = true;
      _predictionError = null;
    });

    try {
      final uri =
          Uri.parse('$_apiBaseUrl/node/${Uri.encodeComponent(sel.nodeName)}/prediction');
      final res = await http.get(uri);

      if (res.statusCode == 404) {
        // No prediction yet for this node – not really an "error", just no data.
        setState(() {
          _loadingPrediction = false;
          _predictedTemp = null;
          _predictedAt = null;
          _predictionError = 'No prediction yet';
        });
        return;
      }

      if (res.statusCode != 200) {
        throw Exception('Prediction API responded with ${res.statusCode}');
      }

      final decoded = json.decode(res.body) as Map<String, dynamic>;
      final dynamic tempRaw = decoded['predicted_temperature'];
      final dynamic tsRaw = decoded['predicted_timestamp'];

      double? temp;
      if (tempRaw is num) {
        temp = tempRaw.toDouble();
      } else {
        temp = double.tryParse(tempRaw.toString());
      }

      final DateTime? ts =
          tsRaw != null ? DateTime.tryParse(tsRaw.toString()) : null;

      setState(() {
        _predictedTemp = temp;
        _predictedAt = ts;
        _loadingPrediction = false;
      });
    } catch (e) {
      setState(() {
        _loadingPrediction = false;
        _predictionError = e.toString();
      });
    }
  }

  void _onNodeSelected(NodeLocation node) async {
    setState(() {
      _selected = node;
    });
    await _fetchPredictionForSelected();
  }

  @override
  Widget build(BuildContext context) {
    // 👇 Get current Firebase user & choose greeting
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName?.trim();
    final String greetingName;

    if (widget.isGuest || user == null) {
      greetingName = 'Guest';
    } else if (displayName != null && displayName.isNotEmpty) {
      greetingName = displayName;
    } else {
      greetingName = 'Resident';
    }

    final String subtitle =
        (widget.isGuest || user == null) ? 'You are in guest mode.' : 'Welcome back.';

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: CurvedHeader(
            title: 'Hello, $greetingName!',
            subtitle: subtitle,
            icon: Icons.shield_moon_outlined,
            compact: true,
          ),
        ),
        SliverList(
          delegate: SliverChildListDelegate([
            _MetricSections(
              selected: _selected,
              loadingNodes: _loading,
              nodeError: _error,
              predictedTemp: _predictedTemp,
              predictedAt: _predictedAt,
              loadingPrediction: _loadingPrediction,
              predictionError: _predictionError,
            ),
            _MapPreview(
              nodes: _nodes,
              selected: _selected,
              loading: _loading,
              error: _error,
              onRetry: _fetchNodes,
              onSelected: _onNodeSelected,
            ),
            if (widget.isGuest)
              _GuestAuthActions()
            else
              _ResidentSafetyActions(),
            const SizedBox(height: 100),
          ]),
        ),
      ],
    );
  }
}

class _MetricSections extends StatelessWidget {
  final NodeLocation? selected;
  final bool loadingNodes;
  final String? nodeError;

  final double? predictedTemp;
  final DateTime? predictedAt;
  final bool loadingPrediction;
  final String? predictionError;

  const _MetricSections({
    required this.selected,
    required this.loadingNodes,
    required this.nodeError,
    required this.predictedTemp,
    required this.predictedAt,
    required this.loadingPrediction,
    required this.predictionError,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Column(
        children: [
          _ForecastSection(
            selected: selected,
            predictedTemp: predictedTemp,
            predictedAt: predictedAt,
            loadingPrediction: loadingPrediction,
            predictionError: predictionError,
          ),
          const SizedBox(height: 12),
          _EnvironmentStatusSection(
            selected: selected,
            loading: loadingNodes,
            error: nodeError,
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// FORECAST (temporarily using temperature as water level)
/// ─────────────────────────────────────────────────────────────────────────
class _ForecastSection extends StatelessWidget {
  final NodeLocation? selected;
  final double? predictedTemp;
  final DateTime? predictedAt;
  final bool loadingPrediction;
  final String? predictionError;

  const _ForecastSection({
    required this.selected,
    required this.predictedTemp,
    required this.predictedAt,
    required this.loadingPrediction,
    required this.predictionError,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // TEMPORARY: reuse temperature values as "water level"
    double? currentTemp = selected?.temperature;
    double? forecastTemp = predictedTemp ?? currentTemp;

    String currentWaterText = '--';
    String water1hText = '--';

    if (currentTemp != null) {
      // using "m" just for the water-level feel; underlying value is temperature
      currentWaterText = '${currentTemp.toStringAsFixed(2)} m';
    }
    if (forecastTemp != null) {
      water1hText = '${forecastTemp.toStringAsFixed(2)} m';
    }

    // Trend: difference between "forecast water" and "current water"
    double trendValue;
    if (currentTemp != null && forecastTemp != null && currentTemp != 0) {
      trendValue = (forecastTemp - currentTemp) / currentTemp;
    } else {
      trendValue = 0.10; // fallback dummy
    }
    final bool rising = trendValue >= 0;

    final Color dangerRed = const Color(0xFFEF4444);
    final Color safeGreen = const Color(0xFF22C55E);
    final Color chipColor = rising ? dangerRed : safeGreen;

    String subtitleExtra = '';
    if (predictedAt != null) {
      subtitleExtra =
          ' • based on latest prediction at ${TimeOfDay.fromDateTime(predictedAt!).format(context)}';
    } else if (predictionError != null) {
      subtitleExtra = ' • prediction unavailable';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Water level overview (temporary)',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Using temperature data as a placeholder for water level$subtitleExtra',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withOpacity(
                      isDark ? 0.7 : 0.6,
                    ),
                  ),
            ),
            const SizedBox(height: 12),

            if (loadingPrediction)
              const Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 8.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),

            Row(
              children: [
                // CURRENT WATER LEVEL (temp reused)
                Expanded(
                  child: Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.primary.withOpacity(
                        isDark ? 0.16 : 0.06,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.water, color: scheme.primary, size: 20),
                        const SizedBox(height: 6),
                        Text(
                          'Current water level',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: scheme.onSurface.withOpacity(
                                  isDark ? 0.75 : 0.60,
                                ),
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          currentWaterText,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),

                // FORECAST WATER LEVEL (1h)
                Expanded(
                  child: Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.primary.withOpacity(
                        isDark ? 0.16 : 0.06,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.timeline, color: scheme.secondary, size: 20),
                        const SizedBox(height: 6),
                        Text(
                          'Water level (1h)',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: scheme.onSurface.withOpacity(
                                  isDark ? 0.75 : 0.60,
                                ),
                              ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              water1hText,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: chipColor.withOpacity(.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    rising
                                        ? Icons.north_east
                                        : Icons.south_east,
                                    size: 16,
                                    color: chipColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${(trendValue.abs() * 100).toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      color: chipColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// ENVIRONMENT STATUS (temp + humidity dynamic, others placeholders)
/// ─────────────────────────────────────────────────────────────────────────
class _EnvironmentStatusSection extends StatelessWidget {
  final NodeLocation? selected;
  final bool loading;
  final String? error;

  const _EnvironmentStatusSection({
    required this.selected,
    required this.loading,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    // final scheme = Theme.of(context).colorScheme;
    // final isDark = Theme.of(context).brightness == Brightness.dark;

    String tempText = '--';
    String humText = '--';

    if (selected != null && selected!.temperature != null) {
      tempText = '${selected!.temperature!.toStringAsFixed(1)}°C';
    }
    if (selected != null && selected!.humidity != null) {
      humText = '${selected!.humidity!.toStringAsFixed(1)}%';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Environment Status',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),

            if (loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'Failed to load latest readings.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),

            Row(
              children: [
                _EnvMetric(
                  icon: Icons.thermostat,
                  label: 'Temperature',
                  value: tempText,
                ),
                _EnvMetric(
                  icon: Icons.water_drop,
                  label: 'Humidity',
                  value: humText,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: const [
                _EnvMetric(
                  icon: Icons.speed,
                  label: 'Air Pressure',
                  value: '—',
                ),
                _EnvMetric(
                  icon: Icons.cloud,
                  label: 'Rain (1 min)',
                  value: '—',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EnvMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _EnvMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.primary.withOpacity(isDark ? 0.16 : 0.06),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: scheme.primary, size: 20),
            const SizedBox(height: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface
                        .withOpacity(isDark ? 0.75 : 0.60),
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// MAP PREVIEW (NO MapController, stateless, uses key to recenter)
/// ─────────────────────────────────────────────────────────────────────────
class _MapPreview extends StatelessWidget {
  final List<NodeLocation> nodes;
  final NodeLocation? selected;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final ValueChanged<NodeLocation> onSelected;

  const _MapPreview({
    required this.nodes,
    required this.selected,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTabletOrDesktop = constraints.maxWidth >= 600;
        final isVeryWide = constraints.maxWidth >= 900;

        final double mapHeight =
            isVeryWide ? 260 : (isTabletOrDesktop ? 220 : 180);
        final double gaugeHeight =
            isVeryWide ? 180 : (isTabletOrDesktop ? 160 : 140);
        final double betweenMapAndGauge =
            isVeryWide ? 24 : (isTabletOrDesktop ? 20 : 16);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HEADER + DROPDOWN
                Row(
                  children: [
                    const Text(
                      'Risk in your area',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    if (loading)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else if (error != null)
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Retry',
                        onPressed: onRetry,
                      )
                    else
                      Theme(
                        data: Theme.of(context).copyWith(
                          hoverColor: Colors.transparent,
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          focusColor: Colors.transparent,
                        ),
                        child: Container(
                          height: 32,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceVariant
                                .withOpacity(0.35),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<NodeLocation>(
                              value: selected,
                              isDense: true,
                              iconSize: 18,
                              borderRadius: BorderRadius.circular(12),
                              dropdownColor: Theme.of(context)
                                  .colorScheme
                                  .surface,
                              items: nodes
                                  .map(
                                    (n) => DropdownMenuItem<NodeLocation>(
                                      value: n,
                                      child: Text(
                                        '${n.siteName} – ${n.nodeName}',
                                        style:
                                            const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (node) {
                                if (node == null) return;
                                onSelected(node);
                              },
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text(
                        selected?.riskLabel ?? 'Low',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // MAP
                SizedBox(
                  height: mapHeight,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: _buildMap(),
                  ),
                ),

                SizedBox(height: betweenMapAndGauge),

                // GAUGE
                SizedBox(
                  height: gaugeHeight,
                  child: RiskGauge(
                    value: selected?.riskGauge ?? 0.28,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMap() {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (error != null) {
      return Center(
        child: Text(
          'Failed to load locations\n$error',
          textAlign: TextAlign.center,
        ),
      );
    }

    if (selected == null || nodes.isEmpty) {
      return const Center(child: Text('No nodes available'));
    }

    final center = latlng.LatLng(selected!.lat, selected!.lng);

    final markers = nodes
        .map(
          (n) => Marker(
            point: latlng.LatLng(n.lat, n.lng),
            width: 40,
            height: 40,
            child: const Icon(
              Icons.location_pin,
              size: 32,
              color: Colors.redAccent,
            ),
          ),
        )
        .toList();

    return FlutterMap(
      key: ValueKey('map-${selected!.nodeId}'),
      options: MapOptions(
        initialCenter: center,
        initialZoom: 17,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.floodwatch',
        ),
        MarkerLayer(markers: markers),
      ],
    );
  }
}

/// Model: node + latest temp/humidity (optional, nullable)
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

  double get riskGauge => (nodeId % 3 == 0)
      ? 0.8
      : (nodeId % 3 == 1)
          ? 0.28
          : 0.52;

  String get riskLabel => (riskGauge >= 0.7)
      ? 'High'
      : (riskGauge >= 0.4)
          ? 'Moderate'
          : 'Low';

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
    double? _toDoubleNullable(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    DateTime? _toDateTime(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    return NodeLocation(
      nodeId: json['node_id'] as int,
      nodeName: json['node_name'] as String,
      siteId: json['site_id'] as int,
      siteName: json['site_name'] as String,
      lat: _toDoubleNullable(json['latitude']) ?? 0.0,
      lng: _toDoubleNullable(json['longitude']) ?? 0.0,
      temperature: _toDoubleNullable(json['temperature']),
      humidity: _toDoubleNullable(json['humidity']),
      lastTimestamp: _toDateTime(json['last_timestamp']),
    );
  }
}

/// Guest actions (Sign In / Register)
class _GuestAuthActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you a resident of Barangay 178?',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sign in or register to receive personalized alerts and share your status during floods.',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ActionButton(
                  icon: Icons.login,
                  label: 'Sign In',
                  onTap: () {
                    Navigator.pushNamed(context, SignInScreen.route);
                  },
                ),
                ActionButton(
                  icon: Icons.person_add_alt,
                  label: 'Register',
                  onTap: () {
                    Navigator.pushNamed(context, RegisterScreen.route);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Logged-in safety actions
class _ResidentSafetyActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you safe?',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ActionButton(
                  icon: Icons.check_circle,
                  label: 'Yes, I\'m safe',
                  onTap: () {
                    // TODO: hook this to reporting logic
                  },
                ),
                ActionButton(
                  icon: Icons.dangerous,
                  label: 'No, I\'m not safe',
                  onTap: () {
                    // TODO: hook this to reporting logic
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

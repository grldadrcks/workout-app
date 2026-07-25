import 'dart:async';
import 'package:flutter/material.dart';
import '../services/lf_equipment_service.dart';

class CardioScreen extends StatefulWidget {
  const CardioScreen({super.key});

  @override
  State<CardioScreen> createState() => _CardioScreenState();
}

class _CardioScreenState extends State<CardioScreen> {
  final _service = LFEquipmentService();
  StreamSubscription<LFEvent>? _sub;

  LFStatus _status = LFStatus.idle;
  LFStreamData? _data;
  String _protocol = '';
  String _serial = '';
  String _errorMsg = '';

  @override
  void initState() {
    super.initState();
    _sub = _service.stream.listen(_onEvent, onError: _onStreamError);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onEvent(LFEvent event) {
    setState(() {
      _status = event.status;
      if (event.data != null) _data = event.data;
      if (event.protocol != null) _protocol = event.protocol!;
      if (event.serial != null) _serial = event.serial!;
      if (event.errorMessage != null) _errorMsg = event.errorMessage!;
    });
  }

  void _onStreamError(Object err) {
    setState(() {
      _status = LFStatus.error;
      _errorMsg = err.toString();
    });
  }

  Future<void> _connect() async {
    try {
      await _service.connect();
    } on Exception catch (e) {
      setState(() {
        _status = LFStatus.error;
        _errorMsg = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _disconnect() async {
    await _service.disconnect();
    setState(() {
      _status = LFStatus.idle;
      _data = null;
      _protocol = '';
      _serial = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cardio Machine'),
        actions: [
          if (_status == LFStatus.connected)
            TextButton(
              onPressed: _disconnect,
              child: const Text('Disconnect'),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: switch (_status) {
          LFStatus.idle || LFStatus.disconnected => _IdleView(
              disconnected: _status == LFStatus.disconnected,
              onConnect: _connect,
            ),
          LFStatus.scanning => const _ScanningView(),
          LFStatus.connected => _ConnectedView(
              data: _data,
              protocol: _protocol,
              serial: _serial,
            ),
          LFStatus.error => _ErrorView(
              message: _errorMsg,
              onRetry: _connect,
            ),
        },
      ),
    );
  }
}

// ── Idle ───────────────────────────────────────────────────────────────────

class _IdleView extends StatelessWidget {
  final bool disconnected;
  final VoidCallback onConnect;
  const _IdleView({required this.disconnected, required this.onConnect});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.bluetooth_searching,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            disconnected ? 'Disconnected' : 'Connect to a Life Fitness machine',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Make sure Bluetooth is on and you are within range of the equipment.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: onConnect,
            icon: const Icon(Icons.bluetooth),
            label: const Text('Scan for Equipment'),
          ),
        ],
      ),
    );
  }
}

// ── Scanning ───────────────────────────────────────────────────────────────

class _ScanningView extends StatelessWidget {
  const _ScanningView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(strokeWidth: 6),
          ),
          const SizedBox(height: 24),
          Text('Scanning for equipment…',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Will auto-connect to the nearest Life Fitness machine.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── Connected / Streaming ──────────────────────────────────────────────────

class _ConnectedView extends StatelessWidget {
  final LFStreamData? data;
  final String protocol;
  final String serial;
  const _ConnectedView({required this.data, required this.protocol, required this.serial});

  String _fmt(int s) {
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final d = data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Connection badge
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              protocol.isNotEmpty ? 'Connected · $protocol' : 'Connected',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            if (serial.isNotEmpty) ...[
              const Text(' · ', style: TextStyle(color: Colors.grey)),
              Text(serial,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
            ],
          ],
        ),
        const SizedBox(height: 32),

        if (d == null)
          const Center(child: Text('Waiting for workout data…',
              style: TextStyle(color: Colors.grey)))
        else ...[
          // Duration — big display
          Center(
            child: Column(
              children: [
                Text('Duration',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                Text(
                  _fmt(d.duration),
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Speed / Distance / Calories row
          Row(
            children: [
              Expanded(child: _MetricCard(
                label: 'Speed',
                value: d.speed.toStringAsFixed(1),
                unit: 'kph',
                icon: Icons.speed,
                color: Colors.blue,
              )),
              const SizedBox(width: 12),
              Expanded(child: _MetricCard(
                label: 'Distance',
                value: (d.distance / 1000).toStringAsFixed(2),
                unit: 'km',
                icon: Icons.straighten,
                color: Colors.orange,
              )),
              const SizedBox(width: 12),
              Expanded(child: _MetricCard(
                label: 'Calories',
                value: d.calories.toInt().toString(),
                unit: 'kcal',
                icon: Icons.local_fire_department,
                color: Colors.red,
              )),
            ],
          ),
        ],
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label, value, unit;
  final IconData icon;
  final Color color;
  const _MetricCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          Text(unit,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey)),
          const SizedBox(height: 2),
          Text(label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color)),
        ],
      ),
    );
  }
}

// ── Error ──────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bluetooth_disabled, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('Connection failed', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}

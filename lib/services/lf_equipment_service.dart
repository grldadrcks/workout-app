import 'dart:async';
import 'package:flutter/services.dart';

enum LFStatus { idle, scanning, connected, disconnected, error }

class LFStreamData {
  final double speed;    // kph
  final double distance; // metres
  final double calories;
  final int duration;    // seconds

  const LFStreamData({
    required this.speed,
    required this.distance,
    required this.calories,
    required this.duration,
  });
}

class LFEvent {
  final LFStatus status;
  final LFStreamData? data;
  final String? protocol;
  final String? serial;
  final String? errorMessage;

  const LFEvent({
    required this.status,
    this.data,
    this.protocol,
    this.serial,
    this.errorMessage,
  });
}

class LFEquipmentService {
  static const _method = MethodChannel('lf_equipment');
  static const _events = EventChannel('lf_equipment/stream');

  Stream<LFEvent> get stream => _events
      .receiveBroadcastStream()
      .map((raw) => _parse(Map<String, dynamic>.from(raw as Map)));

  Future<void> connect() => _method.invokeMethod('connect');
  Future<void> disconnect() => _method.invokeMethod('disconnect');

  static LFEvent _parse(Map<String, dynamic> e) {
    switch (e['type'] as String) {
      case 'scanning':
        return const LFEvent(status: LFStatus.scanning);
      case 'connected':
        return LFEvent(
          status: LFStatus.connected,
          protocol: e['protocol'] as String?,
          serial: e['serial'] as String?,
        );
      case 'stream':
        return LFEvent(
          status: LFStatus.connected,
          data: LFStreamData(
            speed: (e['speed'] as num).toDouble(),
            distance: (e['distance'] as num).toDouble(),
            calories: (e['calories'] as num).toDouble(),
            duration: (e['duration'] as num).toInt(),
          ),
        );
      case 'disconnected':
        return const LFEvent(status: LFStatus.disconnected);
      case 'paused':
        return const LFEvent(status: LFStatus.connected, errorMessage: 'Paused');
      case 'resumed':
        return const LFEvent(status: LFStatus.connected);
      case 'error':
        return LFEvent(status: LFStatus.error, errorMessage: e['message'] as String?);
      default:
        return const LFEvent(status: LFStatus.idle);
    }
  }
}

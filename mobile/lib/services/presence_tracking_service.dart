import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ble_service.dart';

/// Snapshot of a presence tracking session, emitted on every tick.
class PresenceState {
  final Duration elapsed;
  final Duration timePresent;
  final int presencePercentage; // 0-100
  final bool isCurrentlyNearby;
  final bool meetsRequirement;

  PresenceState({
    required this.elapsed,
    required this.timePresent,
    required this.presencePercentage,
    required this.isCurrentlyNearby,
    required this.meetsRequirement,
  });
}

/// Tracks whether a user remains near a BLE beacon over time and calculates
/// their actual presence percentage for duration-based campaigns.
class PresenceTrackingService {
  final BleService _bleService;

  Timer? _ticker;
  final _stateController = StreamController<PresenceState>.broadcast();

  // Session state
  String? _beaconId;
  String? _checkinId;
  int _requiredPercentage = 100;
  int _requiredDurationMinutes = 0;

  DateTime? _sessionStart;
  int _presentTicks = 0;
  int _totalTicks = 0;

  static const _tickInterval = Duration(seconds: 30);
  static const _nearbyThreshold = Duration(seconds: 60);
  static const _storageKey = 'presence_session';

  Stream<PresenceState> get stateStream => _stateController.stream;

  PresenceState? get currentState {
    if (_sessionStart == null) return null;
    return _buildState();
  }

  bool get isTracking => _ticker != null;

  PresenceTrackingService(this._bleService);

  /// Start tracking presence for a duration campaign check-in.
  Future<void> startTracking({
    required String beaconId,
    required String checkinId,
    required int requiredPercentage,
    required int requiredDurationMinutes,
  }) async {
    // Don't restart if already tracking the same checkin
    if (_checkinId == checkinId && _ticker != null) return;

    await stopTracking(persist: false);

    _beaconId = beaconId;
    _checkinId = checkinId;
    _requiredPercentage = requiredPercentage;
    _requiredDurationMinutes = requiredDurationMinutes;

    // Try to resume from a persisted session
    final resumed = await _tryResumeSession(checkinId);
    if (!resumed) {
      _sessionStart = DateTime.now();
      _presentTicks = 0;
      _totalTicks = 0;
    }

    // Record the first tick as present (user is here to start the session)
    if (_totalTicks == 0) {
      _totalTicks = 1;
      _presentTicks = 1;
    }

    _ticker = Timer.periodic(_tickInterval, (_) => _tick());
    _emitState();
    await _persistSession();

    // Start Android foreground service to keep BLE scanning alive
    if (Platform.isAndroid) {
      await _startForegroundTask();
    }

    debugPrint('Presence: started tracking beacon=$beaconId checkin=$checkinId');
  }

  /// Stop tracking and optionally persist the session for crash recovery.
  Future<void> stopTracking({bool persist = false}) async {
    _ticker?.cancel();
    _ticker = null;

    if (Platform.isAndroid) {
      await _stopForegroundTask();
    }

    if (!persist) {
      await _clearPersistedSession();
    }

    debugPrint('Presence: stopped tracking');
  }

  // -- Android foreground service --

  Future<void> _startForegroundTask() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'presence_tracking',
        channelName: 'Presence Tracking',
        channelDescription: 'Tracks your presence for attendance check-in',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(
          _tickInterval.inMilliseconds,
        ),
      ),
    );

    await FlutterForegroundTask.startService(
      notificationTitle: 'Tracking attendance',
      notificationText: 'Stay near the beacon for check-in',
    );
  }

  Future<void> _stopForegroundTask() async {
    await FlutterForegroundTask.stopService();
  }

  void _tick() {
    if (_beaconId == null) return;

    _totalTicks++;
    final nearby = _bleService.isBeaconNearby(_beaconId!, threshold: _nearbyThreshold);
    if (nearby) {
      _presentTicks++;
    }

    _emitState();
    _persistSession();

    debugPrint(
        'Presence tick: nearby=$nearby present=$_presentTicks/$_totalTicks '
        '(${_calculatePercentage()}%)');
  }

  int _calculatePercentage() {
    if (_totalTicks == 0) return 0;
    return ((_presentTicks / _totalTicks) * 100).round();
  }

  PresenceState _buildState() {
    final elapsed = DateTime.now().difference(_sessionStart!);
    final tickDurationSeconds = _tickInterval.inSeconds;
    final timePresent = Duration(seconds: _presentTicks * tickDurationSeconds);
    final percentage = _calculatePercentage();
    final nearby = _beaconId != null &&
        _bleService.isBeaconNearby(_beaconId!, threshold: _nearbyThreshold);

    final requiredDuration = Duration(minutes: _requiredDurationMinutes);
    final meetsRequirement =
        percentage >= _requiredPercentage && elapsed >= requiredDuration;

    return PresenceState(
      elapsed: elapsed,
      timePresent: timePresent,
      presencePercentage: percentage,
      isCurrentlyNearby: nearby,
      meetsRequirement: meetsRequirement,
    );
  }

  void _emitState() {
    if (_sessionStart == null) return;
    _stateController.add(_buildState());
  }

  // -- Persistence for crash/background recovery --

  Future<void> _persistSession() async {
    if (_checkinId == null || _sessionStart == null) return;

    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode({
      'checkin_id': _checkinId,
      'beacon_id': _beaconId,
      'session_start': _sessionStart!.toIso8601String(),
      'present_ticks': _presentTicks,
      'total_ticks': _totalTicks,
      'required_percentage': _requiredPercentage,
      'required_duration_minutes': _requiredDurationMinutes,
      'saved_at': DateTime.now().toIso8601String(),
    });
    await prefs.setString(_storageKey, data);
  }

  Future<bool> _tryResumeSession(String checkinId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return false;

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['checkin_id'] != checkinId) return false;

      _sessionStart = DateTime.parse(data['session_start']);
      _presentTicks = data['present_ticks'] as int;
      _totalTicks = data['total_ticks'] as int;
      _requiredPercentage = data['required_percentage'] as int;
      _requiredDurationMinutes = data['required_duration_minutes'] as int;

      // Estimate missed ticks while app was inactive
      final savedAt = DateTime.parse(data['saved_at']);
      final gap = DateTime.now().difference(savedAt);
      final missedTicks = gap.inSeconds ~/ _tickInterval.inSeconds;
      if (missedTicks > 0) {
        // Conservatively mark missed ticks as absent
        _totalTicks += missedTicks;
      }

      debugPrint('Presence: resumed session, missed ~$missedTicks ticks');
      return true;
    } catch (e) {
      debugPrint('Presence: failed to resume session: $e');
      return false;
    }
  }

  Future<void> _clearPersistedSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  /// Check if there's a persisted session for a given checkin.
  static Future<bool> hasPersistedSession(String checkinId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return false;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return data['checkin_id'] == checkinId;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    stopTracking();
    _stateController.close();
  }
}

/// Provider for PresenceTrackingService
final presenceTrackingServiceProvider = Provider<PresenceTrackingService>((ref) {
  final bleService = ref.read(bleServiceProvider);
  final service = PresenceTrackingService(bleService);
  ref.onDispose(() => service.dispose());
  return service;
});

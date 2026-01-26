import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Callback for when a notification is tapped
typedef NotificationTapCallback = void Function(String? payload);

/// Service for showing local push notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  NotificationTapCallback? _onNotificationTap;

  /// Initialize the notification service
  Future<void> initialize({NotificationTapCallback? onTap}) async {
    _onNotificationTap = onTap;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Request permissions on Android 13+
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.requestNotificationsPermission();
    }

    final ios = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  void _onNotificationResponse(NotificationResponse response) {
    _onNotificationTap?.call(response.payload);
  }

  /// Show a check-in notification
  Future<void> showCheckinNotification({
    required String campaignName,
    required String campaignId,
    String? locationDescription,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'checkin_channel',
      'Check-in Notifications',
      channelDescription: 'Notifications for nearby check-in locations',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'Check-in available',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final body = locationDescription != null
        ? 'You are near $campaignName ($locationDescription). Tap to check in.'
        : 'You are near $campaignName. Tap to check in.';

    await _notifications.show(
      campaignId.hashCode,
      'Check In Available',
      body,
      details,
      payload: campaignId,
    );
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(String campaignId) async {
    await _notifications.cancel(campaignId.hashCode);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}

/// Provider for notification service
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

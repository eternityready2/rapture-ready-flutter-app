import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Permission status simplified for the app's use.
enum NotificationPermissionStatus {
  granted,
  denied,
  notDetermined,
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await NotificationService.instance.setupFlutterNotifications();
  await NotificationService.instance.showNotification(message);
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _isFlutterLocalNotificationsInitialized = false;

  static const String _permissionStatusKey = 'notification_permission_status';

  /// Convert Firebase AuthorizationStatus into app-specific NotificationPermissionStatus.
  NotificationPermissionStatus _mapAuthStatusToPermission(AuthorizationStatus status) {
    switch (status) {
      case AuthorizationStatus.authorized:
      case AuthorizationStatus.provisional:
        return NotificationPermissionStatus.granted;
      case AuthorizationStatus.denied:
        return NotificationPermissionStatus.denied;
      case AuthorizationStatus.notDetermined:
      default:
        return NotificationPermissionStatus.notDetermined;
    }
  }

  /// Initialize notification permissions and services respecting saved permission.
  Future<void> initialize() async {
    final savedStatus = await _getSavedPermissionStatus();

    print('Saved notification permission status: $savedStatus');

    if (savedStatus == NotificationPermissionStatus.granted) {
      print('Notification permission previously granted. Setting up service...');
      await _setupFullNotificationService();
    } else if (savedStatus == NotificationPermissionStatus.notDetermined) {
      print('Notification permission not determined. Requesting permission...');
      try {
        final settings = await _requestPermission();
        final mappedStatus = _mapAuthStatusToPermission(settings.authorizationStatus);
        await _savePermissionStatus(mappedStatus);

        if (mappedStatus == NotificationPermissionStatus.granted) {
          print('Notification permission granted by user.');
          await _setupFullNotificationService();
        } else {
          print('Notification permission denied or provisional by user.');
        }
      } catch (e) {
        print('Warning: Failed to request permission: $e');
      }
    } else {
      print('Notification permission previously denied. Service not started.');
    }
  }
  Future<void> _setupFullNotificationService() async {
    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    } catch (e) {
      print('Warning: Failed to set background message handler: $e');
    }

    try {
      await _setupMessageHandlers();
    } catch (e) {
      print('Warning: Failed to setup message handlers: $e');
    }

    try {
      final token = await _messaging.getToken();
      print('FCM Token: $token');
    } catch (e) {
      print('Warning: Failed to get FCM token: $e');
    }
  }

  Future<NotificationPermissionStatus> _getSavedPermissionStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final statusString = prefs.getString(_permissionStatusKey);
    if (statusString == null) {
      return NotificationPermissionStatus.notDetermined;
    }
    return NotificationPermissionStatus.values.firstWhere(
      (e) => e.toString() == statusString,
      orElse: () => NotificationPermissionStatus.notDetermined,
    );
  }

  Future<void> _savePermissionStatus(NotificationPermissionStatus status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_permissionStatusKey, status.toString());
  }

  Future<NotificationSettings> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
    );

    print('Permission status: ${settings.authorizationStatus}');
    return settings;
  }

  Future<void> setupFlutterNotifications() async {
    if (_isFlutterLocalNotificationsInitialized) return;

    const channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    final iosSettings = DarwinInitializationSettings();

    final initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tapped logic, if needed
      },
    );

    _isFlutterLocalNotificationsInitialized = true;
  }

  Future<void> showNotification(RemoteMessage message) async {
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null && android != null) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            channelDescription: 'This channel is used for important notifications.',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/launcher_icon',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: message.data.toString(),
      );
    }
  }

  Future<void> _setupMessageHandlers() async {
    FirebaseMessaging.onMessage.listen((message) async {
      await setupFlutterNotifications();
      await showNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleBackgroundMessage(initialMessage);
    }
  }

  void _handleBackgroundMessage(RemoteMessage message) {
    print('Notification opened: $message');
    // Add further navigation or processing here if necessary
  }
}


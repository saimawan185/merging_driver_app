import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:door_delights_driver/app/chat_screens/chat_screen.dart';
import 'package:door_delights_driver/app/dash_board_screen/dash_board_screen.dart';
import 'package:door_delights_driver/constant/constant.dart';
import 'package:door_delights_driver/constant/show_toast_dialog.dart';
import 'package:door_delights_driver/controllers/dash_board_controller.dart';
import 'package:door_delights_driver/firebase_options.dart';
import 'package:door_delights_driver/models/user_model.dart';
import 'package:door_delights_driver/services/incoming_order_handler.dart';
import 'package:door_delights_driver/utils/fire_store_utils.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart' hide Trans;
import 'package:easy_localization/easy_localization.dart';

import 'preferences.dart';

// ─── TOP-LEVEL BACKGROUND HANDLER ──────────────────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessageBackgroundHandle(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}

  final data = Map<String, dynamic>.from(message.data);
  final title = message.notification?.title ??
      (data['title'] ?? data['subject'] ?? '').toString();
  final body = message.notification?.body ??
      (data['body'] ?? data['message'] ?? '').toString();
  final type = (data['type'] ?? '').toString();

  if (!IncomingOrderHandler.looksLikeNewOrderNotification(
    type: type,
    title: title,
    data: data,
  )) {
    return;
  }

  try {
    await Preferences.initPref();
    await IncomingOrderHandler.savePending(
      orderId: (data['orderId'] ?? '').toString(),
      type:
          type.isEmpty ? IncomingOrderHandler.inferTypeFromTitle(title) : type,
      title: title,
      body: body,
      preview: IncomingOrderHandler.extractPreview(data),
    );
  } catch (e) {
    log('background savePending failed: $e');
  }

  // On Android the native IncomingOrderActivity shows the half-screen UI.
  // Avoid a second tray-only notification from Flutter.
  if (!Platform.isAndroid) {
    await NotificationService.showIncomingOrderFullScreenIntent(
      title: title.isEmpty ? 'New Order Request' : title,
      body: body,
      data: data,
    );
  }
}

// ─── TOP-LEVEL BACKGROUND TAP HANDLER ──────────────────────────────────
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  try {
    if (response.payload == null || response.payload!.isEmpty) return;
    final data = jsonDecode(response.payload!) as Map<String, dynamic>;
    debugPrint(
      'notificationTapBackground orderId=${data['orderId']} type=${data['type']}',
    );
  } catch (e) {
    debugPrint('notificationTapBackground error: $e');
  }
}

// ─── NOTIFICATION SERVICE ──────────────────────────────────────────────
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String orderChannelId = 'incoming_order_fullscreen';
  static const String orderChannelName = 'Incoming Order Requests';
  static const String defaultChannelId = 'channel_id';
  static const String defaultChannelName = 'High Importance Notifications';

  static String? _lastPayloadHash;

  static bool _isDuplicate(Map<String, dynamic> data) {
    final hash = jsonEncode(data);
    if (_lastPayloadHash == hash) return true;
    _lastPayloadHash = hash;
    return false;
  }

  // ─── Initialisation ──────────────────────────────────────────────────
  Future<void> initInfo() async {
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    final request = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (request.authorizationStatus == AuthorizationStatus.authorized ||
        request.authorizationStatus == AuthorizationStatus.provisional) {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();

      final settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );

      await _createChannels();

      if (Platform.isAndroid) {
        await _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
        await _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestFullScreenIntentPermission();
      }

      await _handleLaunchFromNotification();
      _setupInteractedMessage();
    }
  }

  Future<void> _createChannels() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    // Default channel for regular notifications
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        defaultChannelId,
        defaultChannelName,
        description: 'This channel is used for important notifications.',
        importance: Importance.high,
        sound: RawResourceAndroidNotificationSound('notification_sound'),
      ),
    );

    // Order channel for full-screen notifications
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        orderChannelId,
        orderChannelName,
        description:
            'Full-screen alerts for new ride and order requests when the app is closed.',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        sound: RawResourceAndroidNotificationSound('notification_sound'),
      ),
    );
  }

  Future<void> _handleLaunchFromNotification() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return;
    final response = details!.notificationResponse;
    if (response != null) await _onNotificationResponse(response);
  }

  static Future<void> _onNotificationResponse(
      NotificationResponse response) async {
    if (response.payload == null || response.payload!.isEmpty) return;
    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      await _openIncomingOrderFromPayload(data);
    } catch (e) {
      log('_onNotificationResponse error: $e');
    }
  }

  static Future<void> _openIncomingOrderFromPayload(
      Map<String, dynamic> data) async {
    final type = (data['type'] ?? '').toString();
    final role = (data['chatType'] ?? '').toString();
    final orderId = (data['orderId'] ?? '').toString();
    final senderId = (data['senderId'] ?? '').toString();
    final title = (data['title'] ?? '').toString();
    final body = (data['body'] ?? '').toString();
    final action = (data['action'] ?? '').toString();

    if (IncomingOrderHandler.looksLikeNewOrderNotification(
      type: type,
      title: title,
      data: data,
    )) {
      if (action == IncomingOrderHandler.acceptAction ||
          action == IncomingOrderHandler.declineAction) {
        await IncomingOrderHandler.savePending(
          orderId: orderId,
          type: type.isEmpty
              ? IncomingOrderHandler.inferTypeFromTitle(title)
              : type,
          action: action,
          title: title,
          body: body,
          preview: IncomingOrderHandler.extractPreview(data),
        );
        if (Constant.userModel != null) {
          await IncomingOrderHandler.handlePendingIfAny();
        }
      }
      return;
    }

    await handleMessageClick(
      type: type,
      role: role,
      orderId: orderId,
      senderId: senderId,
    );
  }

  void _setupInteractedMessage() {
    // App opened from terminated state
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) _handleRemoteOpen(message);
    });

    // App opened from background
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      if (message != null) _handleRemoteOpen(message);
    });

    // App in foreground: show tray notification
    FirebaseMessaging.onMessage.listen((message) async {
      final data = Map<String, dynamic>.from(message.data);
      final title =
          message.notification?.title ?? (data['title'] ?? '').toString();
      final body =
          message.notification?.body ?? (data['body'] ?? '').toString();
      final type = (data['type'] ?? '').toString();

      if (IncomingOrderHandler.looksLikeNewOrderNotification(
        type: type,
        title: title,
        data: data,
      )) {
        await showIncomingOrderTrayNotification(
          title: title.isEmpty ? 'New Order Request'.tr() : title,
          body: body,
          data: data,
        );
      } else if (message.notification != null) {
        await _showDisplayNotification(message);
      }
    });

    FirebaseMessaging.instance.subscribeToTopic("driver");
  }

  Future<void> _handleRemoteOpen(RemoteMessage message) async {
    final data = Map<String, dynamic>.from(message.data);
    final type = (data['type'] ?? '').toString();
    final role = (data['chatType'] ?? '').toString();
    final orderId = (data['orderId'] ?? '').toString();
    final senderId = (data['senderId'] ?? '').toString();
    final title =
        message.notification?.title ?? (data['title'] ?? '').toString();
    final body = message.notification?.body ?? (data['body'] ?? '').toString();

    if (IncomingOrderHandler.looksLikeNewOrderNotification(
      type: type,
      title: title,
      data: data,
    )) {
      final action = (data['action'] ?? '').toString();
      if (action == IncomingOrderHandler.acceptAction ||
          action == IncomingOrderHandler.declineAction) {
        await IncomingOrderHandler.savePending(
          orderId: orderId,
          type: type.isEmpty
              ? IncomingOrderHandler.inferTypeFromTitle(title)
              : type,
          action: action,
          title: title,
          body: body,
          preview: IncomingOrderHandler.extractPreview(data),
        );
        if (Constant.userModel != null) {
          await IncomingOrderHandler.handlePendingIfAny();
        }
      }
      return;
    }

    await handleMessageClick(
      type: type,
      role: role,
      orderId: orderId,
      senderId: senderId,
    );
  }

  // ─── Display Notification ────────────────────────────────────────────
  Future<void> _showDisplayNotification(RemoteMessage message) async {
    try {
      final isOrderRelated =
          message.notification!.title.toString().toLowerCase().contains('new');

      final androidDetails = AndroidNotificationDetails(
        defaultChannelId,
        defaultChannelName,
        channelDescription: 'Show DoorDelights Driver App Notification',
        importance: Importance.high,
        priority: Priority.high,
        ticker: 'ticker',
        sound: isOrderRelated
            ? const RawResourceAndroidNotificationSound('notification_sound')
            : null,
      );

      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: isOrderRelated ? 'notification_sound.wav' : null,
      );

      await _plugin.show(
        0,
        message.notification!.title,
        message.notification!.body,
        NotificationDetails(android: androidDetails, iOS: iosDetails),
        payload: jsonEncode(message.data),
      );
    } catch (e) {
      log('_showDisplayNotification error: $e');
    }
  }

  // ─── Incoming Order Notifications ──────────────────────────────────
  static Future<void> showIncomingOrderFullScreenIntent({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    final payloadMap = Map<String, dynamic>.from(data);
    payloadMap['title'] = title;
    payloadMap['body'] = body;
    if ((payloadMap['type'] ?? '').toString().isEmpty) {
      payloadMap['type'] = IncomingOrderHandler.inferTypeFromTitle(title);
    }

    final androidDetails = AndroidNotificationDetails(
      orderChannelId,
      orderChannelName,
      channelDescription: 'Incoming order / ride full-screen alerts',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.call,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('notification_sound'),
      ticker: 'New order request',
      autoCancel: true,
      ongoing: false,
      styleInformation: BigTextStyleInformation(
        body.isEmpty ? title : body,
        contentTitle: title,
        summaryText: 'Door Delights Driver',
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'notification_sound.wav',
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    await _plugin.show(
      IncomingOrderHandler.orderNotificationId,
      title,
      body.isEmpty ? 'New order request' : body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: jsonEncode(payloadMap),
    );
  }

  static Future<void> showIncomingOrderTrayNotification({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    // Avoid duplicate notifications
    if (_isDuplicate(data)) return;

    final payloadMap = Map<String, dynamic>.from(data);
    payloadMap['title'] = title;
    payloadMap['body'] = body;
    if ((payloadMap['type'] ?? '').toString().isEmpty) {
      payloadMap['type'] = IncomingOrderHandler.inferTypeFromTitle(title);
    }

    final androidDetails = AndroidNotificationDetails(
      orderChannelId,
      orderChannelName,
      channelDescription: 'Incoming order / ride alerts',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.call,
      fullScreenIntent: false,
      visibility: NotificationVisibility.public,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('notification_sound'),
      ticker: 'New order request',
      autoCancel: true,
      ongoing: false,
      styleInformation: BigTextStyleInformation(
        body.isEmpty ? title : body,
        contentTitle: title,
        summaryText: 'Door Delights Driver',
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'notification_sound.wav',
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    await _plugin.show(
      IncomingOrderHandler.orderNotificationId,
      title,
      body.isEmpty ? 'New order request' : body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: jsonEncode(payloadMap),
    );
  }

  // ─── Token ──────────────────────────────────────────────────────────
  static Future<String> getToken() async {
    try {
      return await FirebaseMessaging.instance.getToken() ?? '';
    } catch (e) {
      log('getToken error: $e');
      return '';
    }
  }

  // ─── Message Click Handling ──────────────────────────────────────
  static Future<void> handleMessageClick({
    required String type,
    required String role,
    String? senderId,
    String? orderId,
  }) async {
    final String uid = FireStoreUtils.getCurrentUid();
    if (type == 'admin_chat' && uid.isNotEmpty) {
      // Use Get.find if already registered, otherwise Get.put
      DashBoardController? controller;
      try {
        controller = Get.find<DashBoardController>();
      } catch (_) {
        controller = Get.put(DashBoardController());
      }
      controller?.drawerIndex.value = 7;
      Get.offAll(const DashBoardScreen());
    } else if (type == 'orderChat') {
      ShowToastDialog.showLoader("Please wait".tr());
      try {
        final customer = await FireStoreUtils.getUserProfile(senderId!);
        final driver = await FireStoreUtils.getUserProfile(uid);
        ShowToastDialog.closeLoader();

        if (customer == null || driver == null) {
          ShowToastDialog.showToast("User not found");
          return;
        }

        DashBoardController? dashBoardController;
        try {
          dashBoardController = Get.find<DashBoardController>();
        } catch (_) {
          dashBoardController = Get.put(DashBoardController());
        }
        dashBoardController?.drawerIndex.value = 5;
        Get.offAll(const DashBoardScreen());

        Get.to(
          () => const ChatScreen(),
          arguments: {
            "senderName": driver.fullName(),
            "senderId": driver.id,
            "senderProfileUrl": driver.profilePictureURL ?? "",
            "receivedName": customer.fullName(),
            "receivedId": customer.id,
            "receivedProfileUrl": customer.profilePictureURL ?? "",
            "orderId": orderId,
            "token": customer.fcmToken,
            "chatType": Constant.userRoleDriver,
          },
        );
      } catch (e) {
        ShowToastDialog.closeLoader();
        log('handleMessageClick error: $e');
      }
    }
  }
}

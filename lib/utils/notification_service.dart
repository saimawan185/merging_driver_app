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
import 'package:door_delights_driver/utils/preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart' hide Trans;
import 'package:easy_localization/easy_localization.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessageBackgroundHandle(RemoteMessage message) async {
  log("BackGround Message :: ${message.messageId} data=${message.data}");
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
      type: type.isEmpty
          ? IncomingOrderHandler.inferTypeFromTitle(title)
          : type,
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

class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String orderChannelId = 'incoming_order_fullscreen';
  static const String orderChannelName = 'Incoming Order Requests';
  static const String defaultChannelId = 'channel_id';

  Future<void> initInfo() async {
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    var request = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (request.authorizationStatus == AuthorizationStatus.authorized ||
        request.authorizationStatus == AuthorizationStatus.provisional) {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iosInitializationSettings =
          DarwinInitializationSettings();

      final InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: iosInitializationSettings,
      );

      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );

      await _createChannels();
      if (Platform.isAndroid) {
        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestFullScreenIntentPermission();
      }

      await _handleLaunchFromNotification();
      setupInteractedMessage();
    }
  }

  Future<void> _createChannels() async {
    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        defaultChannelId,
        'High Importance Notifications',
        description: 'This channel is used for important notifications.',
        importance: Importance.high,
        sound: RawResourceAndroidNotificationSound('notification_sound'),
      ),
    );

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
    final details = await flutterLocalNotificationsPlugin
        .getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return;
    final response = details!.notificationResponse;
    if (response == null) return;
    await _onNotificationResponse(response);
  }

  Future<void> _onNotificationResponse(NotificationResponse response) async {
    if (response.payload == null || response.payload!.isEmpty) return;
    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      await _openIncomingOrderFromPayload(data);
    } catch (e) {
      log('onNotificationResponse error: $e');
    }
  }

  Future<void> _openIncomingOrderFromPayload(Map<String, dynamic> data) async {
    final String type = (data['type'] ?? '').toString();
    final String role = (data['chatType'] ?? '').toString();
    final String orderId = (data['orderId'] ?? '').toString();
    final String senderId = (data['senderId'] ?? '').toString();
    final String title = (data['title'] ?? '').toString();
    final String body = (data['body'] ?? '').toString();
    final String action = (data['action'] ?? '').toString();

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

    handleMessageClick(
        type: type, role: role, orderId: orderId, senderId: senderId);
  }

  Future<void> setupInteractedMessage() async {
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      await _handleRemoteOpen(initialMessage);
    }

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage? message) {
      if (message != null) {
        _handleRemoteOpen(message);
      }
    });

    // App in foreground: show tray notification only (no half-screen popup).
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final data = Map<String, dynamic>.from(message.data);
      final title = message.notification?.title ??
          (data['title'] ?? '').toString();
      final body = message.notification?.body ??
          (data['body'] ?? '').toString();
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
        display(message);
      }
    });

    await FirebaseMessaging.instance.subscribeToTopic("driver");
  }

  Future<void> _handleRemoteOpen(RemoteMessage message) async {
    final data = Map<String, dynamic>.from(message.data);
    final String type = (data['type'] ?? '').toString();
    final String role = (data['chatType'] ?? '').toString();
    final String orderId = (data['orderId'] ?? '').toString();
    final String senderId = (data['senderId'] ?? '').toString();
    final title = message.notification?.title ??
        (data['title'] ?? '').toString();
    final body = message.notification?.body ??
        (data['body'] ?? '').toString();

      if (IncomingOrderHandler.looksLikeNewOrderNotification(
        type: type,
        title: title,
        data: data,
      )) {
        final action = (data['action'] ?? '').toString();
        // Only process Accept/Decline from native closed-app popup.
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

      handleMessageClick(
          type: type, role: role, orderId: orderId, senderId: senderId);
  }

  static Future<String> getToken() async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      return token!;
    } catch (e) {
      return '';
    }
  }

  /// Wakes the phone / brings app over other apps, then Flutter shows the
  /// half-screen order design. No Accept/Decline on the notification tray.
  static Future<void> showIncomingOrderFullScreenIntent({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    final plugin = FlutterLocalNotificationsPlugin();
    final payloadMap = Map<String, dynamic>.from(data);
    payloadMap['title'] = title;
    payloadMap['body'] = body;
    if ((payloadMap['type'] ?? '').toString().isEmpty) {
      payloadMap['type'] = IncomingOrderHandler.inferTypeFromTitle(title);
    }

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
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

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'notification_sound.wav',
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    await plugin.show(
      IncomingOrderHandler.orderNotificationId,
      title,
      body.isEmpty ? 'New order request' : body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: jsonEncode(payloadMap),
    );
  }

  /// Tray notification while app is open (no full-screen / half-screen UI).
  static Future<void> showIncomingOrderTrayNotification({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    final plugin = FlutterLocalNotificationsPlugin();
    final payloadMap = Map<String, dynamic>.from(data);
    payloadMap['title'] = title;
    payloadMap['body'] = body;
    if ((payloadMap['type'] ?? '').toString().isEmpty) {
      payloadMap['type'] = IncomingOrderHandler.inferTypeFromTitle(title);
    }

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
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

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'notification_sound.wav',
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    await plugin.show(
      IncomingOrderHandler.orderNotificationId,
      title,
      body.isEmpty ? 'New order request' : body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: jsonEncode(payloadMap),
    );
  }

  /// Kept for older call sites; redirects to full-screen intent (no actions).
  static Future<void> showIncomingOrderNotification({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) =>
      showIncomingOrderFullScreenIntent(
          title: title, body: body, data: data);

  void display(RemoteMessage message) async {
    try {
      AndroidNotificationChannel channel = const AndroidNotificationChannel(
        "01",
        "DoorDelights Driver App_driver",
        description: 'Show DoorDelights Driver App Notification',
        importance: Importance.max,
      );
      AndroidNotificationDetails notificationDetails =
          AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: 'Order notification sound',
        importance: Importance.high,
        priority: Priority.high,
        ticker: 'ticker',
        sound:
            message.notification!.title.toString().toLowerCase().contains('new')
                ? const RawResourceAndroidNotificationSound(
                    'notification_sound')
                : null,
      );

      DarwinNotificationDetails darwinNotificationDetails =
          DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
              sound: message.notification!.title
                      .toString()
                      .toLowerCase()
                      .contains('new')
                  ? 'notification_sound.wav'
                  : null);

      NotificationDetails notificationDetailsBoth = NotificationDetails(
          android: notificationDetails, iOS: darwinNotificationDetails);

      await FlutterLocalNotificationsPlugin().show(
        0,
        message.notification!.title,
        message.notification!.body,
        notificationDetailsBoth,
        payload: jsonEncode(message.data),
      );
    } on Exception catch (e) {
      log(e.toString());
    }
  }

  Future<void> handleMessageClick(
      {required String type,
      String? senderId,
      String? orderId,
      required String role}) async {
    final String uid = FireStoreUtils.getCurrentUid();
    if (type == 'admin_chat' && uid.isNotEmpty) {
      DashBoardController controller = Get.put(DashBoardController());
      controller.drawerIndex.value = 7;
      Get.offAll(DashBoardScreen());
    } else if (type == 'orderChat') {
      ShowToastDialog.showLoader("Please wait".tr());
      log("Customer Notification :: $senderId :: ${FireStoreUtils.getCurrentUid()}");
      UserModel? customer =
          await FireStoreUtils.getUserProfile(senderId.toString());
      UserModel? driver =
          await FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid());
      ShowToastDialog.closeLoader();
      DashBoardController dashBoardScreen = Get.put(DashBoardController());
      dashBoardScreen.drawerIndex.value = 5;
      Get.offAll(DashBoardScreen());
      Get.to(const ChatScreen(), arguments: {
        "senderName": driver!.fullName(),
        "senderId": driver.id,
        "senderProfileUrl": driver.profilePictureURL ?? "",
        "receivedName": customer!.fullName(),
        "receivedId": customer.id,
        "receivedProfileUrl": customer.profilePictureURL ?? "",
        "orderId": orderId,
        "token": customer.fcmToken,
        "chatType": Constant.userRoleDriver,
      });
    }
  }
}

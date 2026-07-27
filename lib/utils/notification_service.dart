import 'dart:convert';
import 'dart:developer';
import 'package:door_delights_driver/app/chat_screens/chat_screen.dart';
import 'package:door_delights_driver/app/dash_board_screen/dash_board_screen.dart';
import 'package:door_delights_driver/constant/constant.dart';
import 'package:door_delights_driver/constant/show_toast_dialog.dart';
import 'package:door_delights_driver/controllers/dash_board_controller.dart';
import 'package:door_delights_driver/models/user_model.dart';
import 'package:door_delights_driver/utils/fire_store_utils.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart' hide Trans;
import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization/easy_localization.dart';

Future<void> firebaseMessageBackgroundHandle(RemoteMessage message) async {
  log("BackGround Message :: ${message.messageId}");
}

class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

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
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (response.payload != null) {
            final data = jsonDecode(response.payload!);
            final String type = data['type'] ?? '';
            final String role = data['chatType'] ?? '';
            final String orderId = data['orderId'] ?? '';
            final String senderId = data['senderId'] ?? '';
            handleMessageClick(
                type: type, role: role, orderId: orderId, senderId: senderId);
          }
        },
      );

      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'channel_id',
        'High Importance Notifications',
        description: 'This channel is used for important notifications.',
        importance: Importance.high,
        sound: RawResourceAndroidNotificationSound('notification_sound'),
      );

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      setupInteractedMessage();
    }
  }

  Future<void> setupInteractedMessage() async {
    // App opened from terminated state
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      final String type = initialMessage.data['type'] ?? '';
      final String role = initialMessage.data['chatType'] ?? '';
      final String orderId = initialMessage.data['orderId'] ?? '';
      final String senderId = initialMessage.data['senderId'] ?? '';
      handleMessageClick(
          type: type, role: role, orderId: orderId, senderId: senderId);
    }

    // App in background and notification tapped
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage? message) {
      if (message != null) {
        final String type = message.data['type'] ?? '';
        final String role = message.data['chatType'] ?? '';
        final String orderId = message.data['orderId'] ?? '';
        final String senderId = message.data['senderId'] ?? '';
        handleMessageClick(
            type: type, role: role, orderId: orderId, senderId: senderId);
      }
    });

    // App in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        display(message);
      }
    });

    await FirebaseMessaging.instance.subscribeToTopic("driver");
  }

  static Future<String> getToken() async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      return token!;
    } catch (e) {
      return '';
    }
  }

  void display(RemoteMessage message) async {
    try {
      // final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

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
                ? RawResourceAndroidNotificationSound('notification_sound')
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

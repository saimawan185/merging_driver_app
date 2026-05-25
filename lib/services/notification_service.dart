import 'dart:convert';
import 'dart:developer';

import 'package:door_delights_driver/main.dart';
import 'package:door_delights_driver/rental_service/rental_service_dashboard.dart';
import 'package:door_delights_driver/services/helper.dart';
import 'package:door_delights_driver/ui/chat_screen/chat_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

Future<void> firebaseMessageBackgroundHandle(RemoteMessage message) async {
  log("BackGround Message :: ${message.messageId}");
}

class NotificationService {
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final GlobalKey<NavigatorState> navigatorKey =
      new GlobalKey<NavigatorState>();

  initInfo() async {
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    var request = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (request.authorizationStatus == AuthorizationStatus.authorized ||
        request.authorizationStatus == AuthorizationStatus.provisional) {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      var iosInitializationSettings = const DarwinInitializationSettings();
      final InitializationSettings initializationSettings =
          InitializationSettings(
              android: initializationSettingsAndroid,
              iOS: iosInitializationSettings);
      await flutterLocalNotificationsPlugin.initialize(
          settings: initializationSettings,
          onDidReceiveNotificationResponse: (payload) {});

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
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      FirebaseMessaging.onBackgroundMessage(
          (message) => firebaseMessageBackgroundHandle(message));
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        display(message);
      }
    });
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (message.notification != null) {
        log(message.notification.toString());
        // display(message);

        String orderId = message.data['orderId'];
        if (message.data['type'] == 'rental_order') {
          pushReplacement(
              navigatorKey.currentContext!,
              RentalServiceDashBoard(
                user: MyAppState.currentUser!,
              ));
        } else if (message.data['type'] == 'cab_parcel_chat' ||
            message.data['type'] == 'vendor_chat') {
          push(
              navigatorKey.currentContext!,
              ChatScreens(
                orderId: orderId,
                customerId: message.data['customerId'],
                customerName: message.data['customerName'],
                customerProfileImage: message.data['customerProfileImage'],
                restaurantId: message.data['restaurantId'],
                restaurantName: message.data['restaurantName'],
                restaurantProfileImage: message.data['restaurantProfileImage'],
                token: message.data['token'],
                chatType: message.data['chatType'],
                type: message.data['type'],
              ));
        } else {
          /// receive message through inbox
          push(
              navigatorKey.currentContext!,
              ChatScreens(
                orderId: orderId,
                customerId: message.data['customerId'],
                customerName: message.data['customerName'],
                customerProfileImage: message.data['customerProfileImage'],
                restaurantId: message.data['restaurantId'],
                restaurantName: message.data['restaurantName'],
                restaurantProfileImage: message.data['restaurantProfileImage'],
                token: message.data['token'],
                chatType: message.data['chatType'],
              ));
        }
      }
    });
    try {
      await FirebaseMessaging.instance.subscribeToTopic("QuicklAI");
    } catch (e) {}
  }

  static Future<String> getToken() async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      return token!;
    } catch (e) {
      log("Error getting token: ${e.toString()}");
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
        channelDescription: 'your channel Description',
        importance: Importance.high,
        priority: Priority.high,
        ticker: 'ticker',
        sound: message.notification!.title
                .toString()
                .toLowerCase()
                .contains('New'.toLowerCase())
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
                      .contains('New'.toLowerCase())
                  ? 'notification_sound.wav'
                  : null);

      NotificationDetails notificationDetailsBoth = NotificationDetails(
          android: notificationDetails, iOS: darwinNotificationDetails);

      await FlutterLocalNotificationsPlugin().show(
        id: 0,
        title: message.notification!.title,
        body: message.notification!.body,
        notificationDetails: notificationDetailsBoth,
        payload: jsonEncode(message.data),
      );
    } on Exception catch (e) {
      log(e.toString());
    }
  }
}

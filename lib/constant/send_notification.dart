import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:door_delights_driver/constant/constant.dart';
import 'package:door_delights_driver/models/notification_model.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import '../constants.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;

class SendNotification {
  static Future getCharacters() {
    return http.get(Uri.parse(Constant.jsonNotificationFileURL.toString()));
  }

  static Future<String> getAccessToken() async {
    final serviceAccJson = {
      "type": "service_account",
      "project_id": "doordelights-423407",
      "private_key_id": "619f3cecaa6fd3c901c87e7c283d7430c7d3dfed",
      "private_key":
          "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDDkffgHSd0p2lV\nCXGBJWTWiLi1eg+JaQgy/2105rFPQle47EuTZkcKiFlhybW8SnteqPHLWYDaMj97\nkGxKzuu9xQxvzjzIyjHCCTFRtvmaZEzIL9etJP2Or6B3su3OuvjufrOci/YPOJSg\nLJJp/DbtVK2MdPNEsrBQZ1WYWWrfHsGCJnFLZozXUIrZ5cHTtAmfQaxGhpnwlk4M\nbt15uYboTtKMZBnR+ghYE59y7/WxgG5h7IhpgtRbzA57R9V/H7jZz0qew6cE3vjA\nJgcWsSZQJvSKA6ehk1lrb9IWuBC8JqsMl5MUDyTLbL7MknAVggYWsjpbnz5zVRWX\nZzKJX04rAgMBAAECggEAPmDnDrFN3evt8WUvMnGibbkzLRMvNHVvW5DUMUbJxE2V\nXFLmMjAbtbTSyZmEYXfiTMmXQfSc4DvJuthQajYAxEk/E8RU5/hyEYFMHVO+3mti\ngDGeWcgkJehHxxYnutoxPyTjlimgRK+X3FULKEn9nQp2xoeg9kcGbMbg6tSOfXar\noE1ZxmvfhONIVNb9z78bknGIw0NNkh97W1IJmZmllfFHqwtSeRL4lXGuCTWFTCCv\n1yG3X8GrBHuteVItR4j40J9GrlLk8Yq429xTVJ4ywun8djzCQ75+oU90vbv6ccbN\nQn4FFnuKq6XK2iFsO2moWmJ8R16jbPCLhypcgGAVeQKBgQDjyStdljzf2z3lVjgm\nL3jsFKQOuu+3m4JbU0Bnv/aVOvt1/kqun5pemqHSOxaC0IHQkLEszglC7f+Kn20M\n9bdndXC1dcunDVN3gNh3RtMcZfGYjVObp3IgntSXguTkeM3pQDF79BeCTlM8KYK5\nU9oF9VnTltJknmB3gbl7sxruUwKBgQDby0cXdT0yoVnwNkGgYlzdEVv59jV1BMsv\nLo/Q/74XkUH51g4iFb3QbCQoT5U6ZrLe5hZfYTErBQs8wqL/hzfm+QaLDJLgClws\nIZ7nAODkyZeg+GR6aYEzgtMidhS6QtRO1aXVbVjK3rmf1YuV2fk5Tb92RM92Q8n8\nqe1HaDE1yQKBgQCeOv8hypxM0IplhggJFo8ER65TAS5GOANMlz81EtcigM9u/o84\nUGw2bWodlKglhNu4WtqIijNKx/Lsg6SIDSQy/RSnKMWoLIyfheRYrt01a+dwljPO\n+3k/CbYZ7XY882HuNoZpWXz/KpONRjSlsobP/shAQBO0i4PtYDLNp/P8OwKBgEq8\n876hSh8GSLvq5yPvbp5pgboco47YA3NWxOaPoAcJiMK4q/OhKvtNWnounZLPSzGK\nUb87IGn9fBW8JYr4YuTyduwfaW4vd6o2AH+Sh+akOiAtdpU9fQaUDNFiD6hKg0EP\nWyWY2iGZ3Mrh5WYeSaXXryw7N8SCRpPZAGtQnbMpAoGBAL17pMbi22PrCERJ3PAS\nFM2QfZ2HGKA9wEnWOERZ3u0oqfSX3BwdrWSivRUp4IhDQ1PKYJju0VaYmiAiK1SC\nJ5Mx4KMh3dew50xfoUXt4pxTxuhr8N8M0h/H/TKgcwTUy6B8kPmPLBE0ABF0eZkE\nE/daRfx0PQbOMfNydui/mPal\n-----END PRIVATE KEY-----\n",
      "client_email": "doordelights-423407@appspot.gserviceaccount.com",
      "client_id": "114396527611623662050",
      "auth_uri": "https://accounts.google.com/o/oauth2/auth",
      "token_uri": "https://oauth2.googleapis.com/token",
      "auth_provider_x509_cert_url":
          "https://www.googleapis.com/oauth2/v1/certs",
      "client_x509_cert_url":
          "https://www.googleapis.com/robot/v1/metadata/x509/doordelights-423407%40appspot.gserviceaccount.com",
      "universe_domain": "googleapis.com",
    };

    List<String> scopes = [
      'https://www.googleapis.com/auth/userinfo.email',
      'https://www.googleapis.com/auth/firebase.database',
      'https://www.googleapis.com/auth/firebase.messaging',
    ];

    http.Client client = await auth.clientViaServiceAccount(
      auth.ServiceAccountCredentials.fromJson(serviceAccJson),
      scopes,
    );

    auth.AccessCredentials credentials =
        await auth.obtainAccessCredentialsViaServiceAccount(
      auth.ServiceAccountCredentials.fromJson(serviceAccJson),
      scopes,
      client,
    );

    client.close();

    return credentials.accessToken.data;
  }

  static Future<NotificationModel?> getNotificationContent(String type) async {
    NotificationModel? notificationModel;
    await FirebaseFirestore.instance
        .collection(dynamicNotification)
        .where('type', isEqualTo: type)
        .get()
        .then((value) {
      print("------>");
      if (value.docs.isNotEmpty) {
        print(value.docs.first.data());

        notificationModel = NotificationModel.fromJson(
          value.docs.first.data(),
        );
      } else {
        notificationModel = NotificationModel(
          id: "",
          message: "Notification setup is pending",
          subject: "setup notification",
          type: "",
        );
      }
    });
    return notificationModel;
  }

  static Future<bool> sendFcmMessage(
    String type,
    String token,
    Map<String, dynamic>? payload,
  ) async {
    try {
      final String serverAccessToken = await getAccessToken();

      NotificationModel? notificationModel = await getNotificationContent(type);
      var url =
          'https://fcm.googleapis.com/v1/projects/doordelights-423407/messages:send';
      var header = {
        "Content-Type": "application/json",
        "Authorization": "Bearer $serverAccessToken",
      };

      var request = {
        "message": {
          "token": token,
          "notification": {
            "body": notificationModel!.message ?? '',
            "title": notificationModel.subject ?? '',
          },
          'data': payload ?? <String, dynamic>{},
          "android": {
            "notification": {"click_action": "FLUTTER_NOTIFICATION_CLICK"},
          },
          "apns": {
            "headers": {"apns-priority": "10", "apns-push-type": "alert"},
            "payload": {
              "aps": {
                "alert": {
                  "title": notificationModel.subject ?? '',
                  "body": notificationModel.message ?? '',
                },
                "sound":
                    notificationModel.subject.toString().toLowerCase().contains(
                              'New'.toLowerCase(),
                            )
                        ? "notification_sound.wav"
                        : "default",
                "badge": 1,
              },
            },
          },
        },
      };

      var client = new http.Client();
      await client.post(
        Uri.parse(url),
        headers: header,
        body: json.encode(request),
      );
      return true;
    } catch (e) {
      debugPrint(e.toString());
      return false;
    }
  }

  static Future<bool> sendOneNotification(
      {required String token,
      required String title,
      required String body,
      required Map<String, dynamic> payload}) async {
    try {
      final String accessToken = await getAccessToken();
      debugPrint("accessToken=======>");
      debugPrint(accessToken);

      final response = await http.post(
        Uri.parse(
            'https://fcm.googleapis.com/v1/projects/${Constant.senderId}/messages:send'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(
          <String, dynamic>{
            'message': {
              'token': token,
              'notification': {'body': body, 'title': title},
              'data': payload,
            }
          },
        ),
      );

      debugPrint("Notification=======>");
      debugPrint(response.statusCode.toString());
      debugPrint(response.body);
      return true;
    } catch (e) {
      debugPrint(e.toString());
      return false;
    }
  }

  static Future<bool> sendChatFcmMessage(String title, String message,
      String token, Map<String, dynamic>? payload) async {
    try {
      final String accessToken = await getAccessToken();
      final response = await http.post(
        Uri.parse(
            'https://fcm.googleapis.com/v1/projects/${Constant.senderId}/messages:send'),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(
          <String, dynamic>{
            'message': {
              'token': token,
              'notification': {'body': message, 'title': title},
              'data': payload,
            }
          },
        ),
      );
      debugPrint("Notification=======>");
      debugPrint(response.statusCode.toString());
      debugPrint(response.body);
      return true;
    } catch (e) {
      print(e);
      return false;
    }
  }
}

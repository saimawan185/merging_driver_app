import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:door_delights_driver/model/mail_setting.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'model/CurrencyModel.dart';
import 'models/tax_model.dart';

const FINISHED_ON_BOARDING = 'finishedOnBoarding';
LocationData? locationDataFinal;

const COLOR_ACCENT = 0xFF8fd468;
const COLOR_PRIMARY_DARK = 0xFF2c7305;
var COLOR_PRIMARY = 0xFF00B761;
const DARK_COLOR = 0xff191A1C;
const COLOR_ACCENt1 = 0xFF94D5BE;
const DARK_CARD_BG_COLOR = 0xff242528; // 0xFF5EA23A;

var WHITE = 0xFFFFFFFF;
// 0xFF5EA23A;
const FACEBOOK_BUTTON_COLOR = 0xFF415893;
const USERS = 'users';
const CARMAKES = 'car_make';
const VEHICLETYPE = 'vehicle_type';
const RENTALVEHICLETYPE = 'rental_vehicle_type';
const CARMODEL = 'car_model';
const RIDESORDER = "rides";
const PARCELORDER = "parcel_orders";
const RENTALORDER = "rental_orders";
const SECTION = 'sections';

String appVersion = '';

const STORAGE_ROOT = 'DoorDelights';
const REPORTS = 'reports';
const CATEGORIES = 'vendor_categories';
const VENDORS = 'vendors';
const PRODUCTS = 'vendor_products';
const Setting = 'settings';
const CONTACT_US = 'ContactUs';
const ORDERS = 'vendor_orders';
const OrderTransaction = "order_transactions";
const driverPayouts = "driver_payouts";
const Order_Rating = 'items_review';
const Wallet = "wallet";
const REFERRAL = 'referral';
const dynamicNotification = 'dynamic_notification';
const emailTemplates = 'email_templates';

const SECOND_MILLIS = 1000;
const MINUTE_MILLIS = 60 * SECOND_MILLIS;
const HOUR_MILLIS = 60 * MINUTE_MILLIS;
const GlobalURL = "https://doordelights.lk/admin/";

String SERVER_KEY =
    'AAAA9O9J2mc:APA91bGlpltxylZr6zx30KPcIrZ6Hvj4-c-XIhlpWzXKu4fNQAvWt44hFToWuhJy_e_tnY_W4ZVkCLJM329e8oIZ6mLxuABqTkLqC-dzTCG5WWLjIjtaiSMcYYy3068hrPwIy4BtnjhV';
String GOOGLE_API_KEY = 'AIzaSyCQy1lcXsx_E1cibmuTKs2XL3M7gEqLIdY';

String placeholderImage =
    'https://firebasestorage.googleapis.com/v0/b/doordelights-423407.appspot.com/o/app_logo.png?alt=media&token=f232ca89-df07-42ea-bf41-a7cc48d4d088';

const ORDER_STATUS_PLACED = 'Order Placed';
const ORDER_STATUS_ACCEPTED = 'Order Accepted';
const ORDER_STATUS_REJECTED = 'Order Rejected';
const ORDER_STATUS_CANCELLED = 'Order Cancelled';
const ORDER_STATUS_DRIVER_PENDING = 'Driver Pending';
const ORDER_STATUS_DRIVER_ACCEPTED = 'Driver Accepted';
const ORDER_STATUS_DRIVER_REJECTED = 'Driver Rejected';
const ORDER_STATUS_SHIPPED = 'Order Shipped';
const ORDER_STATUS_IN_TRANSIT = 'In Transit';
const ORDER_STATUS_COMPLETED = 'Order Completed';
const ORDER_REACHED_DESTINATION = 'Reached Destination';

const driverCompleted = "driver_completed";
const driverAccepted = "driver_accepted";
const cabAccepted = "cab_accepted";
const cabCompleted = "cab_completed";
const cabCancelled = "cab_cancelled";
const parcelAccepted = "parcel_accepted";
const parcelCompleted = "parcel_completed";
const parcelRejected = "parcel_rejected";
const rentalRejected = "rental_rejected";
const rentalAccepted = "rental_accepted";
const startRide = "start_ride";
const rentalCompleted = "rental_completed";

const walletTopup = "wallet_topup";
const newVendorSignup = "new_vendor_signup";
const payoutRequestStatus = "payout_request_status";
const payoutRequest = "payout_request";
const newOrderPlaced = "new_order_placed";
const newCarBook = "new_car_book";

const USER_ROLE_DRIVER = 'driver';

const DEFAULT_CAR_IMAGE =
    'https://firebasestorage.googleapis.com/v0/b/emart-8d99f.appspot.com/o/images%2Fcar_default_image.png?alt=media&token=ba12a79d-d876-4b1c-87ed-2b06cd5b50f0';

const Currency = 'currencies';

int driverOrderAcceptRejectDuration = 60;
bool enableOTPParcelReceive = false;
bool enableOTPTripStart = false;

CurrencyModel? currencyData;
String currentCabOrderID = "";

String minimumAmountToWithdrawal = "0.0";
String minimumDepositToRideAccept = "0.0";

String orderId({String orderId = ''}) {
  return "#${(orderId).substring(orderId.length - 10)}";
}

String timestampToDateTime(Timestamp timestamp) {
  DateTime dateTime = timestamp.toDate();
  return DateFormat('MMM dd,yyyy hh:mm aa').format(dateTime);
}

Future<void> checkForUpdate({required BuildContext context}) async {
  try {
    if (Platform.isIOS) {
      final FirebaseRemoteConfig remoteConfig = FirebaseRemoteConfig.instance;
      PackageInfo packageInfo = await PackageInfo.fromPlatform();

      String appVersion = packageInfo.version;
      String appVersionCode = packageInfo.buildNumber;

      await remoteConfig.setDefaults(<String, dynamic>{
        'driverForceUpdateIOS': false,
        'driverAppRequiredVersion': appVersion,
        'driverAppRequiredVersionCode': appVersionCode,
      });

      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: const Duration(seconds: 10),
        ),
      );
      await remoteConfig.fetchAndActivate();
      bool forceUpdate = remoteConfig.getBool('driverForceUpdateIOS');
      String appRequiredVersion =
          remoteConfig.getString('driverAppRequiredVersion');
      String appRequiredVersionCode =
          remoteConfig.getString('driverAppRequiredVersionCode');

      if (forceUpdate &&
          (appRequiredVersion != appVersion ||
              appRequiredVersionCode != appVersionCode)) {
        showCupertinoDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return CupertinoAlertDialog(
              title: const Text(
                'Update Available',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              content: const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  'You are using an old version of the app. Please install the latest version to receive the best possible experience!',
                  style: TextStyle(fontSize: 16),
                ),
              ),
              actions: [
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () async {
                    Navigator.pop(context);
                    await launchUrl(Uri.parse(
                        'https://apps.apple.com/us/app/doordelights-driver/id6737223497'));
                  },
                  child: const Text(
                    'Update Now',
                    style: TextStyle(color: CupertinoColors.activeBlue),
                  ),
                ),
              ],
            );
          },
        );
      }
    }
  } catch (e) {
    log("Error checking for update: $e");
  }
}

String amountShow({required String? amount}) {
  if (currencyData == null) return '';
  if (currencyData!.symbolatright == true) {
    return "${(double.tryParse(amount.toString()) ?? 0).toStringAsFixed(currencyData!.decimal)} ${currencyData!.symbol.toString()}";
  } else {
    return "${currencyData!.symbol.toString()} ${(double.tryParse(amount.toString()) ?? 0).toStringAsFixed(currencyData!.decimal)}";
  }
}

double calculateTax({String? amount, TaxModel? taxModel}) {
  double taxAmount = 0.0;
  if (taxModel != null && taxModel.enable == true) {
    if (taxModel.type == "fix") {
      taxAmount = double.parse(taxModel.tax.toString());
    } else {
      taxAmount = (double.parse(amount.toString()) *
              double.parse(taxModel.tax!.toString())) /
          100;
    }
  }
  return taxAmount;
}

String generateId() {
  var uuid = const Uuid().v4();
  var bytes = utf8.encode(uuid);
  var digest = sha256.convert(bytes);
  return digest.toString().substring(0, 15); // Take first 15 characters of hash
}

MailSettings? mailSettings;

final smtpServer = SmtpServer(mailSettings!.host.toString(),
    username: mailSettings!.userName.toString(),
    password: mailSettings!.password.toString(),
    port: 465,
    ignoreBadCertificate: false,
    ssl: true,
    allowInsecure: true);

sendMail(
    {String? subject,
    String? body,
    bool? isAdmin = false,
    List<dynamic>? recipients}) async {
  // Create our message.
  if (isAdmin == true) {
    recipients!.add(mailSettings!.userName.toString());
  }
  final message = Message()
    ..from = Address(
        mailSettings!.userName.toString(), mailSettings!.fromName.toString())
    ..recipients = recipients!
    ..subject = subject
    ..text = body
    ..html = body;

  try {
    final sendReport = await send(message, smtpServer);
    print('Message sent: ' + sendReport.toString());
  } on MailerException catch (e) {
    print(e);
    print('Message not sent.');
    for (var p in e.problems) {
      print('Problem: ${p.code}: ${p.msg}');
    }
  }
}

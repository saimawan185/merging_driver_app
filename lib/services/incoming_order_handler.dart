import 'dart:convert';
import 'dart:developer';

import 'package:door_delights_driver/app/incoming_order/incoming_order_request_screen.dart';
import 'package:door_delights_driver/constant/constant.dart';
import 'package:door_delights_driver/constant/send_notification.dart';
import 'package:door_delights_driver/constant/show_toast_dialog.dart';
import 'package:door_delights_driver/constants.dart';
import 'package:door_delights_driver/controllers/signup_controller.dart';
import 'package:door_delights_driver/models/cab_order_model.dart';
import 'package:door_delights_driver/models/order_model.dart';
import 'package:door_delights_driver/models/parcel_order_model.dart';
import 'package:door_delights_driver/models/rental_order_model.dart';
import 'package:door_delights_driver/models/user_model.dart';
import 'package:door_delights_driver/utils/fire_store_utils.dart';
import 'package:door_delights_driver/utils/preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart' hide Trans;
import 'package:easy_localization/easy_localization.dart';

/// Opens the half-screen incoming-order UI and processes Accept / Decline.
class IncomingOrderHandler {
  static const String acceptAction = 'accept_order';
  static const String declineAction = 'decline_order';
  static const String pendingKey = 'pending_incoming_order';
  static const int orderNotificationId = 99101;

  static bool _uiOpen = false;

  static const List<String> orderRequestTypes = [
    'cab_order',
    'parcel_order',
    'vendor_order',
    'rental_order',
    'new_order_placed',
    'order_request',
  ];

  static bool isOrderRequestType(String? type) {
    if (type == null || type.isEmpty) return false;
    final t = type.toLowerCase();
    return orderRequestTypes.any((e) => t == e || t.contains(e));
  }

  static bool looksLikeNewOrderNotification({
    required String? type,
    required String? title,
    required Map<String, dynamic> data,
  }) {
    if (isOrderRequestType(type)) return true;
    final clickAction = (data['click_action'] ?? '').toString();
    if (clickAction == 'FLUTTER_NOTIFICATION_CLICK' &&
        (data['orderId'] ?? '').toString().isNotEmpty) {
      return true;
    }
    final t = (title ?? '').toLowerCase();
    if (t.contains('new') &&
        (t.contains('order') ||
            t.contains('ride') ||
            t.contains('booking') ||
            t.contains('request') ||
            t.contains('parcel'))) {
      return true;
    }
    if ((data['orderId'] ?? '').toString().isNotEmpty && t.contains('new')) {
      return true;
    }
    return false;
  }

  static String inferTypeFromTitle(String? title) {
    final t = (title ?? '').toLowerCase();
    if (t.contains('ride') || t.contains('cab')) return 'cab_order';
    if (t.contains('parcel')) return 'parcel_order';
    if (t.contains('rental')) return 'rental_order';
    return 'vendor_order';
  }

  static Future<void> savePending({
    required String orderId,
    required String type,
    String? action,
    String? title,
    String? body,
    Map<String, dynamic>? preview,
  }) async {
    await Preferences.setString(
      pendingKey,
      jsonEncode({
        'orderId': orderId,
        'type': type,
        'action': action ?? '',
        'title': title ?? '',
        'body': body ?? '',
        'preview': preview ?? {},
        'savedAt': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  }

  static Future<Map<String, dynamic>?> takePending() async {
    final raw = Preferences.getString(pendingKey);
    await Preferences.clearKeyData(pendingKey);
    if (raw.isEmpty) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  /// Half-screen overlay (Accept Now + X). No notification action buttons.
  static Future<void> openRequestUi({
    required String orderId,
    required String type,
    String title = '',
    String body = '',
    Map<String, dynamic>? preview,
  }) async {
    if (orderId.isEmpty) {
      await openFromDriverPendingRequest(title: title, body: body);
      return;
    }
    if (_uiOpen) return;
    _uiOpen = true;

    try {
      await Get.dialog(
        IncomingOrderRequestScreen(
          orderId: orderId,
          type: type.isEmpty ? inferTypeFromTitle(title) : type,
          title: title,
          body: body,
          preview: preview,
        ),
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.55),
        useSafeArea: false,
      );
    } finally {
      _uiOpen = false;
    }
  }

  /// When FCM has no orderId, use request fields already written on the driver.
  static Future<void> openFromDriverPendingRequest({
    String title = '',
    String body = '',
  }) async {
    try {
      UserModel? driver = Constant.userModel;
      final uid = FireStoreUtils.getCurrentUid();
      if (uid.isNotEmpty) {
        driver = await FireStoreUtils.getUserProfile(uid) ?? driver;
        if (driver != null) Constant.userModel = driver;
      }
      if (driver == null) return;

      if (driver.orderCabRequestData?.id != null &&
          driver.orderCabRequestData!.id!.isNotEmpty) {
        await openRequestUi(
          orderId: driver.orderCabRequestData!.id!,
          type: 'cab_order',
          title: title,
          body: body,
        );
        return;
      }

      if (driver.orderParcelRequestData?.id != null &&
          driver.orderParcelRequestData!.id!.isNotEmpty) {
        await openRequestUi(
          orderId: driver.orderParcelRequestData!.id!,
          type: 'parcel_order',
          title: title,
          body: body,
        );
        return;
      }

      if (driver.orderRequestData?.id != null &&
          driver.orderRequestData!.id!.isNotEmpty) {
        await openRequestUi(
          orderId: driver.orderRequestData!.id!,
          type: 'vendor_order',
          title: title,
          body: body,
        );
        return;
      }

      final deliveryRequests = driver.deliveryOrderRequests;
      if (deliveryRequests != null && deliveryRequests.isNotEmpty) {
        final last = deliveryRequests.last;
        if (last.id != null && last.id!.isNotEmpty) {
          await openRequestUi(
            orderId: last.id!,
            type: 'vendor_order',
            title: title,
            body: body,
          );
        }
      }
    } catch (e, s) {
      log('openFromDriverPendingRequest error: $e\n$s');
    }
  }

  /// Call after driver is logged in. Only processes Accept/Decline from the
  /// closed-app native popup — does not show half-screen UI while app is open.
  static Future<void> handlePendingIfAny() async {
    await Future.delayed(const Duration(milliseconds: 700));

    final pending = await takePending();
    if (pending == null) return;

    var orderId = (pending['orderId'] ?? '').toString();
    var type = (pending['type'] ?? '').toString();
    final action = (pending['action'] ?? '').toString();
    final title = (pending['title'] ?? '').toString();

    if (type.isEmpty) type = inferTypeFromTitle(title);

    // Half-screen is only for closed app (native). When app is open, only honor
    // Accept / Decline actions coming from that native popup.
    if (action != acceptAction && action != declineAction) {
      return;
    }

    if (orderId.isEmpty) {
      final uid = FireStoreUtils.getCurrentUid();
      if (uid.isEmpty) return;
      final driver = await FireStoreUtils.getUserProfile(uid);
      if (driver == null) return;
      Constant.userModel = driver;
      orderId = driver.orderCabRequestData?.id ??
          driver.orderParcelRequestData?.id ??
          driver.orderRequestData?.id ??
          ((driver.deliveryOrderRequests?.isNotEmpty == true)
              ? driver.deliveryOrderRequests!.last.id
              : null) ??
          '';
      if (orderId.isEmpty) return;
      if (type.isEmpty || type == 'order_request') {
        if (driver.orderCabRequestData?.id == orderId) {
          type = 'cab_order';
        } else if (driver.orderParcelRequestData?.id == orderId) {
          type = 'parcel_order';
        } else {
          type = 'vendor_order';
        }
      }
    }

    await processAction(action: action, orderId: orderId, type: type);
  }

  static Future<bool> processAction({
    required String action,
    required String orderId,
    required String type,
  }) async {
    try {
      try {
        await FlutterLocalNotificationsPlugin().cancel(orderNotificationId);
      } catch (_) {}

      ShowToastDialog.showLoader(
        action == acceptAction ? 'Accepting...'.tr() : 'Please wait'.tr(),
      );

      final uid = FireStoreUtils.getCurrentUid();
      if (uid.isEmpty) {
        ShowToastDialog.closeLoader();
        ShowToastDialog.showToast('Please login again'.tr());
        return false;
      }

      final driver = await FireStoreUtils.getUserProfile(uid);
      if (driver == null) {
        ShowToastDialog.closeLoader();
        return false;
      }
      Constant.userModel = driver;

      final normalized = _normalizeType(type, orderId);
      bool ok = false;
      if (action == acceptAction) {
        ok = await _accept(orderId: orderId, type: normalized, driver: driver);
      } else {
        ok = await _decline(orderId: orderId, type: normalized, driver: driver);
      }

      ShowToastDialog.closeLoader();
      if (ok) {
        if (Get.isDialogOpen == true) {
          Get.back();
        }
        ShowToastDialog.showToast(
          action == acceptAction
              ? 'Order accepted'.tr()
              : 'Order declined'.tr(),
        );
        SignupController.navigateByUserModel(driver);
      } else {
        ShowToastDialog.showToast(
            'Something went wrong. Please try again.'.tr());
      }
      return ok;
    } catch (e, s) {
      ShowToastDialog.closeLoader();
      log('IncomingOrderHandler.processAction error: $e\n$s');
      ShowToastDialog.showToast('Something went wrong. Please try again.'.tr());
      return false;
    }
  }

  static String _normalizeType(String type, String orderId) {
    final t = type.toLowerCase();
    if (t.contains('cab') || t.contains('ride')) return 'cab_order';
    if (t.contains('parcel')) return 'parcel_order';
    if (t.contains('rental')) return 'rental_order';
    if (t.contains('vendor') || t.contains('delivery')) return 'vendor_order';
    return t.isEmpty ? 'vendor_order' : type;
  }

  static Future<bool> _accept({
    required String orderId,
    required String type,
    required UserModel driver,
  }) async {
    switch (type) {
      case 'cab_order':
        final order = await FireStoreUtils.getCabOrderById(orderId);
        if (order == null) return false;
        driver.inProgressOrderID = order.id;
        driver.orderCabRequestData = null;
        await FireStoreUtils.updateUser(driver);
        order.status = Constant.driverAccepted;
        order.driverId = driver.id;
        order.driver = driver;
        await FireStoreUtils.setCabOrder(order);
        await SendNotification.sendFcmMessage(
          Constant.driverAcceptedNotification,
          order.author?.fcmToken ?? '',
          {'type': 'cab_order', 'orderId': order.id},
        );
        return true;

      case 'parcel_order':
        final order = await FireStoreUtils.getParcelOrderById(orderId);
        if (order == null) return false;
        driver.inProgressOrderID = order.id;
        driver.orderParcelRequestData = null;
        await FireStoreUtils.updateUser(driver);
        order.status = ORDER_STATUS_DRIVER_ACCEPTED;
        order.driverId = driver.id;
        order.driver = driver;
        await FireStoreUtils.setParcelOrder(order);
        await SendNotification.sendFcmMessage(
          Constant.parcelAccepted,
          order.author?.fcmToken ?? '',
          {'type': 'parcel_order', 'orderId': order.id},
        );
        return true;

      case 'rental_order':
        final order = await FireStoreUtils.getRentalOrderById(orderId);
        if (order == null) return false;
        driver.inProgressOrderID = order.id;
        await FireStoreUtils.updateUser(driver);
        order.status = Constant.driverAccepted;
        order.driverId = driver.id;
        order.driver = driver;
        await FireStoreUtils.rentalOrderPlace(order);
        await SendNotification.sendFcmMessage(
          Constant.rentalAccepted,
          order.author?.fcmToken ?? '',
          {'type': 'rental_order', 'orderId': order.id},
        );
        return true;

      case 'vendor_order':
      default:
        final OrderModel? order = await FireStoreUtils.getOrderById(orderId);
        if (order == null) return false;
        driver.inProgressOrderID = order.id;
        driver.orderRequestData = null;
        final oid = order.id;
        if (oid != null) {
          final ids = driver.deliveryInProgressOrderIds;
          if (ids == null) {
            driver.deliveryInProgressOrderIds = [oid];
          } else if (!ids.contains(oid)) {
            ids.add(oid);
          }
        }
        driver.deliveryOrderRequests?.removeWhere((o) => o.id == order.id);
        await FireStoreUtils.updateUser(driver);
        order.status = ORDER_STATUS_ACCEPTED;
        order.driverID = driver.id;
        order.driver = driver;
        await FireStoreUtils.setOrder(order);
        await Future.wait([
          SendNotification.sendFcmMessage(
            Constant.driverAcceptedNotification,
            order.author?.fcmToken ?? '',
            {'type': 'vendor_order', 'orderId': order.id},
          ),
          if (order.vendor?.fcmToken != null)
            SendNotification.sendFcmMessage(
              Constant.driverAcceptedNotification,
              order.vendor!.fcmToken.toString(),
              {'type': 'vendor_order', 'orderId': order.id},
            ),
        ]);
        return true;
    }
  }

  static Future<bool> _decline({
    required String orderId,
    required String type,
    required UserModel driver,
  }) async {
    switch (type) {
      case 'cab_order':
        final CabOrderModel? order =
            await FireStoreUtils.getCabOrderById(orderId);
        if (order == null) return false;
        order.status = Constant.driverRejected;
        order.rejectedByDrivers ??= [];
        if (!order.rejectedByDrivers!.contains(driver.id)) {
          order.rejectedByDrivers!.add(driver.id);
        }
        driver.orderCabRequestData = null;
        driver.inProgressOrderID = null;
        await Future.wait([
          FireStoreUtils.setCabOrder(order),
          FireStoreUtils.updateUser(driver),
        ]);
        return true;

      case 'parcel_order':
        final ParcelOrderModel? order =
            await FireStoreUtils.getParcelOrderById(orderId);
        if (order == null) return false;
        order.rejectedByDrivers ??= [];
        order.rejectedByDrivers!.add(driver.id);
        order.status = ORDER_STATUS_DRIVER_REJECTED;
        driver.orderParcelRequestData = null;
        await Future.wait([
          FireStoreUtils.setParcelOrder(order),
          FireStoreUtils.updateUser(driver),
        ]);
        return true;

      case 'rental_order':
        final RentalOrderModel? order =
            await FireStoreUtils.getRentalOrderById(orderId);
        if (order == null) return false;
        order.rejectedByDrivers ??= [];
        order.rejectedByDrivers!.add(driver.id);
        order.status = Constant.driverRejected;
        driver.inProgressOrderID = null;
        await Future.wait([
          FireStoreUtils.rentalOrderPlace(order),
          FireStoreUtils.updateUser(driver),
        ]);
        return true;

      case 'vendor_order':
      default:
        final OrderModel? order = await FireStoreUtils.getOrderById(orderId);
        if (order == null) return false;
        order.rejectedByDrivers ??= [];
        order.rejectedByDrivers!.add(driver.id);
        order.status = ORDER_STATUS_DRIVER_REJECTED;
        driver.orderRequestData = null;
        driver.deliveryOrderRequests?.removeWhere((o) => o.id == order.id);
        await Future.wait([
          FireStoreUtils.setOrder(order),
          FireStoreUtils.updateUser(driver),
        ]);
        return true;
    }
  }

  static IncomingOrderDisplayData? previewFromPayload(
      Map<String, dynamic>? preview) {
    if (preview == null || preview.isEmpty) return null;
    final amount = (preview['amount'] ?? '').toString();
    final pickup = (preview['pickup'] ?? '').toString();
    final destination = (preview['destination'] ?? '').toString();
    if (amount.isEmpty && pickup.isEmpty && destination.isEmpty) return null;
    return IncomingOrderDisplayData(
      amount: amount.isEmpty ? '0' : amount,
      paymentMethod: (preview['paymentMethod'] ?? '').toString(),
      vehicleLabel: (preview['vehicleLabel'] ?? '').toString(),
      pickup: pickup,
      destination: destination,
      distance: (preview['distance'] ?? '').toString(),
      duration: (preview['duration'] ?? '').toString(),
      type: (preview['type'] ?? '').toString(),
    );
  }

  static Map<String, dynamic> extractPreview(Map<String, dynamic> data) {
    return {
      'amount': (data['amount'] ?? '').toString(),
      'pickup': (data['pickup'] ?? '').toString(),
      'destination': (data['destination'] ?? '').toString(),
      'paymentMethod': (data['paymentMethod'] ?? '').toString(),
      'distance': (data['distance'] ?? '').toString(),
      'duration': (data['duration'] ?? '').toString(),
      'vehicleLabel': (data['vehicleLabel'] ?? '').toString(),
      'type': (data['type'] ?? '').toString(),
    };
  }

  static Future<IncomingOrderDisplayData?> loadDisplayData({
    required String orderId,
    required String type,
    Map<String, dynamic>? preview,
  }) async {
    final fromPayload = previewFromPayload(preview);
    final normalized = _normalizeType(type, orderId);
    try {
      switch (normalized) {
        case 'cab_order':
          final o = await FireStoreUtils.getCabOrderById(orderId);
          if (o == null) return fromPayload;
          return IncomingOrderDisplayData(
            amount: o.subTotal ?? fromPayload?.amount ?? '0',
            paymentMethod:
                o.paymentMethod ?? fromPayload?.paymentMethod ?? '',
            vehicleLabel:
                o.vehicleType?.name ?? fromPayload?.vehicleLabel ?? 'Ride',
            pickup: o.sourceLocationName ?? fromPayload?.pickup ?? '',
            destination:
                o.destinationLocationName ?? fromPayload?.destination ?? '',
            distance: o.distance ?? fromPayload?.distance ?? '',
            duration: o.duration ?? fromPayload?.duration ?? '',
            type: normalized,
          );
        case 'parcel_order':
          final o = await FireStoreUtils.getParcelOrderById(orderId);
          if (o == null) return fromPayload;
          return IncomingOrderDisplayData(
            amount: o.subTotal ?? fromPayload?.amount ?? '0',
            paymentMethod:
                o.paymentMethod ?? fromPayload?.paymentMethod ?? '',
            vehicleLabel: fromPayload?.vehicleLabel.isNotEmpty == true
                ? fromPayload!.vehicleLabel
                : 'Parcel',
            pickup: o.sender?.address ?? fromPayload?.pickup ?? '',
            destination: o.receiver?.address ?? fromPayload?.destination ?? '',
            distance: o.distance ?? fromPayload?.distance ?? '',
            duration: fromPayload?.duration ?? '',
            type: normalized,
          );
        case 'rental_order':
          final o = await FireStoreUtils.getRentalOrderById(orderId);
          if (o == null) return fromPayload;
          return IncomingOrderDisplayData(
            amount: o.subTotal ?? fromPayload?.amount ?? '0',
            paymentMethod:
                o.paymentMethod ?? fromPayload?.paymentMethod ?? '',
            vehicleLabel: o.rentalVehicleType?.name ??
                fromPayload?.vehicleLabel ??
                'Rental',
            pickup: o.sourceLocationName ?? fromPayload?.pickup ?? '',
            destination: fromPayload?.destination ?? '',
            distance: fromPayload?.distance ?? '',
            duration: fromPayload?.duration ?? '',
            type: normalized,
          );
        default:
          final o = await FireStoreUtils.getOrderById(orderId);
          if (o == null) return fromPayload;
          return IncomingOrderDisplayData(
            amount: o.deliveryCharge ?? fromPayload?.amount ?? '0',
            paymentMethod:
                o.paymentMethod ?? fromPayload?.paymentMethod ?? '',
            vehicleLabel: fromPayload?.vehicleLabel.isNotEmpty == true
                ? fromPayload!.vehicleLabel
                : 'Delivery',
            pickup: o.vendor?.location ?? fromPayload?.pickup ?? '',
            destination:
                o.address?.getFullAddress() ?? fromPayload?.destination ?? '',
            distance: fromPayload?.distance ?? '',
            duration: fromPayload?.duration ?? '',
            type: 'vendor_order',
          );
      }
    } catch (e) {
      log('loadDisplayData error: $e');
      return fromPayload;
    }
  }
}

class IncomingOrderDisplayData {
  final String amount;
  final String paymentMethod;
  final String vehicleLabel;
  final String pickup;
  final String destination;
  final String distance;
  final String duration;
  final String type;

  IncomingOrderDisplayData({
    required this.amount,
    required this.paymentMethod,
    required this.vehicleLabel,
    required this.pickup,
    required this.destination,
    required this.distance,
    required this.duration,
    required this.type,
  });
}

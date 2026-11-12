import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:door_delights_driver/constant/collection_name.dart';
import 'package:door_delights_driver/constant/constant.dart';
import 'package:door_delights_driver/constant/send_notification.dart';
import 'package:door_delights_driver/constant/show_toast_dialog.dart';
import 'package:door_delights_driver/models/order_model.dart';
import 'package:door_delights_driver/models/user_model.dart';
import 'package:door_delights_driver/services/audio_player_service.dart';
import 'package:door_delights_driver/utils/fire_store_utils.dart';
import 'package:get/get.dart' hide Trans;
import 'package:easy_localization/easy_localization.dart';

import '../constants.dart';

class HomeScreenMultipleOrderController extends GetxController {
  Rx<UserModel> driverModel = Constant.userModel!.obs;
  RxBool isLoading = true.obs;
  RxInt selectedTabIndex = 0.obs;

  RxList<dynamic> newOrder = [].obs;
  RxList<dynamic> activeOrder = [].obs;

  // ── In-flight guards (prevent double-tap / cross-tap) ─────────────
  bool _isAccepting = false;
  bool _isRejecting = false;

  // ── Orders the driver has handled locally — used to hide them from the
  //    "New" tab even if the stream lags a beat behind the write.
  final Set<String> _locallyHandledOrderIds = {};

  // ── Capacity limits (must match the cloud dispatch function) ──────
  static const int _maxInProgress = 3;

  // ── Acceptable / rejectable statuses for delivery orders ──────────
  static const Set<String> _acceptableStatuses = {
    "Order Placed",
    "Order Accepted",
    "Driver Pending",
    "Driver Rejected",
  };

  static const Set<String> _rejectableStatuses = {
    "Order Placed",
    "Order Accepted",
    "Driver Pending",
    "Driver Rejected",
  };

  @override
  void onInit() {
    getDriver();
    super.onInit();
  }

  // ═════════════════════════════════════════════════════════════════
  // Live driver stream — filters locally-handled orders from "New" tab
  // ═════════════════════════════════════════════════════════════════
  Future<void> getDriver() async {
    FireStoreUtils.fireStore
        .collection(CollectionName.users)
        .doc(FireStoreUtils.getCurrentUid())
        .snapshots()
        .listen((event) async {
      if (!event.exists) return;

      driverModel.value = UserModel.fromJson(event.data()!);
      Constant.userModel = driverModel.value;

      // Requests — drop anything we've locally processed
      newOrder.clear();
      final requests = driverModel.value.deliveryOrderRequests;
      if (requests != null && requests.isNotEmpty) {
        newOrder.addAll(
          requests.where((o) => !_locallyHandledOrderIds.contains(o.id)),
        );
      }

      // In-progress — direct copy
      activeOrder.clear();
      final inProgress = driverModel.value.deliveryInProgressOrderIds;
      if (inProgress != null && inProgress.isNotEmpty) {
        activeOrder.addAll(inProgress);
      }

      if (newOrder.isEmpty) {
        await AudioPlayerService.playSound(false);
      } else if (driverModel.value.vendorID?.isEmpty == true) {
        await AudioPlayerService.playSound(true);
      }

      update();
    });
    isLoading.value = false;
    update();
  }

  // ═════════════════════════════════════════════════════════════════
  // ACCEPT
  // ═════════════════════════════════════════════════════════════════
  Future<void> acceptOrder(OrderModel currentOrder) async {
    if (_isAccepting || _isRejecting) return;

    final orderId = currentOrder.id;
    if (orderId == null || orderId.isEmpty) return;

    _isAccepting = true;
    ShowToastDialog.showLoader("Please wait".tr());
    await AudioPlayerService.playSound(false);

    try {
      await _acceptOrderTransaction(orderId, FireStoreUtils.getCurrentUid());

      // Commit succeeded — now it's safe to reflect it locally.
      _locallyHandledOrderIds.add(orderId);
      _applyLocalAccept(orderId);

      // Fire-and-forget notifications (parallel, error-tolerant)
      await Future.wait<void>([
        _safeSendFcm(
            Constant.driverAcceptedNotification, currentOrder.author?.fcmToken),
        _safeSendFcm(
            Constant.driverAcceptedNotification, currentOrder.vendor?.fcmToken),
      ], eagerError: false);
    } on _OrderAbortedException catch (e) {
      // Business-logic abort (status changed, capacity, etc.)
      await _refreshDriverState();
      Get.snackbar("Error", e.reason);
    } catch (e, st) {
      // Network / unexpected — state on server may be unchanged
      // (transaction is atomic), so leave local state alone.
      log("Accept failed: $e\n$st");
      Get.snackbar("Error", "Could not accept order. Please retry.");
    } finally {
      ShowToastDialog.closeLoader();
      _isAccepting = false;
    }
  }

  Future<void> _acceptOrderTransaction(String orderId, String driverId) async {
    await FireStoreUtils.fireStore.runTransaction((tx) async {
      final orderRef = FireStoreUtils.fireStore.collection(ORDERS).doc(orderId);
      final driverRef = FireStoreUtils.fireStore
          .collection(CollectionName.users)
          .doc(driverId);

      // ── Reads first (Firestore requirement) ────────────────────
      final orderSnap = await tx.get(orderRef);
      final driverSnap = await tx.get(driverRef);

      if (!orderSnap.exists) {
        throw const _OrderAbortedException('Order no longer available.');
      }
      if (!driverSnap.exists) {
        throw const _OrderAbortedException('Driver profile missing.');
      }

      final orderData = orderSnap.data()!;
      final driverData = driverSnap.data()!;

      // ── Status guard ───────────────────────────────────────────
      final currentStatus = orderData['status'] as String?;
      if (!_acceptableStatuses.contains(currentStatus)) {
        throw _OrderAbortedException(
            'Order already ${_prettyStatus(currentStatus)}.');
      }

      // ── Another driver may have grabbed it ─────────────────────
      final existingDriverId = orderData['driverID']?.toString() ?? '';
      if (existingDriverId.isNotEmpty && existingDriverId != driverId) {
        throw const _OrderAbortedException(
            'Another driver already accepted this order.');
      }

      // ── Read current driver capacity state ─────────────────────
      final inProgress = (driverData['deliveryInProgressOrderIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          <String>[];
      final requests = (driverData['deliveryOrderRequests'] as List?) ?? [];

      if (inProgress.contains(orderId)) {
        throw const _OrderAbortedException(
            'You are already handling this order.');
      }
      if (inProgress.length >= _maxInProgress) {
        throw _OrderAbortedException(
            'You can only have $_maxInProgress active orders at a time.');
      }

      final updatedInProgress = [...inProgress, orderId];
      final updatedRequests = requests
          .where((r) => !(r is Map && r['id']?.toString() == orderId))
          .toList();

      // ── Driver snapshot embedded on the order doc ──────────────
      // Strip request-side fields: they belong on the driver doc, not
      // on the order (and would bloat/duplicate if copied here).
      final driverSnapshot = Map<String, dynamic>.from(driverData)
        ..remove('orderRequestData')
        ..remove('deliveryOrderRequests');

      // ── Write 1: order ─────────────────────────────────────────
      tx.update(orderRef, {
        'status': ORDER_STATUS_ACCEPTED,
        'driverID': driverId,
        'driver': driverSnapshot,
      });

      // ── Write 2: driver ────────────────────────────────────────
      final driverPatch = <String, dynamic>{
        'orderRequestData': FieldValue.delete(),
        'deliveryOrderRequests':
            updatedRequests.isEmpty ? FieldValue.delete() : updatedRequests,
        'deliveryInProgressOrderIds': updatedInProgress,
        'inProgressOrderID': orderId, // legacy field — keep in sync
      };
      tx.update(driverRef, driverPatch);
    });
  }

  /// Apply the accept to the local model so the UI switches tabs
  /// instantly, without waiting for the stream to fire.
  void _applyLocalAccept(String orderId) {
    final driver = driverModel.value;

    final ids = List<String>.from(driver.deliveryInProgressOrderIds ?? []);
    if (!ids.contains(orderId)) ids.add(orderId);
    driver.deliveryInProgressOrderIds = ids;
    driver.inProgressOrderID = orderId;
    driver.orderRequestData = null;

    if (driver.deliveryOrderRequests != null) {
      final remaining =
          driver.deliveryOrderRequests!.where((o) => o.id != orderId).toList();
      driver.deliveryOrderRequests = remaining.isEmpty ? null : remaining;
    }

    newOrder.removeWhere((o) => o.id == orderId);
    if (!activeOrder.contains(orderId)) activeOrder.add(orderId);

    driverModel.refresh();
    update();
  }

  // ═════════════════════════════════════════════════════════════════
  // REJECT
  // ═════════════════════════════════════════════════════════════════
  Future<void> rejectOrder(OrderModel currentOrder) async {
    if (_isAccepting || _isRejecting) return;

    final orderId = currentOrder.id;
    if (orderId == null || orderId.isEmpty) return;

    _isRejecting = true;
    ShowToastDialog.showLoader("Please wait".tr());
    await AudioPlayerService.playSound(false);

    try {
      await _rejectOrderTransaction(orderId, FireStoreUtils.getCurrentUid());

      _locallyHandledOrderIds.add(orderId);
      _applyLocalReject(orderId);

      // No customer FCM on reject — the cloud `dispatch` function
      // automatically re-tries the order with the next driver in radius.
    } on _OrderAbortedException catch (e) {
      await _refreshDriverState();
      Get.snackbar("Error", e.reason);
    } catch (e, st) {
      log("Reject failed: $e\n$st");
      Get.snackbar("Error", "Could not reject order. Please retry.");
    } finally {
      ShowToastDialog.closeLoader();
      _isRejecting = false;
    }
  }

  Future<void> _rejectOrderTransaction(String orderId, String driverId) async {
    await FireStoreUtils.fireStore.runTransaction((tx) async {
      final orderRef = FireStoreUtils.fireStore.collection(ORDERS).doc(orderId);
      final driverRef = FireStoreUtils.fireStore
          .collection(CollectionName.users)
          .doc(driverId);

      final orderSnap = await tx.get(orderRef);
      final driverSnap = await tx.get(driverRef);

      if (!orderSnap.exists) {
        throw const _OrderAbortedException('Order no longer available.');
      }

      final orderData = orderSnap.data()!;
      final currentStatus = orderData['status'] as String?;
      final rejected = (orderData['rejectedByDrivers'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          <String>[];

      final alreadyRejectedByUs = rejected.contains(driverId);

      if (!alreadyRejectedByUs &&
          !_rejectableStatuses.contains(currentStatus)) {
        throw _OrderAbortedException(
            'Order already ${_prettyStatus(currentStatus)}.');
      }

      // ── Write 1: order ─────────────────────────────────────────
      if (!alreadyRejectedByUs) {
        tx.update(orderRef, {
          'status': ORDER_STATUS_DRIVER_REJECTED,
          'rejectedByDrivers': FieldValue.arrayUnion([driverId]),
        });
      }

      // ── Write 2: driver (drop from pending list) ───────────────
      if (driverSnap.exists) {
        final driverData = driverSnap.data()!;
        final requests = (driverData['deliveryOrderRequests'] as List?) ?? [];
        final updatedRequests = requests
            .where((r) => !(r is Map && r['id']?.toString() == orderId))
            .toList();

        final driverPatch = <String, dynamic>{
          'deliveryOrderRequests':
              updatedRequests.isEmpty ? FieldValue.delete() : updatedRequests,
          // Legacy single-request field — clear if it's still this order
          if (driverData['orderRequestData'] is Map &&
              (driverData['orderRequestData'] as Map)['id']?.toString() ==
                  orderId)
            'orderRequestData': FieldValue.delete(),
        };
        tx.update(driverRef, driverPatch);
      }
    });
  }

  void _applyLocalReject(String orderId) {
    final driver = driverModel.value;

    if (driver.deliveryOrderRequests != null) {
      final remaining =
          driver.deliveryOrderRequests!.where((o) => o.id != orderId).toList();
      driver.deliveryOrderRequests = remaining.isEmpty ? null : remaining;
    }
    if (driver.orderRequestData?.id == orderId) {
      driver.orderRequestData = null;
    }

    newOrder.removeWhere((o) => o.id == orderId);

    driverModel.refresh();
    update();
  }

  // ═════════════════════════════════════════════════════════════════
  // HELPERS
  // ═════════════════════════════════════════════════════════════════
  Future<void> _safeSendFcm(String type, String? token) async {
    if (token == null || token.isEmpty) return;
    try {
      await SendNotification.sendFcmMessage(type, token, {});
    } catch (e) {
      log("FCM skipped: $e");
    }
  }

  /// Pull fresh server state — used after an abort so local UI re-syncs.
  Future<void> _refreshDriverState() async {
    try {
      final snap = await FireStoreUtils.fireStore
          .collection(CollectionName.users)
          .doc(FireStoreUtils.getCurrentUid())
          .get();
      if (snap.exists) {
        driverModel.value = UserModel.fromJson(snap.data()!);
        Constant.userModel = driverModel.value;
        update();
      }
    } catch (e) {
      log("refreshDriverState failed: $e");
    }
  }

  String _prettyStatus(String? s) {
    switch (s) {
      case "Order Completed":
        return 'completed';
      case "Order Cancelled":
      case "Order Canceled":
        return 'cancelled';
      case "Order Accepted":
        return 'accepted';
      case "Order Rejected":
        return 'rejected';
      case "Order Shipped":
      case "In Transit":
        return 'in progress';
      default:
        return s ?? 'updated';
    }
  }
}

class _OrderAbortedException implements Exception {
  final String reason;
  const _OrderAbortedException(this.reason);
  @override
  String toString() => reason;
}

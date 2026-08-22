import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:door_delights_driver/services/incoming_order_handler.dart';
import 'package:door_delights_driver/themes/app_them_data.dart';
import 'package:door_delights_driver/themes/custom_dialog_box.dart';
import 'package:door_delights_driver/themes/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Trans;
import 'package:easy_localization/easy_localization.dart';
import 'package:permission_handler/permission_handler.dart';

/// Bridges Android native incoming-order UI ↔ Flutter accept/decline.
class IncomingOrderBridge {
  static const MethodChannel _channel =
      MethodChannel('com.doordelights.rider/incoming_order');

  static bool _bound = false;
  static bool _permissionPromptRunning = false;

  static Future<void> bind() async {
    if (_bound || !Platform.isAndroid) return;
    _bound = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onIncomingOrder') {
        await _handlePayload(call.arguments);
      }
    });
  }

  static Future<void> _handlePayload(dynamic raw) async {
    try {
      Map<String, dynamic> data;
      if (raw is String) {
        data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      } else if (raw is Map) {
        data = Map<String, dynamic>.from(raw);
      } else {
        return;
      }

      final orderId = (data['orderId'] ?? '').toString();
      final type = (data['type'] ?? '').toString();
      final title = (data['title'] ?? '').toString();
      final body = (data['body'] ?? '').toString();
      final action = (data['action'] ?? '').toString();
      final preview = IncomingOrderHandler.extractPreview(data);

      await IncomingOrderHandler.savePending(
        orderId: orderId,
        type: type.isEmpty
            ? IncomingOrderHandler.inferTypeFromTitle(title)
            : type,
        action: action,
        title: title,
        body: body,
        preview: preview,
      );

      if (action == IncomingOrderHandler.acceptAction ||
          action == IncomingOrderHandler.declineAction) {
        if (Get.key.currentContext != null) {
          await IncomingOrderHandler.handlePendingIfAny();
        }
      }
    } catch (e, s) {
      log('IncomingOrderBridge._handlePayload error: $e\n$s');
    }
  }

  static Future<void> _waitForNavigator({int tries = 25}) async {
    for (var i = 0; i < tries; i++) {
      final ctx = Get.context ?? Get.key.currentContext;
      if (ctx != null && Get.key.currentState?.overlay != null) {
        return;
      }
      await Future.delayed(const Duration(milliseconds: 250));
    }
  }

  static Future<bool> _showThemedConfirmDialog({
    required String title,
    required String description,
    required String positive,
    required String negative,
    required IconData icon,
  }) async {
    var confirmed = false;
    final isDark = Get.isRegistered<ThemeController>()
        ? Get.find<ThemeController>().isDark.value
        : false;

    await Get.dialog(
      barrierDismissible: false,
      CustomDialogBox(
        title: title,
        descriptions: description,
        positiveString: positive,
        negativeString: negative,
        positiveClick: () {
          confirmed = true;
          Get.back();
        },
        negativeClick: () {
          confirmed = false;
          Get.back();
        },
        img: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: (isDark ? AppThemeData.primary500 : AppThemeData.primary50)
                .withValues(alpha: isDark ? 0.4 : 1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 32,
            color: AppThemeData.primary300,
          ),
        ),
      ),
    );
    return confirmed;
  }

  /// Shows themed permission dialogs until overlay / full-screen access is set.
  static Future<void> ensureIncomingOrderPermissions() async {
    if (!Platform.isAndroid) return;
    if (_permissionPromptRunning) return;
    _permissionPromptRunning = true;
    try {
      await Permission.notification.request();
      await _waitForNavigator();

      final ctx = Get.context ?? Get.key.currentContext;
      if (ctx == null) {
        log('ensureIncomingOrderPermissions: no Get.context yet');
        return;
      }

      var canOverlay = false;
      try {
        canOverlay =
            await _channel.invokeMethod<bool>('canDrawOverlays') ?? false;
      } catch (e) {
        log('canDrawOverlays channel error: $e');
        canOverlay = await Permission.systemAlertWindow.isGranted;
      }

      if (!canOverlay) {
        final go = await _showThemedConfirmDialog(
          title: 'Allow order popup'.tr(),
          description:
              'To show new ride/order requests when the app is closed, allow "Display over other apps" for Door Delights Driver.'
                  .tr(),
          positive: 'Open Settings'.tr(),
          negative: 'Later'.tr(),
          icon: Icons.layers_rounded,
        );
        if (go) {
          try {
            await _channel.invokeMethod('openOverlaySettings');
          } catch (_) {
            await Permission.systemAlertWindow.request();
          }
        }
      }

      try {
        final canFsi =
            await _channel.invokeMethod<bool>('canUseFullScreenIntent') ?? true;
        if (!canFsi) {
          final goFsi = await _showThemedConfirmDialog(
            title: 'Allow full screen alerts'.tr(),
            description:
                'Allow full screen notifications so new orders can appear over other apps.'
                    .tr(),
            positive: 'Open Settings'.tr(),
            negative: 'Later'.tr(),
            icon: Icons.notifications_active_rounded,
          );
          if (goFsi) {
            await _channel.invokeMethod('openFullScreenIntentSettings');
          }
        }
      } catch (e) {
        log('full screen permission check failed: $e');
      }
    } catch (e, s) {
      log('ensureIncomingOrderPermissions: $e\n$s');
    } finally {
      _permissionPromptRunning = false;
    }
  }
}

import 'dart:async';
import 'dart:developer';

import 'package:door_delights_driver/app/auth_screen/login_screen.dart';
import 'package:door_delights_driver/app/maintenance_mode_screen/maintenance_mode_screen.dart';
import 'package:door_delights_driver/app/on_boarding_screen.dart';
import 'package:door_delights_driver/app/owner_screen/owner_dashboard_screen.dart';
import 'package:door_delights_driver/constant/constant.dart';
import 'package:door_delights_driver/controllers/signup_controller.dart';
import 'package:door_delights_driver/models/user_model.dart';
import 'package:door_delights_driver/services/incoming_order_bridge.dart';
import 'package:door_delights_driver/services/incoming_order_handler.dart';
import 'package:door_delights_driver/utils/fire_store_utils.dart';
import 'package:door_delights_driver/utils/notification_service.dart';
import 'package:door_delights_driver/utils/preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart' hide Trans;

class SplashController extends GetxController {
  @override
  void onInit() {
    final hasPending =
        Preferences.getString(IncomingOrderHandler.pendingKey).isNotEmpty;
    // Open faster when woken by an incoming-order intent.
    Timer(
      Duration(milliseconds: hasPending ? 400 : 3000),
      () => redirectScreen(),
    );
    super.onInit();
  }

  Future<void> redirectScreen() async {
    if (await FireStoreUtils.isMaintenanceMode() == true) {
      Get.offAll(() => MaintenanceModeScreen());
      return;
    } else {
      if (Preferences.getBoolean(Preferences.isFinishOnBoardingKey) == false) {
        Get.offAll(const OnboardingScreen());
      } else {
        bool isLogin = await FireStoreUtils.isLogin();
        if (isLogin == true) {
          await FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid())
              .then((value) async {
            if (value != null) {
              UserModel userModel = value;
              log(userModel.toJson().toString());
              if (userModel.role == Constant.userRoleDriver) {
                if (userModel.active == true) {
                  userModel.fcmToken = await NotificationService.getToken();
                  await FireStoreUtils.updateUser(userModel);
                  Constant.userModel = userModel;
                  if (userModel.isOwner == true) {
                    Get.offAll(OwnerDashboardScreen());
                  } else {
                    SignupController.navigateByUserModel(userModel);
                  }
                  IncomingOrderHandler.handlePendingIfAny();
                  // After dashboard mounts — show "Display over other apps" dialog.
                  Future.delayed(const Duration(milliseconds: 1200), () {
                    IncomingOrderBridge.ensureIncomingOrderPermissions();
                  });
                } else {
                  await FirebaseAuth.instance.signOut();
                  Get.offAll(const LoginScreen());
                }
              } else {
                await FirebaseAuth.instance.signOut();
                Get.offAll(const LoginScreen());
              }
            }
          });
        } else {
          await FirebaseAuth.instance.signOut();
          Get.offAll(const LoginScreen());
        }
      }
    }
  }
}

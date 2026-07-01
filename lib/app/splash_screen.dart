import 'package:door_delights_driver/controllers/splash_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // final themeController = Get.find<ThemeController>();
    // final isDark = themeController.isDark.value;
    return GetBuilder<SplashController>(
      init: SplashController(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: Color(0xFFFFFFFF),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset(
                  "assets/images/app_logo.png",
                  height: 100,
                ),
                const SizedBox(
                  height: 12,
                ),
                Text(
                  'Welcome to DoorDelights Driver App'.tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Color(COLOR_PRIMARY),
                      fontSize: 24.0,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  "Your Favorite Ride, Parcel, Rental & Item Delivered Fast!"
                      .tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

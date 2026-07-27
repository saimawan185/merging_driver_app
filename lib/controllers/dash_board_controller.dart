import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:get/instance_manager.dart';
import 'package:get/state_manager.dart';
import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart' as permission;
import '../constant/collection_name.dart';
import '../constant/constant.dart' show Constant;
import '../constant/show_toast_dialog.dart';
import '../models/order_model.dart';
import '../models/section_model.dart';
import '../models/user_model.dart';
import '../themes/theme_controller.dart';
import '../utils/fire_store_utils.dart';
import '../utils/preferences.dart';

class DashBoardController extends GetxController {
  RxInt drawerIndex = 0.obs;
  final RxInt sectionIndex = 0.obs;
  final RxList<SectionModel> userSections = <SectionModel>[].obs;

  @override
  void onInit() {
    getUser();
    updateDriverOrder();
    getTheme();
    loadUserSections();
    super.onInit();
  }

  Future<void> loadUserSections() async {
    final user = Constant.userModel;
    if (user == null || user.sectionIds == null || user.sectionIds!.isEmpty) {
      userSections.clear();
      return;
    }

    try {
      final allSections = await FireStoreUtils.getAllActiveSections();

      final filtered = allSections
          .where((section) => user.sectionIds!.contains(section.id))
          .toList();

      // Store in the cache for later use
      for (final section in filtered) {
        Constant.sectionModels[section.id!] = section;
      }

      userSections.value = filtered;
    } catch (e) {
      print('Error loading user sections: $e');
      userSections.clear();
    }
  }

  Rx<UserModel> userModel = UserModel().obs;

  DateTime? currentBackPressTime;
  RxBool canPopNow = false.obs;

  Future<void> toggleDriverStatus() async {
    // Get the current status
    final bool currentStatus = userModel.value.isActive ?? false;
    final bool newStatus = !currentStatus;

    // If auto-verify is disabled, check document verification first
    if (userModel.value.isAutoVerify == false) {
      if (userModel.value.isDocumentVerify == true) {
        // Update status and other fields
        userModel.value.isActive = newStatus;
        userModel.value.inProgressOrderID =
            Constant.userModel!.inProgressOrderID;
        userModel.value.orderRequestData = Constant.userModel!.orderRequestData;

        if (userModel.value.isActive == true) {
          await updateCurrentLocation();
        }
        await FireStoreUtils.updateUser(userModel.value);
      } else {
        ShowToastDialog.showToast(
          "Document verification is pending. Please proceed to set up your document verification."
              .tr(),
        );
      }
    } else {
      // Auto-verify is enabled – just toggle
      userModel.value.isActive = newStatus;
      userModel.value.inProgressOrderID = Constant.userModel!.inProgressOrderID;
      userModel.value.orderRequestData = Constant.userModel!.orderRequestData;

      if (userModel.value.isActive == true) {
        await updateCurrentLocation();
      }
      await FireStoreUtils.updateUser(userModel.value);
    }
  }

  Future<void> getUser() async {
    await updateCurrentLocation();
    FireStoreUtils.fireStore
        .collection(CollectionName.users)
        .doc(FireStoreUtils.getCurrentUid())
        .snapshots()
        .listen(
      (event) {
        if (event.exists) {
          userModel.value = UserModel.fromJson(event.data()!);
          Constant.userModel = UserModel.fromJson(event.data()!);
        }
      },
    );
  }

  RxString isDarkMode = "Light".obs;
  RxBool isDarkModeSwitch = false.obs;

  void getTheme() {
    bool isDark = Preferences.getBoolean(Preferences.themKey);
    isDarkMode.value = isDark ? "Dark" : "Light";
    isDarkModeSwitch.value = isDark;
  }

  void toggleDarkMode(bool value) {
    isDarkModeSwitch.value = value;
    isDarkMode.value = value ? "Dark" : "Light";
    Preferences.setBoolean(Preferences.themKey, value);
    // Update ThemeController for instant app theme change
    if (Get.isRegistered<ThemeController>()) {
      final themeController = Get.find<ThemeController>();
      themeController.isDark.value = value;
    }
  }

  Future<void> updateDriverOrder() async {
    Timestamp startTimestamp = Timestamp.now();
    DateTime currentDate = startTimestamp.toDate();
    currentDate = currentDate.subtract(const Duration(hours: 3));
    startTimestamp = Timestamp.fromDate(currentDate);

    List<OrderModel> orders = [];

    await FireStoreUtils.fireStore
        .collection(CollectionName.vendorOrders)
        .where('status',
            whereIn: [Constant.orderAccepted, Constant.orderRejected])
        .where('createdAt', isGreaterThan: startTimestamp)
        .get()
        .then((value) async {
          await Future.forEach(value.docs,
              (QueryDocumentSnapshot<Map<String, dynamic>> element) {
            try {
              orders.add(OrderModel.fromJson(element.data()));
            } catch (e, s) {
              print('watchOrdersStatus parse error ${element.id}$e $s');
            }
          });
        });

    orders.forEach((element) async {
      OrderModel orderModel = element;
      orderModel.triggerDelivery = Timestamp.now();
      await FireStoreUtils.setOrder(orderModel);
    });
  }

  Location location = Location();

  Future<void> updateCurrentLocation() async {
    try {
      PermissionStatus permissionStatus = await location.hasPermission();
      if (permissionStatus == PermissionStatus.granted) {
        var backgroundLocation =
            await permission.Permission.locationAlways.status;
        if (!backgroundLocation.isGranted) {
          await openBackgroundLocationDialog();
        }

        try {
          await location.enableBackgroundMode(enable: true);
        } catch (_) {}
        location.changeSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: double.parse(Constant.driverLocationUpdate));

        location.onLocationChanged.listen((locationData) async {
          Constant.locationDataFinal = locationData;
          await FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid())
              .then((value) async {
            if (value != null) {
              userModel.value = value;
              // Always update location in Firestore so home/cab maps stay centred,
              // regardless of isActive status.
              userModel.value.location = UserLocation(
                  latitude: locationData.latitude ?? 0.0,
                  longitude: locationData.longitude ?? 0.0);
              userModel.value.rotation = locationData.heading;
              await FireStoreUtils.updateUser(userModel.value);
            }
          });
        });
      } else {
        location.requestPermission().then((permissionStatus) async {
          if (permissionStatus == PermissionStatus.granted) {
            try {
              await location.enableBackgroundMode(enable: true);
            } catch (_) {}
            location.changeSettings(
                accuracy: LocationAccuracy.high,
                distanceFilter: double.parse(Constant.driverLocationUpdate));
            location.onLocationChanged.listen((locationData) async {
              Constant.locationDataFinal = locationData;
              await FireStoreUtils.getUserProfile(
                      FireStoreUtils.getCurrentUid())
                  .then((value) async {
                if (value != null) {
                  userModel.value = value;
                  userModel.value.location = UserLocation(
                      latitude: locationData.latitude ?? 0.0,
                      longitude: locationData.longitude ?? 0.0);
                  userModel.value.rotation = locationData.heading;
                  await FireStoreUtils.updateUser(userModel.value);
                  ShowToastDialog.closeLoader();
                }
              });
            });
          } else {
            ShowToastDialog.closeLoader();
          }
        });
        await openBackgroundLocationDialog();
      }
    } catch (e) {
      print(e);
    }
  }
}

openBackgroundLocationDialog() {
  final isDark = Get.find<ThemeController>().isDark.value;

  return showDialog(
      context: Get.context!,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16.0))),
          contentPadding: EdgeInsets.only(top: 10.0),
          content: Container(
            //width: 300.0,
            width: MediaQuery.of(context).size.width * 0.6,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding:
                      const EdgeInsets.only(left: 8.0, right: 8.0, top: 8.0),
                  child: Text(
                    "Background Location permission".tr(),
                    style: TextStyle(
                        color: isDark ? Color(0xffFFFFFF) : Color(0xff555555),
                        fontWeight: FontWeight.bold),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                      left: 8.0, right: 8.0, top: 8.0, bottom: 8.0),
                  child: Text(
                      "This app collects location data to enable location fetching at the time of you are on the way to deliver order or even when the app is in background."
                          .tr()),
                ),
                InkWell(
                  onTap: () async {
                    await permission.Permission.locationAlways.request();
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: EdgeInsets.only(top: 20.0, bottom: 20.0),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(16.0),
                          bottomRight: Radius.circular(16.0)),
                    ),
                    child: Text(
                      "Okay",
                      style: TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      });
}

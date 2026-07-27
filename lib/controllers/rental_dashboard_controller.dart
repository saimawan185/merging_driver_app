import 'package:door_delights_driver/constant/collection_name.dart';
import 'package:door_delights_driver/constant/constant.dart';
import 'package:door_delights_driver/constant/show_toast_dialog.dart';
import 'package:door_delights_driver/models/user_model.dart';
import 'package:door_delights_driver/utils/fire_store_utils.dart';
import 'package:door_delights_driver/utils/preferences.dart';
import 'package:get/get.dart' hide Trans;
import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart' as permission;

import '../models/section_model.dart';
import '../themes/theme_controller.dart';
import 'dash_board_controller.dart';

class RentalDashboardController extends GetxController {
  RxInt drawerIndex = 0.obs;

  @override
  void onInit() {
    getUser();
    getTheme();
    loadUserSections();
    super.onInit();
  }

  final RxInt sectionIndex = 0.obs;
  final RxList<SectionModel> userSections = <SectionModel>[].obs;

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

  Future<void> getUser() async {
    await updateCurrentLocation();
    FireStoreUtils.fireStore
        .collection(CollectionName.users)
        .doc(FireStoreUtils.getCurrentUid())
        .snapshots()
        .listen(
      (event) async {
        if (event.exists) {
          userModel.value = UserModel.fromJson(event.data()!);
          Constant.userModel = UserModel.fromJson(event.data()!);
          // Preload all registered sections into cache
          final sid = userModel.value.sectionId!;
          // for (final sid in userModel.value.sectionIds ?? <String>[]) {
          if (!Constant.sectionModels.containsKey(sid)) {
            FireStoreUtils.getSectionBySectionId(sid).then((sectionValue) {
              if (sectionValue != null)
                Constant.sectionModels[sid] = sectionValue;
            });
          }
          // }
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
              if (userModel.value.isActive == true) {
                userModel.value.location = UserLocation(
                    latitude: locationData.latitude ?? 0.0,
                    longitude: locationData.longitude ?? 0.0);
                userModel.value.rotation = locationData.heading;
                await FireStoreUtils.updateUser(userModel.value);
              }
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
                  if (userModel.value.isActive == true) {
                    userModel.value.location = UserLocation(
                        latitude: locationData.latitude ?? 0.0,
                        longitude: locationData.longitude ?? 0.0);
                    userModel.value.rotation = locationData.heading;
                    await FireStoreUtils.updateUser(userModel.value);
                  }
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

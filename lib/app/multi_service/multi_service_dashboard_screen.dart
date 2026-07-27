import 'package:door_delights_driver/app/cab_screen/cab_dashboard_screen.dart';
import 'package:door_delights_driver/app/dash_board_screen/dash_board_screen.dart';
import 'package:door_delights_driver/app/parcel_screen/parcel_dashboard_screen.dart';
import 'package:door_delights_driver/app/rental_service/rental_dashboard_screen.dart';
import 'package:door_delights_driver/constant/constant.dart';
import 'package:door_delights_driver/controllers/cab_dashboard_controller.dart';
import 'package:door_delights_driver/controllers/dash_board_controller.dart';
import 'package:door_delights_driver/controllers/parcel_dashboard_controller.dart';
import 'package:door_delights_driver/controllers/rental_dashboard_controller.dart';
import 'package:door_delights_driver/themes/app_them_data.dart';
import 'package:door_delights_driver/themes/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Trans;
import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization/easy_localization.dart';

/// Controller that tracks which service tab is active.
class MultiServiceDashboardController extends GetxController {
  RxInt currentIndex = 0.obs;
}

/// Unified dashboard for drivers registered to multiple services.
/// Shows a BottomNavigationBar with one tab per registered service.
/// Each tab renders the full existing service dashboard.
class MultiServiceDashboardScreen extends StatelessWidget {
  const MultiServiceDashboardScreen({super.key});

  Widget _dashboardForService(String serviceType) {
    switch (serviceType) {
      case 'cab-service':
        return const CabDashboardScreen();
      case 'parcel_delivery':
        return const ParcelDashboardScreen();
      case 'rental-service':
        return const RentalDashboardScreen();
      default:
        return const DashBoardScreen();
    }
  }

  BottomNavigationBarItem _navItemForService(String serviceType) {
    switch (serviceType) {
      case 'cab-service':
        return const BottomNavigationBarItem(
          icon: Icon(Icons.local_taxi_outlined),
          activeIcon: Icon(Icons.local_taxi),
          label: 'Cab',
        );
      case 'parcel_delivery':
        return const BottomNavigationBarItem(
          icon: Icon(Icons.inventory_2_outlined),
          activeIcon: Icon(Icons.inventory_2),
          label: 'Parcel',
        );
      case 'rental-service':
        return const BottomNavigationBarItem(
          icon: Icon(Icons.car_rental_outlined),
          activeIcon: Icon(Icons.car_rental),
          label: 'Rental',
        );
      default:
        return const BottomNavigationBarItem(
          icon: Icon(Icons.delivery_dining_outlined),
          activeIcon: Icon(Icons.delivery_dining),
          label: 'Delivery',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (Constant.userModel!.serviceType != null &&
        Constant.userModel!.serviceType!.isNotEmpty) {
      return _dashboardForService(Constant.userModel!.serviceType!);
    }

    final themeController = Get.find<ThemeController>();

    return GetBuilder<MultiServiceDashboardController>(
      init: MultiServiceDashboardController(),
      builder: (controller) {
        return Obx(() {
          final isDark = themeController.isDark.value;
          return Scaffold(
            body: IndexedStack(
              index: controller.currentIndex.value,
              children: [
                _dashboardForService(Constant.userModel!.serviceType!)
              ],
            ),
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: controller.currentIndex.value,
              onTap: (index) {
                controller.currentIndex.value = index;
                // Reset each dashboard to home screen when switching tabs
                if (Get.isRegistered<DashBoardController>()) {
                  Get.find<DashBoardController>().drawerIndex.value = 0;
                }
                if (Get.isRegistered<CabDashBoardController>()) {
                  Get.find<CabDashBoardController>().drawerIndex.value = 0;
                }
                if (Get.isRegistered<ParcelDashboardController>()) {
                  Get.find<ParcelDashboardController>().drawerIndex.value = 0;
                }
                if (Get.isRegistered<RentalDashboardController>()) {
                  Get.find<RentalDashboardController>().drawerIndex.value = 0;
                }
              },
              type: BottomNavigationBarType.fixed,
              selectedItemColor: AppThemeData.primary300,
              unselectedItemColor:
                  isDark ? AppThemeData.grey400 : AppThemeData.grey500,
              backgroundColor:
                  isDark ? AppThemeData.grey900 : AppThemeData.grey50,
              items: [_navItemForService(Constant.userModel!.serviceType!)],
            ),
          );
        });
      },
    );
  }
}

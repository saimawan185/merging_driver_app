import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:get/get.dart' hide Trans;
import '../../controllers/dash_board_controller.dart';
import '../../models/section_model.dart';
import '../../themes/app_them_data.dart';
import '../../themes/theme_controller.dart';
import '../cab_screen/cab_order_list_screen.dart';
import '../parcel_screen/parcel_order_list_screen.dart';
import '../rental_service/rental_order_list_screen.dart';
import 'order_list_screen.dart';

class AllOrdersScreen extends StatefulWidget {
  const AllOrdersScreen({super.key});

  @override
  State<AllOrdersScreen> createState() => _AllOrdersScreenState();
}

class _AllOrdersScreenState extends State<AllOrdersScreen> {
  late final DashBoardController _dashboardController;

  final ThemeController _themeController = Get.find<ThemeController>();

  SectionModel? _selectedSection;

  @override
  void initState() {
    try {
      _dashboardController = Get.find<DashBoardController>();
    } catch (e) {
      _dashboardController =
          Get.put<DashBoardController>(DashBoardController());
      print('Error in initState: $e');
    }
    super.initState();
    if (_dashboardController.userSections.isNotEmpty) {
      _selectedSection = _dashboardController.userSections.last;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isDark = _themeController.isDark.value;
      return Scaffold(
        backgroundColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
        appBar: AppBar(
          backgroundColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
          title: Text(
            'Orders'.tr(),
            style: TextStyle(
              color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
            ),
          ),
          centerTitle: true,
          elevation: 0,
          actions: [
            Obx(() {
              final sections = _dashboardController.userSections;
              if (sections.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('No sections available'),
                );
              }
              return DropdownButton<SectionModel>(
                value: _selectedSection,
                dropdownColor:
                    isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                items: sections.map((section) {
                  return DropdownMenuItem<SectionModel>(
                    value: section,
                    child: Text(
                      _getSectionDisplayName(section),
                      style: TextStyle(
                        color:
                            isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (SectionModel? newSection) {
                  if (newSection != null) {
                    setState(() {
                      _selectedSection = newSection;
                    });
                  }
                },
                underline: const SizedBox.shrink(),
                icon: Icon(
                  Icons.arrow_drop_down,
                  color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                ),
              );
            }),
            const SizedBox(width: 8),
          ],
        ),
        body: _selectedSection == null
            ? Center(
                child: Text(
                  'Please select a section',
                  style: TextStyle(
                    color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                  ),
                ),
              )
            : _buildOrderListForSection(_selectedSection!),
      );
    });
  }

  String _getSectionDisplayName(SectionModel section) {
    final flag = section.serviceTypeFlag ?? '';
    switch (flag) {
      case 'cab-service':
        return 'Cab'.tr();
      case 'parcel_delivery':
        return 'Parcel'.tr();
      case 'rental-service':
        return 'Rental'.tr();
      default:
        return 'Delivery'.tr();
    }
  }

  Widget _buildOrderListForSection(SectionModel section) {
    final flag = section.serviceTypeFlag ?? 'delivery-service';
    switch (flag) {
      case 'cab-service':
        return const CabOrderListScreen();
      case 'parcel_delivery':
        return const ParcelOrderListScreen();
      case 'rental-service':
        return const RentalOrderListScreen();
      default:
        return const OrderListScreen();
    }
  }
}

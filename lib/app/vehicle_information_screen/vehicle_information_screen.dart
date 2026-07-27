import 'package:door_delights_driver/models/car_makes.dart';
import 'package:door_delights_driver/models/car_model.dart';
import 'package:door_delights_driver/models/vehicle_type.dart';
import 'package:door_delights_driver/themes/app_them_data.dart';
import 'package:door_delights_driver/themes/responsive.dart';
import 'package:door_delights_driver/themes/text_field_widget.dart';
import 'package:door_delights_driver/themes/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Trans;
import 'package:easy_localization/easy_localization.dart';
import '../../constant/constant.dart';
import '../../controllers/vehicle_information_controller.dart';

class VehicleInformationScreen extends StatelessWidget {
  final String serviceType;

  const VehicleInformationScreen({
    super.key,
    this.serviceType = 'delivery-service',
  });

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    return Obx(() {
      final isDark = themeController.isDark.value;
      return GetBuilder<VehicleInformationController>(
        init: VehicleInformationController(initialServiceType: serviceType),
        tag: serviceType,
        builder: (controller) {
          final isOwnerDriver = controller.userModel.value.ownerId != null &&
              controller.userModel.value.ownerId!.isNotEmpty;

          return Scaffold(
            backgroundColor:
                isDark ? AppThemeData.surfaceDark : AppThemeData.grey100,
            body: controller.isLoading.value
                ? Center(child: Constant.loader())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Service badge ────────────────────────────────
                        Row(
                          children: [
                            Icon(Icons.directions_car_rounded,
                                size: 16, color: AppThemeData.primary300),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Obx(
                                () => Text(
                                  controller.allUserSections.isNotEmpty
                                      ? controller.allUserSections
                                          .map((s) => s.name ?? '')
                                          .join(', ')
                                      : controller
                                          .getReadableServiceType(serviceType),
                                  style: TextStyle(
                                    fontFamily: AppThemeData.semiBold,
                                    fontSize: 13,
                                    color: AppThemeData.primary300,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // ── Single Vehicle Details Card ──────────────────
                        _Card(
                          isDark: isDark,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Vehicle Details".tr(),
                                style: TextStyle(
                                  fontFamily: AppThemeData.semiBold,
                                  fontSize: 16,
                                  color: isDark
                                      ? AppThemeData.greyDark900
                                      : AppThemeData.grey800,
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Vehicle Type
                              if (controller.vehicleTypeOptions.isNotEmpty)
                                _DropdownField<VehicleType>(
                                  label: "Vehicle Type".tr(),
                                  value: controller.selectedVehicleType.value,
                                  items: controller.vehicleTypeOptions,
                                  isDark: isDark,
                                  enabled: !isOwnerDriver,
                                  onChanged: (v) =>
                                      controller.selectedVehicleType.value = v,
                                ),
                              const SizedBox(height: 12),

                              // Ride Type (cab only)
                              if (controller.rideTypeOptions.isNotEmpty)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Ride Type".tr(),
                                      style: TextStyle(
                                        fontFamily: AppThemeData.semiBold,
                                        fontSize: 13,
                                        color: isDark
                                            ? AppThemeData.greyDark900
                                            : AppThemeData.grey700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Obx(
                                      () => Wrap(
                                        spacing: 8,
                                        children: controller.rideTypeOptions
                                            .map((type) {
                                          final isSelected = controller
                                                  .selectedRideType.value ==
                                              type;
                                          return ChoiceChip(
                                            label: Text(
                                              type[0].toUpperCase() +
                                                  type.substring(1),
                                              style: TextStyle(
                                                color: isSelected
                                                    ? Colors.white
                                                    : (isDark
                                                        ? Colors.white70
                                                        : Colors.grey.shade700),
                                                fontWeight: isSelected
                                                    ? FontWeight.w600
                                                    : FontWeight.w400,
                                              ),
                                            ),
                                            selected: isSelected,
                                            onSelected: (_) => controller
                                                .selectedRideType.value = type,
                                            backgroundColor: isDark
                                                ? AppThemeData.greyDark100
                                                : Colors.white,
                                            selectedColor:
                                                AppThemeData.primary300,
                                            side: BorderSide(
                                              color: isSelected
                                                  ? AppThemeData.primary300
                                                  : (isDark
                                                      ? AppThemeData.greyDark400
                                                      : Colors.grey.shade300),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                ),

                              // Car Brand
                              _DropdownField<CarMakes>(
                                label: "Car Brand".tr(),
                                value: controller.selectedCarMakes.value,
                                items: controller.carMakesList,
                                isDark: isDark,
                                enabled: !isOwnerDriver,
                                onChanged: (v) {
                                  controller.selectedCarMakes.value = v;
                                  controller.getCarModels();
                                },
                              ),
                              const SizedBox(height: 12),

                              // Car Model
                              _DropdownField<CarModel>(
                                label: "Car Model".tr(),
                                value: controller.selectedCarModel.value,
                                items: controller.carModelList,
                                isDark: isDark,
                                enabled: !isOwnerDriver,
                                onChanged: (v) =>
                                    controller.selectedCarModel.value = v,
                              ),
                              const SizedBox(height: 12),

                              // Car Plate
                              TextFieldWidget(
                                title: 'Car Plate Number'.tr(),
                                controller: controller.carPlateController.value,
                                hintText: 'e.g. GJ05JH9405'.tr(),
                                textInputAction: TextInputAction.done,
                                enable: !isOwnerDriver,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
            bottomNavigationBar: isOwnerDriver || controller.isLoading.value
                ? const SizedBox.shrink()
                : SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: ElevatedButton(
                        onPressed: () => controller.saveVehicleInformation(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppThemeData.primary300,
                          minimumSize: Size(Responsive.width(100, context), 52),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Text(
                          "Save".tr(),
                          style: TextStyle(
                            color: AppThemeData.grey50,
                            fontSize: 16,
                            fontFamily: AppThemeData.semiBold,
                          ),
                        ),
                      ),
                    ),
                  ),
          );
        },
      );
    });
  }
}

// ── Reusable card container ──────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  final bool isDark;

  const _Card({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppThemeData.greyDark50 : AppThemeData.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ── Reusable dropdown ──────────────────────────────────────────────

class _DropdownField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<T> items;
  final bool isDark;
  final bool enabled;
  final ValueChanged<T?> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.isDark,
    required this.enabled,
    required this.onChanged,
  });

  String _labelFor(T item) {
    if (item is String) return item;
    if (item is VehicleType) return item.name ?? '';
    if (item is CarMakes) return item.name ?? '';
    if (item is CarModel) return item.name ?? '';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppThemeData.greyDark900 : AppThemeData.grey900;
    final borderColor =
        isDark ? AppThemeData.greyDark400 : AppThemeData.grey300;
    final fillColor = isDark ? AppThemeData.greyDark100 : AppThemeData.grey50;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: AppThemeData.semiBold,
            fontSize: 13,
            color: isDark ? AppThemeData.greyDark900 : AppThemeData.grey700,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<T>(
          value: items.contains(value) ? value : null,
          onChanged: enabled ? onChanged : null,
          isExpanded: true,
          dropdownColor:
              isDark ? AppThemeData.greyDark100 : AppThemeData.surface,
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            filled: true,
            fillColor: fillColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  BorderSide(color: AppThemeData.primary300, width: 1.5),
            ),
          ),
          style: TextStyle(
            fontSize: 14,
            color: textColor,
            fontFamily: AppThemeData.medium,
          ),
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              size: 20, color: borderColor),
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(
                _labelFor(item),
                style: TextStyle(
                    fontSize: 14,
                    color: textColor,
                    fontFamily: AppThemeData.medium),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

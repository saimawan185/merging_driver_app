import 'package:door_delights_driver/constant/constant.dart';
import 'package:door_delights_driver/controllers/change_section_controller.dart';
import 'package:door_delights_driver/themes/app_them_data.dart';
import 'package:door_delights_driver/themes/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Trans;
import 'package:easy_localization/easy_localization.dart';

class ChangeSectionScreen extends StatelessWidget {
  const ChangeSectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Get.find<ThemeController>().isDark.value;

    return GetX(
      init: ChangeSectionController(),
      builder: (controller) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor:
                isDark ? AppThemeData.grey900 : AppThemeData.grey50,
            centerTitle: false,
            titleSpacing: 0,
            title: Text(
              "Change Section".tr(),
              style: TextStyle(
                color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                fontSize: 18,
                fontFamily: AppThemeData.medium,
              ),
            ),
          ),
          body: controller.isLoading.value
              ? Constant.loader()
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Select the sections you want to serve. You can change them anytime."
                              .tr(),
                          style: TextStyle(
                            color: isDark
                                ? AppThemeData.grey400
                                : AppThemeData.grey600,
                            fontSize: 14,
                            fontFamily: AppThemeData.regular,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Available Sections".tr(),
                          style: TextStyle(
                            fontFamily: AppThemeData.semiBold,
                            fontSize: 14,
                            color: isDark
                                ? AppThemeData.grey100
                                : AppThemeData.grey800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        controller.allSections.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    "No sections available".tr(),
                                    style: TextStyle(
                                      color: isDark
                                          ? AppThemeData.grey400
                                          : AppThemeData.grey600,
                                    ),
                                  ),
                                ),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppThemeData.grey900
                                      : AppThemeData.grey50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isDark
                                        ? AppThemeData.grey700
                                        : AppThemeData.grey300,
                                  ),
                                ),
                                child: Column(
                                  children:
                                      controller.allSections.map((section) {
                                    return CheckboxListTile(
                                      dense: true,
                                      title: Text(
                                        section.name ?? '',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isDark
                                              ? AppThemeData.grey50
                                              : AppThemeData.grey900,
                                          fontFamily: AppThemeData.medium,
                                        ),
                                      ),
                                      subtitle: Text(
                                        controller.serviceFlagLabel(
                                            section.serviceTypeFlag),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? AppThemeData.grey400
                                              : AppThemeData.grey600,
                                          fontFamily: AppThemeData.regular,
                                        ),
                                      ),
                                      value:
                                          controller.isSectionSelected(section),
                                      onChanged: (_) =>
                                          controller.toggleSection(section),
                                      activeColor: AppThemeData.primary300,
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      secondary: Icon(
                                        Icons.drag_handle,
                                        color: isDark
                                            ? AppThemeData.grey600
                                            : AppThemeData.grey400,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.all(16),
            child: InkWell(
              onTap: () => controller.saveChanges(),
              child: Container(
                decoration: BoxDecoration(
                  color: AppThemeData.primary300,
                  borderRadius: BorderRadius.circular(10),
                ),
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    "Save Changes".tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppThemeData.grey50,
                      fontSize: 16,
                      fontFamily: AppThemeData.medium,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

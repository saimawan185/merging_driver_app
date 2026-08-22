import 'package:door_delights_driver/constant/show_toast_dialog.dart';
import 'package:door_delights_driver/controllers/forgot_password_controller.dart';
import 'package:door_delights_driver/themes/app_them_data.dart';
import 'package:door_delights_driver/themes/responsive.dart';
import 'package:door_delights_driver/themes/text_field_widget.dart';
import 'package:door_delights_driver/themes/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart' hide Trans;
import 'package:easy_localization/easy_localization.dart';

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
        init: ForgotPasswordController(),
        builder: (controller) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor:
                  isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
            ),
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Forgot Password".tr(),
                    style: TextStyle(
                        color:
                            isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                        fontSize: 22,
                        fontFamily: AppThemeData.semiBold),
                  ),
                  Text(
                    "No worries!! We’ll send you reset instructions".tr(),
                    style: TextStyle(
                        color: isDark
                            ? AppThemeData.grey400
                            : AppThemeData.grey500,
                        fontSize: 16,
                        fontFamily: AppThemeData.regular),
                  ),
                  const SizedBox(
                    height: 32,
                  ),
                  TextFieldWidget(
                    title: 'Email Address'.tr(),
                    controller: controller.emailEditingController.value,
                    hintText: 'Enter email address'.tr(),
                    prefix: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SvgPicture.asset(
                        "assets/icons/ic_mail.svg",
                        colorFilter: ColorFilter.mode(
                          isDark ? AppThemeData.grey300 : AppThemeData.grey600,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 32,
                  ),
                ],
              ),
            ),
            bottomNavigationBar: InkWell(
              onTap: () {
                if (controller.emailEditingController.value.text.isEmpty) {
                  ShowToastDialog.showToast("Please enter valid email".tr());
                } else {
                  controller.forgotPassword();
                }
              },
              child: Container(
                color: AppThemeData.primary300,
                width: Responsive.width(100, context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    "Forgot Password".tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark ? AppThemeData.grey50 : AppThemeData.grey50,
                      fontSize: 16,
                      fontFamily: AppThemeData.medium,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          );
        });
  }
}

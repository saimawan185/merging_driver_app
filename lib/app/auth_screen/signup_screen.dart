import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart' hide Trans;
import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../constant/constant.dart';
import '../../constant/show_toast_dialog.dart';
import '../../controllers/signup_controller.dart';
import '../../models/car_makes.dart';
import '../../models/car_model.dart';
import '../../models/vehicle_type.dart';
import '../../models/zone_model.dart';
import '../../theme/app_them_data.dart';
import '../../theme/responsive.dart';
import '../../themes/text_field_widget.dart';
import '../../themes/theme_controller.dart';
import '../../ui/login/LoginScreen.dart';

class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;
    return GetX(
        init: SignupController(),
        builder: (SignupController controller) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor:
                  isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
            ),
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Create an Account".tr(),
                      style: TextStyle(
                          color: isDark
                              ? AppThemeData.grey50
                              : AppThemeData.grey900,
                          fontSize: 22,
                          fontFamily: AppThemeData.semiBold),
                    ),
                    Text(
                      "Sign up now to start your journey as a DoorDelights driver and begin earning with every delivery."
                          .tr(),
                      style: TextStyle(
                          color: isDark
                              ? AppThemeData.grey50
                              : AppThemeData.grey500,
                          fontFamily: AppThemeData.regular),
                    ),
                    const SizedBox(height: 10),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Already Have an account?'.tr(),
                            style: TextStyle(
                                color: isDark
                                    ? AppThemeData.grey50
                                    : AppThemeData.grey900,
                                fontFamily: AppThemeData.medium,
                                fontWeight: FontWeight.w500),
                          ),
                          const WidgetSpan(child: SizedBox(width: 5)),
                          TextSpan(
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                Get.offAll(() => LoginScreen());
                              },
                            text: 'Log in'.tr(),
                            style: TextStyle(
                              color: AppThemeData.primary300,
                              fontFamily: AppThemeData.medium,
                              fontWeight: FontWeight.w500,
                              decoration: TextDecoration.underline,
                              decorationColor: AppThemeData.primary300,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                'Profile Picture',
                                style: AppThemeData.mediumTextStyle(
                                    fontSize: 14,
                                    color: isDark
                                        ? AppThemeData.greyDark700
                                        : AppThemeData.grey700),
                              ),
                              Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 50,
                                    backgroundImage: controller
                                                .profileImage.value !=
                                            null
                                        ? FileImage(
                                            controller.profileImage.value!)
                                        : AssetImage(
                                                'assets/images/placeholder.jpg')
                                            as ImageProvider,
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: IconButton(
                                      icon: const Icon(Icons.camera_alt),
                                      onPressed: () =>
                                          controller.pickImage(true),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                'Car Image',
                                style: AppThemeData.mediumTextStyle(
                                    fontSize: 14,
                                    color: isDark
                                        ? AppThemeData.greyDark700
                                        : AppThemeData.grey700),
                              ),
                              Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 50,
                                    backgroundImage: controller
                                                .carImage.value !=
                                            null
                                        ? FileImage(controller.carImage.value!)
                                        : AssetImage(
                                                'assets/images/car_default_image.png')
                                            as ImageProvider,
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: IconButton(
                                      icon: const Icon(Icons.camera_alt),
                                      onPressed: () =>
                                          controller.pickImage(false),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Individual / Company ─────────────────────────────
                    Text(
                      'Continue as'.tr(),
                      style: AppThemeData.mediumTextStyle(
                          fontSize: 14,
                          color: isDark
                              ? AppThemeData.greyDark700
                              : AppThemeData.grey700),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: Text('Individual'.tr(),
                                style: TextStyle(
                                    color: isDark
                                        ? AppThemeData.greyDark700
                                        : AppThemeData.grey700)),
                            value: 'Individual',
                            groupValue: controller.selectedValue.value,
                            activeColor: AppThemeData.primary300,
                            onChanged: (v) => controller.onRoleChanged(v!),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: Text('Company'.tr(),
                                style: TextStyle(
                                    color: isDark
                                        ? AppThemeData.greyDark700
                                        : AppThemeData.grey700)),
                            value: 'Company',
                            groupValue: controller.selectedValue.value,
                            activeColor: AppThemeData.primary300,
                            onChanged: (v) => controller.onRoleChanged(v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // ── Section selection ─────────────────────────────────
                    Text(
                      "Select Sections".tr(),
                      style: TextStyle(
                          fontFamily: AppThemeData.semiBold,
                          fontSize: 14,
                          color: isDark
                              ? AppThemeData.grey100
                              : AppThemeData.grey800),
                    ),
                    const SizedBox(height: 5),
                    controller.visibleSections.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                  controller.allSections.isEmpty
                                      ? "Loading sections...".tr()
                                      : "No sections available".tr(),
                                  style: TextStyle(
                                      color: isDark
                                          ? AppThemeData.grey400
                                          : AppThemeData.grey600)),
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
                                      ? AppThemeData.greyDark400
                                      : AppThemeData.grey400),
                            ),
                            child: Column(
                              children:
                                  controller.visibleSections.map((section) {
                                final isChecked =
                                    controller.isSectionSelected(section);
                                return CheckboxListTile(
                                  dense: true,
                                  title: Text(
                                    section.name ?? '',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: isDark
                                            ? AppThemeData.grey50
                                            : AppThemeData.grey900,
                                        fontFamily: AppThemeData.medium),
                                  ),
                                  subtitle: Text(
                                    controller.serviceFlagLabel(
                                        section.serviceTypeFlag),
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? AppThemeData.grey400
                                            : AppThemeData.grey600,
                                        fontFamily: AppThemeData.regular),
                                  ),
                                  value: isChecked,
                                  activeColor: AppThemeData.primary300,
                                  checkColor: Colors.white,
                                  onChanged: (_) async {
                                    await controller.toggleSection(section);
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                    const SizedBox(height: 10),

                    // ── Vehicle details (single block) ──────────────────
                    Obx(() {
                      final needsVehicle = controller.selectedSections
                              .any((s) => controller.sectionNeedsVehicle(s)) &&
                          controller.selectedValue.value != "Company";
                      if (!needsVehicle) return const SizedBox.shrink();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          Text(
                            'Vehicle Details',
                            style: TextStyle(
                                fontFamily: AppThemeData.semiBold,
                                fontSize: 14,
                                color: AppThemeData.primary300),
                          ),
                          const SizedBox(height: 5),
                          // ── Vehicle Type ──
                          if (controller.vehicleTypeOptions.isNotEmpty)
                            DropdownButtonFormField<String>(
                              hint: Text('Vehicle Type'.tr(),
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: AppThemeData.grey700,
                                      fontFamily: AppThemeData.regular)),
                              icon: const Icon(Icons.keyboard_arrow_down),
                              dropdownColor: isDark
                                  ? AppThemeData.grey900
                                  : AppThemeData.grey50,
                              decoration: _dropdownDecoration(isDark),
                              value: controller.selectedVehicleTypeName.value,
                              onChanged: (value) {
                                if (value != null) {
                                  controller.selectedVehicleTypeName.value =
                                      value;
                                  controller.selectedVehicleTypeId.value =
                                      controller.vehicleTypeNameToId[value];
                                  controller.update();
                                }
                              },
                              style: TextStyle(
                                  fontSize: 14,
                                  color: isDark
                                      ? AppThemeData.grey50
                                      : AppThemeData.grey900,
                                  fontFamily: AppThemeData.medium),
                              items: controller.vehicleTypeOptions
                                  .map((item) => DropdownMenuItem<String>(
                                        value: item,
                                        child: Text(item),
                                      ))
                                  .toList(),
                            ),
                          // ── Ride Type (only if cab section selected) ──
                          if (controller.rideTypeOptions.isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 12),
                                Text(
                                  'Ride Type'.tr(),
                                  style: TextStyle(
                                    fontFamily: AppThemeData.semiBold,
                                    fontSize: 14,
                                    color: AppThemeData.primary300,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Obx(
                                  () => Wrap(
                                    spacing: 8,
                                    children:
                                        controller.rideTypeOptions.map((type) {
                                      final isSelected =
                                          controller.selectedRideType.value ==
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
                                        selectedColor: AppThemeData.primary300,
                                        side: BorderSide(
                                          color: isSelected
                                              ? AppThemeData.primary300
                                              : (isDark
                                                  ? AppThemeData.greyDark400
                                                  : Colors.grey.shade300),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 10),
                          // ── Car Brand ──
                          DropdownButtonFormField<CarMakes>(
                            hint: Text('Car Brand'.tr(),
                                style: TextStyle(
                                    fontSize: 14,
                                    color: AppThemeData.grey700,
                                    fontFamily: AppThemeData.regular)),
                            icon: const Icon(Icons.keyboard_arrow_down),
                            dropdownColor: isDark
                                ? AppThemeData.grey900
                                : AppThemeData.grey50,
                            decoration: _dropdownDecoration(isDark),
                            value: controller.selectedCarMakes.value,
                            onChanged: (value) {
                              if (value != null) {
                                controller.selectedCarMakes.value = value;
                                controller.getCarModels();
                                controller.update();
                              }
                            },
                            style: TextStyle(
                                fontSize: 14,
                                color: isDark
                                    ? AppThemeData.grey50
                                    : AppThemeData.grey900,
                                fontFamily: AppThemeData.medium),
                            items: controller.carMakesList
                                .map((item) => DropdownMenuItem<CarMakes>(
                                    value: item,
                                    child: Text(item.name.toString())))
                                .toList(),
                          ),
                          const SizedBox(height: 10),
                          // ── Car Model ──
                          DropdownButtonFormField<CarModel>(
                            hint: Text('Car Model'.tr(),
                                style: TextStyle(
                                    fontSize: 14,
                                    color: AppThemeData.grey700,
                                    fontFamily: AppThemeData.regular)),
                            icon: const Icon(Icons.keyboard_arrow_down),
                            dropdownColor: isDark
                                ? AppThemeData.grey900
                                : AppThemeData.grey50,
                            decoration: _dropdownDecoration(isDark),
                            value: controller.selectedCarModel.value,
                            onChanged: (value) {
                              if (value != null) {
                                controller.selectedCarModel.value = value;
                                controller.update();
                              }
                            },
                            style: TextStyle(
                                fontSize: 14,
                                color: isDark
                                    ? AppThemeData.grey50
                                    : AppThemeData.grey900,
                                fontFamily: AppThemeData.medium),
                            items: controller.carModelList
                                .map((item) => DropdownMenuItem<CarModel>(
                                    value: item,
                                    child: Text(item.name.toString())))
                                .toList(),
                          ),
                          const SizedBox(height: 10),
                          // ── Car Plate ──
                          TextFieldWidget(
                            title: 'Car Plate Number'.tr(),
                            controller: controller.carPlateController.value,
                            hintText: 'Enter Car Plate Number'.tr(),
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 16),
                        ],
                      );
                    }),

                    // ── Name fields ───────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: TextFieldWidget(
                            title: 'First Name'.tr(),
                            controller:
                                controller.firstNameEditingController.value,
                            hintText: 'Enter First Name'.tr(),
                            prefix: Padding(
                              padding: const EdgeInsets.all(12),
                              child: SvgPicture.asset(
                                  "assets/icons/ic_user.svg",
                                  colorFilter: ColorFilter.mode(
                                      isDark
                                          ? AppThemeData.grey300
                                          : AppThemeData.grey600,
                                      BlendMode.srcIn)),
                            ),
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFieldWidget(
                            title: 'Last Name'.tr(),
                            controller:
                                controller.lastNameEditingController.value,
                            hintText: 'Enter Last Name'.tr(),
                            prefix: Padding(
                              padding: const EdgeInsets.all(12),
                              child: SvgPicture.asset(
                                  "assets/icons/ic_user.svg",
                                  colorFilter: ColorFilter.mode(
                                      isDark
                                          ? AppThemeData.grey300
                                          : AppThemeData.grey600,
                                      BlendMode.srcIn)),
                            ),
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                      ],
                    ),

                    // ── Email ─────────────────────────────────────────────
                    TextFieldWidget(
                      title: 'Email Address'.tr(),
                      textInputType: TextInputType.emailAddress,
                      controller: controller.emailEditingController.value,
                      hintText: 'Enter Email Address'.tr(),
                      enable: controller.type.value == "google" ||
                              controller.type.value == "apple"
                          ? false
                          : true,
                      prefix: Padding(
                        padding: const EdgeInsets.all(12),
                        child: SvgPicture.asset("assets/icons/ic_mail.svg",
                            colorFilter: ColorFilter.mode(
                                isDark
                                    ? AppThemeData.grey300
                                    : AppThemeData.grey600,
                                BlendMode.srcIn)),
                      ),
                      textInputAction: TextInputAction.next,
                    ),

                    // ── Phone number ──────────────────────────────────────
                    TextFieldWidget(
                      title: 'Phone Number'.tr(),
                      controller: controller.phoneNUmberEditingController.value,
                      hintText: 'Enter Phone Number'.tr(),
                      enable: controller.type.value == "mobileNumber"
                          ? false
                          : true,
                      textInputType: const TextInputType.numberWithOptions(
                          signed: true, decimal: true),
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp('[0-9]'))
                      ],
                      prefix: CountryCodePicker(
                        onInit: (value) {
                          controller.countryCodeEditingController.value.text =
                              value?.dialCode ?? Constant.defaultCountryCode;
                          controller
                                  .countryISOCodeEditingController.value.text =
                              value?.code ?? Constant.defaultCountryCode;
                        },
                        enabled: controller.type.value == "mobileNumber"
                            ? false
                            : true,
                        onChanged: (value) {
                          controller.countryCodeEditingController.value.text =
                              value.dialCode ?? Constant.defaultCountryCode;
                          controller.countryISOCodeEditingController.value
                              .text = value.code ?? Constant.defaultCountryCode;
                        },
                        dialogTextStyle: TextStyle(
                            color: isDark
                                ? AppThemeData.grey50
                                : AppThemeData.grey900,
                            fontWeight: FontWeight.w500,
                            fontFamily: AppThemeData.medium),
                        dialogBackgroundColor: isDark
                            ? AppThemeData.grey800
                            : AppThemeData.grey100,
                        initialSelection: controller
                            .countryISOCodeEditingController.value.text,
                        comparator: (a, b) =>
                            b.name!.compareTo(a.name.toString()),
                        textStyle: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? AppThemeData.grey50
                                : AppThemeData.grey900,
                            fontFamily: AppThemeData.medium),
                        searchDecoration: InputDecoration(
                            iconColor: isDark
                                ? AppThemeData.grey50
                                : AppThemeData.grey900),
                        searchStyle: TextStyle(
                            color: isDark
                                ? AppThemeData.grey50
                                : AppThemeData.grey900,
                            fontWeight: FontWeight.w500,
                            fontFamily: AppThemeData.medium),
                      ),
                    ),

                    // ── Zone ──────────────────────────────────────────────
                    controller.selectedValue.value == "Company"
                        ? const SizedBox()
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Zone".tr(),
                                  style: TextStyle(
                                      fontFamily: AppThemeData.semiBold,
                                      fontSize: 14,
                                      color: isDark
                                          ? AppThemeData.grey100
                                          : AppThemeData.grey800)),
                              const SizedBox(height: 5),
                              DropdownButtonFormField<ZoneModel>(
                                hint: Text('Select zone'.tr(),
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: isDark
                                            ? AppThemeData.grey700
                                            : AppThemeData.grey700,
                                        fontFamily: AppThemeData.regular)),
                                dropdownColor: isDark
                                    ? AppThemeData.grey900
                                    : AppThemeData.grey50,
                                decoration: InputDecoration(
                                  errorStyle:
                                      const TextStyle(color: Colors.red),
                                  isDense: true,
                                  filled: true,
                                  fillColor: isDark
                                      ? AppThemeData.grey900
                                      : AppThemeData.grey50,
                                  disabledBorder: UnderlineInputBorder(
                                      borderRadius: const BorderRadius.all(
                                          Radius.circular(10)),
                                      borderSide: BorderSide(
                                          color: isDark
                                              ? AppThemeData.grey900
                                              : AppThemeData.grey50,
                                          width: 1)),
                                  focusedBorder: OutlineInputBorder(
                                      borderRadius: const BorderRadius.all(
                                          Radius.circular(10)),
                                      borderSide: BorderSide(
                                          color: isDark
                                              ? AppThemeData.primary300
                                              : AppThemeData.primary300,
                                          width: 1)),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: const BorderRadius.all(
                                          Radius.circular(10)),
                                      borderSide: BorderSide(
                                          color: isDark
                                              ? AppThemeData.grey900
                                              : AppThemeData.grey50,
                                          width: 1)),
                                  errorBorder: OutlineInputBorder(
                                      borderRadius: const BorderRadius.all(
                                          Radius.circular(10)),
                                      borderSide: BorderSide(
                                          color: isDark
                                              ? AppThemeData.grey900
                                              : AppThemeData.grey50,
                                          width: 1)),
                                  border: OutlineInputBorder(
                                      borderRadius: const BorderRadius.all(
                                          Radius.circular(10)),
                                      borderSide: BorderSide(
                                          color: isDark
                                              ? AppThemeData.grey900
                                              : AppThemeData.grey50,
                                          width: 1)),
                                ),
                                initialValue:
                                    controller.selectedZone.value.id == null
                                        ? null
                                        : controller.selectedZone.value,
                                onChanged: (value) {
                                  controller.selectedZone.value = value!;
                                  controller.update();
                                },
                                style: TextStyle(
                                    fontSize: 14,
                                    color: isDark
                                        ? AppThemeData.grey50
                                        : AppThemeData.grey900,
                                    fontFamily: AppThemeData.medium),
                                items: controller.zoneList
                                    .map((item) => DropdownMenuItem<ZoneModel>(
                                        value: item,
                                        child: Text(item.name.toString())))
                                    .toList(),
                              ),
                            ],
                          ),
                    const SizedBox(height: 10),

                    // ── Password (email sign-up only) ─────────────────────
                    controller.type.value == "google" ||
                            controller.type.value == "apple" ||
                            controller.type.value == "mobileNumber"
                        ? const SizedBox()
                        : Column(
                            children: [
                              TextFieldWidget(
                                title: 'Password'.tr(),
                                controller:
                                    controller.passwordEditingController.value,
                                hintText: 'Enter Password'.tr(),
                                obscureText: controller.passwordVisible.value,
                                prefix: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: SvgPicture.asset(
                                      "assets/icons/ic_lock.svg",
                                      colorFilter: ColorFilter.mode(
                                          isDark
                                              ? AppThemeData.grey300
                                              : AppThemeData.grey600,
                                          BlendMode.srcIn)),
                                ),
                                suffix: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: InkWell(
                                    onTap: () =>
                                        controller.passwordVisible.value =
                                            !controller.passwordVisible.value,
                                    child: SvgPicture.asset(
                                      controller.passwordVisible.value
                                          ? "assets/icons/ic_password_show.svg"
                                          : "assets/icons/ic_password_close.svg",
                                      colorFilter: ColorFilter.mode(
                                          isDark
                                              ? AppThemeData.grey300
                                              : AppThemeData.grey600,
                                          BlendMode.srcIn),
                                    ),
                                  ),
                                ),
                                textInputAction: TextInputAction.next,
                              ),
                              TextFieldWidget(
                                title: 'Confirm Password'.tr(),
                                controller: controller
                                    .conformPasswordEditingController.value,
                                hintText: 'Enter Confirm Password'.tr(),
                                obscureText:
                                    controller.conformPasswordVisible.value,
                                prefix: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: SvgPicture.asset(
                                      "assets/icons/ic_lock.svg",
                                      colorFilter: ColorFilter.mode(
                                          isDark
                                              ? AppThemeData.grey300
                                              : AppThemeData.grey600,
                                          BlendMode.srcIn)),
                                ),
                                suffix: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: InkWell(
                                    onTap: () => controller
                                            .conformPasswordVisible.value =
                                        !controller
                                            .conformPasswordVisible.value,
                                    child: SvgPicture.asset(
                                      controller.conformPasswordVisible.value
                                          ? "assets/icons/ic_password_show.svg"
                                          : "assets/icons/ic_password_close.svg",
                                      colorFilter: ColorFilter.mode(
                                          isDark
                                              ? AppThemeData.grey300
                                              : AppThemeData.grey600,
                                          BlendMode.srcIn),
                                    ),
                                  ),
                                ),
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 10),
                              // ── License images ──
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Text(
                                          'Vehicle License',
                                          style: AppThemeData.mediumTextStyle(
                                              fontSize: 14,
                                              color: isDark
                                                  ? AppThemeData.greyDark700
                                                  : AppThemeData.grey700),
                                        ),
                                        GestureDetector(
                                          onTap: () => controller
                                              .pickLicenseImage(false),
                                          child: Stack(
                                            children: [
                                              Container(
                                                width: 90,
                                                height: 90,
                                                decoration: BoxDecoration(
                                                  border: Border.all(),
                                                  image: controller
                                                              .vehicleLicenseImage
                                                              .value !=
                                                          null
                                                      ? DecorationImage(
                                                          image: FileImage(
                                                              controller
                                                                  .vehicleLicenseImage
                                                                  .value!),
                                                          fit: BoxFit.cover,
                                                        )
                                                      : null,
                                                ),
                                                child: controller
                                                            .vehicleLicenseImage
                                                            .value ==
                                                        null
                                                    ? const Icon(Icons.image,
                                                        size: 50)
                                                    : null,
                                              ),
                                              Positioned(
                                                bottom: 0,
                                                right: 0,
                                                child: IconButton(
                                                  icon: const Icon(
                                                      Icons.camera_alt,
                                                      size: 20),
                                                  onPressed: () => controller
                                                      .pickLicenseImage(false),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Text(
                                          'Driver License',
                                          style: AppThemeData.mediumTextStyle(
                                              fontSize: 14,
                                              color: isDark
                                                  ? AppThemeData.greyDark700
                                                  : AppThemeData.grey700),
                                        ),
                                        GestureDetector(
                                          onTap: () =>
                                              controller.pickLicenseImage(true),
                                          child: Stack(
                                            children: [
                                              Container(
                                                width: 90,
                                                height: 90,
                                                decoration: BoxDecoration(
                                                  border: Border.all(),
                                                  image: controller
                                                              .driverLicenseImage
                                                              .value !=
                                                          null
                                                      ? DecorationImage(
                                                          image: FileImage(
                                                              controller
                                                                  .driverLicenseImage
                                                                  .value!),
                                                          fit: BoxFit.cover,
                                                        )
                                                      : null,
                                                ),
                                                child: controller
                                                            .driverLicenseImage
                                                            .value ==
                                                        null
                                                    ? const Icon(Icons.image,
                                                        size: 50)
                                                    : null,
                                              ),
                                              Positioned(
                                                bottom: 0,
                                                right: 0,
                                                child: IconButton(
                                                  icon: const Icon(
                                                      Icons.camera_alt,
                                                      size: 20),
                                                  onPressed: () => controller
                                                      .pickLicenseImage(true),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                  ],
                ),
              ),
            ),
            bottomNavigationBar: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () {
                    if (controller.profileImage.value == null) {
                      ShowToastDialog.showToast(
                          'Please upload a profile picture.');
                      return;
                    }
                    if (controller.carImage.value == null) {
                      ShowToastDialog.showToast(
                          'Please upload a car image.'.tr());
                      return;
                    }
                    if (controller.vehicleLicenseImage.value == null) {
                      ShowToastDialog.showToast(
                          'Please upload a vehicle license image.');
                      return;
                    }
                    if (controller.driverLicenseImage.value == null) {
                      ShowToastDialog.showToast(
                          'Please upload a driver license image.');
                      return;
                    }
                    if (controller.selectedSections.isEmpty) {
                      ShowToastDialog.showToast(
                          "Please select at least one section".tr());
                      return;
                    }
                    if (controller
                        .firstNameEditingController.value.text.isEmpty) {
                      ShowToastDialog.showToast("Please enter first name".tr());
                    } else if (controller
                        .lastNameEditingController.value.text.isEmpty) {
                      ShowToastDialog.showToast("Please enter last name".tr());
                    } else if (controller
                            .emailEditingController.value.text.isEmpty ||
                        !controller.emailEditingController.value.text
                            .trim()
                            .isEmail) {
                      ShowToastDialog.showToast(
                          "Please enter valid email".tr());
                    } else if (controller
                        .phoneNUmberEditingController.value.text.isEmpty) {
                      ShowToastDialog.showToast(
                          "Please enter Phone number".tr());
                    } else if (controller.type.value != "google" &&
                        controller.type.value != "apple" &&
                        controller.type.value != "mobileNumber" &&
                        controller
                            .passwordEditingController.value.text.isEmpty) {
                      ShowToastDialog.showToast("Please enter password".tr());
                    } else if (controller.type.value != "google" &&
                        controller.type.value != "apple" &&
                        controller.type.value != "mobileNumber" &&
                        controller.conformPasswordEditingController.value.text
                            .isEmpty) {
                      ShowToastDialog.showToast(
                          "Please enter Confirm password".tr());
                    } else if (controller.type.value != "google" &&
                        controller.type.value != "apple" &&
                        controller.type.value != "mobileNumber" &&
                        controller.passwordEditingController.value.text !=
                            controller
                                .conformPasswordEditingController.value.text) {
                      ShowToastDialog.showToast(
                          "Password and Confirm password doesn't match".tr());
                    } else if (controller.selectedValue.value == "Individual" &&
                        controller.selectedZone.value.id == null) {
                      ShowToastDialog.showToast("Please select zone".tr());
                    } else {
                      controller.signUpWithEmailAndPassword();
                    }
                  },
                  child: Container(
                    color: AppThemeData.primary300,
                    width: Responsive.width(100, context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        "Sign up".tr(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppThemeData.grey50,
                            fontSize: 16,
                            fontFamily: AppThemeData.medium,
                            fontWeight: FontWeight.w400),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        });
  }

  InputDecoration _dropdownDecoration(bool isDark) {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppThemeData.grey400)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
              color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey400)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
              color: isDark ? AppThemeData.greyDark400 : AppThemeData.grey400,
              width: 1.2)),
    );
  }
}

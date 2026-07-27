import 'dart:developer';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:door_delights_driver/constant/constant.dart';
import 'package:door_delights_driver/constant/show_toast_dialog.dart';
import 'package:door_delights_driver/models/car_makes.dart';
import 'package:door_delights_driver/models/car_model.dart';
import 'package:door_delights_driver/models/section_model.dart';
import 'package:door_delights_driver/models/user_model.dart';
import 'package:door_delights_driver/models/vehicle_type.dart';
import 'package:door_delights_driver/models/zone_model.dart';
import 'package:door_delights_driver/utils/fire_store_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Trans;
import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization/easy_localization.dart';

class DriverCreateController extends GetxController {
  RxBool isLoading = true.obs;

  // ── Form controllers ────────────────────────────────────────────────────
  final firstNameEditingController = TextEditingController().obs;
  final lastNameEditingController = TextEditingController().obs;
  final emailEditingController = TextEditingController().obs;
  final phoneNumberEditingController = TextEditingController().obs;
  final countryCodeEditingController =
      TextEditingController(text: Constant.defaultCountryCode).obs;
  final countryISOCodeEditingController =
      TextEditingController(text: Constant.defaultCountryCode).obs;
  final passwordEditingController = TextEditingController().obs;
  final confirmPasswordEditingController = TextEditingController().obs;

  RxBool passwordVisible = true.obs;
  RxBool conformPasswordVisible = true.obs;

  // ── Zone ────────────────────────────────────────────────────────────────
  RxList<ZoneModel> zoneList = <ZoneModel>[].obs;
  Rx<ZoneModel> selectedZone = ZoneModel().obs;

  // ── Sections ────────────────────────────────────────────────────────────
  RxList<SectionModel> ownerSections = <SectionModel>[].obs;
  final Rx<SectionModel?> selectedSection = Rx<SectionModel?>(null);

  // ── Vehicle data (per‑section, but only one section will be used) ────
  RxList<CarMakes> carMakesList = <CarMakes>[].obs;
  final Map<String, RxList<VehicleType>> vehicleTypesPerSection = {};
  final Map<String, Rx<VehicleType>> selectedVehiclePerSection = {};
  final Map<String, RxString> selectedRideTypePerSection = {};
  final Map<String, Rx<CarMakes>> selectedCarMakesPerSection = {};
  final Map<String, RxList<CarModel>> carModelListPerSection = {};
  final Map<String, Rx<CarModel>> selectedCarModelPerSection = {};
  final Map<String, Rx<TextEditingController>> carPlatePerSection = {};

  Rx<UserModel> driverModel = UserModel().obs;

  // ── Helpers ────────────────────────────────────────────────────────────

  bool sectionNeedsVehicle(SectionModel s) =>
      s.serviceType == 'cab-service' || s.serviceType == 'rental-service';

  bool get hasVehicleBasedSection =>
      selectedSection.value != null &&
      sectionNeedsVehicle(selectedSection.value!);

  bool isSectionSelected(SectionModel section) =>
      selectedSection.value?.id == section.id;

  String serviceFlagLabel(String? flag) {
    switch (flag) {
      case 'cab-service':
        return 'Cab';
      case 'parcel_delivery':
        return 'Parcel';
      case 'rental-service':
        return 'Rental';
      default:
        return 'Delivery';
    }
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────

  @override
  void onInit() {
    getArguments();
    super.onInit();
  }

  Future<void> getArguments() async {
    ShowToastDialog.showLoader("Please wait".tr());
    try {
      await Future.wait([
        FireStoreUtils.getZone().then((v) {
          if (v != null) zoneList.value = v;
        }),
        FireStoreUtils.getCarMakes().then((v) => carMakesList.value = v),
        FireStoreUtils.getAllActiveSections().then((v) {
          final ownerSectionId = Constant.userModel?.sectionId;
          ownerSections.value =
              v.where((s) => s.id != null && s.id == ownerSectionId).toList();
        }),
      ]);

      // Edit mode: prefill from existing driver model.
      final argumentData = Get.arguments;
      if (argumentData != null) {
        driverModel.value = argumentData['driverModel'] as UserModel;

        firstNameEditingController.value.text =
            driverModel.value.firstName ?? '';
        lastNameEditingController.value.text = driverModel.value.lastName ?? '';
        emailEditingController.value.text = driverModel.value.email ?? '';
        phoneNumberEditingController.value.text =
            driverModel.value.phoneNumber ?? '';
        countryCodeEditingController.value.text =
            driverModel.value.countryCode ?? Constant.defaultCountryCode;
        countryISOCodeEditingController.value.text =
            driverModel.value.countryISOCode ?? Constant.defaultCountryCode;

        // Zone
        for (final z in zoneList) {
          if (z.id == driverModel.value.zoneId) {
            selectedZone.value = z;
            break;
          }
        }

        // Single section
        final driverSectionId = driverModel.value.sectionId;
        if (driverSectionId != null && driverSectionId.isNotEmpty) {
          final existing = ownerSections.firstWhereOrNull(
            (s) => s.id == driverSectionId,
          );
          if (existing != null) {
            // Load vehicle data if needed
            if (sectionNeedsVehicle(existing)) {
              await _loadVehicleDataForSection(existing, prefill: true);
            }
            selectedSection.value = existing;
          }
        }
      }
    } catch (e) {
      log("DriverCreateController.getArguments error: $e");
    } finally {
      ShowToastDialog.closeLoader();
      isLoading.value = false;
    }
  }

  // ── Section toggle ────────────────────────────────────────────────────

  Future<void> toggleSection(SectionModel section) async {
    final sid = section.id;
    if (sid == null) return;

    if (isSectionSelected(section)) {
      // Deselect
      selectedSection.value = null;
      // Clear vehicle data for this section
      _clearSectionData(sid);
    } else {
      // Select new section
      selectedSection.value = section;
      // Load vehicle data if needed
      if (sectionNeedsVehicle(section)) {
        await _loadVehicleDataForSection(section);
      } else {
        // Clear any leftover vehicle data for this section
        _clearSectionData(sid);
      }
    }
    update();
  }

  void _clearSectionData(String sid) {
    vehicleTypesPerSection.remove(sid);
    selectedVehiclePerSection.remove(sid);
    selectedRideTypePerSection.remove(sid);
    selectedCarMakesPerSection.remove(sid);
    carModelListPerSection.remove(sid);
    selectedCarModelPerSection.remove(sid);
    carPlatePerSection.remove(sid);
  }

  Future<void> _loadVehicleDataForSection(
    SectionModel section, {
    bool prefill = false,
  }) async {
    final sid = section.id!;
    ShowToastDialog.showLoader("Please wait".tr());
    try {
      // Vehicle types
      final types = section.serviceType == 'rental-service'
          ? await FireStoreUtils.getRentalVehicleType(sid)
          : await FireStoreUtils.getCabVehicleType(sid);
      vehicleTypesPerSection[sid] = RxList<VehicleType>(types);

      final Map<String, dynamic>? sectionData =
          prefill && driverModel.value.vehicleDetails != null
              ? (driverModel.value.vehicleDetails![sid] as Map?)
                  ?.cast<String, dynamic>()
              : null;

      // Selected vehicle
      final savedVehicleId = sectionData?['vehicleId']?.toString();
      VehicleType selectedVehicle =
          types.isNotEmpty ? types.first : VehicleType();
      if (savedVehicleId != null &&
          savedVehicleId.isNotEmpty &&
          types.isNotEmpty) {
        selectedVehicle = types.firstWhere(
          (e) => e.id == savedVehicleId,
          orElse: () => types.first,
        );
      }
      selectedVehiclePerSection[sid] = Rx<VehicleType>(selectedVehicle);

      // Ride type (cab only)
      final savedRideType = sectionData?['rideType']?.toString() ?? 'ride';
      selectedRideTypePerSection[sid] = RxString(savedRideType);

      // Car plate
      final savedPlate = sectionData?['carPlateNumber']?.toString() ?? '';
      carPlatePerSection[sid] =
          Rx<TextEditingController>(TextEditingController(text: savedPlate));

      // Car brand / model
      final savedBrand = sectionData?['carBrand']?.toString();
      if (savedBrand != null &&
          savedBrand.isNotEmpty &&
          carMakesList.isNotEmpty) {
        final brand = carMakesList.firstWhere(
          (e) => e.name == savedBrand,
          orElse: () => CarMakes(),
        );
        selectedCarMakesPerSection[sid] = Rx<CarMakes>(brand);
        final models = await FireStoreUtils.getCarModel(savedBrand);
        carModelListPerSection[sid] = RxList<CarModel>(models);

        final savedModel = sectionData?['carModel']?.toString();
        if (savedModel != null && savedModel.isNotEmpty && models.isNotEmpty) {
          selectedCarModelPerSection[sid] = Rx<CarModel>(
            models.firstWhere(
              (e) => e.name == savedModel,
              orElse: () => models.first,
            ),
          );
        } else {
          selectedCarModelPerSection[sid] = Rx<CarModel>(CarModel());
        }
      } else {
        selectedCarMakesPerSection[sid] = Rx<CarMakes>(CarMakes());
        carModelListPerSection[sid] = <CarModel>[].obs;
        selectedCarModelPerSection[sid] = Rx<CarModel>(CarModel());
      }
    } finally {
      ShowToastDialog.closeLoader();
    }
  }

  Future<void> getCarModelForSection(String sectionId) async {
    ShowToastDialog.showLoader("Please wait".tr());
    try {
      final carMakes = selectedCarMakesPerSection[sectionId]?.value;
      carModelListPerSection[sectionId]?.clear();
      selectedCarModelPerSection[sectionId]?.value = CarModel();
      if (carMakes?.name != null && carMakes!.name!.isNotEmpty) {
        final models = await FireStoreUtils.getCarModel(carMakes.name!);
        carModelListPerSection[sectionId]?.value = models;
      }
    } finally {
      ShowToastDialog.closeLoader();
    }
  }

  // ── Save ───────────────────────────────────────────────────────────────

  Future<void> signUp() async {
    try {
      ShowToastDialog.showLoader("Please wait".tr());
      final secondaryApp = await Firebase.initializeApp(
        name: 'SecondaryApp',
        options: Firebase.app().options,
      );
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: emailEditingController.value.text.trim(),
        password: passwordEditingController.value.text.trim(),
      );
      if (credential.user != null) {
        driverModel.value.id = credential.user!.uid;
        _applyCommonFields();
        driverModel.value.vehicleDetails = _buildVehicleDetails();
        await FireStoreUtils.updateUser(driverModel.value);
        ShowToastDialog.closeLoader();
        ShowToastDialog.showToast("Driver created successfully".tr());
        Get.back(result: true);
      }
    } on FirebaseAuthException catch (e) {
      ShowToastDialog.closeLoader();
      if (e.code == 'weak-password') {
        ShowToastDialog.showToast("The password provided is too weak.".tr());
      } else if (e.code == 'email-already-in-use') {
        ShowToastDialog.showToast(
            "The account already exists for that email.".tr());
      } else if (e.code == 'invalid-email') {
        ShowToastDialog.showToast("Enter email is Invalid".tr());
      } else {
        ShowToastDialog.showToast(e.message ?? e.toString());
      }
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast(e.toString());
    }
  }

  Future<void> updateDriver() async {
    ShowToastDialog.showLoader("Please wait".tr());
    try {
      _applyCommonFields();
      driverModel.value.vehicleDetails = _buildVehicleDetails();
      await FireStoreUtils.updateUser(driverModel.value);
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Driver updated successfully".tr());
      Get.back(result: true);
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast(e.toString());
    }
  }

  void _applyCommonFields() {
    driverModel.value.firstName = firstNameEditingController.value.text.trim();
    driverModel.value.lastName = lastNameEditingController.value.text.trim();
    driverModel.value.email =
        emailEditingController.value.text.trim().toLowerCase();
    driverModel.value.phoneNumber =
        phoneNumberEditingController.value.text.trim();
    driverModel.value.role = Constant.userRoleDriver;
    driverModel.value.active = true;
    driverModel.value.isActive = false;
    driverModel.value.isDocumentVerify = true;
    driverModel.value.countryCode = countryCodeEditingController.value.text;
    driverModel.value.countryISOCode =
        countryISOCodeEditingController.value.text;
    driverModel.value.createdAt ??= Timestamp.now();
    driverModel.value.zoneId = selectedZone.value.id;
    driverModel.value.appIdentifier = Platform.isAndroid ? 'android' : 'ios';
    driverModel.value.provider = 'email';
    driverModel.value.isOwner = false;
    driverModel.value.ownerId = FireStoreUtils.getCurrentUid();

    // Single section
    final section = selectedSection.value;
    if (section != null && section.id != null) {
      driverModel.value.sectionId = section.id;
      driverModel.value.serviceType = section.serviceType ?? 'delivery-service';
    } else {
      driverModel.value.sectionId = null;
    }
  }

  Map<String, dynamic> _buildVehicleDetails() {
    final Map<String, dynamic> details = {};
    final section = selectedSection.value;
    if (section == null || section.id == null) return details;
    if (!sectionNeedsVehicle(section)) return details;

    final sid = section.id!;
    final vehicle = selectedVehiclePerSection[sid]?.value;
    if (vehicle?.id != null) {
      details[sid] = {
        'vehicleId': vehicle!.id ?? '',
        'vehicleType': vehicle.name ?? '',
        'carBrand': selectedCarMakesPerSection[sid]?.value.name ?? '',
        'carModel': selectedCarModelPerSection[sid]?.value.name ?? '',
        'carPlateNumber': carPlatePerSection[sid]?.value.text.trim() ?? '',
        if (section.serviceType == 'cab-service')
          'rideType': selectedRideTypePerSection[sid]?.value ?? 'ride',
      };
    }
    return details;
  }
}

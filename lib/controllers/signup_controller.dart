import 'dart:developer';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../app/cab_screen/cab_dashboard_screen.dart';
import '../app/dash_board_screen/dash_board_screen.dart';
import '../app/owner_screen/owner_dashboard_screen.dart';
import '../app/parcel_screen/parcel_dashboard_screen.dart';
import '../app/rental_service/rental_dashboard_screen.dart';
import '../constant/constant.dart';
import '../constant/show_toast_dialog.dart';
import '../models/car_makes.dart';
import '../models/car_model.dart';
import '../models/section_model.dart';
import '../models/user_model.dart';
import '../models/vehicle_type.dart';
import '../models/zone_model.dart';
import '../ui/login/LoginScreen.dart';
import '../utils/fire_store_utils.dart';

class SignupController extends GetxController {
  Rx<TextEditingController> firstNameEditingController =
      TextEditingController().obs;
  Rx<TextEditingController> lastNameEditingController =
      TextEditingController().obs;
  Rx<TextEditingController> emailEditingController =
      TextEditingController().obs;
  Rx<TextEditingController> phoneNUmberEditingController =
      TextEditingController().obs;
  Rx<TextEditingController> countryCodeEditingController =
      TextEditingController(text: Constant.defaultCountryCode).obs;
  Rx<TextEditingController> countryISOCodeEditingController =
      TextEditingController(text: Constant.defaultCountryCode).obs;
  Rx<TextEditingController> passwordEditingController =
      TextEditingController().obs;
  Rx<TextEditingController> conformPasswordEditingController =
      TextEditingController().obs;
  Rx<TextEditingController> carPlatNumberEditingController =
      TextEditingController().obs;

  RxBool passwordVisible = true.obs;
  RxBool conformPasswordVisible = true.obs;

  RxString type = "".obs;
  Rx<UserModel> userModel = UserModel().obs;

  RxList<ZoneModel> zoneList = <ZoneModel>[].obs;
  Rx<ZoneModel> selectedZone = ZoneModel().obs;

  /// All active sections loaded from Firestore (no service filter)
  RxList<SectionModel> allSections = <SectionModel>[].obs;

  /// ── Single selected section ──
  final Rx<SectionModel?> selectedSection = Rx<SectionModel?>(null);

  /// Vehicle types for the selected section (only if cab/rental)
  RxMap<String, List<VehicleType>> vehicleTypesPerSection =
      <String, List<VehicleType>>{}.obs;
  RxMap<String, VehicleType> selectedVehiclePerSection =
      <String, VehicleType>{}.obs;

  /// Shared car makes list (loaded once from Firestore)
  RxList<CarMakes> carMakesList = <CarMakes>[].obs;

  /// Per-section car details (only for the selected section)
  final Map<String, Rx<CarMakes>> selectedCarMakesPerSection = {};
  final Map<String, RxList<CarModel>> carModelListPerSection = {};
  final Map<String, Rx<CarModel>> selectedCarModelPerSection = {};
  final Map<String, Rx<TextEditingController>> carPlatePerSection = {};

  RxString selectedValue = "Individual".obs;

  // ── Helpers ────────────────────────────────────────────────────────────────

  bool sectionNeedsVehicle(SectionModel section) =>
      section.serviceTypeFlag == 'cab-service' ||
      section.serviceTypeFlag == 'rental-service';

  bool get hasVehicleBasedSection =>
      selectedSection.value != null &&
      sectionNeedsVehicle(selectedSection.value!);

  bool isSectionSelected(SectionModel section) =>
      selectedSection.value?.id == section.id;

  /// Sections visible based on role selection.
  /// Company/Owner cannot register for delivery-service — only cab, parcel, rental.
  List<SectionModel> get visibleSections {
    if (selectedValue.value == 'Company') {
      return allSections
          .where((s) => s.serviceTypeFlag != 'delivery-service')
          .toList();
    }
    return allSections;
  }

  /// Called when switching between Individual / Company to deselect
  /// any section that is no longer visible (delivery-service for Company).
  void onRoleChanged(String role) {
    selectedValue.value = role;
    if (role == 'Company') {
      // If the currently selected section is delivery-service, clear it.
      if (selectedSection.value != null &&
          selectedSection.value!.serviceTypeFlag == 'delivery-service') {
        selectedSection.value = null;
        // Also clear any vehicle data
        final sid = selectedSection.value?.id;
        if (sid != null) {
          vehicleTypesPerSection.remove(sid);
          selectedVehiclePerSection.remove(sid);
          selectedCarMakesPerSection.remove(sid);
          carModelListPerSection.remove(sid);
          selectedCarModelPerSection.remove(sid);
          carPlatePerSection.remove(sid);
        }
      }
    }
    update();
  }

  /// Returns a human-readable label for a section's serviceTypeFlag.
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

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void onInit() {
    getArgument();
    super.onInit();
  }

  Future<void> getArgument() async {
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      type.value = argumentData['type'];
      userModel.value = argumentData['userModel'];
      if (type.value == "mobileNumber") {
        phoneNUmberEditingController.value.text =
            userModel.value.phoneNumber ?? "";
        countryCodeEditingController.value.text =
            userModel.value.countryCode ?? Constant.defaultCountryCode;
        countryISOCodeEditingController.value.text =
            userModel.value.countryISOCode ?? Constant.defaultCountryCode;
      } else if (type.value == "google" || type.value == "apple") {
        emailEditingController.value.text = userModel.value.email ?? "";
        firstNameEditingController.value.text = userModel.value.firstName ?? "";
        lastNameEditingController.value.text = userModel.value.lastName ?? "";
      }
    }

    await Future.wait([
      FireStoreUtils.getZone().then((v) {
        if (v != null) zoneList.value = v;
      }),
      FireStoreUtils.getCarMakes().then((v) => carMakesList.value = v),
      FireStoreUtils.getAllActiveSections().then((v) => allSections.value = v),
    ]);
  }

  // ── Section toggle (single selection) ─────────────────────────────────────

  Future<void> toggleSection(SectionModel section) async {
    final sid = section.id;
    if (sid == null) return;

    if (isSectionSelected(section)) {
      // Deselect the current section
      selectedSection.value = null;
      // Clear all vehicle data
      vehicleTypesPerSection.remove(sid);
      selectedVehiclePerSection.remove(sid);
      selectedCarMakesPerSection.remove(sid);
      carModelListPerSection.remove(sid);
      selectedCarModelPerSection.remove(sid);
      carPlatePerSection.remove(sid);
    } else {
      // Select the new section (deselect old one automatically)
      selectedSection.value = section;
      // Load vehicle types if needed
      if (sectionNeedsVehicle(section)) {
        await _loadVehicleTypesForSection(section);
        // Init per-section car details
        selectedCarMakesPerSection[sid] = Rx<CarMakes>(CarMakes());
        carModelListPerSection[sid] = <CarModel>[].obs;
        selectedCarModelPerSection[sid] = Rx<CarModel>(CarModel());
        carPlatePerSection[sid] = Rx<TextEditingController>(
          TextEditingController(),
        );
      } else {
        // Clear any leftover vehicle data for this section
        vehicleTypesPerSection.remove(sid);
        selectedVehiclePerSection.remove(sid);
        selectedCarMakesPerSection.remove(sid);
        carModelListPerSection.remove(sid);
        selectedCarModelPerSection.remove(sid);
        carPlatePerSection.remove(sid);
      }
    }
    update();
  }

  Future<void> _loadVehicleTypesForSection(SectionModel section) async {
    ShowToastDialog.showLoader("Please wait".tr);
    List<VehicleType> types;
    if (section.serviceTypeFlag == 'cab-service') {
      types = await FireStoreUtils.getCabVehicleType(section.id.toString());
    } else {
      types = await FireStoreUtils.getRentalVehicleType(section.id.toString());
    }
    vehicleTypesPerSection[section.id!] = types;
    if (types.isNotEmpty) selectedVehiclePerSection[section.id!] = types.first;
    ShowToastDialog.closeLoader();
    update();
  }

  Future<void> getCarModelForSection(String sectionId) async {
    ShowToastDialog.showLoader("Please wait".tr);
    final carMakes = selectedCarMakesPerSection[sectionId]?.value;
    carModelListPerSection[sectionId]?.clear();
    selectedCarModelPerSection[sectionId]?.value = CarModel();
    if (carMakes?.name != null) {
      await FireStoreUtils.getCarModel(carMakes!.name.toString()).then((v) {
        carModelListPerSection[sectionId]?.value = v;
      });
    }
    ShowToastDialog.closeLoader();
  }

  // ── Image files ──────────────────────────────────────────────
  final Rx<File?> profileImage = Rx<File?>(null);
  final Rx<File?> carImage = Rx<File?>(null);
  final Rx<File?> vehicleLicenseImage = Rx<File?>(null);
  final Rx<File?> driverLicenseImage = Rx<File?>(null);

  Future<void> pickImage(bool isUserImage) async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      if (isUserImage) {
        profileImage.value = File(pickedFile.path);
      } else {
        carImage.value = File(pickedFile.path);
      }
    }
  }

  Future<void> pickLicenseImage(bool isDriverLicense) async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      if (isDriverLicense) {
        driverLicenseImage.value = File(pickedFile.path);
      } else {
        vehicleLicenseImage.value = File(pickedFile.path);
      }
    }
  }

  Future<void> _uploadImagesAndUpdateUser(UserModel user) async {
    final List<Future> uploadFutures = [];
    final List<File> filesToDelete = [];

    // ── Profile image ──────────────────────────────────────────
    if (profileImage.value != null) {
      final file = profileImage.value!;
      filesToDelete.add(file);
      uploadFutures.add(
        FireStoreUtils.uploadUserImageToFireStorage(
          file,
          user.id!,
        ).then((url) => user.profilePictureURL = url),
      );
    }

    // ── Car image ──────────────────────────────────────────────
    if (carImage.value != null) {
      final file = carImage.value!;
      filesToDelete.add(file);
      uploadFutures.add(
        FireStoreUtils.uploadCarImageToFireStorage(
          file,
          user.id!,
        ).then((url) => user.carPictureURL = url),
      );
    }

    // ── Vehicle license image ─────────────────────────────────
    if (vehicleLicenseImage.value != null) {
      final file = vehicleLicenseImage.value!;
      filesToDelete.add(file);
      uploadFutures.add(
        FireStoreUtils.uploadCarImageToFireStorage(
          file,
          'vehicle_license_${user.id}',
        ).then((url) => user.carProofPictureURL = url),
      );
    }

    // ── Driver license image ──────────────────────────────────
    if (driverLicenseImage.value != null) {
      final file = driverLicenseImage.value!;
      filesToDelete.add(file);
      uploadFutures.add(
        FireStoreUtils.uploadCarImageToFireStorage(
          file,
          'driver_license_${user.id}',
        ).then((url) => user.driverProofPictureURL = url),
      );
    }

    try {
      // ── Upload all images in parallel ──────────────────────────
      if (uploadFutures.isNotEmpty) {
        await Future.wait(uploadFutures);
      }

      // ── Save all URLs to Firestore ─────────────────────────────
      await FireStoreUtils.updateUser(user);
    } finally {
      // ── Clear memory references ────────────────────────────────
      profileImage.value = null;
      carImage.value = null;
      vehicleLicenseImage.value = null;
      driverLicenseImage.value = null;

      // ── Delete temporary files from storage ────────────────────
      for (final file in filesToDelete) {
        try {
          if (await file.exists()) {
            file.delete();
          }
        } catch (e) {
          print('Error deleting temporary file: $e');
        }
      }
    }
  }

  // ── Sign up ────────────────────────────────────────────────────────────────

  Future<void> signUpWithEmailAndPassword() async {
    await signUp();
  }

  Future<void> signUp() async {
    if (selectedSection.value == null) {
      ShowToastDialog.showToast("Please select a section.".tr);
      return;
    }
    ShowToastDialog.showLoader("Please wait".tr);

    if (type.value == "google" ||
        type.value == "apple" ||
        type.value == "mobileNumber") {
      _populateUserModel();
      await FireStoreUtils.updateUser(userModel.value);
      _navigateAfterSignup(userModel.value);
    } else {
      try {
        final credential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailEditingController.value.text.trim(),
          password: passwordEditingController.value.text.trim(),
        );
        if (credential.user != null) {
          userModel.value.id = credential.user!.uid;
          _populateUserModel();
          await _uploadImagesAndUpdateUser(userModel.value);
          _navigateAfterSignup(userModel.value);
        }
      } on FirebaseAuthException catch (e) {
        if (e.code == 'weak-password') {
          ShowToastDialog.showToast("The password provided is too weak.".tr);
        } else if (e.code == 'email-already-in-use') {
          ShowToastDialog.showToast(
            "The account already exists for that email.".tr,
          );
        } else if (e.code == 'invalid-email') {
          ShowToastDialog.showToast("Enter email is Invalid".tr);
        }
        print(e);
      } catch (e) {
        print(e);
        ShowToastDialog.showToast(e.toString());
      }
    }

    ShowToastDialog.closeLoader();
  }

  void _populateUserModel() {
    final section = selectedSection.value!;
    userModel.value.firstName = firstNameEditingController.value.text;
    userModel.value.lastName = lastNameEditingController.value.text;
    userModel.value.email = emailEditingController.value.text.toLowerCase();
    userModel.value.phoneNumber = phoneNUmberEditingController.value.text;
    userModel.value.role = Constant.userRoleDriver;
    userModel.value.isActive = false;
    userModel.value.active = Constant.autoApproveDriver == true ? true : false;
    userModel.value.isDocumentVerify = selectedValue.value == "Company"
        ? Constant.isOwnerVerification == true
            ? false
            : true
        : Constant.isDriverVerification == true
            ? false
            : true;
    userModel.value.countryCode = countryCodeEditingController.value.text;
    userModel.value.countryISOCode = countryISOCodeEditingController.value.text;
    userModel.value.createdAt = Timestamp.now();
    userModel.value.zoneId = selectedZone.value.id;
    userModel.value.appIdentifier = Platform.isAndroid ? 'android' : 'ios';
    userModel.value.provider = type.value.isEmpty ? 'email' : type.value;
    userModel.value.isOwner = selectedValue.value == "Company" ? true : false;
    userModel.value.isAutoVerify = selectedValue.value == "Company"
        ? Constant.isOwnerVerification == false
            ? true
            : false
        : Constant.isDriverVerification == false
            ? true
            : false;

    // ── Single section ──────────────────────────────────────────────────────
    userModel.value.sectionId = section.id;

    // ── Derive serviceTypes from single section ──────────────────────────
    userModel.value.serviceType = section.serviceType ?? 'delivery-service';

    // ── sectionNames: {sectionId → sectionName} ──────────────────────────

    // ── vehicleDetails: only if the selected section needs a vehicle ─────
    // Skip for Company users — they register their own drivers separately.
    final Map<String, dynamic> vDetails = {};
    final bool isCompany = selectedValue.value == "Company";
    if (!isCompany && sectionNeedsVehicle(section)) {
      final vehicle = selectedVehiclePerSection[section.id];
      final carMakes = selectedCarMakesPerSection[section.id]?.value;
      final carModel = selectedCarModelPerSection[section.id]?.value;
      final carPlate = carPlatePerSection[section.id]?.value.text ?? '';
      vDetails[section.id!] = {
        'vehicleId': vehicle?.id ?? '',
        'vehicleType': vehicle?.name ?? '',
        'carBrand': carMakes?.name ?? '',
        'carModel': carModel?.name ?? '',
        'carPlateNumber': carPlate,
        if (section.serviceTypeFlag == 'cab-service')
          'rideType': section.rideType ?? 'ride',
      };
    }
    if (vDetails.isNotEmpty) userModel.value.vehicleDetails = vDetails;

    log(userModel.value.toJson().toString());
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _navigateAfterSignup(UserModel user) {
    if (!(Constant.autoApproveDriver ?? false)) {
      ShowToastDialog.showToast(
        "Thank you for sign up, your application is under approval so please wait till that approve."
            .tr,
      );
      Get.offAll(LoginScreen());
      return;
    }
    navigateByUserModel(user);
  }

  static void navigateByUserModel(UserModel user) {
    if (user.isOwner == true) {
      Get.offAll(OwnerDashboardScreen());
    }
    //  else if ((user.serviceType?.length ?? 0) > 1) {
    //   Get.offAll(const MultiServiceDashboardScreen());
    // }
    else {
      _navigateByServiceType(user.serviceType ?? 'delivery-service');
    }
  }

  static void _navigateByServiceType(String serviceType) {
    switch (serviceType) {
      case 'cab-service':
        Get.offAll(const CabDashboardScreen());
        break;
      case 'parcel_delivery':
        Get.offAll(const ParcelDashboardScreen());
        break;
      case 'rental-service':
        Get.offAll(const RentalDashboardScreen());
        break;
      default:
        Get.offAll(const DashBoardScreen());
    }
  }
}

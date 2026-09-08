import 'dart:developer';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Trans;
import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization/easy_localization.dart';
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
  // ── Text controllers ─────────────────────────────────────────────────
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

  RxBool passwordVisible = true.obs;
  RxBool conformPasswordVisible = true.obs;

  RxString type = "".obs;
  Rx<UserModel> userModel = UserModel().obs;

  // ── Zones ──────────────────────────────────────────────────────────
  RxList<ZoneModel> zoneList = <ZoneModel>[].obs;
  Rx<ZoneModel> selectedZone = ZoneModel().obs;

  // ── Sections ──────────────────────────────────────────────────────
  RxList<SectionModel> allSections = <SectionModel>[].obs;
  final RxList<SectionModel> selectedSections = <SectionModel>[].obs;

  // ── Vehicle fields (single set, shared across sections) ──────────
  RxList<String> vehicleTypeOptions = <String>[].obs;
  RxMap<String, String> vehicleTypeNameToId = <String, String>{}.obs;
  Rx<String?> selectedVehicleTypeName = Rx<String?>(null);
  Rx<String?> selectedVehicleTypeId = Rx<String?>(null);

  RxList<CarMakes> carMakesList = <CarMakes>[].obs;
  Rx<CarMakes?> selectedCarMakes = Rx<CarMakes?>(null);
  RxList<CarModel> carModelList = <CarModel>[].obs;
  Rx<CarModel?> selectedCarModel = Rx<CarModel?>(null);
  Rx<TextEditingController> carPlateController = TextEditingController().obs;

  // ── Ride Type ──────────────────────────────────────────────────────
  RxString selectedRideType = 'ride'.obs;
  RxList<String> rideTypeOptions = <String>[].obs;

  // ── Role ──────────────────────────────────────────────────────────
  RxString selectedValue = "Individual".obs;

  // ── Helpers ──────────────────────────────────────────────────────

  bool sectionNeedsVehicle(SectionModel section) =>
      section.serviceTypeFlag == 'cab-service' ||
      section.serviceTypeFlag == 'rental-service' ||
      section.serviceTypeFlag == 'delivery-service' ||
      section.serviceTypeFlag == 'parcel_delivery';

  bool isSectionSelected(SectionModel section) =>
      selectedSections.any((s) => s.id == section.id);

  List<SectionModel> get visibleSections {
    if (selectedValue.value == 'Company') {
      return allSections
          .where((s) => s.serviceTypeFlag != 'delivery-service')
          .toList();
    }
    return allSections;
  }

  void onRoleChanged(String role) {
    selectedValue.value = role;
    if (role == 'Company') {
      final toRemove = selectedSections
          .where((s) => s.serviceTypeFlag == 'delivery-service')
          .toList();
      for (final section in toRemove) {
        selectedSections.remove(section);
      }
      _recomputeVehicleOptions();
      _updateRideTypeOptions();
    }
    update();
  }

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

  // ── Lifecycle ──────────────────────────────────────────────────────

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

  // ── Section toggle ────────────────────────────────────────────────

  Future<void> toggleSection(SectionModel section) async {
    final sid = section.id;
    if (sid == null) return;

    if (isSectionSelected(section)) {
      selectedSections.removeWhere((s) => s.id == sid);
    } else {
      selectedSections.add(section);
    }
    await _recomputeVehicleOptions();
    await _updateRideTypeOptions();
    update();
  }

  Future<void> _recomputeVehicleOptions() async {
    final List<String> names = [];
    final Map<String, String> nameToId = {};
    final Set<String> seenNames = {};

    final hasCabOrRental = selectedSections.any(
      (s) =>
          s.serviceTypeFlag == 'cab-service' ||
          s.serviceTypeFlag == 'rental-service',
    );

    for (final section in selectedSections) {
      if (!sectionNeedsVehicle(section)) continue;
      if (section.serviceTypeFlag == 'delivery-service' ||
          section.serviceTypeFlag == 'parcel_delivery') {
        if (!hasCabOrRental) {
          _addVehicleTypeIfNotExists(
              names, nameToId, seenNames, 'Bike', 'bike');
          _addVehicleTypeIfNotExists(
              names, nameToId, seenNames, 'Carriage', 'carriage');
        }
      } else if (section.serviceTypeFlag == 'cab-service') {
        final types = await FireStoreUtils.getCabVehicleType(section.id!);
        for (final t in types) {
          _addVehicleTypeIfNotExists(
              names, nameToId, seenNames, t.name!, t.id!);
        }
      } else if (section.serviceTypeFlag == 'rental-service') {
        final types = await FireStoreUtils.getRentalVehicleType(section.id!);
        for (final t in types) {
          _addVehicleTypeIfNotExists(
              names, nameToId, seenNames, t.name!, t.id!);
        }
      }
    }

    vehicleTypeOptions.value = names;
    vehicleTypeNameToId.value = nameToId;

    if (selectedVehicleTypeName.value != null &&
        !vehicleTypeOptions.contains(selectedVehicleTypeName.value)) {
      selectedVehicleTypeName.value =
          vehicleTypeOptions.isNotEmpty ? vehicleTypeOptions.first : null;
      selectedVehicleTypeId.value = selectedVehicleTypeName.value != null
          ? vehicleTypeNameToId[selectedVehicleTypeName.value]
          : null;
    } else if (vehicleTypeOptions.isNotEmpty &&
        selectedVehicleTypeName.value == null) {
      selectedVehicleTypeName.value = vehicleTypeOptions.first;
      selectedVehicleTypeId.value =
          vehicleTypeNameToId[vehicleTypeOptions.first];
    }
  }

  void _addVehicleTypeIfNotExists(
      List<String> names,
      Map<String, String> nameToId,
      Set<String> seenNames,
      String name,
      String id) {
    if (!seenNames.contains(name)) {
      seenNames.add(name);
      names.add(name);
      nameToId[name] = id;
    }
  }

  Future<void> _updateRideTypeOptions() async {
    final cabSections = selectedSections
        .where((s) => s.serviceTypeFlag == 'cab-service')
        .toList();

    if (cabSections.isEmpty) {
      rideTypeOptions.clear();
      selectedRideType.value = 'ride';
      return;
    }

    final firstCab = cabSections.first;
    final allowed = firstCab.rideType ?? 'ride';

    if (allowed == 'both') {
      rideTypeOptions.value = ['ride', 'intercity', 'both'];
    } else if (allowed == 'intercity') {
      rideTypeOptions.value = ['intercity'];
    } else {
      rideTypeOptions.value = ['ride'];
    }

    if (!rideTypeOptions.contains(selectedRideType.value)) {
      selectedRideType.value =
          rideTypeOptions.isNotEmpty ? rideTypeOptions.first : 'ride';
    }
  }

  // ── Car model loading ──────────────────────────────────────────────

  Future<void> getCarModels() async {
    ShowToastDialog.showLoader("Please wait".tr());
    carModelList.clear();
    selectedCarModel.value = null;
    if (selectedCarMakes.value?.name != null) {
      final models = await FireStoreUtils.getCarModel(
          selectedCarMakes.value!.name.toString());
      carModelList.value = models;
    }
    ShowToastDialog.closeLoader();
  }

  // ── Image pickers ──────────────────────────────────────────────────

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
    final List<String> errors = [];

    // ── Prepare upload tasks ──────────────────────────────────────────────
    final uploadFutures = <Future<MapEntry<String, String?>>>[];

    if (profileImage.value != null) {
      uploadFutures.add(
        FireStoreUtils.uploadUserImageToFireStorage(
          profileImage.value!,
          user.id!,
        ).then((url) => MapEntry('profile', url)).catchError((e, stack) {
          errors.add('Profile image: $e');
          log('Profile upload error: $e');
          log('Stack: $stack');
          return MapEntry('profile', null);
        }),
      );
    }

    if (carImage.value != null) {
      uploadFutures.add(
        FireStoreUtils.uploadCarImageToFireStorage(
          carImage.value!,
          user.id!,
        ).then((url) => MapEntry('car', url)).catchError((e, stack) {
          errors.add('Car image: $e');
          log('Car upload error: $e');
          log('Stack: $stack');
          return MapEntry('car', null);
        }),
      );
    }

    if (vehicleLicenseImage.value != null) {
      uploadFutures.add(
        FireStoreUtils.uploadCarImageToFireStorage(
          vehicleLicenseImage.value!,
          'vehicle_license_${user.id}',
        ).then((url) => MapEntry('vehicleLicense', url)).catchError((e, stack) {
          errors.add('Vehicle license: $e');
          log('Vehicle license upload error: $e');
          log('Stack: $stack');
          return MapEntry('vehicleLicense', null);
        }),
      );
    }

    if (driverLicenseImage.value != null) {
      uploadFutures.add(
        FireStoreUtils.uploadCarImageToFireStorage(
          driverLicenseImage.value!,
          'driver_license_${user.id}',
        ).then((url) => MapEntry('driverLicense', url)).catchError((e, stack) {
          errors.add('Driver license: $e');
          log('Driver license upload error: $e');
          log('Stack: $stack');
          return MapEntry('driverLicense', null);
        }),
      );
    }

    // ── Run all uploads concurrently ──────────────────────────────────────
    final results = await Future.wait(uploadFutures);

    // ── Apply successful uploads ──────────────────────────────────────────
    for (final entry in results) {
      final url = entry.value;
      if (url != null) {
        switch (entry.key) {
          case 'profile':
            user.profilePictureURL = url;
            break;
          case 'car':
            user.carPictureURL = url;
            break;
          case 'vehicleLicense':
            user.carProofPictureURL = url;
            break;
          case 'driverLicense':
            user.driverProofPictureURL = url;
            break;
        }
      }
    }

    // ── Update user in Firestore ──────────────────────────────────────────
    await FireStoreUtils.updateUser(user);

    // ── Feedback ──────────────────────────────────────────────────────────
    if (errors.isNotEmpty) {
      ShowToastDialog.showToast(
        'Profile created, but some images failed to upload: ${errors.join('; ')}',
      );
    } else {
      ShowToastDialog.showToast('Profile created successfully.');
    }

    // ── Clean up ──────────────────────────────────────────────────────────
    _clearTempFiles();
  }

  void _clearTempFiles() {
    final files = [
      profileImage.value,
      carImage.value,
      vehicleLicenseImage.value,
      driverLicenseImage.value,
    ];
    for (final file in files) {
      if (file != null && file.existsSync()) {
        file.deleteSync();
      }
    }
    profileImage.value = null;
    carImage.value = null;
    vehicleLicenseImage.value = null;
    driverLicenseImage.value = null;
  }

  // ── Sign up ──────────────────────────────────────────────────────
  Future<void> signUpWithEmailAndPassword() async {
    await signUp();
  }

  Future<void> signUp() async {
    if (selectedSections.isEmpty) {
      ShowToastDialog.showToast("Please select at least one section.".tr());
      return;
    }
    ShowToastDialog.showLoader("Please wait".tr());

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
          ShowToastDialog.showToast("The password provided is too weak.".tr());
        } else if (e.code == 'email-already-in-use') {
          ShowToastDialog.showToast(
            "The account already exists for that email.".tr(),
          );
        } else if (e.code == 'invalid-email') {
          ShowToastDialog.showToast("Enter email is Invalid".tr());
        }
      } catch (e) {
        ShowToastDialog.showToast(e.toString());
      }
    }

    ShowToastDialog.closeLoader();
  }

  void _populateUserModel() {
    // Basic info
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

    // ── Multiple sections ──
    final sectionIds = selectedSections.map((s) => s.id!).toList();
    final serviceTypes = selectedSections
        .map((s) => s.serviceTypeFlag ?? 'delivery-service')
        .toList();

    userModel.value.sectionIds = sectionIds;
    userModel.value.serviceTypes = serviceTypes;

    if (sectionIds.isNotEmpty) {
      userModel.value.sectionId = sectionIds.first;
      userModel.value.serviceType = serviceTypes.first;
    } else {
      userModel.value.sectionId = null;
      userModel.value.serviceType = null;
    }

    // ── Vehicle details ──
    if (selectedValue.value != "Company" &&
        selectedSections.any((s) => sectionNeedsVehicle(s))) {
      final vehicleName = selectedVehicleTypeName.value;
      final vehicleId = selectedVehicleTypeId.value;
      final carMakes = selectedCarMakes.value;
      final carModel = selectedCarModel.value;
      final carPlate = carPlateController.value.text;
      final rideType = selectedRideType.value;

      userModel.value.vehicleType = vehicleName;
      userModel.value.vehicleId = vehicleId;
      userModel.value.carMakes = carMakes?.name ?? '';
      userModel.value.carName = carModel?.name ?? '';
      userModel.value.carNumber = carPlate;
      userModel.value.rideType = rideType;

      userModel.value.vehicleDetails = {
        'vehicleId': vehicleId ?? '',
        'vehicleType': vehicleName ?? '',
        'carBrand': carMakes?.name ?? '',
        'carModel': carModel?.name ?? '',
        'carPlateNumber': carPlate,
        'rideType': rideType,
      };
    } else {
      userModel.value.vehicleType = null;
      userModel.value.vehicleId = null;
      userModel.value.carMakes = null;
      userModel.value.carName = null;
      userModel.value.carNumber = null;
      userModel.value.rideType = null;
      userModel.value.vehicleDetails = null;
    }
  }

  void _navigateAfterSignup(UserModel user) {
    if (!(Constant.autoApproveDriver ?? false)) {
      ShowToastDialog.showToast(
        "Thank you for sign up, your application is under approval so please wait till that approve."
            .tr(),
      );
      Get.offAll(LoginScreen());
      return;
    }
    navigateByUserModel(user);
  }

  static void navigateByUserModel(UserModel user) {
    if (user.isOwner == true) {
      Get.offAll(OwnerDashboardScreen());
    } else {
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

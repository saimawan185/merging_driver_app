import 'dart:developer';
import 'package:door_delights_driver/constant/show_toast_dialog.dart';
import 'package:door_delights_driver/models/car_makes.dart';
import 'package:door_delights_driver/models/car_model.dart';
import 'package:door_delights_driver/models/section_model.dart';
import 'package:door_delights_driver/models/user_model.dart';
import 'package:door_delights_driver/models/vehicle_type.dart';
import 'package:door_delights_driver/utils/fire_store_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Trans;

class VehicleInformationController extends GetxController {
  final String initialServiceType;

  VehicleInformationController({required this.initialServiceType});

  // ── User and sections ──────────────────────────────────────────────
  Rx<UserModel> userModel = UserModel().obs;
  RxList<SectionModel> driverSections = <SectionModel>[].obs;

  // ── All sections the user is registered in (across all services) ──
  RxList<SectionModel> allUserSections = <SectionModel>[].obs;

  // ── Single set of vehicle details ─────────────────────────────────
  RxList<VehicleType> vehicleTypeOptions = <VehicleType>[].obs;
  Rx<VehicleType?> selectedVehicleType = Rx<VehicleType?>(null);

  RxList<CarMakes> carMakesList = <CarMakes>[].obs;
  Rx<CarMakes?> selectedCarMakes = Rx<CarMakes?>(null);
  RxList<CarModel> carModelList = <CarModel>[].obs;
  Rx<CarModel?> selectedCarModel = Rx<CarModel?>(null);
  Rx<TextEditingController> carPlateController = TextEditingController().obs;

  // ── Ride Type ──────────────────────────────────────────────────────
  RxString selectedRideType = 'ride'.obs;
  RxList<String> rideTypeOptions = <String>[].obs;

  RxBool isLoading = false.obs;

  bool get hasVehicleBasedSection =>
      initialServiceType == 'cab-service' ||
      initialServiceType == 'rental-service';

  @override
  void onInit() {
    super.onInit();
    loadUserData();
  }

  Future<void> loadUserData() async {
    try {
      isLoading.value = true;

      UserModel? model =
          await FireStoreUtils.getUserProfile(FireStoreUtils.getCurrentUid());
      if (model == null) return;

      userModel.value = model;

      // ── Load all sections for this service type (for vehicle details) ──
      final sections = await FireStoreUtils.getSections(initialServiceType);
      final driverSectionIds = model.sectionIds;
      if (driverSectionIds != null && driverSectionIds.isNotEmpty) {
        driverSections.value =
            sections.where((s) => driverSectionIds.contains(s.id)).toList();
      } else {
        driverSections.value = sections;
      }

      // ── Load ALL user sections (across all services) ──────────────────
      // For ride type, we need to know if cab is selected anywhere.
      final allSections = await FireStoreUtils.getAllActiveSections();
      if (driverSectionIds != null && driverSectionIds.isNotEmpty) {
        allUserSections.value =
            allSections.where((s) => driverSectionIds.contains(s.id)).toList();
      } else {
        allUserSections.value = [];
      }

      // Load vehicle types
      await _loadVehicleTypes();

      // Load car makes list
      await _loadCarMakes();

      // Load saved vehicle details (flat map)
      _loadSavedVehicleDetails(model);

      // Load ride type options if cab is selected in any section
      _updateRideTypeOptions();
    } catch (e) {
      log("loadUserData error: $e");
    } finally {
      isLoading.value = false;
      update();
    }
  }

  Future<void> _loadVehicleTypes() async {
    final Set<String> typeNames = {};
    final List<VehicleType> types = [];

    final hasCab =
        allUserSections.any((s) => s.serviceTypeFlag == 'cab-service');
    final hasRental =
        allUserSections.any((s) => s.serviceTypeFlag == 'rental-service');
    final hasNonDelivery = hasCab || hasRental;

    for (final section in allUserSections) {
      final flag = section.serviceTypeFlag ?? '';

      if (flag == 'delivery-service' || flag == 'parcel_delivery') {
        final bikeId = await FireStoreUtils.getVehicleTypeIdByName('Bike');
        if (bikeId != null) {
          _addTypeIfNotExists(types, typeNames, 'Bike', bikeId);
          if (!hasNonDelivery) {
            _addTypeIfNotExists(types, typeNames, 'Carriage', bikeId);
          }
        } else {
          _addTypeIfNotExists(types, typeNames, 'Bike', 'bike');
          if (!hasNonDelivery) {
            _addTypeIfNotExists(types, typeNames, 'Carriage', 'carriage');
          }
        }
      } else if (flag == 'cab-service') {
        final cabTypes = await FireStoreUtils.getCabVehicleType(section.id!);
        for (final t in cabTypes) {
          _addTypeIfNotExists(types, typeNames, t.name!, t.id!);
        }
      } else if (flag == 'rental-service') {
        final rentalTypes =
            await FireStoreUtils.getRentalVehicleType(section.id!);
        for (final t in rentalTypes) {
          _addTypeIfNotExists(types, typeNames, t.name!, t.id!);
        }
      }
    }

    vehicleTypeOptions.value = types;
    if (types.isNotEmpty && selectedVehicleType.value == null) {
      selectedVehicleType.value = types.first;
    } else if (types.isEmpty) {
      selectedVehicleType.value = null;
    }
  }

  void _addTypeIfNotExists(
      List<VehicleType> list, Set<String> seen, String name, String id) {
    if (!seen.contains(name)) {
      seen.add(name);
      list.add(VehicleType(id: id, name: name));
    }
  }

  Future<void> _loadCarMakes() async {
    try {
      carMakesList.value = await FireStoreUtils.getCarMakes();
    } catch (e) {
      log("Error loading car makes: $e");
    }
  }

  void _loadSavedVehicleDetails(UserModel user) {
    final Map<String, dynamic>? details = user.vehicleDetails;

    final vehicleTypeName =
        details?['vehicleType']?.toString() ?? user.vehicleType;
    final carBrand = details?['carBrand']?.toString() ?? user.carMakes;
    final carModelName = details?['carModel']?.toString() ?? user.carName;
    final carPlate = details?['carPlateNumber']?.toString() ?? user.carNumber;
    final rideType =
        details?['rideType']?.toString() ?? user.rideType ?? 'ride';

    // Set vehicle type
    if (vehicleTypeName != null && vehicleTypeOptions.isNotEmpty) {
      final found = vehicleTypeOptions.firstWhere(
          (t) => t.name == vehicleTypeName,
          orElse: () => VehicleType());
      if (found.id != null) selectedVehicleType.value = found;
    }

    // Set car brand and load its models
    if (carBrand != null && carBrand.isNotEmpty) {
      final found = carMakesList.firstWhere((c) => c.name == carBrand,
          orElse: () => CarMakes());
      if (found.id != null) {
        selectedCarMakes.value = found;
        // Load car models for this brand
        getCarModels();
      }
    }

    // Set car model
    if (carModelName != null &&
        carModelName.isNotEmpty &&
        carModelList.isNotEmpty) {
      final found = carModelList.firstWhere((m) => m.name == carModelName,
          orElse: () => CarModel());
      if (found.id != null) selectedCarModel.value = found;
    }

    // Set car plate
    if (carPlate != null) {
      carPlateController.value.text = carPlate;
    }

    // Set ride type
    selectedRideType.value = rideType;
  }

  void _updateRideTypeOptions() {
    // Check if user has any cab section (across all sections)
    final hasCab = allUserSections
        .any((section) => section.serviceTypeFlag == 'cab-service');

    if (!hasCab) {
      rideTypeOptions.clear();
      selectedRideType.value = 'ride';
      return;
    }

    // Get the first cab section to determine allowed ride types
    final firstCab = allUserSections.firstWhere(
      (s) => s.serviceTypeFlag == 'cab-service',
      orElse: () => SectionModel(),
    );
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

  Future<void> getCarModels() async {
    final brand = selectedCarMakes.value?.name;
    if (brand == null || brand.isEmpty) {
      carModelList.clear();
      selectedCarModel.value = null;
      update();
      return;
    }
    try {
      final models = await FireStoreUtils.getCarModel(brand);
      carModelList.value = models;
      if (models.isNotEmpty) {
        final savedModelName =
            userModel.value.vehicleDetails?['carModel']?.toString();
        if (savedModelName != null && savedModelName.isNotEmpty) {
          final found = models.firstWhere((m) => m.name == savedModelName,
              orElse: () => models.first);
          selectedCarModel.value = found;
        } else {
          selectedCarModel.value = models.first;
        }
      } else {
        selectedCarModel.value = null;
      }
    } catch (e) {
      log("Error loading car models: $e");
      carModelList.clear();
      selectedCarModel.value = null;
    }
    update();
  }

  Future<void> saveVehicleInformation() async {
    if (userModel.value.isOwner == true) {
      ShowToastDialog.showToast("Update not allowed for Owner type users.");
      return;
    }

    if (selectedVehicleType.value == null) {
      ShowToastDialog.showToast("Please select a vehicle type.");
      return;
    }
    if (selectedCarMakes.value == null) {
      ShowToastDialog.showToast("Please select a car brand.");
      return;
    }
    if (selectedCarModel.value == null) {
      ShowToastDialog.showToast("Please select a car model.");
      return;
    }
    if (carPlateController.value.text.trim().isEmpty) {
      ShowToastDialog.showToast("Please enter car plate number.");
      return;
    }

    ShowToastDialog.showLoader("Updating vehicle information...");
    try {
      final vehicle = selectedVehicleType.value!;
      final carMakes = selectedCarMakes.value!;
      final carModel = selectedCarModel.value!;
      final carPlate = carPlateController.value.text.trim();
      final rideType = selectedRideType.value;

      String vehicleId;
      // if (vehicle.name == 'Bike') {
      //   vehicleId = 'bike';
      // } else if (vehicle.name == 'Carriage') {
      //   vehicleId = 'carriage';
      // } else {
      vehicleId = vehicle.id?.isNotEmpty == true ? vehicle.id! : vehicle.name!;
      // }

      // Build details map
      final Map<String, dynamic> details = {
        'vehicleId': vehicleId,
        'vehicleType': vehicle.name ?? '',
        'carBrand': carMakes.name ?? '',
        'carModel': carModel.name ?? '',
        'carPlateNumber': carPlate,
      };

      // Always save rideType if the user has any cab section
      final hasCab =
          allUserSections.any((s) => s.serviceTypeFlag == 'cab-service');
      if (hasCab) {
        details['rideType'] = rideType;
      }

      // Update user model fields
      userModel.value.vehicleId = vehicleId;
      userModel.value.vehicleType = vehicle.name;
      userModel.value.carMakes = carMakes.name;
      userModel.value.carName = carModel.name;
      userModel.value.carNumber = carPlate;
      if (hasCab) {
        userModel.value.rideType = rideType;
      }
      userModel.value.vehicleDetails = details;

      final success = await FireStoreUtils.updateUser(userModel.value);
      ShowToastDialog.closeLoader();
      if (success) {
        ShowToastDialog.showToast("Vehicle information updated successfully.");
        // Reload user data to refresh all fields
        await loadUserData();
      } else {
        ShowToastDialog.showToast("Failed to update. Please try again.");
      }
    } catch (e) {
      ShowToastDialog.closeLoader();
      ShowToastDialog.showToast("Error updating vehicle info: $e");
      log("Error: $e");
    }
  }

  String getReadableServiceType(String key) {
    switch (key) {
      case 'cab-service':
        return 'Cab Service';
      case 'parcel_delivery':
        return 'Parcel Service';
      case 'rental-service':
        return 'Rental Service';
      default:
        return 'Delivery Service';
    }
  }
}

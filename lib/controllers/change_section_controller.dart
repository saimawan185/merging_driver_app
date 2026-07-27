import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart' hide Trans;
import 'package:easy_localization/easy_localization.dart';
import '../constant/collection_name.dart';
import '../constant/constant.dart';
import '../constant/show_toast_dialog.dart';
import '../models/section_model.dart';
import '../models/user_model.dart';
import '../utils/fire_store_utils.dart' show FireStoreUtils;
import 'signup_controller.dart';

class ChangeSectionController extends GetxController {
  var isLoading = false.obs;

  RxList<SectionModel> allSections = <SectionModel>[].obs;
  final RxList<SectionModel> selectedSections =
      <SectionModel>[].obs; // multiple

  @override
  void onInit() {
    super.onInit();
    loadData();
  }

  Future<void> loadData() async {
    isLoading.value = true;

    allSections.value = await FireStoreUtils.getAllActiveSections();

    final user = Constant.userModel;
    if (user != null &&
        user.sectionIds != null &&
        user.sectionIds!.isNotEmpty) {
      // Pre-select sections that are in user.sectionIds
      for (final section in allSections) {
        if (user.sectionIds!.contains(section.id)) {
          selectedSections.add(section);
        }
      }
    } else if (user != null &&
        user.sectionId != null &&
        user.sectionId!.isNotEmpty) {
      // Fallback: if single sectionId is set, select it
      final singleSection = allSections.firstWhere(
        (s) => s.id == user.sectionId,
        orElse: () => SectionModel(),
      );
      if (singleSection.id != null) {
        selectedSections.add(singleSection);
      }
    }

    isLoading.value = false;
  }

  // Check if a section is currently selected
  bool isSectionSelected(SectionModel section) =>
      selectedSections.any((s) => s.id == section.id);

  // Toggle selection
  void toggleSection(SectionModel section) {
    if (isSectionSelected(section)) {
      selectedSections.removeWhere((s) => s.id == section.id);
    } else {
      selectedSections.add(section);
    }
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

  Future<void> saveChanges() async {
    if (selectedSections.isEmpty) {
      ShowToastDialog.showToast("Please select at least one section.".tr());
      return;
    }

    ShowToastDialog.showLoader("Please wait".tr());

    final UserModel user = Constant.userModel!;

    // Get selected section IDs and service types
    final List<String> sectionIds = selectedSections.map((s) => s.id!).toList();
    final List<String> serviceTypes =
        selectedSections.map((s) => s.serviceTypeFlag!).toList();

    // Update user fields
    user.sectionIds = sectionIds;
    user.serviceTypes = serviceTypes;

    // Set sectionId and serviceType from the first selected section
    final firstSection = selectedSections.first;
    user.sectionId = firstSection.id;
    user.serviceType = firstSection.serviceTypeFlag;

    // Handle vehicleDetails: keep only for relevant sections
    // Map<String, dynamic>? newVehicleDetails = {};
    // for (final section in selectedSections) {
    //   if (section.serviceTypeFlag == 'cab-service' ||
    //       section.serviceTypeFlag == 'rental-service') {
    //     if (user.vehicleDetails != null &&
    //         user.vehicleDetails!.containsKey(section.id)) {
    //       newVehicleDetails![section.id!] = user.vehicleDetails![section.id];
    //     } else {
    //       // You might want to initialize with default or null; we'll keep empty for now
    //       newVehicleDetails![section.id!] = null;
    //     }
    //   }
    // }
    // // If no cab/rental sections, set to null
    // if (newVehicleDetails!.isEmpty) {
    //   newVehicleDetails = null;
    // }
    // user.vehicleDetails = newVehicleDetails;

    // Save all user fields via updateUser (merges)
    await FireStoreUtils.updateUser(user);

    // final docRef = FirebaseFirestore.instance
    //     .collection(CollectionName.users)
    //     .doc(user.id);

    // await docRef.set(
    //     {
    //       'vehicleDetails': newVehicleDetails ?? FieldValue.delete(),
    //       'carMakes': user.carMakes ?? FieldValue.delete(),
    //       'carNumber': user.carNumber ?? FieldValue.delete(),
    //       'carName': user.carName ?? FieldValue.delete(),
    //     },
    //     SetOptions(mergeFields: [
    //       'vehicleDetails',
    //       'carMakes',
    //       'carNumber',
    //       'carName'
    //     ]));

    // Update local cache
    Constant.userModel = user;
    // Update section models cache if needed
    for (final section in selectedSections) {
      Constant.sectionModels[section.id!] = section;
    }

    ShowToastDialog.closeLoader();
    ShowToastDialog.showToast("Sections updated successfully".tr());

    SignupController.navigateByUserModel(user);
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

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
  final Rx<SectionModel?> selectedSection = Rx<SectionModel?>(null);

  @override
  void onInit() {
    super.onInit();
    loadData();
  }

  Future<void> loadData() async {
    isLoading.value = true;

    allSections.value = await FireStoreUtils.getAllActiveSections();

    final user = Constant.userModel;
    if (user != null && user.sectionId != null) {
      for (final section in allSections) {
        if (section.id == user.sectionId) {
          selectedSection.value = section;
          break;
        }
      }
    }

    isLoading.value = false;
  }

  // Check if a section is currently selected
  bool isSectionSelected(SectionModel section) =>
      selectedSection.value?.id == section.id;

  // Select a single section; if already selected, deselect it
  void toggleSection(SectionModel section) {
    if (isSectionSelected(section)) {
      selectedSection.value = null;
    } else {
      selectedSection.value = section;
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
    if (selectedSection.value == null) {
      ShowToastDialog.showToast("Please select a section.".tr);
      return;
    }

    ShowToastDialog.showLoader("Please wait".tr);

    final UserModel user = Constant.userModel!;
    final section = selectedSection.value!;
    final sectionId = section.id!;

    // Update user fields – single section
    user.sectionId = sectionId;
    user.serviceType = section.serviceTypeFlag;

    // Remove vehicle details if section is not cab/rental
    Map<String, dynamic>? newVehicleDetails;
    if (section.serviceTypeFlag == 'cab-service' ||
        section.serviceTypeFlag == 'rental-service') {
      // Keep existing vehicle details for this section if any
      if (user.vehicleDetails != null &&
          user.vehicleDetails!.containsKey(sectionId)) {
        newVehicleDetails = {sectionId: user.vehicleDetails![sectionId]};
      } else {
        newVehicleDetails = null; // or empty map, but we can keep null
      }
    } else {
      newVehicleDetails = null;
    }
    user.vehicleDetails = newVehicleDetails;

    // Save all user fields via updateUser (merges)
    await FireStoreUtils.updateUser(user);

    // Overwrite nested fields cleanly (optional but safe)
    final docRef = FirebaseFirestore.instance
        .collection(CollectionName.users)
        .doc(user.id);

    await docRef.set(
        {
          'vehicleDetails': newVehicleDetails ?? FieldValue.delete(),
          'carMakes': user.carMakes ?? FieldValue.delete(),
          'carNumber': user.carNumber ?? FieldValue.delete(),
          'carName': user.carName ?? FieldValue.delete(),
        },
        SetOptions(mergeFields: [
          'vehicleDetails',
          'carMakes',
          'carNumber',
          'carName'
        ]));

    // Update local cache
    Constant.userModel = user;
    Constant.sectionModels[sectionId] = section;

    ShowToastDialog.closeLoader();
    ShowToastDialog.showToast("Section updated successfully".tr);

    SignupController.navigateByUserModel(user);
  }
}

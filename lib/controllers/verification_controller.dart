import 'package:door_delights_driver/constant/constant.dart';
import 'package:door_delights_driver/models/document_model.dart';
import 'package:door_delights_driver/models/driver_document_model.dart';
import 'package:door_delights_driver/utils/fire_store_utils.dart';
import 'package:get/get.dart';

class VerificationController extends GetxController {
  RxBool isLoading = true.obs;

  @override
  void onInit() {
    // TODO: implement onInit
    getDocument();
    super.onInit();
  }

  RxList documentList = <DocumentModel>[].obs;
  RxList driverDocumentList = <Documents>[].obs;

  Future<void> getDocument() async {
    await FireStoreUtils.getDocumentList(
            Constant.userModel!.isOwner == true ? "owner" : "driver")
        .then((value) {
      documentList.value = value;
    });
    await FireStoreUtils.getDocumentOfDriver().then((value) {
      if (value != null) {
        driverDocumentList.value = value.documents!;
      }
    });
    isLoading.value = false;
    update();
  }
}

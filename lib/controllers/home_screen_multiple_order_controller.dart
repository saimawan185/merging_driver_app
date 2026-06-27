import 'package:door_delights_driver/constant/collection_name.dart';
import 'package:door_delights_driver/constant/constant.dart';
import 'package:door_delights_driver/constant/send_notification.dart';
import 'package:door_delights_driver/constant/show_toast_dialog.dart';
import 'package:door_delights_driver/models/order_model.dart';
import 'package:door_delights_driver/models/user_model.dart';
import 'package:door_delights_driver/services/audio_player_service.dart';
import 'package:door_delights_driver/utils/fire_store_utils.dart';
import 'package:get/get.dart';

import '../constants.dart';

class HomeScreenMultipleOrderController extends GetxController {
  Rx<UserModel> driverModel = Constant.userModel!.obs;
  RxBool isLoading = true.obs;
  RxInt selectedTabIndex = 0.obs;

  RxList<dynamic> newOrder = [].obs;
  RxList<dynamic> activeOrder = [].obs;

  @override
  void onInit() {
    getDriver();
    super.onInit();
  }

  Future<void> getDriver() async {
    FireStoreUtils.fireStore
        .collection(CollectionName.users)
        .doc(FireStoreUtils.getCurrentUid())
        .snapshots()
        .listen(
      (event) async {
        if (event.exists) {
          driverModel.value = UserModel.fromJson(event.data()!);
          Constant.userModel = driverModel.value;
          newOrder.clear();
          activeOrder.clear();
          if (driverModel.value.orderRequestData != null) {
            newOrder.add(driverModel.value.orderRequestData!);
          }

          if (driverModel.value.inProgressOrderID != null) {
            activeOrder.add(driverModel.value.inProgressOrderID!);
          }

          if (newOrder.isEmpty == true) {
            await AudioPlayerService.playSound(false);
          }

          if (newOrder.isNotEmpty) {
            if (driverModel.value.vendorID?.isEmpty == true) {
              await AudioPlayerService.playSound(true);
            }
          }
        }
      },
    );
    isLoading.value = false;
    update();
  }

  Future<void> acceptOrder(OrderModel currentOrder) async {
    await AudioPlayerService.playSound(false);
    ShowToastDialog.showLoader("Please wait".tr);

    driverModel.value.inProgressOrderID = currentOrder.id;
    driverModel.value.orderRequestData = null;

    await FireStoreUtils.updateUser(driverModel.value);

    currentOrder.status = ORDER_STATUS_ACCEPTED;
    currentOrder.driverID = driverModel.value.id;
    currentOrder.driver = driverModel.value;

    await FireStoreUtils.setOrder(currentOrder);
    ShowToastDialog.closeLoader();
    await Future.wait([
      SendNotification.sendFcmMessage(Constant.driverAcceptedNotification,
          currentOrder.author!.fcmToken.toString(), {}),
      SendNotification.sendFcmMessage(Constant.driverAcceptedNotification,
          currentOrder.vendor!.fcmToken.toString(), {})
    ]);
  }

  Future<void> rejectOrder(OrderModel currentOrder) async {
    ShowToastDialog.showLoader("Please wait".tr);
    await AudioPlayerService.playSound(false);
    currentOrder.rejectedByDrivers ??= [];
    currentOrder.rejectedByDrivers!.add(driverModel.value.id);
    currentOrder.status = ORDER_STATUS_DRIVER_REJECTED;
    driverModel.value.orderRequestData = null;
    await Future.wait([
      FireStoreUtils.setOrder(currentOrder),
      FireStoreUtils.updateUser(driverModel.value)
    ]);
    ShowToastDialog.closeLoader();
  }
}

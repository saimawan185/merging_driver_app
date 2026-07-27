import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart' hide Trans;
import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization/easy_localization.dart';

import '../constant/constant.dart';
import '../constant/send_notification.dart';
import '../constant/show_toast_dialog.dart';
import '../models/order_model.dart';
import '../models/wallet_transaction_model.dart';
import '../services/audio_player_service.dart';
import '../utils/fire_store_utils.dart';

class DeliverOrderController extends GetxController {
  RxBool isLoading = true.obs;
  RxBool conformPickup = false.obs;

  @override
  void onInit() {
    getArgument();
    super.onInit();
  }

  Rx<OrderModel> orderModel = OrderModel().obs;

  RxInt totalQuantity = 0.obs;

  void getArgument() {
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      orderModel.value = argumentData['orderModel'];
      for (var element in orderModel.value.products!) {
        totalQuantity.value += (element.quantity);
      }
    }
    isLoading.value = false;
  }

  Future<void> completedOrder() async {
    ShowToastDialog.showLoader("Please wait".tr());
    await AudioPlayerService.playSound(false);
    orderModel.value.status = Constant.orderCompleted;
    await FireStoreUtils.updateWallateAmount(orderModel.value);
    if (orderModel.value.cashback?.cashbackValue != null &&
        orderModel.value.cashback?.id != null) {
      WalletTransactionModel transactionModel = WalletTransactionModel(
          id: Constant.getUuid(),
          amount: double.parse(
              "${orderModel.value.cashback?.cashbackValue ?? 0.0}"),
          date: Timestamp.now(),
          paymentMethod: "Cashback Amount",
          transactionUser: "user",
          userId: orderModel.value.author?.id,
          isTopup: true,
          orderId: orderModel.value.id,
          note: "Cashback Amount",
          paymentStatus: "success");
      await FireStoreUtils.setWalletTransaction(transactionModel)
          .then((value) async {
        if (value == true) {
          await FireStoreUtils.updateUserWallet(
              amount: double.parse(
                      "${orderModel.value.cashback?.cashbackValue ?? 0.0}")
                  .toString(),
              userId: orderModel.value.author!.id.toString());
        }
      });
    }
    await FireStoreUtils.setOrder(orderModel.value);
    if (Constant.userModel?.vendorID != null) {
      Constant.userModel?.orderRequestData = null;
      Constant.userModel?.inProgressOrderID = null;
      await FireStoreUtils.updateUser(Constant.userModel!);
    }
    await FireStoreUtils.getFirestOrderOrNOt(orderModel.value)
        .then((value) async {
      if (value == true) {
        await FireStoreUtils.updateReferralAmount(orderModel.value);
      }
    });

    await SendNotification.sendFcmMessage(Constant.driverCompleted,
        orderModel.value.author!.fcmToken.toString(), {});
    ShowToastDialog.closeLoader();
    Get.back(result: true);
  }
}

import 'dart:developer';

import 'package:door_delights_driver/constant/collection_name.dart';
import 'package:door_delights_driver/constant/constant.dart';
import 'package:door_delights_driver/models/order_model.dart';
import 'package:door_delights_driver/utils/fire_store_utils.dart';
import 'package:get/get.dart' hide Trans;
import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization/easy_localization.dart';

class OrderListController extends GetxController {
  RxBool isLoading = true.obs;

  @override
  void onInit() {
    // TODO: implement onInit
    getOrder();
    super.onInit();
  }

  RxList<OrderModel> orderList = <OrderModel>[].obs;

  Future<void> getOrder() async {
    await FireStoreUtils.fireStore
        .collection(CollectionName.vendorOrders)
        .where('driverID', isEqualTo: Constant.userModel!.id.toString())
        .orderBy('createdAt', descending: true)
        .get()
        .then((value) {
      for (var element in value.docs) {
        OrderModel dailyEarningModel = OrderModel.fromJson(element.data());
        orderList.add(dailyEarningModel);
      }
    }).catchError((error) {
      log(error.toString());
    });

    isLoading.value = false;
  }
}

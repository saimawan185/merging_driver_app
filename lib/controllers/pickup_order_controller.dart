import 'package:door_delights_driver/models/order_model.dart';
import 'package:get/get.dart' hide Trans;

class PickupOrderController extends GetxController {
  RxBool isLoading = true.obs;
  RxBool conformPickup = false.obs;

  @override
  void onInit() {
    getArgument();
    super.onInit();
  }

  Rx<OrderModel> orderModel = OrderModel().obs;

  void getArgument() {
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      orderModel.value = argumentData['orderModel'];
    }
    isLoading.value = false;
    update();
  }
}

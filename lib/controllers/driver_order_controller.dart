import 'package:get/get.dart' hide Trans;
import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization/easy_localization.dart';

class DriverOrderListController extends GetxController {
  RxString driverId = "".obs;
  RxString serviceType = "".obs;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;

    if (args != null) {
      if (args['driverId'] != null) {
        driverId.value = args['driverId'];
      }
      if (args['serviceType'] != null) {
        serviceType.value = args['serviceType'];
      }
    }
  }
}

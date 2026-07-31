import 'package:door_delights_driver/constant/constant.dart';
import 'package:door_delights_driver/controllers/dash_board_controller.dart';
import 'package:door_delights_driver/controllers/home_screen_multiple_order_controller.dart';
import 'package:door_delights_driver/models/order_model.dart';
import 'package:door_delights_driver/themes/app_them_data.dart';
import 'package:door_delights_driver/themes/round_button_fill.dart';
import 'package:door_delights_driver/themes/theme_controller.dart';
import 'package:door_delights_driver/utils/fire_store_utils.dart';
import 'package:door_delights_driver/widget/my_separator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart' hide Trans;
import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:timelines_plus/timelines_plus.dart';
import '../../constant/global.dart';
import '../../constants.dart';
import '../../models/user_model.dart';
import '../../ui/home/HomeScreen.dart';

String _formatDuration(int seconds) {
  if (seconds < 60) {
    return '${seconds} sec${seconds == 1 ? '' : 's'}';
  } else if (seconds < 3600) {
    int minutes = seconds ~/ 60;
    return '${minutes} min${minutes == 1 ? '' : 's'}';
  } else {
    int hours = seconds ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    if (minutes == 0) {
      return '${hours} hr${hours == 1 ? '' : 's'}';
    } else {
      return '${hours} hr${hours == 1 ? '' : 's'} ${minutes} min${minutes == 1 ? '' : 's'}';
    }
  }
}

Map<String, String>? _parseDistanceResult(dynamic result) {
  if (result != null &&
      result['rows'] != null &&
      result['rows'].isNotEmpty &&
      result['rows'].first['elements'] != null &&
      result['rows'].first['elements'].isNotEmpty &&
      result['rows'].first['elements'].first['status'] == 'OK') {
    final element = result['rows'].first['elements'].first;
    final distanceText = element['distance']['text'];
    final durationSeconds = element['duration']['value'] as int;
    return {
      'duration': _formatDuration(durationSeconds),
      'distance': distanceText,
    };
  }
  return null;
}

class HomeScreenMultipleOrder extends StatelessWidget {
  const HomeScreenMultipleOrder({super.key});

  @override
  Widget build(BuildContext context) {
    return GetX(
        init: HomeScreenMultipleOrderController(),
        builder: (controller) {
          final isDark = Get.find<ThemeController>().isDark.value;

          return Scaffold(
            body: controller.isLoading.value
                ? Constant.loader()
                : Constant.userModel?.vendorID?.isEmpty == true &&
                        Constant.userModel?.isDocumentVerify == false &&
                        controller.driverModel.value.isAutoVerify == false
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              decoration: ShapeDecoration(
                                color: isDark
                                    ? AppThemeData.grey700
                                    : AppThemeData.grey200,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(120),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: SvgPicture.asset(
                                    "assets/icons/ic_document.svg"),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "document_verification_pending".tr(),
                              style: TextStyle(
                                color: isDark
                                    ? AppThemeData.grey100
                                    : AppThemeData.grey800,
                                fontSize: 22,
                                fontFamily: AppThemeData.semiBold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              "document_review_notification".tr(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isDark
                                    ? AppThemeData.grey50
                                    : AppThemeData.grey500,
                                fontSize: 16,
                                fontFamily: AppThemeData.bold,
                              ),
                            ),
                            const SizedBox(height: 20),
                            RoundedButtonFill(
                              title: "view_status".tr(),
                              width: 55,
                              height: 5.5,
                              color: AppThemeData.primary300,
                              textColor: AppThemeData.grey50,
                              onPress: () async {
                                DashBoardController dashBoardController =
                                    Get.put(DashBoardController());
                                dashBoardController.drawerIndex.value = 4;
                              },
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          Constant.userModel?.vendorID?.isEmpty == true &&
                                  double.parse(controller
                                          .driverModel.value.walletAmount
                                          .toString()) <
                                      0
                              ? Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    "${"Your wallet balance is ".tr()}${amountShow(amount: controller.driverModel.value.walletAmount?.toString())} ${"you’ll temporarily receive card & wallet orders or rides until its’s restored".tr()}",
                                    style: TextStyle(
                                        color: isDark
                                            ? AppThemeData.grey50
                                            : AppThemeData.grey900,
                                        fontSize: 14,
                                        fontFamily: AppThemeData.semiBold),
                                  ),
                                )
                              : const SizedBox(),
                          Expanded(
                            child: DefaultTabController(
                              length:
                                  Constant.userModel?.vendorID?.isEmpty == true
                                      ? 2
                                      : 1,
                              child: Column(
                                children: [
                                  Container(
                                    color: isDark
                                        ? AppThemeData.grey900
                                        : AppThemeData.grey50,
                                    child: TabBar(
                                      onTap: (value) {
                                        controller.selectedTabIndex.value =
                                            value;
                                      },
                                      labelStyle: const TextStyle(
                                          fontFamily: AppThemeData.semiBold),
                                      labelColor: isDark
                                          ? AppThemeData.carRent300
                                          : AppThemeData.primary300,
                                      unselectedLabelStyle: const TextStyle(
                                          fontFamily: AppThemeData.medium),
                                      unselectedLabelColor: isDark
                                          ? AppThemeData.greyDark900
                                          : AppThemeData.grey400,
                                      indicatorColor: AppThemeData.carRent300,
                                      isScrollable: false,
                                      dividerColor: Colors.transparent,
                                      tabs: [
                                        if (Constant
                                                .userModel?.vendorID?.isEmpty ==
                                            true)
                                          Tab(
                                            text: "New".tr(),
                                          ),
                                        Tab(
                                          text: "Active".tr(),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 10),
                                      child: TabBarView(
                                        children: Constant.userModel?.vendorID
                                                    ?.isEmpty ==
                                                true
                                            ? [
                                                controller.newOrder.isEmpty
                                                    ? Constant.showEmptyView(
                                                        message:
                                                            "New Order not found."
                                                                .tr(),
                                                        isDark: isDark)
                                                    : ListView.builder(
                                                        shrinkWrap: true,
                                                        padding:
                                                            EdgeInsets.zero,
                                                        scrollDirection:
                                                            Axis.vertical,
                                                        itemCount: controller
                                                            .newOrder.length,
                                                        itemBuilder:
                                                            (BuildContext
                                                                    context,
                                                                int index) {
                                                          return Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    vertical:
                                                                        5),
                                                            child: _OrderCard(
                                                              orderId:
                                                                  controller
                                                                      .newOrder[
                                                                          index]
                                                                      .id!,
                                                              driverModel:
                                                                  controller
                                                                      .driverModel
                                                                      .value,
                                                              isDark: isDark,
                                                              isNew: true,
                                                              controller:
                                                                  controller,
                                                            ),
                                                          );
                                                        },
                                                      ),
                                                controller.activeOrder.isEmpty
                                                    ? Constant.showEmptyView(
                                                        message:
                                                            "Active order not found."
                                                                .tr(),
                                                        isDark: isDark)
                                                    : ListView.builder(
                                                        itemCount: controller
                                                            .activeOrder.length,
                                                        shrinkWrap: true,
                                                        padding:
                                                            EdgeInsets.zero,
                                                        itemBuilder:
                                                            (context, index) {
                                                          return Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    vertical:
                                                                        5),
                                                            child: _OrderCard(
                                                              orderId: controller
                                                                      .activeOrder[
                                                                  index],
                                                              driverModel:
                                                                  controller
                                                                      .driverModel
                                                                      .value,
                                                              isDark: isDark,
                                                              isNew: false,
                                                              controller:
                                                                  controller,
                                                            ),
                                                          );
                                                        },
                                                      ),
                                              ]
                                            : [
                                                controller.activeOrder.isEmpty
                                                    ? Constant.showEmptyView(
                                                        message:
                                                            "Active order not found."
                                                                .tr(),
                                                        isDark: isDark)
                                                    : ListView.builder(
                                                        itemCount: controller
                                                            .activeOrder.length,
                                                        shrinkWrap: true,
                                                        padding:
                                                            EdgeInsets.zero,
                                                        itemBuilder:
                                                            (context, index) {
                                                          return Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    vertical:
                                                                        5),
                                                            child: _OrderCard(
                                                              orderId: controller
                                                                      .activeOrder[
                                                                  index],
                                                              driverModel:
                                                                  controller
                                                                      .driverModel
                                                                      .value,
                                                              isDark: isDark,
                                                              isNew: false,
                                                              controller:
                                                                  controller,
                                                            ),
                                                          );
                                                        },
                                                      ),
                                              ],
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ),
                          )
                        ],
                      ),
          );
        });
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Order Card Widget – handles its own distance calculations with caching
// ─────────────────────────────────────────────────────────────────────────
class _OrderCard extends StatefulWidget {
  final String orderId;
  final UserModel driverModel;
  final bool isDark;
  final bool isNew;
  final HomeScreenMultipleOrderController controller;

  const _OrderCard({
    required this.orderId,
    required this.driverModel,
    required this.isDark,
    required this.isNew,
    required this.controller,
  });

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  OrderModel? _orderModel;
  bool _isLoading = true;
  Map<String, String>? _driverToVendorInfo;
  Map<String, String>? _vendorToCustomerInfo;

  // ── Static caches per order ID ──
  static final Map<String, Map<String, String>?> _driverToVendorCache = {};
  static final Map<String, Map<String, String>?> _vendorToCustomerCache = {};

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    final order = await FireStoreUtils.getOrderById(widget.orderId);
    if (order != null) {
      setState(() {
        _orderModel = order;
        _isLoading = false;
      });
      _fetchDistances();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchDistances() async {
    final orderId = widget.orderId;
    if (_orderModel == null || widget.driverModel.location == null) return;

    // ── Driver → Vendor (cached) ──
    if (_driverToVendorCache.containsKey(orderId)) {
      setState(() {
        _driverToVendorInfo = _driverToVendorCache[orderId];
      });
    } else {
      final result = await _getDriverToVendorInfo();
      _driverToVendorCache[orderId] = result;
      setState(() {
        _driverToVendorInfo = result;
      });
    }

    // ── Vendor → Customer (cached) ──
    if (_vendorToCustomerCache.containsKey(orderId)) {
      setState(() {
        _vendorToCustomerInfo = _vendorToCustomerCache[orderId];
      });
    } else {
      final result = await _getVendorToCustomerInfo();
      _vendorToCustomerCache[orderId] = result;
      setState(() {
        _vendorToCustomerInfo = result;
      });
    }
  }

  Future<Map<String, String>?> _getDriverToVendorInfo() async {
    if (_orderModel == null ||
        _orderModel!.vendor == null ||
        widget.driverModel.location == null) {
      return null;
    }
    final vendorLat = _orderModel!.vendor!.latitude ?? 0.0;
    final vendorLng = _orderModel!.vendor!.longitude ?? 0.0;
    if (vendorLat == 0.0 && vendorLng == 0.0) return null;

    final driverLat = widget.driverModel.location!.latitude!;
    final driverLng = widget.driverModel.location!.longitude!;

    final result = await getDurationDistance(
      LatLng(driverLat, driverLng),
      LatLng(vendorLat, vendorLng),
    );
    return _parseDistanceResult(result);
  }

  Future<Map<String, String>?> _getVendorToCustomerInfo() async {
    if (_orderModel == null ||
        _orderModel!.vendor == null ||
        _orderModel!.address == null ||
        _orderModel!.address!.location == null) {
      return null;
    }
    final vendorLat = _orderModel!.vendor!.latitude ?? 0.0;
    final vendorLng = _orderModel!.vendor!.longitude ?? 0.0;
    final customerLat = _orderModel!.address!.location!.latitude ?? 0.0;
    final customerLng = _orderModel!.address!.location!.longitude ?? 0.0;
    if (vendorLat == 0.0 && vendorLng == 0.0) return null;
    if (customerLat == 0.0 && customerLng == 0.0) return null;

    final result = await getDurationDistance(
      LatLng(vendorLat, vendorLng),
      LatLng(customerLat, customerLng),
    );
    return _parseDistanceResult(result);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _orderModel == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: ShapeDecoration(
          color: widget.isDark ? AppThemeData.grey900 : AppThemeData.grey50,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final order = _orderModel!;
    final distanceInMeters = Geolocator.distanceBetween(
      order.vendor!.latitude ?? 0.0,
      order.vendor!.longitude ?? 0.0,
      order.address!.location!.latitude ?? 0.0,
      order.address!.location!.longitude ?? 0.0,
    );
    final kilometer = distanceInMeters / 1000;

    return GestureDetector(
      onTap: () {
        Get.to(
          () => const HomeScreen(isAppBarShow: true),
          arguments: {"orderModel": order},
        );
      },
      child: Container(
        decoration: ShapeDecoration(
          color: widget.isDark ? AppThemeData.grey900 : AppThemeData.grey50,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              // ── Timeline ───────────────────────────────────────────
              Timeline.tileBuilder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                theme: TimelineThemeData(nodePosition: 0),
                builder: TimelineTileBuilder.connected(
                  contentsAlign: ContentsAlign.basic,
                  indicatorBuilder: (context, index) {
                    return index == 0
                        ? Container(
                            decoration: ShapeDecoration(
                              color: AppThemeData.primary50,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(120),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: SvgPicture.asset(
                                "assets/icons/ic_building.svg",
                                colorFilter: ColorFilter.mode(
                                    AppThemeData.primary300, BlendMode.srcIn),
                              ),
                            ),
                          )
                        : Container(
                            decoration: ShapeDecoration(
                              color: AppThemeData.carRent50,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(120),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: SvgPicture.asset(
                                "assets/icons/ic_location.svg",
                                colorFilter: ColorFilter.mode(
                                    AppThemeData.primary300, BlendMode.srcIn),
                              ),
                            ),
                          );
                  },
                  connectorBuilder: (context, index, connectorType) {
                    return const DashedLineConnector(
                      color: AppThemeData.grey300,
                      gap: 3,
                    );
                  },
                  contentsBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      child: index == 0
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order.vendor!.title ?? '',
                                  textAlign: TextAlign.start,
                                  style: TextStyle(
                                    fontFamily: AppThemeData.semiBold,
                                    fontSize: 16,
                                    color: widget.isDark
                                        ? AppThemeData.grey50
                                        : AppThemeData.grey900,
                                  ),
                                ),
                                Text(
                                  order.vendor!.location ?? '',
                                  textAlign: TextAlign.start,
                                  style: TextStyle(
                                    fontFamily: AppThemeData.medium,
                                    fontSize: 14,
                                    color: widget.isDark
                                        ? AppThemeData.grey300
                                        : AppThemeData.grey600,
                                  ),
                                ),
                                // ── Driver → Vendor distance ──
                                if (_driverToVendorInfo != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    "🚗 ${_driverToVendorInfo!['duration']} away (${_driverToVendorInfo!['distance']})",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                      fontFamily: "Poppinsr",
                                    ),
                                  ),
                                ] else
                                  const SizedBox(height: 2),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Deliver to the".tr(),
                                  textAlign: TextAlign.start,
                                  style: TextStyle(
                                    fontFamily: AppThemeData.semiBold,
                                    fontSize: 16,
                                    color: widget.isDark
                                        ? AppThemeData.grey50
                                        : AppThemeData.grey900,
                                  ),
                                ),
                                Text(
                                  order.address!.getFullAddress(),
                                  textAlign: TextAlign.start,
                                  style: TextStyle(
                                    fontFamily: AppThemeData.medium,
                                    fontSize: 14,
                                    color: widget.isDark
                                        ? AppThemeData.grey300
                                        : AppThemeData.grey600,
                                  ),
                                ),
                                // ── Vendor → Customer distance ──
                                if (_vendorToCustomerInfo != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    "🛣️ ${_vendorToCustomerInfo!['duration']} (${_vendorToCustomerInfo!['distance']})",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                      fontFamily: "Poppinsr",
                                    ),
                                  ),
                                ] else
                                  const SizedBox(height: 2),
                              ],
                            ),
                    );
                  },
                  itemCount: 2,
                ),
              ),
              // ── Separator ──
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: MySeparator(
                  color: widget.isDark
                      ? AppThemeData.grey700
                      : AppThemeData.grey200,
                ),
              ),
              // ── Trip Distance ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      "Trip Distance".tr(),
                      textAlign: TextAlign.start,
                      style: TextStyle(
                        fontFamily: AppThemeData.regular,
                        color: widget.isDark
                            ? AppThemeData.grey300
                            : AppThemeData.grey600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Text(
                    "${kilometer.toStringAsFixed(2)} ${Constant.distanceType}",
                    textAlign: TextAlign.start,
                    style: TextStyle(
                      fontFamily: AppThemeData.semiBold,
                      color: widget.isDark
                          ? AppThemeData.grey50
                          : AppThemeData.grey900,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              // ── Delivery Charge ──
              Visibility(
                visible:
                    (widget.controller.driverModel.value.vendorID?.isEmpty ==
                        true),
                child: Column(
                  children: [
                    const SizedBox(height: 5),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            "Delivery Charge".tr(),
                            textAlign: TextAlign.start,
                            style: TextStyle(
                              fontFamily: AppThemeData.regular,
                              color: widget.isDark
                                  ? AppThemeData.grey300
                                  : AppThemeData.grey600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Text(
                          Constant.amountShow(amount: order.deliveryCharge),
                          textAlign: TextAlign.start,
                          style: TextStyle(
                            fontFamily: AppThemeData.semiBold,
                            color: widget.isDark
                                ? AppThemeData.grey50
                                : AppThemeData.grey900,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // ── Tips ──
              const SizedBox(height: 5),
              if (order.tipAmount != null &&
                  order.tipAmount!.isNotEmpty &&
                  double.parse(order.tipAmount.toString()) > 0)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        "Tips".tr(),
                        textAlign: TextAlign.start,
                        style: TextStyle(
                          fontFamily: AppThemeData.regular,
                          color: widget.isDark
                              ? AppThemeData.grey300
                              : AppThemeData.grey600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Text(
                      Constant.amountShow(amount: order.tipAmount),
                      textAlign: TextAlign.start,
                      style: TextStyle(
                        fontFamily: AppThemeData.semiBold,
                        color: widget.isDark
                            ? AppThemeData.grey50
                            : AppThemeData.grey900,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 10),
              // ── Buttons ──
              if (widget.isNew) ...[
                Row(
                  children: [
                    Expanded(
                      child: RoundedButtonFill(
                        title: "Reject".tr(),
                        width: 24,
                        height: 5.5,
                        borderRadius: 10,
                        color: AppThemeData.danger300,
                        textColor: AppThemeData.grey50,
                        onPress: () {
                          widget.controller.rejectOrder(order);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RoundedButtonFill(
                        title: "Accept".tr(),
                        width: 24,
                        height: 5.5,
                        borderRadius: 10,
                        color: AppThemeData.success400,
                        textColor: AppThemeData.grey50,
                        onPress: () {
                          widget.controller.acceptOrder(order);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

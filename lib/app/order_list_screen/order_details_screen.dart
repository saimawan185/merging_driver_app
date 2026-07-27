import 'package:door_delights_driver/constant/constant.dart';
import 'package:door_delights_driver/controllers/order_details_controller.dart';
import 'package:door_delights_driver/themes/app_them_data.dart';
import 'package:door_delights_driver/themes/theme_controller.dart';
import 'package:door_delights_driver/utils/network_image_widget.dart';
import 'package:door_delights_driver/widget/my_separator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart' hide Trans;
import 'package:easy_localization/easy_localization.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:timelines_plus/timelines_plus.dart';
import '../../model/ProductModel.dart';

class OrderDetailsScreen extends StatelessWidget {
  const OrderDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;

    final controller =
        Get.put<OrderDetailsController>(OrderDetailsController());

    return Scaffold(
      backgroundColor: isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
      appBar: AppBar(
        backgroundColor:
            isDark ? AppThemeData.surfaceDark : AppThemeData.surface,
        centerTitle: false,
        titleSpacing: 0,
        title: Text(
          "Order Details".tr(),
          textAlign: TextAlign.start,
          style: TextStyle(
            fontFamily: AppThemeData.medium,
            fontSize: 16,
            color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
          ),
        ),
      ),
      body: Obx(() {
        // Catch any unexpected error to avoid white screen
        try {
          if (controller.isLoading.value) {
            return Constant.loader();
          }
          final order = controller.orderModel.value;
          if (order.id == null) {
            return Center(child: Text("No order data".tr()));
          }
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(controller, isDark),
                  const SizedBox(height: 14),
                  _buildTimeline(controller, isDark),
                  const SizedBox(height: 14),
                  _buildOrderDetails(controller, isDark, context),
                  const SizedBox(height: 14),
                  _buildBillDetails(controller, isDark, context),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          );
        } catch (e, stack) {
          // Log error – helps debugging
          debugPrint("OrderDetailsScreen error: $e\n$stack");
          return Center(child: Text("Something went wrong".tr()));
        }
      }),
    );
  }

  // ---------------------------------- HEADER ---------------------------------
  Widget _buildHeader(OrderDetailsController controller, bool isDark) {
    final order = controller.orderModel.value;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            "${'Order'.tr()} ${Constant.orderId(orderId: order.id.toString())}"
                .tr(),
            style: TextStyle(
              fontFamily: AppThemeData.semiBold,
              fontSize: 18,
              color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Constant.statusColor(status: order.status.toString()),
            borderRadius: BorderRadius.circular(15),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
          child: Text(
            order.status.toString().tr(),
            style: TextStyle(
              fontFamily: AppThemeData.bold,
              fontSize: 14,
              color: Constant.statusText(status: order.status.toString()),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------- TIMELINE --------------------------------
  Widget _buildTimeline(OrderDetailsController controller, bool isDark) {
    final order = controller.orderModel.value;
    return Container(
      decoration: ShapeDecoration(
        color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Timeline.tileBuilder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          theme: TimelineThemeData(nodePosition: 0),
          builder: TimelineTileBuilder.connected(
            contentsAlign: ContentsAlign.basic,
            indicatorBuilder: (_, index) =>
                SvgPicture.asset("assets/icons/ic_location.svg"),
            connectorBuilder: (_, index, __) => const DashedLineConnector(
              color: AppThemeData.grey300,
              gap: 3,
            ),
            contentsBuilder: (_, index) {
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: index == 0
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.vendor?.title ?? '',
                            style: TextStyle(
                              fontFamily: AppThemeData.semiBold,
                              fontSize: 16,
                              color: AppThemeData.primary300,
                            ),
                          ),
                          Text(
                            order.vendor?.location ?? '',
                            style: TextStyle(
                              fontFamily: AppThemeData.medium,
                              fontSize: 14,
                              color: isDark
                                  ? AppThemeData.grey300
                                  : AppThemeData.grey600,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.address?.addressAs ?? '',
                            style: TextStyle(
                              fontFamily: AppThemeData.semiBold,
                              fontSize: 16,
                              color: AppThemeData.primary300,
                            ),
                          ),
                          Text(
                            order.author?.fullName() ?? '',
                            style: TextStyle(
                              fontFamily: AppThemeData.semiBold,
                              fontSize: 16,
                              color: AppThemeData.primary300,
                            ),
                          ),
                          Text(
                            order.address?.getFullAddress() ?? '',
                            style: TextStyle(
                              fontFamily: AppThemeData.medium,
                              fontSize: 14,
                              color: isDark
                                  ? AppThemeData.grey300
                                  : AppThemeData.grey600,
                            ),
                          ),
                        ],
                      ),
              );
            },
            itemCount: 2,
          ),
        ),
      ),
    );
  }

  // -------------------------------- ORDER PRODUCTS ----------------------------
  Widget _buildOrderDetails(
      OrderDetailsController controller, bool isDark, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Order Details".tr(),
          style: TextStyle(
            fontFamily: AppThemeData.semiBold,
            fontSize: 16,
            color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: ShapeDecoration(
            color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: controller.orderModel.value.products?.length ?? 0,
              itemBuilder: (context, index) {
                final product = controller.orderModel.value.products![index];
                return _buildProductItem(product, isDark);
              },
              separatorBuilder: (_, __) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: MySeparator(
                  color: isDark ? AppThemeData.grey700 : AppThemeData.grey200,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductItem(ProductModel product, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(14)),
              child: Stack(
                children: [
                  NetworkImageWidget(
                    imageUrl: product.photo,
                    height: 70,
                    width: 70,
                    fit: BoxFit.cover,
                  ),
                  Container(
                    height: 70,
                    width: 70,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: const Alignment(-0.00, -1.00),
                        end: const Alignment(0, 1),
                        colors: [
                          Colors.black.withOpacity(0),
                          const Color(0xFF111827)
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: TextStyle(
                            fontFamily: AppThemeData.regular,
                            color: isDark
                                ? AppThemeData.grey50
                                : AppThemeData.grey900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Text(
                        "x ${product.quantity}",
                        style: TextStyle(
                          fontFamily: AppThemeData.regular,
                          color: isDark
                              ? AppThemeData.grey50
                              : AppThemeData.grey900,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  if ((double.tryParse(product.discount_price) ?? 0) <= 0)
                    Text(
                      Constant.amountShow(amount: product.price),
                      style: TextStyle(
                        fontSize: 16,
                        color:
                            isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                        fontFamily: AppThemeData.semiBold,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    Row(
                      children: [
                        Text(
                          Constant.amountShow(amount: product.discount_price),
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark
                                ? AppThemeData.grey50
                                : AppThemeData.grey900,
                            fontFamily: AppThemeData.semiBold,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          Constant.amountShow(amount: product.price),
                          style: TextStyle(
                            fontSize: 14,
                            decoration: TextDecoration.lineThrough,
                            decorationColor: isDark
                                ? AppThemeData.grey500
                                : AppThemeData.grey400,
                            color: isDark
                                ? AppThemeData.grey500
                                : AppThemeData.grey400,
                            fontFamily: AppThemeData.semiBold,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
        // Variants
        if (product.variant_info?.variantOptions?.isNotEmpty == true) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Variants".tr(),
                  style: TextStyle(
                    fontFamily: AppThemeData.semiBold,
                    color: isDark ? AppThemeData.grey300 : AppThemeData.grey600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: product.variant_info!.variantOptions!.entries
                      .map((entry) {
                    return Container(
                      decoration: ShapeDecoration(
                        color: isDark
                            ? AppThemeData.grey800
                            : AppThemeData.grey100,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 5),
                        child: Text(
                          "${entry.key} : ${entry.value}",
                          style: TextStyle(
                            fontFamily: AppThemeData.medium,
                            color: isDark
                                ? AppThemeData.grey500
                                : AppThemeData.grey400,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
        // Extras
        if (product.extras?.isNotEmpty == true) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  "Addons".tr(),
                  style: TextStyle(
                    fontFamily: AppThemeData.semiBold,
                    color: isDark ? AppThemeData.grey300 : AppThemeData.grey600,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                Constant.amountShow(
                  amount: ((double.tryParse(product.extras_price ?? '0') ?? 0) *
                          (int.tryParse(product.quantity.toString()) ?? 1))
                      .toString(),
                ),
                style: TextStyle(
                  fontFamily: AppThemeData.semiBold,
                  color: AppThemeData.primary300,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: product.extras!.map((extra) {
              return Container(
                decoration: ShapeDecoration(
                  color: isDark ? AppThemeData.grey800 : AppThemeData.grey100,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                  child: Text(
                    extra.toString(),
                    style: TextStyle(
                      fontFamily: AppThemeData.medium,
                      color:
                          isDark ? AppThemeData.grey500 : AppThemeData.grey400,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  // -------------------------------- BILL DETAILS -----------------------------
  Widget _buildBillDetails(
      OrderDetailsController controller, bool isDark, BuildContext context) {
    final order = controller.orderModel.value;
    final isCod = order.paymentMethod == 'cod';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Bill Details".tr(),
          style: TextStyle(
            fontFamily: AppThemeData.semiBold,
            fontSize: 16,
            color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          decoration: ShapeDecoration(
            color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            shadows: const [
              BoxShadow(color: Color(0x14000000), blurRadius: 52)
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            child: isCod
                ? _buildCodBill(controller, isDark)
                : _buildOnlineBill(controller, isDark),
          ),
        ),
      ],
    );
  }

  Widget _buildCodBill(OrderDetailsController controller, bool isDark) {
    return Column(
      children: [
        amountRow(
          title: "Item totals".tr(),
          amount:
              Constant.amountShow(amount: controller.subTotal.value.toString()),
          isDark: isDark,
        ),
        sectionDivider(isDark),
        amountRow(
          title: "Coupon Discount".tr(),
          amount:
              "- (${Constant.amountShow(amount: controller.couponAmount.value.toString())})",
          isDark: isDark,
          amountColor: AppThemeData.danger300,
        ),
        sectionDivider(isDark),
        if (controller.orderModel.value.vendor?.specialDiscountEnable ==
            true) ...[
          amountRow(
            title: "Special Discount".tr(),
            amount:
                "- (${Constant.amountShow(amount: controller.specialDiscountAmount.value.toString())})",
            isDark: isDark,
            amountColor: AppThemeData.danger300,
          ),
          if (controller.specialDiscountAmount.value > 0)
            const SizedBox(height: 5),
        ],
        amountRow(
          title: "Packaging charge".tr(),
          amount: Constant.amountShow(
              amount: controller.packagingCharge.value.toString()),
          isDark: isDark,
        ),
        sectionDivider(isDark),
        if (controller.orderModel.value.takeAway == false)
          _buildDeliveryFeeRow(controller, isDark),
        if (!(controller.orderModel.value.takeAway == true ||
            controller.orderModel.value.vendor?.isSelfDelivery == true ||
            controller.orderModel.value.isFreeDelivery == true)) ...[
          const SizedBox(height: 10),
          _buildDeliveryTipsRow(controller, isDark),
          sectionDivider(isDark),
        ],
        amountRow(
          title: "Service Charges".tr(),
          amount: Constant.amountShow(
              amount: controller.orderModel.value.serviceCharges.toString()),
          isDark: isDark,
        ),
        sectionDivider(isDark),
        amountRow(
          title: "Platform fee".tr(),
          amount: Constant.amountShow(
              amount: controller.platformFee.value.toString()),
          isDark: isDark,
        ),
        sectionDivider(isDark),
        InkWell(
          onTap: () =>
              showBillBifurcationDialog(Get.context!, isDark, controller),
          child: amountRow(
            title: "Tax amount".tr(),
            amount: Constant.amountShow(
                amount: controller.totalTaxAmount.value.toString()),
            isDark: isDark,
            textColour: AppThemeData.secondary300,
            underline: true,
          ),
        ),
        sectionDivider(isDark),
        amountRow(
          title: "To Pay".tr(),
          amount: Constant.amountShow(
              amount: controller.totalAmount.value.toString()),
          amountColor: AppThemeData.primary400,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildOnlineBill(OrderDetailsController controller, bool isDark) {
    return Column(
      children: [
        _buildDeliveryFeeRow(controller, isDark),
        if (!(controller.orderModel.value.takeAway == true ||
            controller.orderModel.value.vendor?.isSelfDelivery == true ||
            controller.orderModel.value.isFreeDelivery == true)) ...[
          const SizedBox(height: 10),
          _buildDeliveryTipsRow(controller, isDark),
        ],
        sectionDivider(isDark),
        if (controller.orderModel.value.takeAway != true &&
            controller.orderModel.value.vendor?.isSelfDelivery != true)
          _buildTaxList(controller, 'driverDeliveryTax', isDark,
              taxLabel: 'Tax on Delivery Fee'),
        if (controller.orderModel.value.takeAway != true &&
            controller.orderModel.value.vendor?.isSelfDelivery != true)
          sectionDivider(isDark),
        amountRow(
          title: "To Pay".tr(),
          amount: Constant.amountShow(
              amount: controller.totalAmount.value.toString()),
          amountColor: AppThemeData.primary300,
          isDark: isDark,
        ),
      ],
    );
  }

  // Helper rows
  Widget _buildDeliveryFeeRow(OrderDetailsController controller, bool isDark) {
    final isFree = controller.orderModel.value.vendor?.isSelfDelivery == true ||
        controller.orderModel.value.isFreeDelivery == true;
    return amountRow(
      title: "Delivery Fee".tr(),
      isDark: isDark,
      trailing: isFree
          ? Text(
              'Free Delivery'.tr(),
              style: TextStyle(
                fontFamily: AppThemeData.regular,
                color: AppThemeData.success400,
                fontSize: 16,
              ),
            )
          : Text(
              Constant.amountShow(
                  amount: controller.deliveryCharges.value.toString()),
              style: TextStyle(
                fontFamily: AppThemeData.regular,
                color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                fontSize: 16,
              ),
            ),
      amount: '',
    );
  }

  Widget _buildDeliveryTipsRow(OrderDetailsController controller, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Delivery Tips".tr(),
                style: TextStyle(
                  fontFamily: AppThemeData.regular,
                  color: isDark ? AppThemeData.grey300 : AppThemeData.grey600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        Text(
          Constant.amountShow(amount: controller.deliveryTips.toString()),
          style: TextStyle(
            fontFamily: AppThemeData.regular,
            color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildTaxList(
      OrderDetailsController controller, String listKey, bool isDark,
      {String taxLabel = ''}) {
    final list = controller.orderModel.value.driverDeliveryTax ?? [];
    if (list.isEmpty) return const SizedBox();
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final tax = list[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: amountRow(
            title: "${tax.title} $taxLabel".tr(),
            amount: Constant.amountShow(
              amount: Constant.calculateTax(
                taxModel: tax,
                amount: controller.deliveryCharges.value.toString(),
              ).toString(),
            ),
            isDark: isDark,
          ),
        );
      },
    );
  }
}

// ---------------------------------- HELPERS ---------------------------------
Widget amountRow({
  required String title,
  required String amount,
  required bool isDark,
  Color? textColour,
  Color? amountColor,
  bool? underline,
  Widget? trailing,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Text(
          title.tr(),
          style: TextStyle(
            fontFamily: AppThemeData.regular,
            color: textColour ??
                (isDark ? AppThemeData.grey300 : AppThemeData.grey600),
            fontSize: 16,
            decoration: underline == true
                ? TextDecoration.underline
                : TextDecoration.none,
          ),
        ),
      ),
      trailing ??
          Text(
            amount,
            style: TextStyle(
              fontFamily: AppThemeData.regular,
              color: amountColor ??
                  (isDark ? AppThemeData.grey50 : AppThemeData.grey900),
              fontSize: 16,
            ),
          ),
    ],
  );
}

Widget sectionDivider(bool isDark) {
  return Column(
    children: [
      const SizedBox(height: 10),
      MySeparator(color: isDark ? AppThemeData.grey700 : AppThemeData.grey200),
      const SizedBox(height: 10),
    ],
  );
}

void showBillBifurcationDialog(
    BuildContext context, bool isDark, OrderDetailsController controller) {
  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
        insetPadding: const EdgeInsets.symmetric(horizontal: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width * 0.9,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Text(
                  "Tax Details".tr(),
                  style: TextStyle(
                    fontFamily: AppThemeData.medium,
                    fontSize: 18,
                    color: isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                  ),
                ),
                const SizedBox(height: 5),
                sectionDivider(isDark),
                const SizedBox(height: 5),
                if (controller.orderModel.value.taxScope == 'product')
                  amountRow(
                    title: "Tax on item total".tr(),
                    amount: Constant.amountShow(
                        amount: controller.productTaxAmount.value.toString()),
                    isDark: isDark,
                  )
                else
                  amountRow(
                    title: "Tax on Order Total".tr(),
                    amount: Constant.amountShow(
                        amount: controller.orderTaxAmount.value.toString()),
                    isDark: isDark,
                  ),
                sectionDivider(isDark),
                if (controller.orderModel.value.takeAway != true &&
                    controller.orderModel.value.vendor?.isSelfDelivery != true)
                  _buildTaxListDialog(controller, 'driverDeliveryTax', isDark,
                      label: 'Tax on Delivery Fee'),
                if (controller.orderModel.value.takeAway != true &&
                    controller.orderModel.value.vendor?.isSelfDelivery != true)
                  sectionDivider(isDark),
                _buildTaxListDialog(controller, 'packagingTax', isDark,
                    label: 'Tax on Packaging Fee',
                    amountGetter: () => controller.packagingCharge.value),
                sectionDivider(isDark),
                _buildTaxListDialog(controller, 'platformTax', isDark,
                    label: 'Tax on Platform Fee',
                    amountGetter: () => controller.platformFee.value),
                sectionDivider(isDark),
                amountRow(
                  title: "Total Tax Amount".tr(),
                  amount: Constant.amountShow(
                      amount: controller.totalTaxAmount.value.toString()),
                  amountColor: AppThemeData.primary300,
                  isDark: isDark,
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("Close".tr()),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Widget _buildTaxListDialog(
    OrderDetailsController controller, String listKey, bool isDark,
    {String label = '', double Function()? amountGetter}) {
  List? taxList;
  if (listKey == 'packagingTax')
    taxList = controller.orderModel.value.packagingTax;
  if (listKey == 'platformTax')
    taxList = controller.orderModel.value.platformTax;
  if (listKey == 'driverDeliveryTax')
    taxList = controller.orderModel.value.driverDeliveryTax;
  if (taxList == null || taxList.isEmpty) return const SizedBox();
  final amount = amountGetter != null ? amountGetter() : 0.0;
  return Column(
    children: taxList.map((tax) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: amountRow(
          title: "${tax.title} ${label.tr()}",
          amount: Constant.amountShow(
              amount: amount == 0.0
                  ? '0'
                  : Constant.calculateTax(
                          taxModel: tax, amount: amount.toString())
                      .toString()),
          isDark: isDark,
        ),
      );
    }).toList(),
  );
}

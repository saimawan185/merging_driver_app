import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:door_delights_driver/app/cab_screen/cab_order_details.dart';
import 'package:door_delights_driver/app/parcel_screen/parcel_order_details.dart';
import 'package:door_delights_driver/app/rental_service/rental_order_details_screen.dart';
import 'package:door_delights_driver/model/onePaySettingsModel.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:door_delights_driver/model/FlutterWaveSettingDataModel.dart';
import 'package:door_delights_driver/model/MercadoPagoSettingsModel.dart';
import 'package:door_delights_driver/model/PayFastSettingData.dart';
import 'package:door_delights_driver/model/PayStackSettingsModel.dart';
import 'package:door_delights_driver/model/getPaytmTxtToken.dart';
import 'package:door_delights_driver/model/payStackURLModel.dart';
import 'package:door_delights_driver/model/paypalSettingData.dart';
import 'package:door_delights_driver/model/paytmSettingData.dart';
import 'package:door_delights_driver/model/withdrawHistoryModel.dart';
import 'package:door_delights_driver/services/FirebaseHelper.dart';
import 'package:door_delights_driver/services/helper.dart';
import 'package:door_delights_driver/services/payStackScreen.dart';
import 'package:door_delights_driver/services/paystack_url_genrater.dart';
import 'package:door_delights_driver/services/show_toast_dialog.dart';
import 'package:door_delights_driver/ui/wallet/paymenturlscreen.dart';
import 'package:door_delights_driver/ui/wallet/PayFastScreen.dart';
import 'package:door_delights_driver/userPrefrence.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/instance_manager.dart';
import 'package:get/route_manager.dart';
// import 'package:flutter_paypal_native/flutter_paypal_native.dart';
// ... other imports omitted for brevity (keep as is)

import 'package:get/state_manager.dart';
import 'package:http/http.dart' as http;
// import 'package:mercadopago_sdk/mercadopago_sdk.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../constant/constant.dart';
import '../../constants.dart';
import '../../models/cab_order_model.dart';
import '../../models/order_model.dart';
import '../../models/parcel_order_model.dart';
import '../../models/rental_order_model.dart';
import '../../models/user_model.dart';
import '../../theme/app_them_data.dart';
import '../../theme/responsive.dart';
import '../../theme/round_button_fill.dart';
import '../../themes/text_field_widget.dart';
import '../../themes/theme_controller.dart';
import '../../widget/my_separator.dart';
import 'card_management_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({Key? key}) : super(key: key);

  @override
  WalletScreenState createState() => WalletScreenState();
}

class WalletScreenState extends State<WalletScreen> {
  static FirebaseFirestore fireStore = FirebaseFirestore.instance;
  Stream<QuerySnapshot>? withdrawalHistoryQuery;
  Stream<QuerySnapshot>? dailyEarningQuery;
  Stream<QuerySnapshot>? monthlyEarningQuery;
  Stream<QuerySnapshot>? yearlyEarningQuery;

  Stream<DocumentSnapshot<Map<String, dynamic>>>? userQuery;

  String? selectedRadioTile;

  GlobalKey<FormState> _globalKey = GlobalKey();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  TextEditingController _amountController =
      TextEditingController(text: 110.toString());
  TextEditingController _noteController = TextEditingController(text: '');

  getData() async {
    try {
      userQuery = fireStore.collection(USERS).doc(userId).snapshots();
    } catch (e) {
      print(e);
    }

    withdrawalHistoryQuery = fireStore
        .collection(driverPayouts)
        .where('driverID', isEqualTo: userId)
        .orderBy('paidDate', descending: true)
        .snapshots();

    DateTime nowDate = DateTime.now();
    log("Service: ${Constant.userModel!.serviceType}");
    // Use serviceType (singular) for all checks
    if (Constant.userModel!.serviceType == "cab-service") {
      dailyEarningQuery = fireStore
          .collection(RIDESORDER)
          .where('driverID', isEqualTo: driverId)
          // .where('createdAt',
          //     isGreaterThanOrEqualTo: Timestamp.fromDate(
          //         DateTime(nowDate.year, nowDate.month, nowDate.day)))
          .orderBy('createdAt', descending: true)
          .snapshots();

      monthlyEarningQuery = fireStore
          .collection(RIDESORDER)
          .where('driverID', isEqualTo: driverId)
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(
                nowDate.year,
                nowDate.month,
              )))
          .orderBy('createdAt', descending: true)
          .snapshots();

      yearlyEarningQuery = fireStore
          .collection(RIDESORDER)
          .where('driverID', isEqualTo: driverId)
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(
                nowDate.year,
              )))
          .orderBy('createdAt', descending: true)
          .snapshots();
    } else if (Constant.userModel!.serviceType == "parcel_delivery") {
      dailyEarningQuery = fireStore
          .collection(PARCELORDER)
          .where('driverId', isEqualTo: driverId)
          // .where('createdAt',
          //     isGreaterThanOrEqualTo: Timestamp.fromDate(
          //         DateTime(nowDate.year, nowDate.month, nowDate.day)))
          .orderBy('createdAt', descending: true)
          .snapshots();

      monthlyEarningQuery = fireStore
          .collection(PARCELORDER)
          .where('driverID', isEqualTo: driverId)
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(
                nowDate.year,
                nowDate.month,
              )))
          .orderBy('createdAt', descending: true)
          .snapshots();

      yearlyEarningQuery = fireStore
          .collection(PARCELORDER)
          .where('driverID', isEqualTo: driverId)
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(
                nowDate.year,
              )))
          .orderBy('createdAt', descending: true)
          .snapshots();
    } else if (Constant.userModel!.serviceType == "rental-service") {
      dailyEarningQuery = fireStore
          .collection(RENTALORDER)
          .where('driverID', isEqualTo: driverId)
          // .where('createdAt',
          //     isGreaterThanOrEqualTo: Timestamp.fromDate(
          //         DateTime(nowDate.year, nowDate.month, nowDate.day)))
          .orderBy('createdAt', descending: true)
          .snapshots();

      monthlyEarningQuery = fireStore
          .collection(RENTALORDER)
          .where('driverID', isEqualTo: driverId)
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(
                nowDate.year,
                nowDate.month,
              )))
          .orderBy('createdAt', descending: true)
          .snapshots();

      yearlyEarningQuery = fireStore
          .collection(RENTALORDER)
          .where('driverID', isEqualTo: driverId)
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(
                nowDate.year,
              )))
          .orderBy('createdAt', descending: true)
          .snapshots();
    } else {
      // default: delivery-service
      dailyEarningQuery = fireStore
          .collection(ORDERS)
          .where('driverID', isEqualTo: driverId)
          // .where('createdAt',
          //     isGreaterThanOrEqualTo: Timestamp.fromDate(
          //         DateTime(nowDate.year, nowDate.month, nowDate.day)))
          .orderBy('createdAt', descending: true)
          .snapshots();

      monthlyEarningQuery = fireStore
          .collection(ORDERS)
          .where('driverID', isEqualTo: driverId)
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(
                nowDate.year,
                nowDate.month,
              )))
          .orderBy('createdAt', descending: true)
          .snapshots();

      yearlyEarningQuery = fireStore
          .collection(ORDERS)
          .where('driverID', isEqualTo: driverId)
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(
                nowDate.year,
              )))
          .orderBy('createdAt', descending: true)
          .snapshots();
    }
  }

  Map<String, dynamic>? paymentIntentData;

  showAlert(context, {required String response, required Color colors}) {
    return ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(response),
      backgroundColor: colors,
      duration: Duration(seconds: 8),
    ));
  }

  final userId = Constant.userModel!.id!;
  final driverId = Constant.userModel!.id; //'8BBDG88lB4dqRaCcLIhdonuwQtU2';
  UserBankDetails? userBankDetail = Constant.userModel!.userBankDetails;
  String walletAmount = "0.0";

  paymentCompleted({required String paymentMethod}) async {
    await FireStoreUtils.createPaymentId().then((value) async {
      final paymentID = value;
      await FireStoreUtils.topUpWalletAmount(
              paymentMethod: paymentMethod,
              amount: double.parse(_amountController.text),
              id: paymentID,
              userID: Constant.userModel!.id!)
          .then((value) {
        FireStoreUtils.updateWalletAmount(
                userId: userId, amount: double.parse(_amountController.text))
            .then((value) {
          FireStoreUtils.sendTopUpMail(
              paymentMethod: paymentMethod,
              amount: _amountController.text,
              tractionId: paymentID);
          ScaffoldMessenger.of(_scaffoldKey.currentContext!)
              .showSnackBar(SnackBar(
            content: Text("Payment Successful!!".tr() + "\n"),
            backgroundColor: Colors.green,
          ));
        });
      });
    });
  }

  @override
  void initState() {
    getData();
    getPaymentSettingData();
    selectedRadioTile = "Stripe";

    // _razorPay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    // _razorPay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWaller);
    // _razorPay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    super.initState();
  }

  Stream<QuerySnapshot>? topupHistoryQuery;
  // Razorpay _razorPay = Razorpay();
  // RazorPayModel? razorPayData;
  PaytmSettingData? paytmSettingData;
  PaypalSettingData? paypalSettingData;
  PayStackSettingData? payStackSettingData;
  FlutterWaveSettingData? flutterWaveSettingData;
  PayFastSettingData? payFastSettingData;
  MercadoPagoSettingData? mercadoPagoSettingData;
  OnePaySettingData? onePaySettingData;

  getPaymentSettingData() async {
    topupHistoryQuery = fireStore
        .collection(Wallet)
        .where('user_id', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots();
    userQuery =
        fireStore.collection(USERS).doc(Constant.userModel!.id).snapshots();

    // razorPayData = await UserPreference.getRazorPayData();
    onePaySettingData = await UserPreference.getOnePayData();
    paytmSettingData = await UserPreference.getPaytmData();
    paypalSettingData = await UserPreference.getPayPalData();
    payStackSettingData = await UserPreference.getPayStackData();
    flutterWaveSettingData = await UserPreference.getFlutterWaveData();
    payFastSettingData = await UserPreference.getPayFastData();
    mercadoPagoSettingData = await UserPreference.getMercadoPago();
    print("onePaySettingData ::  ${onePaySettingData?.appId.toString()}");
    // setRef();
    // initPayPal();
    // await UserPreference.getStripeData().then((value) async {
    //   stripeData = value;
    //   if (stripeData?.clientpublishableKey != '') {
    //     stripe1.Stripe.publishableKey = stripeData!.clientpublishableKey;
    //     stripe1.Stripe.merchantIdentifier = 'DoorDelights Driver App';
    //     await stripe1.Stripe.instance.applySettings();
    //   }
    // });
  }

  // final _flutterPaypalNativePlugin = FlutterPaypalNative.instance;

  // void initPayPal() async {
  //   //set debugMode for error logging
  //   FlutterPaypalNative.isDebugMode =
  //       paypalSettingData!.isLive == false ? true : false;
  //   //initiate payPal plugin
  //   await _flutterPaypalNativePlugin.init(
  //     returnUrl: "com.doordelights.rider://paypalpay",
  //     clientID: paypalSettingData!.paypalClient,
  //     payPalEnvironment: paypalSettingData!.isLive == true
  //         ? FPayPalEnvironment.live
  //         : FPayPalEnvironment.sandbox,
  //     currencyCode: FPayPalCurrencyCode.usd,
  //     action: FPayPalUserAction.payNow,
  //   );

  //   //call backs for payment
  //   _flutterPaypalNativePlugin.setPayPalOrderCallback(
  //     callback: FPayPalOrderCallback(
  //       onCancel: () {
  //         //user canceled the payment
  //         Navigator.pop(context);
  //         ShowToastDialog.showToast("Payment canceled");
  //       },
  //       onSuccess: (data) {
  //         //successfully paid
  //         //remove all items from queue
  //         Navigator.pop(context);
  //         _flutterPaypalNativePlugin.removeAllPurchaseItems();
  //         ShowToastDialog.showToast("Payment Successfully");
  //         paymentCompleted(paymentMethod: "Paypal");
  //       },
  //       onError: (data) {
  //         //an error occured
  //         Navigator.pop(context);
  //         ShowToastDialog.showToast("error: ${data.reason}");
  //       },
  //       onShippingChange: (data) {
  //         //the user updated the shipping address
  //         Navigator.pop(context);
  //         ShowToastDialog.showToast(
  //             "shipping change: ${data.shippingChangeAddress?.adminArea1 ?? ""}");
  //       },
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      body: Container(
        color: Colors.black.withOpacity(0.03),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Container(
                width: Responsive.width(100, context),
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                  image: DecorationImage(
                    image: AssetImage("assets/images/earning_bg_@3x.png"),
                    fit: BoxFit.fill,
                  ),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Column(
                    children: [
                      Text(
                        "My Wallet".tr(),
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 18),
                      ),
                      const SizedBox(height: 10),
                      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: userQuery,
                        builder: (context,
                            AsyncSnapshot<
                                    DocumentSnapshot<Map<String, dynamic>>>
                                asyncSnapshot) {
                          if (asyncSnapshot.hasError) {
                            return Text(
                              "error".tr(),
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 30),
                            );
                          }
                          if (asyncSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Center(
                              child: SizedBox(
                                height: 30,
                                width: 30,
                                child: CircularProgressIndicator(
                                  strokeWidth: 0.8,
                                  color: Colors.white,
                                  backgroundColor: Colors.transparent,
                                ),
                              ),
                            );
                          }
                          UserModel userData =
                              UserModel.fromJson(asyncSnapshot.data!.data()!);
                          walletAmount = userData.walletAmount.toString();
                          return Text(
                            "${amountShow(amount: userData.walletAmount.toString())}",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 28),
                          );
                        },
                      ),
                      const SizedBox(
                        height: 20,
                      ),
                      buildTopUpButton(),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            tabController(),
          ],
        ),
      ),
      // bottomNavigationBar: Padding(
      //   padding: const EdgeInsets.only(bottom: 10, top: 5),
      //   child: Constant.userModel!.serviceType == "rental-service" ||
      //           Constant.userModel!.serviceType == "cab-service"
      //       ? Row(
      //           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      //           children: [
      //             buildButton(context, width: 0.32, title: 'WITHDRAW'.tr(),
      //                 onPress: () {
      //               if (Constant.userModel!.userBankDetails != null &&
      //                   Constant.userModel!.userBankDetails!.accountNumber
      //                       .isNotEmpty) {
      //                 withdrawAmountBottomSheet(context);
      //               } else {
      //                 final snackBar = SnackBar(
      //                   backgroundColor: Colors.red[400],
      //                   content: Text(
      //                     'Please add your Bank Details first'.tr(),
      //                   ),
      //                 );
      //                 ScaffoldMessenger.of(context).showSnackBar(snackBar);
      //               }
      //             }),
      //             buildTransButton(context,
      //                 width: 0.55,
      //                 title: 'WITHDRAWAL HISTORY'.tr(), onPress: () {
      //               if (Constant.userModel!.userBankDetails != null &&
      //                   Constant.userModel!.userBankDetails!.accountNumber
      //                       .isNotEmpty) {
      //                 withdrawalHistoryBottomSheet(context);
      //               } else {
      //                 final snackBar = SnackBar(
      //                   backgroundColor: Colors.red[400],
      //                   content: Text(
      //                     'Please add your Bank Details first'.tr(),
      //                   ),
      //                 );
      //                 ScaffoldMessenger.of(context).showSnackBar(snackBar);
      //               }
      //             }),
      //           ],
      //         )
      //       : Row(
      //           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      //           children: [
      //             buildButton(context, width: 0.32, title: 'WITHDRAW'.tr(),
      //                 onPress: () {
      //               if (Constant.userModel!.userBankDetails != null &&
      //                   Constant.userModel!.userBankDetails!.accountNumber
      //                       .isNotEmpty) {
      //                 withdrawAmountBottomSheet(context);
      //               } else {
      //                 final snackBar = SnackBar(
      //                   backgroundColor: Colors.red[400],
      //                   content: Text(
      //                     'Please add your Bank Details first'.tr(),
      //                   ),
      //                 );
      //                 ScaffoldMessenger.of(context).showSnackBar(snackBar);
      //               }
      //             }),
      //             buildTransButton(context,
      //                 width: 0.55,
      //                 title: 'WITHDRAWAL HISTORY'.tr(), onPress: () {
      //               if (Constant.userModel!.userBankDetails != null &&
      //                   Constant.userModel!.userBankDetails!.accountNumber
      //                       .isNotEmpty) {
      //                 withdrawalHistoryBottomSheet(context);
      //               } else {
      //                 final snackBar = SnackBar(
      //                   backgroundColor: Colors.red[400],
      //                   content: Text(
      //                     'Please add your Bank Details first'.tr(),
      //                   ),
      //                 );
      //                 ScaffoldMessenger.of(context).showSnackBar(snackBar);
      //               }
      //             }),
      //           ],
      //         ),
      // ),
    );
  }

  Widget buildTopUpButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: RoundedButtonFill(
              title: "Withdraw".tr(),
              width: 24,
              height: 5.5,
              color: AppThemeData.grey50,
              textColor: AppThemeData.grey900,
              borderRadius: 200,
              onPress: () {
                if (Constant.userModel!.userBankDetails != null &&
                    Constant
                        .userModel!.userBankDetails!.accountNumber.isNotEmpty) {
                  withdrawAmountBottomSheet(context);
                } else {
                  final snackBar = SnackBar(
                    backgroundColor: Colors.red[400],
                    content: Text(
                      'Please add your Bank Details first'.tr(),
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                }
                // Navigator.push(context,
                //     MaterialPageRoute(builder: (context) => TopUpScreen()));
              },
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: RoundedButtonFill(
              title: "Top up".tr(),
              width: 24,
              height: 5.5,
              borderRadius: 200,
              color: AppThemeData.primary300,
              textColor: AppThemeData.grey50,
              onPress: () {
                topUpBalance();
              },
            ),
            //  GestureDetector(
            //   onTap: () {
            //     topUpBalance();
            //   },
            //   child: Container(
            //     decoration: BoxDecoration(
            //       color: Colors.white,
            //       borderRadius: BorderRadius.circular(32),
            //     ),
            //     child: Padding(
            //       padding: const EdgeInsets.symmetric(
            //           horizontal: 18.0, vertical: 10),
            //       child: Text(
            //         "Top up".tr(),
            //         style: TextStyle(
            //             color: Color(DARK_CARD_BG_COLOR),
            //             fontWeight: FontWeight.w700,
            //             fontSize: 16),
            //       ),
            //     ),
            //   ),
            // ),
          ),
        ],
      ),
    );
  }

  bool stripe = true;

  bool razorPay = false;
  bool payTm = false;
  bool paypal = false;
  bool payStack = false;
  bool flutterWave = false;
  bool payFast = false;
  bool mercadoPago = false;
  bool onePay = false;

  topUpBalance() {
    final size = MediaQuery.sizeOf(context);
    final isDark = Get.find<ThemeController>().isDark.value;

    return showModalBottomSheet(
        elevation: 5,
        enableDrag: true,
        useRootNavigator: true,
        isScrollControlled: true,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(15), topRight: Radius.circular(15))),
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) => Container(
              //height: size.height * 0.85,
              width: size.width,
              height: size.height * 0.95,
              child: Form(
                key: _globalKey,
                autovalidateMode: AutovalidateMode.always,
                child: SingleChildScrollView(
                  physics: BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10.0),
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 15.0,
                              ),
                              child: RichText(
                                text: TextSpan(
                                  text: "Topup Wallet".tr(),
                                  style: TextStyle(
                                    fontSize: 20,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20.0, vertical: 5),
                            child: RichText(
                              text: TextSpan(
                                text: "Add Topup Amount".tr(),
                                style: TextStyle(
                                    fontSize: 16,
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.black54),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20.0, vertical: 2),
                        child: Card(
                          elevation: 2.0,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 0.0, horizontal: 8),
                            child: TextFormField(
                              controller: _amountController,
                              style: TextStyle(
                                color: Color(COLOR_PRIMARY),
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                              //initialValue:"50",
                              maxLines: 1,
                              validator: (value) {
                                if (value!.isEmpty) {
                                  return "*required Field".tr();
                                } else {
                                  return null;
                                }
                              },
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                prefix: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12.0, vertical: 2),
                                  child: Text(
                                    currencyData!.symbol.toString(),
                                    style: TextStyle(
                                      color: Colors.blueGrey.shade900,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20.0, vertical: 5),
                            child: RichText(
                              text: TextSpan(
                                text: "Select Payment Option".tr(),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Visibility(
                        visible: onePaySettingData != null &&
                            onePaySettingData!.isEnabled,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 3.0, horizontal: 20),
                          child: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: onePay ? 0 : 2,
                            child: RadioListTile(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                      color: onePay
                                          ? Color(COLOR_PRIMARY)
                                          : Colors.transparent)),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              controlAffinity: ListTileControlAffinity.trailing,
                              value: "Card",
                              groupValue: selectedRadioTile,
                              onChanged: (String? value) {
                                setState(() {
                                  stripe = false;
                                  payTm = false;
                                  mercadoPago = false;
                                  flutterWave = false;
                                  razorPay = false;
                                  paypal = false;
                                  payFast = false;
                                  payStack = false;
                                  onePay = true;
                                  selectedRadioTile = value!;
                                });
                              },
                              selected: onePay,
                              //selectedRadioTile == "strip" ? true : false,
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Container(
                                      decoration: BoxDecoration(
                                        color: Colors.blueGrey.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 3.0, horizontal: 10),
                                          child: Icon(
                                            Icons.credit_card,
                                            color: Color(COLOR_PRIMARY),
                                          ))),
                                  SizedBox(
                                    width: 20,
                                  ),
                                  Text("Card"),
                                ],
                              ),
                              //toggleable: true,
                            ),
                          ),
                        ),
                      ),
                      // Visibility(
                      //   visible: stripeData!.isEnabled,
                      //   child: Padding(
                      //     padding: const EdgeInsets.symmetric(
                      //         vertical: 3.0, horizontal: 20),
                      //     child: Card(
                      //       shape: RoundedRectangleBorder(
                      //         borderRadius: BorderRadius.circular(8),
                      //       ),
                      //       elevation: stripe ? 0 : 2,
                      //       child: RadioListTile(
                      //         shape: RoundedRectangleBorder(
                      //             borderRadius: BorderRadius.circular(8),
                      //             side: BorderSide(
                      //                 color: stripestrip
                      //                     ? Color(COLOR_PRIMARY)
                      //                     : Colors.transparent)),
                      //         controlAffinity: ListTileControlAffinity.trailing,
                      //         value: "Stripe",
                      //         groupValue: selectedRadioTile,
                      //         onChanged: (String? value) {
                      //           setState(() {
                      //             onePay = false;
                      //             flutterWave = false;
                      //             stripe = true;
                      //             mercadoPago = false;
                      //             payFast = false;
                      //             payStack = false;
                      //             razorPay = false;
                      //             payTm = false;
                      //             paypal = false;
                      //             selectedRadioTile = value!;
                      //           });
                      //         },
                      //         selected: stripe,
                      //         //selectedRadioTile == "strip" ? true : false,
                      //         contentPadding: EdgeInsets.symmetric(
                      //           horizontal: 6,
                      //         ),
                      //         title: Row(
                      //           mainAxisAlignment: MainAxisAlignment.start,
                      //           children: [
                      //             Container(
                      //                 decoration: BoxDecoration(
                      //                   color: Colors.blueGrey.shade50,
                      //                   borderRadius: BorderRadius.circular(8),
                      //                 ),
                      //                 child: Padding(
                      //                   padding: const EdgeInsets.symmetric(
                      //                       vertical: 4.0, horizontal: 10),
                      //                   child: SizedBox(
                      //                     width: 80,
                      //                     height: 35,
                      //                     child: Padding(
                      //                       padding: const EdgeInsets.symmetric(
                      //                           vertical: 6.0),
                      //                       child: Image.asset(
                      //                         "assets/images/stripe.png",
                      //                       ),
                      //                     ),
                      //                   ),
                      //                 )),
                      //             SizedBox(
                      //               width: 20,
                      //             ),
                      //             Text("Stripe"),
                      //           ],
                      //         ),
                      //         //toggleable: true,
                      //       ),
                      //     ),
                      //   ),
                      // ),

                      Visibility(
                        visible: payStackSettingData!.isEnabled,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 3.0, horizontal: 20),
                          child: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: payStack ? 0 : 2,
                            child: RadioListTile(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                      color: payStack
                                          ? Color(COLOR_PRIMARY)
                                          : Colors.transparent)),
                              controlAffinity: ListTileControlAffinity.trailing,
                              value: "PayStack",
                              groupValue: selectedRadioTile,
                              onChanged: (String? value) {
                                setState(() {
                                  onePay = false;
                                  flutterWave = false;
                                  payStack = true;
                                  mercadoPago = false;
                                  stripe = false;
                                  payFast = false;
                                  razorPay = false;
                                  payTm = false;
                                  paypal = false;
                                  selectedRadioTile = value!;
                                });
                              },
                              selected: payStack,
                              //selectedRadioTile == "strip" ? true : false,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Container(
                                      decoration: BoxDecoration(
                                        color: Colors.blueGrey.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 4.0, horizontal: 10),
                                        child: SizedBox(
                                          width: 80,
                                          height: 35,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 6.0),
                                            child: Image.asset(
                                              "assets/images/paystack.png",
                                            ),
                                          ),
                                        ),
                                      )),
                                  SizedBox(
                                    width: 20,
                                  ),
                                  Text("PayStack".tr()),
                                ],
                              ),
                              //toggleable: true,
                            ),
                          ),
                        ),
                      ),
                      Visibility(
                        visible: flutterWaveSettingData != null &&
                            flutterWaveSettingData!.isEnable,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 3.0, horizontal: 20),
                          child: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: flutterWave ? 0 : 2,
                            child: RadioListTile(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                      color: flutterWave
                                          ? Color(COLOR_PRIMARY)
                                          : Colors.transparent)),
                              controlAffinity: ListTileControlAffinity.trailing,
                              value: "FlutterWave",
                              groupValue: selectedRadioTile,
                              onChanged: (String? value) {
                                setState(() {
                                  onePay = false;
                                  flutterWave = true;
                                  payStack = false;
                                  mercadoPago = false;
                                  payFast = false;
                                  stripe = false;
                                  razorPay = false;
                                  payTm = false;
                                  paypal = false;
                                  selectedRadioTile = value!;
                                });
                              },
                              selected: flutterWave,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Container(
                                      decoration: BoxDecoration(
                                        color: Colors.blueGrey.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 4.0, horizontal: 10),
                                        child: SizedBox(
                                          width: 80,
                                          height: 35,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 6.0),
                                            child: Image.asset(
                                              "assets/images/flutterwave.png",
                                            ),
                                          ),
                                        ),
                                      )),
                                  SizedBox(
                                    width: 20,
                                  ),
                                  Text("FlutterWave".tr()),
                                ],
                              ),
                              //toggleable: true,
                            ),
                          ),
                        ),
                      ),
                      // Visibility(
                      //   visible: razorPayData!.isEnabled,
                      //   child: Padding(
                      //     padding: const EdgeInsets.symmetric(
                      //         vertical: 3.0, horizontal: 20),
                      //     child: Card(
                      //       shape: RoundedRectangleBorder(
                      //         borderRadius: BorderRadius.circular(8),
                      //       ),
                      //       elevation: razorPay ? 0 : 2,
                      //       child: RadioListTile(
                      //         //toggleable: true,
                      //         shape: RoundedRectangleBorder(
                      //             borderRadius: BorderRadius.circular(8),
                      //             side: BorderSide(
                      //                 color: razorPay
                      //                     ? Color(COLOR_PRIMARY)
                      //                     : Colors.transparent)),
                      //         contentPadding: EdgeInsets.symmetric(
                      //           horizontal: 6,
                      //         ),
                      //         controlAffinity: ListTileControlAffinity.trailing,
                      //         value: "RazorPay",
                      //         groupValue: selectedRadioTile,
                      //         onChanged: (String? value) {
                      //           setState(() {
                      //             onePay = false;
                      //             mercadoPago = false;
                      //             flutterWave = false;
                      //             stripe = false;
                      //             razorPay = true;
                      //             payTm = false;
                      //             payFast = false;
                      //             paypal = false;
                      //             payStack = false;
                      //             selectedRadioTile = value!;
                      //           });
                      //         },
                      //         selected: razorPay,
                      //         //selectedRadioTile == "strip" ? true : false,
                      //         title: Row(
                      //           mainAxisAlignment: MainAxisAlignment.start,
                      //           children: [
                      //             Container(
                      //                 decoration: BoxDecoration(
                      //                   color: Colors.blueGrey.shade50,
                      //                   borderRadius: BorderRadius.circular(8),
                      //                 ),
                      //                 child: Padding(
                      //                   padding: const EdgeInsets.symmetric(
                      //                       vertical: 3.0, horizontal: 10),
                      //                   child: SizedBox(
                      //                       width: 80,
                      //                       height: 35,
                      //                       child: Image.asset(
                      //                           "assets/images/razorpay_@3x.png")),
                      //                 )),
                      //             SizedBox(
                      //               width: 20,
                      //             ),
                      //             Text("RazorPay").tr(),
                      //           ],
                      //         ),
                      //         //toggleable: true,
                      //       ),
                      //     ),
                      //   ),
                      // ),

                      Visibility(
                        visible: payFastSettingData != null &&
                            payFastSettingData!.isEnable,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 4.0, horizontal: 20),
                          child: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: payFast ? 0 : 2,
                            child: RadioListTile(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                      color: payFast
                                          ? Color(COLOR_PRIMARY)
                                          : Colors.transparent)),
                              controlAffinity: ListTileControlAffinity.trailing,
                              value: "payFast",
                              groupValue: selectedRadioTile,
                              onChanged: (String? value) {
                                setState(() {
                                  onePay = false;
                                  payFast = true;
                                  stripe = false;
                                  mercadoPago = false;
                                  razorPay = false;
                                  payStack = false;
                                  flutterWave = false;
                                  payTm = false;
                                  paypal = false;
                                  selectedRadioTile = value!;
                                });
                              },
                              selected: payFast,
                              //selectedRadioTile == "strip" ? true : false,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Container(
                                      decoration: BoxDecoration(
                                        color: Colors.blueGrey.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 4.0, horizontal: 10),
                                        child: SizedBox(
                                          width: 80,
                                          height: 35,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 6.0),
                                            child: Image.asset(
                                              "assets/images/payfast.png",
                                            ),
                                          ),
                                        ),
                                      )),
                                  SizedBox(
                                    width: 20,
                                  ),
                                  Text("Pay Fast"),
                                ],
                              ),
                              //toggleable: true,
                            ),
                          ),
                        ),
                      ),
                      Visibility(
                        visible: paytmSettingData!.isEnabled,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 3.0, horizontal: 20),
                          child: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: payTm ? 0 : 2,
                            child: RadioListTile(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                      color: payTm
                                          ? Color(COLOR_PRIMARY)
                                          : Colors.transparent)),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              controlAffinity: ListTileControlAffinity.trailing,
                              value: "PayTm",
                              groupValue: selectedRadioTile,
                              onChanged: (String? value) {
                                setState(() {
                                  onePay = false;
                                  stripe = false;
                                  flutterWave = false;
                                  payTm = true;
                                  mercadoPago = false;
                                  razorPay = false;
                                  paypal = false;
                                  payFast = false;
                                  payStack = false;
                                  selectedRadioTile = value!;
                                });
                              },
                              selected: payTm,
                              //selectedRadioTile == "strip" ? true : false,
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Container(
                                      decoration: BoxDecoration(
                                        color: Colors.blueGrey.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 3.0, horizontal: 10),
                                        child: SizedBox(
                                            width: 80,
                                            height: 35,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 3.0),
                                              child: Image.asset(
                                                "assets/images/paytm_@3x.png",
                                              ),
                                            )),
                                      )),
                                  SizedBox(
                                    width: 20,
                                  ),
                                  Text("Paytm"),
                                ],
                              ),
                              //toggleable: true,
                            ),
                          ),
                        ),
                      ),
                      Visibility(
                        visible: mercadoPagoSettingData != null &&
                            mercadoPagoSettingData!.isEnabled,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 4.0, horizontal: 20),
                          child: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: mercadoPago ? 0 : 2,
                            child: RadioListTile(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                      color: mercadoPago
                                          ? Color(COLOR_PRIMARY)
                                          : Colors.transparent)),
                              controlAffinity: ListTileControlAffinity.trailing,
                              value: "MercadoPago",
                              groupValue: selectedRadioTile,
                              onChanged: (String? value) {
                                setState(() {
                                  onePay = false;
                                  mercadoPago = true;
                                  payFast = false;
                                  stripe = false;
                                  razorPay = false;
                                  payStack = false;
                                  flutterWave = false;
                                  payTm = false;
                                  paypal = false;
                                  selectedRadioTile = value!;
                                });
                              },
                              selected: mercadoPago,
                              //selectedRadioTile == "strip" ? true : false,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Container(
                                      decoration: BoxDecoration(
                                        color: Colors.blueGrey.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 4.0, horizontal: 10),
                                        child: SizedBox(
                                          width: 80,
                                          height: 35,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 6.0),
                                            child: Image.asset(
                                              "assets/images/mercadopago.png",
                                            ),
                                          ),
                                        ),
                                      )),
                                  SizedBox(
                                    width: 20,
                                  ),
                                  Text("Mercado Pago"),
                                ],
                              ),
                              //toggleable: true,
                            ),
                          ),
                        ),
                      ),
                      Visibility(
                        visible: paypalSettingData != null &&
                            paypalSettingData!.isEnabled,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 3.0, horizontal: 20),
                          child: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: paypal ? 0 : 2,
                            child: RadioListTile(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                      color: paypal
                                          ? Color(COLOR_PRIMARY)
                                          : Colors.transparent)),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              controlAffinity: ListTileControlAffinity.trailing,
                              value: "PayPal",
                              groupValue: selectedRadioTile,
                              onChanged: (String? value) {
                                setState(() {
                                  onePay = false;
                                  stripe = false;
                                  payTm = false;
                                  mercadoPago = false;
                                  flutterWave = false;
                                  razorPay = false;
                                  paypal = true;
                                  payFast = false;
                                  payStack = false;
                                  selectedRadioTile = value!;
                                });
                              },
                              selected: paypal,
                              //selectedRadioTile == "strip" ? true : false,
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Container(
                                      decoration: BoxDecoration(
                                        color: Colors.blueGrey.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 3.0, horizontal: 10),
                                        child: SizedBox(
                                            width: 80,
                                            height: 35,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 3.0),
                                              child: Image.asset(
                                                  "assets/images/paypal_@3x.png"),
                                            )),
                                      )),
                                  SizedBox(
                                    width: 20,
                                  ),
                                  Text("PayPal"),
                                ],
                              ),
                              //toggleable: true,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12.0, horizontal: 22),
                        child: GestureDetector(
                          onTap: () async {
                            await FireStoreUtils.createPaymentId();

                            // if (selectedRadioTile == "Stripe" &&
                            //     stripeData?.isEnabled == true) {
                            //   Navigator.pop(context);
                            //   showLoadingAlert();
                            //   // stripeMakePayment(amount: _amountController.text);
                            //   //push(context, CardDetailsScreen(paymentMode: selectedRadioTile,),);
                            // } else

                            if (selectedRadioTile == 'Card') {
                              Navigator.pop(context);
                              // showLoadingAlert();
                              _onePayPayment();
                            } else if (selectedRadioTile == "MercadoPago") {
                              Navigator.pop(context);
                              showLoadingAlert();
                              mercadoPagoMakePayment();
                            } else if (selectedRadioTile == "payFast") {
                              showLoadingAlert();
                              PayStackURLGen.getPayHTML(
                                      payFastSettingData: payFastSettingData!,
                                      amount: _amountController.text)
                                  .then((value) async {
                                bool isDone = await Navigator.of(context)
                                    .push(MaterialPageRoute(
                                        builder: (context) => PayFastScreen(
                                              htmlData: value,
                                              payFastSettingData:
                                                  payFastSettingData!,
                                            )));
                                if (isDone) {
                                  Navigator.pop(context);
                                  Navigator.pop(context);
                                  paymentCompleted(paymentMethod: "payFast");
                                } else {
                                  Navigator.pop(context);
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                    content: Text(
                                      "Payment Unsuccessful!!".tr() + "\n",
                                    ),
                                    backgroundColor: Colors.red.shade400,
                                    duration: Duration(seconds: 6),
                                  ));
                                }
                              });
                            }
                            //  else if (selectedRadioTile == "RazorPay") {
                            //   Navigator.pop(context);
                            //   showLoadingAlert();
                            //   RazorPayController()
                            //       .createOrderRazorPay(
                            //           amount: int.parse(_amountController.text))
                            //       .then((value) {
                            //     if (value != null) {
                            //       CreateRazorPayOrderModel result = value;
                            //       print("RAZORPAY");
                            //       print(value);

                            //       openCheckout(
                            //         amount: _amountController.text,
                            //         orderId: result.id,
                            //       );
                            //     } else {
                            //       Navigator.pop(context);
                            //       showAlert(_globalKey.currentContext!,
                            //           response:
                            //               "Something went wrong, please contact admin."
                            //                   .tr(),
                            //           colors: Colors.red);
                            //     }
                            //   });
                            // }
                            else if (selectedRadioTile == "PayTm") {
                              Navigator.pop(context);
                              showLoadingAlert();
                              getPaytmCheckSum(context,
                                  amount: double.parse(_amountController.text));
                            } else if (selectedRadioTile == "PayPal") {
                              Navigator.pop(context);
                              showLoadingAlert();
                              //_paypalPayment();
                              // paypalPaymentSheet();
                            } else if (selectedRadioTile == "PayStack") {
                              Navigator.pop(context);
                              showLoadingAlert();
                              payStackPayment();
                            } else if (selectedRadioTile == "FlutterWave") {
                              _flutterWaveInitiatePayment(context);
                            }
                          },
                          child: Container(
                            height: 45,
                            decoration: BoxDecoration(
                              color: Color(COLOR_PRIMARY),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                                child: Text(
                              "CONTINUE".tr(),
                              style: TextStyle(color: Colors.white),
                            )),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        });
  }

  ///FlutterWave Payment Method
  // String? _ref;

  // setRef() {
  //   Random numRef = Random();
  //   int year = DateTime.now().year;
  //   int refNumber = numRef.nextInt(20000);
  //   if (Platform.isAndroid) {
  //     setState(() {
  //       _ref = "AndroidRef$year$refNumber";
  //     });
  //   } else if (Platform.isIOS) {
  //     setState(() {
  //       _ref = "IOSRef$year$refNumber";
  //     });
  //   }
  // }

  _onePayPayment() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CardManagementScreen(
          amount: double.parse(_amountController.text).toStringAsFixed(2),
          onePaySettingData: onePaySettingData,
          onPaymentSuccess: (success) {
            if (success) {
              hideProgress();
              paymentCompleted(paymentMethod: "Card");
            } else {
              hideProgress();
            }
            return success;
          },
        ),
      ),
    );
  }

  _flutterWaveInitiatePayment(
    BuildContext context,
  ) async {
    // final flutterwave = Flutterwave(
    //   amount: _amountController.text.toString().trim(),
    //   currency: currencyData!.code,
    //   customer: Customer(
    //       name: Constant.userModel!.firstName,
    //       phoneNumber: Constant.userModel!.phoneNumber.trim(),
    //       email: Constant.userModel!.email.trim()),
    //   context: context,
    //   publicKey: flutterWaveSettingData!.publicKey.trim(),
    //   paymentOptions: "card, payattitude",
    //   customization: Customization(title: "DoorDelights Driver App"),
    //   txRef: _ref!,
    //   redirectUrl: '${GlobalURL}success',
    //   isTestMode: flutterWaveSettingData!.isSandbox,
    // );
    // final ChargeResponse response = await flutterwave.charge();
    // if (response.toString().isNotEmpty) {
    //   if (response.success!) {
    //     Navigator.pop(_scaffoldKey.currentContext!);
    //     paymentCompleted(paymentMethod: "FlutterWave");
    //   } else {
    //     this.showLoading(message: response.status!);
    //   }
    //   print("${response.toJson()}");
    // } else {
    //   this.showLoading(message: "No Response!".tr(), txtColor: Colors.red);
    // }
  }

  Future<void> showLoading(
      {required String message, Color txtColor = Colors.black}) {
    return showDialog(
      context: this.context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Container(
            margin: EdgeInsets.fromLTRB(30, 20, 30, 20),
            width: double.infinity,
            height: 30,
            child: Text(
              message,
              style: TextStyle(color: txtColor),
            ),
          ),
        );
      },
    );
  }

  ///PayStack Payment Method
  payStackPayment() async {
    await PayStackURLGen.payStackURLGen(
      amount: (double.parse(_amountController.text) * 100).toString(),
      currency: currencyData!.code,
      secretKey: payStackSettingData!.secretKey,
    ).then((value) async {
      if (value != null) {
        PayStackUrlModel _payStackModel = value;

        bool isDone = await Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => PayStackScreen(
                  secretKey: payStackSettingData!.secretKey,
                  callBackUrl: payStackSettingData!.callbackURL,
                  initialURl: _payStackModel.data.authorizationUrl,
                  amount: _amountController.text,
                  reference: _payStackModel.data.reference,
                )));
        Navigator.pop(_scaffoldKey.currentContext!);

        if (isDone) {
          paymentCompleted(paymentMethod: "PayStack");
        } else {
          hideProgress();
          ScaffoldMessenger.of(_scaffoldKey.currentContext!)
              .showSnackBar(SnackBar(
            content: Text("Payment UnSuccessful!!".tr() + "\n"),
            backgroundColor: Colors.red,
          ));
        }
      } else {
        hideProgress();

        ScaffoldMessenger.of(_scaffoldKey.currentContext!)
            .showSnackBar(SnackBar(
          content: Text("Error while transaction!".tr() + "\n"),
          backgroundColor: Colors.red,
        ));
      }
    });
  }

  /// PayPal Payment Gateway

  // paypalPaymentSheet() {
  //   //add 1 item to cart. Max is 4!
  //   if (_flutterPaypalNativePlugin.canAddMorePurchaseUnit) {
  //     _flutterPaypalNativePlugin.addPurchaseUnit(
  //       FPayPalPurchaseUnit(
  //         // random prices
  //         amount: double.parse(_amountController.text),

  //         ///please use your own algorithm for referenceId. Maybe ProductID?
  //         referenceId: FPayPalStrHelper.getRandomString(16),
  //       ),
  //     );
  //   }
  //   // initPayPal();
  //   _flutterPaypalNativePlugin.makeOrder(
  //     action: FPayPalUserAction.payNow,
  //   );
  // }

  // _paypalPayment() async {
  //   PayPalClientTokenGen.paypalClientToken(
  //           paypalSettingData: paypalSettingData!)
  //       .then((value) async {
  //     final String tokenizationKey = paypalSettingData!
  //         .braintreeTokenizationKey; //"sandbox_w3dpbsks_5whrtf2sbrp4vx74";
  //
  //     var request = BraintreePayPalRequest(
  //         amount: _amountController.text,
  //         currencyCode: currencyData!.code,
  //         billingAgreementDescription: "djsghxghf",
  //         displayName: 'DoorDelights Driver App company');
  //
  //     BraintreePaymentMethodNonce? resultData;
  //
  //     try {
  //       resultData =
  //           await Braintree.requestPaypalNonce(tokenizationKey, request);
  //     } on Exception catch (ex) {
  //       print("Stripe error");
  //       showAlert(context,
  //           response:
  //               "Something went wrong, please contact admin.".tr() + " $ex",
  //           colors: Colors.red);
  //     }
  //     print(resultData?.nonce);
  //     print(resultData?.paypalPayerId);
  //     if (resultData?.nonce != null) {
  //       PayPalClientTokenGen.paypalSettleAmount(
  //         paypalSettingData: paypalSettingData!,
  //         nonceFromTheClient: resultData?.nonce,
  //         amount: _amountController.text,
  //         deviceDataFromTheClient: resultData?.typeLabel,
  //       ).then((value) {
  //         if (value['success'] == "true" || value['success'] == true) {
  //           if (value['data']['success'] == "true" ||
  //               value['data']['success'] == true) {
  //             payPalSettel.PayPalClientSettleModel settleResult =
  //                 payPalSettel.PayPalClientSettleModel.fromJson(value);
  //             if (settleResult.data.success) {
  //               Navigator.pop(context);
  //               ScaffoldMessenger.of(context).showSnackBar(SnackBar(
  //                 content: Text(
  //                   "Status : ${settleResult.data.transaction.status}\n"
  //                   "Transaction id : ${settleResult.data.transaction.id}\n"
  //                   "Amount : ${settleResult.data.transaction.amount}",
  //                 ),
  //                 duration: Duration(seconds: 8),
  //                 backgroundColor: Colors.green,
  //               ));
  //
  //               paymentCompleted(paymentMethod: "Paypal");
  //             }
  //           } else {
  //             payPalCurrModel.PayPalCurrencyCodeErrorModel settleResult =
  //                 payPalCurrModel.PayPalCurrencyCodeErrorModel.fromJson(value);
  //             Navigator.pop(_scaffoldKey.currentContext!);
  //             ScaffoldMessenger.of(context).showSnackBar(SnackBar(
  //               content:
  //                   Text("Status :".tr() + " ${settleResult.data.message}"),
  //               duration: Duration(seconds: 8),
  //               backgroundColor: Colors.red,
  //             ));
  //           }
  //         } else {
  //           PayPalErrorSettleModel settleResult =
  //               PayPalErrorSettleModel.fromJson(value);
  //           Navigator.pop(_scaffoldKey.currentContext!);
  //           ScaffoldMessenger.of(context).showSnackBar(SnackBar(
  //             content: Text("Status :".tr() + " ${settleResult.data.message}"),
  //             duration: Duration(seconds: 8),
  //             backgroundColor: Colors.red,
  //           ));
  //         }
  //       });
  //     } else {
  //       Navigator.pop(_scaffoldKey.currentContext!);
  //       ScaffoldMessenger.of(_scaffoldKey.currentContext!)
  //           .showSnackBar(SnackBar(
  //         content: Text('Status : Payment Incomplete!!'.tr()),
  //         duration: Duration(seconds: 8),
  //         backgroundColor: Colors.red,
  //       ));
  //     }
  //   });
  // }

  /// Stripe Payment Gateway
  // Future<void> stripeMakePayment({required String amount}) async {
  //   try {
  //     paymentIntentData = await createStripeIntent(
  //       amount,
  //     );
  //     if (paymentIntentData!.containsKey("error")) {
  //       Navigator.pop(context);
  //       showAlert(_scaffoldKey.currentContext,
  //           response: "Something went wrong, please contact admin.".tr(),
  //           colors: Colors.red);
  //     } else {
  //       await stripe1.Stripe.instance
  //           .initPaymentSheet(
  //               paymentSheetParameters: stripe1.SetupPaymentSheetParameters(
  //             paymentIntentClientSecret: paymentIntentData!['client_secret'],
  //             applePay: const stripe1.PaymentSheetApplePay(
  //               merchantCountryCode: 'US',
  //             ),
  //             allowsDelayedPaymentMethods: false,
  //             googlePay: stripe1.PaymentSheetGooglePay(
  //               merchantCountryCode: 'US',
  //               testEnv: true,
  //               currencyCode: currencyData!.code,
  //             ),
  //             style: ThemeMode.system,
  //             customFlow: true,
  //             appearance: stripe1.PaymentSheetAppearance(
  //               colors: stripe1.PaymentSheetAppearanceColors(
  //                 primary: Color(COLOR_PRIMARY),
  //               ),
  //             ),
  //             merchantDisplayName: 'DoorDelights Driver App',
  //           ))
  //           .then((value) {});
  //       setState(() {});
  //       displayStripePaymentSheet();
  //     }
  //   } catch (e, s) {
  //     print('exception:$e$s');
  //   }
  // }

  // displayStripePaymentSheet() async {
  //   try {
  //     await stripe1.Stripe.instance.presentPaymentSheet().then((value) {
  //       paymentCompleted(paymentMethod: "Stripe");
  //       Navigator.pop(context);
  //       paymentIntentData = null;
  //     });
  //   } on stripe1.StripeException catch (e) {
  //     Navigator.pop(context);
  //     var lo1 = jsonEncode(e);
  //     var lo2 = jsonDecode(lo1);
  //     StripePayFailedModel lom = StripePayFailedModel.fromJson(lo2);
  //     showDialog(
  //         context: context,
  //         builder: (_) => AlertDialog(
  //               content: Text("${lom.error.message}"),
  //             ));
  //   } catch (e) {
  //     print('$e');
  //     Navigator.pop(context);
  //     ScaffoldMessenger.of(context).showSnackBar(SnackBar(
  //       content: Text("$e"),
  //       duration: Duration(seconds: 8),
  //       backgroundColor: Colors.red,
  //     ));
  //   }
  // }

  // createStripeIntent(
  //   String amount,
  // ) async {
  //   try {
  //     Map<String, dynamic> body = {
  //       'amount': calculateAmount(amount),
  //       'currency': currencyData!.code,
  //       'payment_method_types[0]': 'card',
  //       // 'payment_method_types[1]': 'ideal',
  //       "description": "${Constant.userModel?.userID} Wallet Topup",
  //       "shipping[name]":
  //           "${Constant.userModel?.firstName} ${Constant.userModel?.lastName}",
  //       "shipping[address][line1]": "510 Townsend St",
  //       "shipping[address][postal_code]": "98140",
  //       "shipping[address][city]": "San Francisco",
  //       "shipping[address][state]": "CA",
  //       "shipping[address][country]": "US",
  //     };
  //     var response = await http.post(
  //         Uri.parse('https://api.stripe.com/v1/payment_intents'),
  //         body: body,
  //         headers: {
  //           'Authorization': 'Bearer ${stripeData?.stripeSecret}',
  //           //$_paymentIntentClientSecret',
  //           'Content-Type': 'application/x-www-form-urlencoded'
  //         });
  //     return jsonDecode(response.body);
  //   } catch (err) {
  //     print('error charging user: ${err.toString()}');
  //   }
  // }

  calculateAmount(String amount) {
    final a = (int.parse(amount)) * 100;
    return a.toString();
  }

  /// RazorPay Payment Gateway
  // void openCheckout({required amount, required orderId}) async {
  //   var options = {
  //     'key': razorPayData!.razorpayKey,
  //     'amount': amount * 100,
  //     'name': 'DoorDelights Driver App',
  //     'order_id': orderId,
  //     "currency": currencyData?.code,
  //     'description': 'wallet Topup',
  //     'retry': {'enabled': true, 'max_count': 1},
  //     'send_sms_hash': true,
  //     'prefill': {
  //       'contact': Constant.userModel!.phoneNumber,
  //       'email': Constant.userModel!.email,
  //     },
  //     'external': {
  //       'wallets': ['paytm']
  //     }
  //   };

  //   try {
  //     // _razorPay.open(options);
  //   } catch (e) {
  //     debugPrint('error'.tr() + ': $e');
  //   }
  // }

  ///MercadoPago Payment Method

  mercadoPagoMakePayment() {
    // makePreference().then((result) async {
    //   if (result.isNotEmpty) {
    //     var preferenceId = result['response']['id'];

    //     final bool isDone = await Navigator.push(
    //         context,
    //         MaterialPageRoute(
    //             builder: (context) => PaymentURLScreen(
    //                 initialURl: result['response']['init_point'])));
    //     print(isDone);
    //     print(result.toString());
    //     print(preferenceId);

    //     if (isDone) {
    //       paymentCompleted(paymentMethod: "MercadoPago");
    //     } else {
    //       Navigator.pop(_scaffoldKey.currentContext!);
    //       ScaffoldMessenger.of(_scaffoldKey.currentContext!)
    //           .showSnackBar(SnackBar(
    //         content: Text("Payment UnSuccessful!!".tr() + "\n"),
    //         backgroundColor: Colors.red,
    //       ));
    //     }
    //   } else {
    //     hideProgress();

    //     ScaffoldMessenger.of(_scaffoldKey.currentContext!)
    //         .showSnackBar(SnackBar(
    //       content: Text("Error while transaction!".tr() + "\n"),
    //       backgroundColor: Colors.red,
    //     ));
    //   }
    // });
  }

  // Future<Map<String, dynamic>> makePreference() async {
  // final mp = MP.fromAccessToken(mercadoPagoSettingData!.accessToken);
  // var pref = {
  //   "items": [
  //     {
  //       "title": "Wallet TopUp",
  //       "quantity": 1,
  //       "unit_price": double.parse(_amountController.text)
  //     }
  //   ],
  //   "auto_return": "all",
  //   "back_urls": {
  //     "failure": "${GlobalURL}payment/failure",
  //     "pending": "${GlobalURL}payment/pending",
  //     "success": "${GlobalURL}payment/success"
  //   },
  // };

  // var result = await mp.createPreference(pref);
  // return result;
  // }

  /// Paytm Payment Gateway
  bool isStaging = true;
  String callbackUrl =
      "http://162.241.125.167/~foodie/payments/paytmpaymentcallback?ORDER_ID=";
  bool restrictAppInvoke = false;
  bool enableAssist = true;
  String result = "";

  getPaytmCheckSum(
    context, {
    required double amount,
  }) async {
    final String orderId = UserPreference.getPaymentId();
    String getChecksum = "${GlobalURL}payments/getpaytmchecksum";

    final response = await http.post(
        Uri.parse(
          getChecksum,
        ),
        headers: {},
        body: {
          "mid": paytmSettingData?.paytmMID,
          "order_id": orderId,
          "key_secret": paytmSettingData?.paytmMerchantKey,
        });

    final data = jsonDecode(response.body);

    await verifyCheckSum(
            checkSum: data["code"], amount: amount, orderId: orderId)
        .then((value) {
      initiatePayment(context, amount: amount, orderId: orderId).then((value) {
        GetPaymentTxtTokenModel result = value;
        String callback = "";
        if (paytmSettingData!.isSandboxEnabled) {
          callback = callback +
              "https://securegw-stage.paytm.in/theia/paytmCallback?ORDER_ID=$orderId";
        } else {
          callback = callback +
              "https://securegw.paytm.in/theia/paytmCallback?ORDER_ID=$orderId";
        }

        _startTransaction(
          context,
          txnTokenBy: result.body.txnToken,
          orderId: orderId,
          amount: amount,
        );
      });
    });
  }

  Future<GetPaymentTxtTokenModel> initiatePayment(BuildContext context,
      {required double amount, required orderId}) async {
    String initiateURL = "${GlobalURL}payments/initiatepaytmpayment";
    String callback = "";
    if (paytmSettingData!.isSandboxEnabled) {
      callback = callback +
          "https://securegw-stage.paytm.in/theia/paytmCallback?ORDER_ID=$orderId";
    } else {
      callback = callback +
          "https://securegw.paytm.in/theia/paytmCallback?ORDER_ID=$orderId";
    }
    final response = await http.post(
        Uri.parse(
          initiateURL,
        ),
        headers: {},
        body: {
          "mid": paytmSettingData?.paytmMID,
          "order_id": orderId,
          "key_secret": paytmSettingData?.paytmMerchantKey.toString(),
          "amount": amount.toString(),
          "currency": currencyData!.code,
          "callback_url": callback,
          "custId": Constant.userModel!.id,
          "issandbox": paytmSettingData!.isSandboxEnabled ? "1" : "2",
        });
    final data = jsonDecode(response.body);
    if (data["body"]["txnToken"] == null ||
        data["body"]["txnToken"].toString().isEmpty) {
      Navigator.pop(_scaffoldKey.currentContext!);
      showAlert(_scaffoldKey.currentContext!,
          response: "something went wrong, please contact admin.".tr(),
          colors: Colors.red);
    }
    return GetPaymentTxtTokenModel.fromJson(data);
  }

  Future<void> _startTransaction(
    context, {
    required String txnTokenBy,
    required orderId,
    required double amount,
  }) async {
    // try {
    //   var response = AllInOneSdk.startTransaction(
    //     paytmSettingData!.paytmMID,
    //     orderId,
    //     amount.toString(),
    //     txnTokenBy,
    //     "https://securegw-stage.paytm.in/theia/paytmCallback?ORDER_ID=$orderId",
    //     isStaging,
    //     true,
    //     enableAssist,
    //   );

    //   response.then((value) {
    //     if (value!["RESPMSG"] == "Txn Success") {
    //       paymentCompleted(paymentMethod: "Paytm");
    //     }
    //   }).catchError((onError) {
    //     if (onError is PlatformException) {
    //       Navigator.pop(_scaffoldKey.currentContext!);

    //       result =
    //           onError.message.toString() + " \n  " + onError.code.toString();
    //       showAlert(_scaffoldKey.currentContext!,
    //           response: onError.message.toString(), colors: Colors.red);
    //     } else {
    //       result = onError.toString();
    //       Navigator.pop(_scaffoldKey.currentContext!);
    //       showAlert(_scaffoldKey.currentContext!,
    //           response: result, colors: Colors.red);
    //     }
    //   });
    // } catch (err) {
    //   result = err.toString();
    //   Navigator.pop(_scaffoldKey.currentContext!);
    //   showAlert(_scaffoldKey.currentContext!,
    //       response: result, colors: Colors.red);
    // }
  }

  Future verifyCheckSum(
      {required String checkSum,
      required double amount,
      required orderId}) async {
    String getChecksum = "${GlobalURL}payments/validatechecksum";
    final response = await http.post(
        Uri.parse(
          getChecksum,
        ),
        headers: {},
        body: {
          "mid": paytmSettingData?.paytmMID,
          "order_id": orderId,
          "key_secret": paytmSettingData?.paytmMerchantKey,
          "checksum_value": checkSum,
        });
    final data = jsonDecode(response.body);
    return data['status'];
  }

  tabController() {
    final themeController = Get.find<ThemeController>();

    return Obx(() {
      final isDark = themeController.isDark.value;

      return Expanded(
        child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Container(
                    height: 40,
                    child: TabBar(
                      //indicator: BoxDecoration(color: const Color(COLOR_PRIMARY), borderRadius: BorderRadius.circular(2.0)),
                      indicatorColor: Color(COLOR_PRIMARY),
                      labelColor: Color(COLOR_PRIMARY),
                      automaticIndicatorColorAdjustment: true,
                      dragStartBehavior: DragStartBehavior.start,
                      unselectedLabelColor:
                          isDark ? Colors.white70 : Colors.black54,
                      indicatorWeight: 1.5,
                      //indicatorPadding: EdgeInsets.symmetric(horizontal: 10),
                      enableFeedback: true,
                      //unselectedLabelColor: const Colors,
                      tabs: [
                        Tab(
                          text: "Wallet History".tr(),
                        ),
                        Tab(
                          text: "Withdrawal History".tr(),
                        ),
                        // Tab(text: 'Daily'.tr()),
                        // Tab(
                        //   text: 'Monthly'.tr(),
                        // ),
                        // Tab(
                        //   text: 'Yearly'.tr(),
                        // ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: TabBarView(
                      children: [
                        showEarningsHistory(context, query: dailyEarningQuery),
                        showWithdrawalHistory(context,
                            query: withdrawalHistoryQuery),
                        // showEarningsHistory(context, query: monthlyEarningQuery),
                        // showEarningsHistory(context, query: yearlyEarningQuery),
                      ],
                    ),
                  ),
                )
              ],
            )),
      );
    });
  }

  Widget showEarningsHistory(BuildContext context,
      {required Stream<QuerySnapshot>? query}) {
    final themeController = Get.find<ThemeController>();

    return StreamBuilder<QuerySnapshot>(
      stream: query,
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
              child: SizedBox(
                  height: 35, width: 35, child: CircularProgressIndicator()));
        }

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          List<String> totalAmounts = [];

          RxDouble orderAmount = (0.0).obs;
          for (var document in snapshot.data!.docs) {
            final currentOrder;
            double amount = 0.0;
            if (Constant.userModel!.serviceType == "cab-service") {
              currentOrder = CabOrderModel.fromJson(
                  document.data() as Map<String, dynamic>);
              amount = amount + double.parse(currentOrder!.subTotal ?? '0.0');
              amount = amount +
                  double.parse((currentOrder!.tipAmount == null ||
                          currentOrder!.tipAmount.toString().isEmpty)
                      ? '0.0'
                      : currentOrder!.tipAmount.toString());
              amount = double.parse(amount.toStringAsFixed(2));
              totalAmounts.add(amount.toString());
            } else if (Constant.userModel!.serviceType == "parcel_delivery") {
              currentOrder = ParcelOrderModel.fromJson(
                  document.data() as Map<String, dynamic>);
              amount = amount + double.parse(currentOrder!.subTotal ?? '0.0');
              amount = double.parse(amount.toStringAsFixed(2));
              totalAmounts.add(amount.toString());
            } else if (Constant.userModel!.serviceType == "rental-service") {
              currentOrder = RentalOrderModel.fromJson(
                  document.data() as Map<String, dynamic>);
              // Rental order processing (if needed)
            } else {
              // delivery-service
              currentOrder =
                  OrderModel.fromJson(document.data() as Map<String, dynamic>);
              for (var product in currentOrder!.products) {
                if (product.extras_price != null &&
                    product.extras_price!.isNotEmpty &&
                    double.parse(product.extras_price!) != 0.0) {
                  amount += double.parse(product.extras_price!);
                }
                amount += product.quantity * double.parse(product.price);
              }
              amount =
                  amount + double.parse(currentOrder!.deliveryCharge ?? '0.0');
              amount = amount -
                  ((currentOrder!.specialDiscount != null &&
                          currentOrder!.specialDiscount is Map &&
                          currentOrder!.specialDiscount!.containsKey(
                            'special_discount',
                          ))
                      ? double.parse(
                          (currentOrder!.specialDiscount!['special_discount'] ??
                                  0)
                              .toString())
                      : 0);
              amount = amount + double.parse(currentOrder!.tipAmount ?? '0.0');
              double.parse(currentOrder!.serviceCharges!.toString());
              amount = amount -
                  double.parse(currentOrder!.deliveryDiscount!.toString());
              amount = double.parse(amount.toStringAsFixed(2));
              totalAmounts.add(amount.toString());
            }

            orderAmount.value = orderAmount.value + amount;
          }

          return Obx(() {
            final isDark = themeController.isDark.value;
            return Column(
              children: [
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            "Orders Amount".tr(),
                            maxLines: 1,
                            style: TextStyle(
                              color: isDark ? Colors.white : Color(DARK_COLOR),
                              fontSize: 14,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Obx(
                            () => Text(
                              amountShow(amount: orderAmount.value.toString()),
                              maxLines: 1,
                              style: TextStyle(
                                color:
                                    isDark ? Colors.white : Color(DARK_COLOR),
                                fontSize: 18,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            "Total Orders.".tr(),
                            maxLines: 1,
                            style: TextStyle(
                              color: isDark ? Colors.white : Color(DARK_COLOR),
                              fontSize: 14,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            snapshot.data!.docs.length.toString(),
                            maxLines: 1,
                            style: TextStyle(
                              color: isDark ? Colors.white : Color(DARK_COLOR),
                              fontSize: 18,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const SizedBox(width: 20),
                    Expanded(
                      child: buildButton(
                        context,
                        title: "Download Statement".tr(),
                        onPress: () async {
                          await createAndSavePdf(
                              snapshot.data!.docs, totalAmounts);
                        },
                      ),
                    ),
                    const SizedBox(width: 20),
                  ],
                ),
                SizedBox(height: 20),
                Expanded(
                  child: ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final document = snapshot.data!.docs[index];
                      final earningData;
                      if (Constant.userModel!.serviceType == "cab-service") {
                        earningData = CabOrderModel.fromJson(
                            document.data() as Map<String, dynamic>);
                      } else if (Constant.userModel!.serviceType ==
                          "parcel_delivery") {
                        earningData = ParcelOrderModel.fromJson(
                            document.data() as Map<String, dynamic>);
                      } else if (Constant.userModel!.serviceType ==
                          "rental-service") {
                        earningData = RentalOrderModel.fromJson(
                            document.data() as Map<String, dynamic>);
                      } else {
                        earningData = OrderModel.fromJson(
                            document.data() as Map<String, dynamic>);
                      }
                      return buildEarningCard(orderModel: earningData);
                    },
                  ),
                ),
              ],
            );
          });
        } else {
          return Obx(() {
            final isDark = themeController.isDark.value;
            return Center(
                child: Text(
              "No Transaction History".tr(),
              style: TextStyle(
                fontSize: 18,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ));
          });
        }
      },
    );
  }

  Future<void> createAndSavePdf(
      List<DocumentSnapshot> transactions, List<String> amounts) async {
    try {
      // if (await Permission.manageExternalStorage.request().isGranted) {
      // Create a new PDF document
      final PdfDocument document = PdfDocument();

      // Add a page to the document
      final PdfPage page = document.pages.add();

      // Create a PDF grid (table)
      final PdfGrid grid = PdfGrid();

      // Add columns to the grid
      grid.columns.add(count: 4);

      // Add headers to the grid
      grid.headers.add(1);
      final PdfGridRow header = grid.headers[0];
      header.cells[0].value = 'Order Id';
      header.cells[1].value = 'Order Amount';
      header.cells[2].value = 'Tip Amount';
      header.cells[3].value = 'Date';

      // Add rows to the grid
      PdfGridRow row = grid.rows.add();
      for (int i = 0; i < transactions.length; i++) {
        final earningData;
        if (Constant.userModel!.serviceType == "cab-service") {
          earningData = CabOrderModel.fromJson(
              transactions[i].data() as Map<String, dynamic>);
        } else if (Constant.userModel!.serviceType == "parcel_delivery") {
          earningData = ParcelOrderModel.fromJson(
              transactions[i].data() as Map<String, dynamic>);
        } else if (Constant.userModel!.serviceType == "rental-service") {
          earningData = RentalOrderModel.fromJson(
              transactions[i].data() as Map<String, dynamic>);
        } else {
          earningData = OrderModel.fromJson(
              transactions[i].data() as Map<String, dynamic>);
        }

        row.cells[0].value = orderId(orderId: earningData.id.toString());
        row.cells[1].value = amountShow(amount: amounts[i].toString());
        row.cells[2].value =
            amountShow(amount: (earningData.tipAmount ?? 0).toString());
        row.cells[3].value = timestampToDateTime(earningData.createdAt);
        row = grid.rows.add();
      }

      // Draw the grid on the page
      grid.draw(page: page, bounds: const Rect.fromLTWH(0, 0, 0, 0));

      // Save the document
      final List<int> bytes = document.saveSync();

      // Dispose of the document
      document.dispose();
      Directory? downloadsDirectory;
      if (Platform.isAndroid) {
        // Get the application directory
        downloadsDirectory = Directory('/storage/emulated/0/Download');
      } else if (Platform.isIOS) {
        downloadsDirectory = await getApplicationDocumentsDirectory();
      }
      if (!downloadsDirectory!.existsSync()) {
        downloadsDirectory.createSync(recursive: true);
      }
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String path =
          '${downloadsDirectory.path}/driver_statement_$timestamp.pdf';
      final File file = File(path);
      await file.writeAsBytes(bytes, flush: true);

      if (Platform.isIOS) {
        OpenFile.open(file.path);
      } else {
        ShowToastDialog.showToast(
          "${"The statement has been successfully downloaded to the".tr()} ${path} ${"folder.".tr()}.",
        );
        print('PDF saved at: $path');
      }

      // } else {
      //   ShowToastDialog.showToast("Storage permission denied");
      // }
    } catch (e) {
      ShowToastDialog.showToast("Error: $e");
    }
  }

  Widget buildEarningCard({required var orderModel}) {
    final size = MediaQuery.sizeOf(context);
    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;

    double amount = 0;
    double adminComm = 0.0;

    // --- Calculate amounts based on service type ---
    if (Constant.userModel!.serviceType == "cab-service") {
      double totalTax = 0.0;
      if (orderModel!.taxModel != null) {
        for (var element in orderModel!.taxModel!) {
          totalTax += calculateTax(
              amount: (double.parse(orderModel.subTotal.toString()) -
                      double.parse(orderModel.discount.toString()))
                  .toString(),
              taxModel: element);
        }
      }
      double subTotal = double.parse(orderModel.subTotal.toString());
      if (orderModel.adminCommission!.isNotEmpty) {
        adminComm = (orderModel.adminCommissionType == 'Percent' ||
                orderModel.adminCommissionType == 'percentage')
            ? (subTotal * double.parse(orderModel.adminCommission!)) / 100
            : double.parse(orderModel.adminCommission!);
      }
      double tipAmount = orderModel.tipAmount!.isEmpty
          ? 0.0
          : double.parse(orderModel.tipAmount.toString());
      amount = subTotal + totalTax + tipAmount;
    } else if (Constant.userModel!.serviceType == "parcel_delivery") {
      double totalTax = 0.0;
      if (orderModel!.taxModel != null) {
        for (var element in orderModel!.taxModel!) {
          totalTax += calculateTax(
              amount: (double.parse(orderModel.subTotal.toString()) -
                      double.parse(orderModel.discount.toString()))
                  .toString(),
              taxModel: element);
        }
      }
      double subTotal = double.parse(orderModel.subTotal.toString());
      if (orderModel.adminCommission!.isNotEmpty) {
        adminComm = (orderModel.adminCommissionType == 'Percent' ||
                orderModel.adminCommissionType == 'percentage')
            ? (subTotal * double.parse(orderModel.adminCommission!)) / 100
            : double.parse(orderModel.adminCommission!);
      }
      amount = subTotal + totalTax;
    } else if (Constant.userModel!.serviceType == "rental-service") {
      double totalTax = 0.0;
      double subTotal = (double.parse(orderModel.subTotal.toString()) +
          double.parse(orderModel.driverRate.toString()));
      if (orderModel!.taxModel != null) {
        for (var element in orderModel!.taxModel!) {
          totalTax +=
              calculateTax(amount: subTotal.toString(), taxModel: element);
        }
      }
      if (orderModel.adminCommission!.isNotEmpty) {
        adminComm = (orderModel.adminCommissionType == 'Percent' ||
                orderModel.adminCommissionType == 'percentage')
            ? (subTotal * double.parse(orderModel.adminCommission!)) / 100
            : double.parse(orderModel.adminCommission!);
      }
      amount = subTotal + totalTax;
    } else {
      // delivery-service
      if (orderModel.deliveryCharge != null &&
          orderModel.deliveryCharge!.isNotEmpty) {
        amount += double.parse(orderModel.deliveryCharge!);
      }
      if (orderModel.tipAmount != null && orderModel.tipAmount!.isNotEmpty) {
        amount += double.parse(orderModel.tipAmount!);
      }
    }

    // --- For delivery service, return a simpler card ---
    if (Constant.userModel!.serviceType == "delivery-service") {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3),
        child: Card(
          elevation: 2,
          color: isDark ? AppThemeData.grey900 : AppThemeData.greyDark900,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: size.width * 0.52,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('dd-MM-yyyy, KK:mma')
                            .format(orderModel.createdAt.toDate())
                            .toUpperCase(),
                        style: AppThemeData.semiBoldTextStyle(
                          fontSize: 17,
                          color: isDark
                              ? AppThemeData.greyDark900
                              : AppThemeData.grey900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Opacity(
                        opacity: 0.75,
                        child: Text(
                          orderModel.status,
                          style: AppThemeData.semiBoldTextStyle(
                            fontSize: 17,
                            color: orderModel.status == "Order Completed"
                                ? AppThemeData.success400
                                : AppThemeData.warning400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 3.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        amountShow(amount: amount.toString()),
                        style: AppThemeData.semiBoldTextStyle(
                          fontSize: 18,
                          color: orderModel.status == "Order Completed"
                              ? amount < 0
                                  ? AppThemeData.danger300
                                  : AppThemeData.success400
                              : AppThemeData.warning400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // --- For cab, parcel, rental services – rich card ---
    return GestureDetector(
      onTap: () => showTransactionDetails(orderModel: orderModel),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isDark ? AppThemeData.greyDark200 : AppThemeData.grey200,
              width: 0.5,
            ),
          ),
          color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(
              children: [
                // Icon with circle background
                Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppThemeData.primary300.withOpacity(0.1)
                        : AppThemeData.primary300.withOpacity(0.06),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 28,
                    color: AppThemeData.primary300,
                  ),
                ),
                const SizedBox(width: 12),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Order Amount Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Order Amount".tr(),
                            style: AppThemeData.semiBoldTextStyle(
                              fontSize: 16,
                              color: isDark
                                  ? AppThemeData.greyDark900
                                  : AppThemeData.grey900,
                            ),
                          ),
                          Text(
                            orderModel.paymentMethod.toLowerCase() != "cod"
                                ? "+ ${amountShow(amount: amount.toString())}"
                                : "- ${amountShow(amount: amount.toString())}",
                            style: AppThemeData.semiBoldTextStyle(
                              fontSize: 18,
                              color: orderModel.paymentMethod.toLowerCase() !=
                                      "cod"
                                  ? AppThemeData.success400
                                  : AppThemeData.danger300,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Admin Commission Row
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "Admin Commission".tr(),
                              style: AppThemeData.mediumTextStyle(
                                fontSize: 14,
                                color: isDark
                                    ? AppThemeData.greyDark800
                                    : AppThemeData.grey800,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "- ${amountShow(amount: adminComm.toString())}",
                            style: AppThemeData.semiBoldTextStyle(
                              fontSize: 16,
                              color: AppThemeData.danger300,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Date
                      Opacity(
                        opacity: 0.65,
                        child: Text(
                          DateFormat('KK:mm:ss a, dd MMM yyyy')
                              .format(orderModel.createdAt.toDate())
                              .toUpperCase(),
                          style: AppThemeData.mediumTextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppThemeData.greyDark700
                                : AppThemeData.grey700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Arrow icon (touch indicator)
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color:
                      isDark ? AppThemeData.greyDark400 : AppThemeData.grey400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  showTransactionDetails({required var orderModel}) {
    double amount = 0;
    double adminComm = 0.0;

    // Calculate amounts based on service type
    if (Constant.userModel!.serviceType == "cab-service") {
      double totalTax = 0.0;
      if (orderModel!.taxModel != null) {
        for (var element in orderModel!.taxModel!) {
          totalTax += calculateTax(
              amount: (double.parse(orderModel.subTotal.toString()) -
                      double.parse(orderModel.discount.toString()))
                  .toString(),
              taxModel: element);
        }
      }
      double subTotal = double.parse(orderModel.subTotal.toString());
      if (orderModel.adminCommission!.isNotEmpty) {
        adminComm = (orderModel.adminCommissionType == 'Percent' ||
                orderModel.adminCommissionType == 'percentage')
            ? (subTotal * double.parse(orderModel.adminCommission!)) / 100
            : double.parse(orderModel.adminCommission!);
      }
      double tipAmount = orderModel.tipAmount!.isEmpty
          ? 0.0
          : double.parse(orderModel.tipAmount.toString());
      amount = subTotal + totalTax + tipAmount;
    } else if (Constant.userModel!.serviceType == "parcel_delivery") {
      double totalTax = 0.0;
      if (orderModel!.taxModel != null) {
        for (var element in orderModel!.taxModel!) {
          totalTax += calculateTax(
              amount: (double.parse(orderModel.subTotal.toString()) -
                      double.parse(orderModel.discount.toString()))
                  .toString(),
              taxModel: element);
        }
      }
      double subTotal = double.parse(orderModel.subTotal.toString());
      if (orderModel.adminCommission!.isNotEmpty) {
        adminComm = (orderModel.adminCommissionType == 'Percent' ||
                orderModel.adminCommissionType == 'percentage')
            ? (subTotal * double.parse(orderModel.adminCommission!)) / 100
            : double.parse(orderModel.adminCommission!);
      }
      amount = subTotal + totalTax;
    } else if (Constant.userModel!.serviceType == "rental-service") {
      double totalTax = 0.0;
      double subTotal = (double.parse(orderModel.subTotal.toString()) +
          double.parse(orderModel.driverRate.toString()));
      if (orderModel!.taxModel != null) {
        for (var element in orderModel!.taxModel!) {
          totalTax +=
              calculateTax(amount: subTotal.toString(), taxModel: element);
        }
      }
      if (orderModel.adminCommission!.isNotEmpty) {
        adminComm = (orderModel.adminCommissionType == 'Percent' ||
                orderModel.adminCommissionType == 'percentage')
            ? (subTotal * double.parse(orderModel.adminCommission!)) / 100
            : double.parse(orderModel.adminCommission!);
      }
      amount = subTotal + totalTax;
    }

    final themeController = Get.find<ThemeController>();
    final isDark = themeController.isDark.value;

    return showModalBottomSheet(
      elevation: 5,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: isDark ? AppThemeData.greyDark50 : AppThemeData.grey50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Draggable handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppThemeData.greyDark200
                            : AppThemeData.grey200,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Title
                  Center(
                    child: Text(
                      "Transaction Details".tr(),
                      style: AppThemeData.boldTextStyle(
                        fontSize: 20,
                        color: isDark
                            ? AppThemeData.greyDark900
                            : AppThemeData.grey900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Transaction ID Card
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppThemeData.greyDark100
                          : AppThemeData.grey100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? AppThemeData.greyDark200
                            : AppThemeData.grey200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          color: isDark
                              ? AppThemeData.greyDark800
                              : AppThemeData.grey800,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Transaction ID".tr(),
                                style: AppThemeData.mediumTextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppThemeData.greyDark800
                                      : AppThemeData.grey800,
                                ),
                              ),
                              Text(
                                orderModel.id ?? '',
                                style: AppThemeData.semiBoldTextStyle(
                                  fontSize: 16,
                                  color: isDark
                                      ? AppThemeData.greyDark900
                                      : AppThemeData.grey900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Amount & Commission Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppThemeData.greyDark100
                          : AppThemeData.grey100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? AppThemeData.greyDark200
                            : AppThemeData.grey200,
                      ),
                    ),
                    child: Column(
                      children: [
                        // Order Amount
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.attach_money,
                                    color: isDark
                                        ? AppThemeData.greyDark800
                                        : AppThemeData.grey800,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Order Amount".tr(),
                                    style: AppThemeData.mediumTextStyle(
                                      fontSize: 16,
                                      color: isDark
                                          ? AppThemeData.greyDark800
                                          : AppThemeData.grey800,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                orderModel.paymentMethod.toLowerCase() != "cod"
                                    ? "+ ${Constant.amountShow(amount: amount.toString())}"
                                    : "- ${Constant.amountShow(amount: amount.toString())}",
                                style: AppThemeData.semiBoldTextStyle(
                                  fontSize: 18,
                                  color:
                                      orderModel.paymentMethod.toLowerCase() !=
                                              "cod"
                                          ? AppThemeData.success400
                                          : AppThemeData.danger300,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(
                          color: AppThemeData.grey200,
                        ),
                        // Admin Commission
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.percent,
                                    color: isDark
                                        ? AppThemeData.greyDark800
                                        : AppThemeData.grey800,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Admin Commission".tr(),
                                    style: AppThemeData.mediumTextStyle(
                                      fontSize: 16,
                                      color: isDark
                                          ? AppThemeData.greyDark800
                                          : AppThemeData.grey800,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                "- ${Constant.amountShow(amount: adminComm.toString())}",
                                style: AppThemeData.semiBoldTextStyle(
                                  fontSize: 18,
                                  color: AppThemeData.danger300,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Date & Time Card
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppThemeData.greyDark100
                          : AppThemeData.grey100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? AppThemeData.greyDark200
                            : AppThemeData.grey200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          color: isDark
                              ? AppThemeData.greyDark800
                              : AppThemeData.grey800,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          DateFormat('KK:mm:ss a, dd MMM yyyy')
                              .format(orderModel.createdAt.toDate())
                              .toUpperCase(),
                          style: AppThemeData.mediumTextStyle(
                            fontSize: 15,
                            color: isDark
                                ? AppThemeData.greyDark800
                                : AppThemeData.grey800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // View Order Button (aligned right)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () async {
                          // Navigate to order detail based on service type
                          if (Constant.userModel!.serviceType ==
                              "cab-service") {
                            await FireStoreUtils.firestore
                                .collection(RIDESORDER)
                                .doc(orderModel.id)
                                .get()
                                .then((value) {
                              CabOrderModel orderModel =
                                  CabOrderModel.fromJson(value.data()!);
                              Get.to(() => CabOrderDetails(),
                                  arguments: {"cabOrderModel": orderModel});
                            });
                          } else if (Constant.userModel!.serviceType ==
                              "parcel_delivery") {
                            await FireStoreUtils.firestore
                                .collection(PARCELORDER)
                                .doc(orderModel.id)
                                .get()
                                .then((value) {
                              ParcelOrderModel orderModel =
                                  ParcelOrderModel.fromJson(value.data()!);
                              Get.to(() => ParcelOrderDetails(),
                                  arguments: orderModel);
                            });
                          } else if (Constant.userModel!.serviceType ==
                              "rental-service") {
                            await FireStoreUtils.firestore
                                .collection(RENTALORDER)
                                .doc(orderModel.id)
                                .get()
                                .then((value) {
                              RentalOrderModel orderModel =
                                  RentalOrderModel.fromJson(value.data()!);
                              Get.to(() => RentalOrderDetailsScreen(),
                                  arguments: {"rentalOrder": orderModel});
                            });
                          }
                        },
                        icon: const Icon(Icons.arrow_forward_ios, size: 16),
                        label: Text(
                          "View Order".tr().toUpperCase(),
                          style: AppThemeData.semiBoldTextStyle(
                            fontSize: 16,
                            color: AppThemeData.primary300,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppThemeData.primary300,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(
                              color: AppThemeData.primary300,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Widget buildEarningCard({required var orderModel}) {
  //   final size = MediaQuery.sizeOf(context);
  //   double amount = 0;
  //   if (Constant.userModel!.serviceType == "cab-service") {
  //     double totalTax = 0.0;
  //
  //   /*  if (orderModel.taxType!.isNotEmpty) {
  //       if (orderModel.taxType == "percent") {
  //         totalTax = (double.parse(orderModel.subTotal.toString()) - double.parse(orderModel.discount.toString())) * double.parse(orderModel.tax.toString()) / 100;
  //       } else {
  //         totalTax = double.parse(orderModel.tax.toString());
  //       }
  //     }*/
  //     if (orderModel!.taxModel != null) {
  //       for (var element in orderModel!.taxModel!) {
  //         totalTax = totalTax + calculateTax(amount: (double.parse(orderModel.subTotal.toString()) -
  //             double.parse(orderModel.discount.toString())).toString(),
  //             taxModel: element);
  //       }
  //     }
  //     print(totalTax);
  //     double subTotal = double.parse(orderModel.subTotal.toString()) - double.parse(orderModel.discount.toString());
  //     double adminComm = 0.0;
  //     if (orderModel.adminCommission!.isNotEmpty) {
  //       adminComm = (orderModel.adminCommissionType == 'Percent') ? (subTotal * double.parse(orderModel.adminCommission!)) / 100 : double.parse(orderModel.adminCommission!);
  //     }
  //
  //     print("--->finalAmount---- $subTotal");
  //     double tipAmount = orderModel.tipAmount!.isEmpty ? 0.0 : double.parse(orderModel.tipAmount.toString());
  //     if (orderModel.paymentMethod.toLowerCase() != "cod") {
  //       amount = subTotal + totalTax + tipAmount + adminComm;
  //     } else {
  //       amount = -(subTotal + totalTax + tipAmount + adminComm);
  //     }
  //   } else if (Constant.userModel!.serviceType == "parcel_delivery") {
  //     double totalTax = 0.0;
  //
  //    /* if (orderModel.taxType!.isNotEmpty) {
  //       if (orderModel.taxType == "percent") {
  //         totalTax = (double.parse(orderModel.subTotal.toString()) - double.parse(orderModel.discount.toString())) * double.parse(orderModel.tax.toString()) / 100;
  //       } else {
  //         totalTax = double.parse(orderModel.tax.toString());
  //       }
  //     */
  //     if (orderModel!.taxModel != null) {
  //       for (var element in orderModel!.taxModel!) {
  //         totalTax = totalTax + calculateTax(amount: (double.parse(orderModel.subTotal.toString()) -
  //             double.parse(orderModel.discount.toString())).toString(),
  //             taxModel: element);
  //       }
  //     }
  //     double subTotal = double.parse(orderModel.subTotal.toString()) - double.parse(orderModel.discount.toString());
  //     double adminComm = 0.0;
  //     if (orderModel.adminCommission!.isNotEmpty) {
  //       adminComm = (orderModel.adminCommissionType == 'Percent') ? (subTotal * double.parse(orderModel.adminCommission!)) / 100 : double.parse(orderModel.adminCommission!);
  //     }
  //
  //     print("--->finalAmount---- $subTotal");
  //     print("11111");
  //     print(orderModel.paymentMethod.toLowerCase());
  //     if (orderModel.paymentMethod.toLowerCase() != "cod") {
  //       amount = subTotal + totalTax + adminComm;
  //     } else {
  //       amount = -(subTotal + totalTax + adminComm);
  //     }
  //   } else if (Constant.userModel!.serviceType == "rental-service") {
  //     double totalTax = 0.0;
  //     double subTotal = (double.parse(orderModel.subTotal.toString()) + double.parse(orderModel.driverRate.toString())) - double.parse(orderModel.discount.toString());
  //
  //     /*if (orderModel.taxType!.isNotEmpty) {
  //       if (orderModel.taxType == "percent") {
  //         totalTax = subTotal * double.parse(orderModel.tax.toString()) / 100;
  //       } else {
  //         totalTax = double.parse(orderModel.tax.toString());
  //       }
  //     }*/
  //     if (orderModel!.taxModel != null) {
  //       for (var element in orderModel!.taxModel!) {
  //         totalTax = totalTax + calculateTax(amount: (orderModel.subTotal.toString()),
  //             taxModel: element);
  //       }
  //     }
  //     double adminComm = 0.0;
  //     if (orderModel.adminCommission!.isNotEmpty) {
  //       adminComm = (orderModel.adminCommissionType == 'Percent')
  //           ? (double.parse(orderModel.subTotal.toString()) + double.parse(orderModel.driverRate.toString()) * double.parse(orderModel.adminCommission!)) / 100
  //           : double.parse(orderModel.adminCommission!);
  //     }
  //
  //     if (orderModel.paymentMethod.toLowerCase() != "cod") {
  //       amount = subTotal + totalTax + adminComm;
  //     } else {
  //       amount = -(subTotal + totalTax + adminComm);
  //     }
  //   } else {
  //     print("delv charge ${orderModel.deliveryCharge}");
  //     if (orderModel.deliveryCharge != null && orderModel.deliveryCharge!.isNotEmpty) {
  //       amount += double.parse(orderModel.deliveryCharge!);
  //     }
  //
  //     if (orderModel.tipAmount != null && orderModel.tipAmount!.isNotEmpty) {
  //       amount += double.parse(orderModel.tipAmount!);
  //     }
  //   }
  //   return Padding(
  //     padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3),
  //     child: Card(
  //       elevation: 2,
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  //       child: Padding(
  //         padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 15),
  //         child: Row(
  //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //           crossAxisAlignment: CrossAxisAlignment.center,
  //           children: [
  //             SizedBox(
  //               width: size.width * 0.52,
  //               child: Column(
  //                 crossAxisAlignment: CrossAxisAlignment.start,
  //                 children: [
  //                   Text(
  //                     "${DateFormat('dd-MM-yyyy, KK:mma').format(orderModel.createdAt.toDate()).toUpperCase()}",
  //                     style: TextStyle(
  //                       fontWeight: FontWeight.w500,
  //                       fontSize: 17,
  //                     ),
  //                   ),
  //                   SizedBox(
  //                     height: 10,
  //                   ),
  //                   Opacity(
  //                     opacity: 0.75,
  //                     child: Text(
  //                       orderModel.status,
  //                       style: TextStyle(
  //                         fontWeight: FontWeight.w500,
  //                         fontSize: 17,
  //                         color: orderModel.status == "Order Completed" ? Colors.green : Colors.deepOrangeAccent,
  //                       ),
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //             Padding(
  //               padding: const EdgeInsets.only(right: 3.0),
  //               child: Column(
  //                 crossAxisAlignment: CrossAxisAlignment.end,
  //                 children: [
  //                   Text(
  //                     " ${amountShow(amount: amount.toString())}",
  //                     style: TextStyle(
  //                       fontWeight: FontWeight.w600,
  //                       color: orderModel.status == "Order Completed"
  //                           ? amount < 0
  //                               ? Colors.red
  //                               : Colors.green
  //                           : Colors.deepOrange,
  //                       fontSize: 18,
  //                     ),
  //                   ),
  //                   SizedBox(
  //                     height: 20,
  //                   ),
  //                   // Icon(
  //                   //   Icons.arrow_forward_ios,
  //                   //   size: 15,
  //                   // )
  //                 ],
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }

  Widget showWithdrawalHistory(BuildContext context,
      {required Stream<QuerySnapshot>? query}) {
    final themeController = Get.find<ThemeController>();
    return Obx(() {
      final isDark = themeController.isDark.value;
      return StreamBuilder<QuerySnapshot>(
        stream: query,
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Something went wrong'.tr()));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
                child: SizedBox(
                    height: 35, width: 35, child: CircularProgressIndicator()));
          }
          if (snapshot.data!.docs.isEmpty) {
            return Center(
                child: Text(
              "No Transaction History".tr(),
              style: TextStyle(
                fontSize: 18,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ));
          } else {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Container(
                decoration: ShapeDecoration(
                  color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    physics: const BouncingScrollPhysics(),
                    itemCount: snapshot.data!.docs.length,
                    separatorBuilder: (BuildContext context, int index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: MySeparator(
                            color: isDark
                                ? AppThemeData.grey700
                                : AppThemeData.grey200),
                      );
                    },
                    itemBuilder: (context, index) {
                      final document = snapshot.data!.docs[index];
                      final topUpData = WithdrawHistoryModel.fromJson(
                          document.data() as Map<String, dynamic>);
                      return transactionCardWithdrawal(isDark, topUpData);
                      // return buildTransactionCard(
                      //   withdrawHistory: topUpData,
                      //   date: topUpData.paidDate.toDate(),
                      // );
                    },
                  ),
                ),
              ),
            );
          }
        },
      );
    });
  }

  InkWell transactionCardWithdrawal(
      isDark, WithdrawHistoryModel transactionModel) {
    return InkWell(
      onTap: () async {},
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Container(
              decoration: ShapeDecoration(
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                      width: 1,
                      color:
                          isDark ? AppThemeData.grey800 : AppThemeData.grey100),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SvgPicture.asset(
                  "assets/icons/ic_debit.svg",
                  height: 16,
                  width: 16,
                ),
              ),
            ),
            const SizedBox(
              width: 10,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              transactionModel.note.toString(),
                              style: TextStyle(
                                fontSize: 16,
                                fontFamily: AppThemeData.semiBold,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppThemeData.grey100
                                    : AppThemeData.grey800,
                              ),
                            ),
                            Text(
                              // "(${transactionModel.withdrawMethod!.capitalizeString()})",
                              '(Bank)',
                              style: TextStyle(
                                fontSize: 14,
                                fontFamily: AppThemeData.medium,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppThemeData.grey100
                                    : AppThemeData.grey800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        "-${Constant.amountShow(amount: transactionModel.amount.toString())}",
                        style: const TextStyle(
                          fontSize: 16,
                          fontFamily: AppThemeData.medium,
                          color: AppThemeData.danger300,
                        ),
                      )
                    ],
                  ),
                  const SizedBox(
                    height: 2,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          transactionModel.paymentStatus.toString(),
                          style: TextStyle(
                            fontSize: 14,
                            fontFamily: AppThemeData.semiBold,
                            fontWeight: FontWeight.w600,
                            color: transactionModel.paymentStatus == "Success"
                                ? AppThemeData.success400
                                : transactionModel.paymentStatus == "Pending"
                                    ? AppThemeData.primary300
                                    : AppThemeData.danger300,
                          ),
                        ),
                      ),
                      Text(
                        Constant.timestampToDateTime(transactionModel.paidDate),
                        style: TextStyle(
                            fontSize: 12,
                            fontFamily: AppThemeData.medium,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? AppThemeData.grey200
                                : AppThemeData.grey700),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTransactionCard({
    required WithdrawHistoryModel withdrawHistory,
    required DateTime date,
  }) {
    final size = MediaQuery.sizeOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3),
      child: GestureDetector(
        onTap: () => showWithdrawalModelSheet(context, withdrawHistory),
        child: Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipOval(
                  child: Container(
                    color: Colors.green.withOpacity(0.06),
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Icon(Icons.account_balance_wallet_rounded,
                          size: 28, color: Color(0xFF00B761)),
                    ),
                  ),
                ),
                SizedBox(
                  width: size.width * 0.75,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 5.0),
                        child: SizedBox(
                          width: size.width * 0.52,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "${DateFormat('MMM dd, yyyy, KK:mma').format(withdrawHistory.paidDate.toDate()).toUpperCase()}",
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 17,
                                ),
                              ),
                              SizedBox(
                                height: 10,
                              ),
                              Opacity(
                                opacity: 0.75,
                                child: Text(
                                  withdrawHistory.paymentStatus,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 17,
                                    color: withdrawHistory.paymentStatus ==
                                            "Success"
                                        ? Colors.green
                                        : Colors.deepOrangeAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 3.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              " ${amountShow(amount: withdrawHistory.amount.toString())}",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color:
                                    withdrawHistory.paymentStatus == "Success"
                                        ? Colors.green
                                        : Colors.deepOrangeAccent,
                                fontSize: 18,
                              ),
                            ),
                            SizedBox(
                              height: 20,
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 15,
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // void _handlePaymentSuccess(PaymentSuccessResponse response) {
  //   paymentCompleted(paymentMethod: "RazorPay");
  // }

  // void _handleExternalWaller(ExternalWalletResponse response) {
  //   Navigator.pop(context);
  //   ScaffoldMessenger.of(context).showSnackBar(SnackBar(
  //     content: Text(
  //       "Payment Processing Via".tr() + "\n" + response.walletName!,
  //     ),
  //     backgroundColor: Colors.blue.shade400,
  //     duration: Duration(seconds: 8),
  //   ));
  // }

  // void _handlePaymentError(PaymentFailureResponse response) {
  //   Navigator.pop(context);
  //   ScaffoldMessenger.of(context).showSnackBar(SnackBar(
  //     content: Text(
  //       "Payment Failed!!".tr() +
  //           "\n" +
  //           jsonDecode(response.message!)['error']['description'],
  //     ),
  //     backgroundColor: Colors.red.shade400,
  //     duration: Duration(seconds: 8),
  //   ));
  // }

  withdrawAmountBottomSheet(BuildContext context) {
    return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        isDismissible: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(30),
          ),
        ),
        clipBehavior: Clip.antiAliasWithSaveLayer,
        builder: (context) {
          return FractionallySizedBox(
            heightFactor: 0.8,
            child: StatefulBuilder(builder: (context, setState) {
              final themeController = Get.find<ThemeController>();
              final isDark = themeController.isDark.value;
              return Scaffold(
                body: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                "Withdrawal".tr(),
                                style: TextStyle(
                                    color: isDark
                                        ? AppThemeData.grey100
                                        : AppThemeData.grey800,
                                    fontSize: 18,
                                    fontFamily: AppThemeData.semiBold),
                              ),
                            ),
                            InkWell(
                                onTap: () {
                                  Get.back();
                                },
                                child: const Icon(Icons.close)),
                          ],
                        ),
                      ),
                      TextFieldWidget(
                        title: 'Withdrawal amount'.tr(),
                        controller: _amountController,
                        hintText: 'Enter withdrawal amount'.tr(),
                        textInputType: const TextInputType.numberWithOptions(
                            signed: true, decimal: true),
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp('[0-9]')),
                        ],
                        prefix: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          child: Text(
                            "${Constant.currencyModel!.symbol}".tr(),
                            style: TextStyle(
                                color: isDark
                                    ? AppThemeData.grey50
                                    : AppThemeData.grey900,
                                fontFamily: AppThemeData.semiBold,
                                fontSize: 18),
                          ),
                        ),
                      ),
                      TextFieldWidget(
                        title: 'Notes'.tr(),
                        controller: _noteController,
                        hintText: 'Add Notes'.tr(),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          "Select Withdraw Method".tr(),
                          style: TextStyle(
                              color: isDark
                                  ? AppThemeData.grey100
                                  : AppThemeData.grey800,
                              fontSize: 16,
                              fontFamily: AppThemeData.medium),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                            borderRadius:
                                const BorderRadius.all(Radius.circular(20)),
                            color: isDark
                                ? AppThemeData.grey900
                                : AppThemeData.grey50),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          child: Column(
                            children: [
                              Constant.userModel!.userBankDetails == null ||
                                      Constant.userModel!.userBankDetails!
                                          .accountNumber.isEmpty
                                  ? const SizedBox()
                                  : InkWell(
                                      onTap: () {},
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 50,
                                            height: 50,
                                            decoration: ShapeDecoration(
                                              shape: RoundedRectangleBorder(
                                                side: BorderSide(
                                                    width: 1,
                                                    color: isDark
                                                        ? AppThemeData.grey700
                                                        : AppThemeData.grey200),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(10),
                                              child: SvgPicture.asset(
                                                  "assets/icons/ic_building_four.svg"),
                                            ),
                                          ),
                                          const SizedBox(
                                            width: 10,
                                          ),
                                          Expanded(
                                            child: Text(
                                              "Bank Transfer".tr(),
                                              style: TextStyle(
                                                  color: isDark
                                                      ? AppThemeData.grey50
                                                      : AppThemeData.grey900,
                                                  fontSize: 16,
                                                  fontFamily:
                                                      AppThemeData.medium),
                                            ),
                                          ),
                                          Radio(
                                            value: 0,
                                            groupValue: 0,
                                            activeColor:
                                                AppThemeData.primary300,
                                            // onChanged: (value) {
                                            //   controller.selectedValue
                                            //       .value = value!;
                                            // },
                                          ),
                                        ],
                                      ),
                                    ),
                              const SizedBox(
                                height: 10,
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Padding(
                      //   padding: const EdgeInsets.symmetric(
                      //       horizontal: 15.0, vertical: 25),
                      //   child: Container(
                      //     decoration: BoxDecoration(
                      //         borderRadius: BorderRadius.circular(18),
                      //         border: Border.all(
                      //             color: Color(COLOR_ACCENt1), width: 4)),
                      //     child: Padding(
                      //       padding: const EdgeInsets.symmetric(
                      //           vertical: 15.0, horizontal: 15),
                      //       child: Column(
                      //         crossAxisAlignment: CrossAxisAlignment.start,
                      //         children: [
                      //           Row(
                      //             mainAxisAlignment:
                      //                 MainAxisAlignment.spaceBetween,
                      //             children: [
                      //               Text(
                      //                 userBankDetail!.bankName,
                      //                 style: TextStyle(
                      //                   fontSize: 22,
                      //                   fontWeight: FontWeight.bold,
                      //                   color: Color(COLOR_PRIMARY_DARK),
                      //                 ),
                      //               ),
                      //               Icon(
                      //                 Icons.account_balance,
                      //                 size: 40,
                      //                 color: Color(COLOR_ACCENt1),
                      //               ),
                      //             ],
                      //           ),
                      //           SizedBox(
                      //             height: 2,
                      //           ),
                      //           Text(
                      //             userBankDetail!.accountNumber,
                      //             style: TextStyle(
                      //               fontSize: 20,
                      //               fontWeight: FontWeight.w600,
                      //               color: isDark
                      //                   ? Colors.white.withOpacity(0.9)
                      //                   : Color(DARK_COLOR).withOpacity(0.9),
                      //             ),
                      //           ),
                      //           SizedBox(
                      //             height: 10,
                      //           ),
                      //           Text(
                      //             userBankDetail!.holderName,
                      //             style: TextStyle(
                      //               fontSize: 18,
                      //               fontWeight: FontWeight.bold,
                      //               color: isDark
                      //                   ? Colors.white.withOpacity(0.7)
                      //                   : Color(DARK_COLOR).withOpacity(0.7),
                      //             ),
                      //           ),
                      //           SizedBox(
                      //             height: 4,
                      //           ),
                      //           Row(
                      //             mainAxisAlignment:
                      //                 MainAxisAlignment.spaceBetween,
                      //             children: [
                      //               Text(
                      //                 userBankDetail!.otherDetails,
                      //                 style: TextStyle(
                      //                   fontSize: 20,
                      //                   color: isDark
                      //                       ? Colors.white.withOpacity(0.9)
                      //                       : Color(DARK_COLOR)
                      //                           .withOpacity(0.9),
                      //                 ),
                      //               ),
                      //               Text(
                      //                 userBankDetail!.branchName,
                      //                 style: TextStyle(
                      //                   fontSize: 18,
                      //                   color: isDark
                      //                       ? Colors.white.withOpacity(0.7)
                      //                       : Color(DARK_COLOR)
                      //                           .withOpacity(0.7),
                      //                 ),
                      //               ),
                      //             ],
                      //           ),
                      //           SizedBox(
                      //             height: 10,
                      //           ),
                      //         ],
                      //       ),
                      //     ),
                      //   ),
                      // ),
                      // Row(
                      //   children: [
                      //     Padding(
                      //       padding: const EdgeInsets.symmetric(
                      //           horizontal: 20.0, vertical: 5),
                      //       child: RichText(
                      //         text: TextSpan(
                      //           text: "Amount to Withdraw".tr(),
                      //           style: TextStyle(
                      //             fontSize: 16,
                      //             color: isDark
                      //                 ? Colors.white70
                      //                 : Color(DARK_COLOR).withOpacity(0.7),
                      //           ),
                      //         ),
                      //       ),
                      //     ),
                      //   ],
                      // ),
                      // Form(
                      //   key: _globalKey,
                      //   child: Padding(
                      //     padding: const EdgeInsets.symmetric(
                      //         horizontal: 20.0, vertical: 2),
                      //     child: Padding(
                      //       padding: const EdgeInsets.symmetric(
                      //           vertical: 0.0, horizontal: 8),
                      //       child: TextFormField(
                      //         controller: _amountController,
                      //         style: TextStyle(
                      //           color: Color(COLOR_PRIMARY_DARK),
                      //           fontSize: 20,
                      //           fontWeight: FontWeight.w700,
                      //         ),
                      //         //initialValue:"50",
                      //         maxLines: 1,
                      //         validator: (value) {
                      //           if (value!.isEmpty) {
                      //             return "*required Field".tr();
                      //           } else {
                      //             if (double.parse(value) <= 0) {
                      //               return "*Invalid Amount".tr();
                      //             } else if (double.parse(value) >
                      //                 double.parse(Constant
                      //                     .userModel!.walletAmount
                      //                     .toString())) {
                      //               return "*withdraw is more then wallet balance"
                      //                   .tr();
                      //             } else {
                      //               return null;
                      //             }
                      //           }
                      //         },
                      //         inputFormatters: [
                      //           FilteringTextInputFormatter.allow(
                      //               RegExp(r'^\d+\.?\d{0,2}')),
                      //         ],
                      //         keyboardType: TextInputType.numberWithOptions(
                      //             decimal: true),
                      //         decoration: InputDecoration(
                      //           prefix: Padding(
                      //             padding: const EdgeInsets.symmetric(
                      //                 horizontal: 12.0, vertical: 2),
                      //             child: Text(
                      //               "${currencyData!.symbol}",
                      //               style: TextStyle(
                      //                 color: isDark
                      //                     ? Colors.white
                      //                     : Color(DARK_COLOR),
                      //                 fontSize: 20,
                      //                 fontWeight: FontWeight.w700,
                      //               ),
                      //             ),
                      //           ),
                      //           fillColor: Colors.grey[200],
                      //           focusedBorder: OutlineInputBorder(
                      //               borderRadius: BorderRadius.circular(5.0),
                      //               borderSide: BorderSide(
                      //                   color: Color(COLOR_PRIMARY),
                      //                   width: 1.50)),
                      //           errorBorder: OutlineInputBorder(
                      //             borderSide: BorderSide(
                      //                 color:
                      //                     Theme.of(context).colorScheme.error),
                      //             borderRadius: BorderRadius.circular(5.0),
                      //           ),
                      //           focusedErrorBorder: OutlineInputBorder(
                      //             borderSide: BorderSide(
                      //                 color:
                      //                     Theme.of(context).colorScheme.error),
                      //             borderRadius: BorderRadius.circular(5.0),
                      //           ),
                      //           enabledBorder: OutlineInputBorder(
                      //             borderSide:
                      //                 BorderSide(color: Colors.grey.shade400),
                      //             borderRadius: BorderRadius.circular(5.0),
                      //           ),
                      //         ),
                      //       ),
                      //     ),
                      //   ),
                      // ),
                      // Padding(
                      //   padding: const EdgeInsets.symmetric(
                      //       horizontal: 25, vertical: 10),
                      //   child: TextFormField(
                      //     controller: _noteController,
                      //     style: TextStyle(
                      //       color: Color(COLOR_PRIMARY_DARK),
                      //       fontSize: 20,
                      //       fontWeight: FontWeight.w700,
                      //     ),
                      //     //initialValue:"50",
                      //     maxLines: 1,
                      //     validator: (value) {
                      //       if (value!.isEmpty) {
                      //         return "*required Field".tr();
                      //       }
                      //       return null;
                      //     },
                      //     keyboardType: TextInputType.text,
                      //     decoration: InputDecoration(
                      //       hintText: 'Add note'.tr(),
                      //       fillColor: Colors.grey[200],
                      //       focusedBorder: OutlineInputBorder(
                      //           borderRadius: BorderRadius.circular(5.0),
                      //           borderSide: BorderSide(
                      //               color: Color(COLOR_PRIMARY), width: 1.50)),
                      //       errorBorder: OutlineInputBorder(
                      //         borderSide: BorderSide(
                      //             color: Theme.of(context).colorScheme.error),
                      //         borderRadius: BorderRadius.circular(5.0),
                      //       ),
                      //       focusedErrorBorder: OutlineInputBorder(
                      //         borderSide: BorderSide(
                      //             color: Theme.of(context).colorScheme.error),
                      //         borderRadius: BorderRadius.circular(5.0),
                      //       ),
                      //       enabledBorder: OutlineInputBorder(
                      //         borderSide:
                      //             BorderSide(color: Colors.grey.shade400),
                      //         borderRadius: BorderRadius.circular(5.0),
                      //       ),
                      //     ),
                      //   ),
                      // ),
                      // Padding(
                      //   padding: const EdgeInsets.symmetric(vertical: 10.0),
                      //   child: buildButton(context, title: "WITHDRAW".tr(),
                      //       onPress: () {
                      //     if (_globalKey.currentState!.validate()) {
                      //       print("------->");
                      //       print(minimumAmountToWithdrawal);
                      //       print(_amountController.text);
                      //       if (double.parse(minimumAmountToWithdrawal) >
                      //           double.parse(_amountController.text)) {
                      //         showAlertDialog(
                      //             context,
                      //             "Failed!".tr(),
                      //             '${"Withdraw amount must be greater or equal to".tr()} ${amountShow(amount: minimumAmountToWithdrawal)}'
                      //                 .tr(),
                      //             true);
                      //       } else {
                      //         withdrawRequest();
                      //       }
                      //     }
                      //   }),
                      // ),
                    ],
                  ),
                ),
                bottomNavigationBar: Container(
                  color: isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: RoundedButtonFill(
                      title: "Withdraw".tr(),
                      height: 5.5,
                      color: AppThemeData.primary300,
                      textColor: AppThemeData.grey50,
                      fontSizes: 16,
                      onPress: () async {
                        if (_amountController.text.isEmpty) {
                          ShowToastDialog.showToast("Please enter amount".tr());
                        } else if (double.parse(minimumAmountToWithdrawal) >
                            double.parse(_amountController.text.trim())) {
                          ShowToastDialog.showToast(
                              "${'Withdraw amount must be greater or equal to'.tr()} ${Constant.amountShow(amount: minimumAmountToWithdrawal)}");
                        } else {
                          withdrawRequest();
                        }
                      },
                    ),
                  ),
                ),
              );
            }),
          );
        });
  }

  withdrawRequest() {
    Navigator.pop(context);
    showLoadingAlert();
    FireStoreUtils.createPaymentId(collectionName: driverPayouts).then((value) {
      final paymentID = value;

      WithdrawHistoryModel withdrawHistory = WithdrawHistoryModel(
          amount: double.parse(_amountController.text),
          driverId: userId,
          vendorID: userId,
          paymentStatus: "Pending".tr(),
          paidDate: Timestamp.now(),
          id: paymentID.toString(),
          note: _noteController.text,
          role: 'driver');

      FireStoreUtils.withdrawWalletAmount(withdrawHistory: withdrawHistory)
          .then((value) {
        FireStoreUtils.updateCurrentUserWallet(
                userId: userId, amount: -double.parse(_amountController.text))
            .whenComplete(() {
          Navigator.pop(_scaffoldKey.currentContext!);
          FireStoreUtils.sendPayoutMail(
              amount: _amountController.text,
              payoutrequestid: paymentID.toString());
          ScaffoldMessenger.of(_scaffoldKey.currentContext!)
              .showSnackBar(SnackBar(
            content: Text("Payment Successful!! \n".tr()),
            backgroundColor: Colors.green,
          ));
        });
      });
    });
  }

  withdrawalHistoryBottomSheet(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(25), topRight: Radius.circular(25)),
        ),
        builder: (context) {
          return StatefulBuilder(builder: (context, setState) {
            return Container(
              height: size.height,
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 80.0),
                    child: showWithdrawalHistory(context,
                        query: withdrawalHistoryQuery),
                  ),
                  Positioned(
                    top: 40,
                    left: 15,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.arrow_back_ios,
                      ),
                    ),
                  ),
                ],
              ),
            );
          });
        });
  }

  buildButton(context,
      {required String title,
      double width = 0.9,
      required Function()? onPress}) {
    final size = MediaQuery.sizeOf(context);
    return SizedBox(
      width: size.width * width,
      child: MaterialButton(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        color: Color(0xFF00B761),
        height: 45,
        elevation: 0.0,
        onPressed: onPress,
        child: Text(
          title,
          style: TextStyle(fontSize: 15, color: Colors.white),
        ),
      ),
    );
  }

  buildTransButton(context,
      {required String title,
      double width = 0.9,
      required Function()? onPress}) {
    final size = MediaQuery.sizeOf(context);
    return SizedBox(
      width: size.width * width,
      child: MaterialButton(
        shape: RoundedRectangleBorder(
            side: BorderSide(color: Color(0xFF00B761), width: 1),
            borderRadius: BorderRadius.circular(6)),
        color: Colors.transparent,
        height: 45,
        elevation: 0.0,
        onPressed: onPress,
        child: Text(
          title,
          style: TextStyle(fontSize: 15, color: Color(0xFF00B761)),
        ),
      ),
    );
  }

  showLoadingAlert() {
    return showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              CircularProgressIndicator(),
              Text('Please wait!!'.tr()),
            ],
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                SizedBox(
                  height: 15,
                ),
                Text(
                  'Please wait!! while completing Transaction'.tr(),
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(
                  height: 15,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

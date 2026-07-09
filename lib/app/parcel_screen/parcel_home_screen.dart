// import 'dart:async';
// import 'dart:developer';
// import 'dart:math' as math;
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:door_delights_driver/services/show_toast_dialog.dart';
// import 'package:door_delights_driver/themes/theme_controller.dart';
// import 'package:easy_localization/easy_localization.dart';
// import 'package:door_delights_driver/constants.dart';
// import 'package:door_delights_driver/services/FirebaseHelper.dart';
// import 'package:door_delights_driver/services/helper.dart';
// import 'package:door_delights_driver/ui/chat_screen/chat_screen.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_polyline_points/flutter_polyline_points.dart';
// import 'package:geoflutterfire2/geoflutterfire2.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:get/instance_manager.dart';
// import 'package:get/state_manager.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:url_launcher/url_launcher.dart' as UrlLauncher;
// import '../../constant/constant.dart';
// import '../../models/parcel_order_model.dart';
// import '../../models/user_model.dart';
// import '../../services/audio_player_service.dart';
// import 'parcel_images_show.dart';

// class ParcelHomeScreen extends StatefulWidget {
//   const ParcelHomeScreen({Key? key}) : super(key: key);

//   @override
//   State<ParcelHomeScreen> createState() => _ParcelHomeScreenState();
// }

// class _ParcelHomeScreenState extends State<ParcelHomeScreen>
//     with SingleTickerProviderStateMixin {
//   final fireStoreUtils = FireStoreUtils();

//   GoogleMapController? _mapController;
//   bool canShowSheet = true;

//   BitmapDescriptor? departureIcon;
//   BitmapDescriptor? destinationIcon;
//   BitmapDescriptor? taxiIcon;

//   Map<PolylineId, Polyline> polyLines = {};
//   PolylinePoints polylinePoints = PolylinePoints(apiKey: GOOGLE_API_KEY);
//   final Map<String, Marker> _markers = {};

//   setIcons() async {
//     BitmapDescriptor.fromAssetImage(
//       const ImageConfiguration(size: Size(10, 10)),
//       "assets/images/pickup.png",
//     ).then((value) {
//       departureIcon = value;
//     });

//     BitmapDescriptor.fromAssetImage(
//       const ImageConfiguration(size: Size(10, 10)),
//       "assets/images/dropoff.png",
//     ).then((value) {
//       destinationIcon = value;
//     });

//     BitmapDescriptor.fromAssetImage(
//       const ImageConfiguration(size: Size(10, 10)),
//       Constant.userModel?.vehicleType == 'Car'
//           ? "assets/images/ic_taxi.png"
//           : Constant.userModel?.vehicleType == 'Tuk Tuk'
//               ? 'assets/icons/ic_tuk.png'
//               : 'assets/icons/ic_bike.png',
//     ).then((value) {
//       taxiIcon = value;
//     });
//   }

//   Timer? _timer;

//   void startTimer(UserModel _driverModel) {
//     const oneSec = const Duration(seconds: 1);
//     _timer = new Timer.periodic(oneSec, (Timer timer) async {
//       if (driverOrderAcceptRejectDuration == 0) {
//         timer.cancel();
//         if (_driverModel.orderParcelRequestData != null) {
//           await rejectOrder();
//           // Navigator.pop(context);
//         }
//       } else {
//         driverOrderAcceptRejectDuration--;
//       }
//     });
//   }

//   updateDriverOrder() async {
//     log("Update Driver Order");
//     Timestamp startTimestamp = Timestamp.now();
//     Timestamp endTimestamp = Timestamp.now();

//     DateTime currentDate = startTimestamp.toDate();
//     currentDate = currentDate.subtract(Duration(hours: 3));
//     startTimestamp = Timestamp.fromDate(currentDate);

//     List<ParcelOrderModel> orders = [];

//     print('-->startTime${startTimestamp.toDate()}');
//     print('-->endTime${endTimestamp.toDate()}');
//     await FirebaseFirestore.instance
//         .collection(PARCELORDER)
//         .where(
//           'status',
//           whereIn: [ORDER_STATUS_PLACED, ORDER_STATUS_DRIVER_REJECTED],
//         )
//         .where('senderPickupDateTime', isGreaterThan: startTimestamp)
//         .where('senderPickupDateTime', isLessThan: endTimestamp)
//         .get()
//         .then((value) async {
//           print('---->${value.docs.length}');
//           await Future.forEach(value.docs, (
//             QueryDocumentSnapshot<Map<String, dynamic>> element,
//           ) {
//             try {
//               orders.add(ParcelOrderModel.fromJson(element.data()));
//             } catch (e, s) {
//               print('watchOrdersStatus parse error ${element.id}$e $s');
//             }
//           });
//         });

//     orders.forEach((element) {
//       ParcelOrderModel orderModel = element;
//       print('---->${orderModel.id}');
//       orderModel.triggerDelevery = Timestamp.now();
//       orderModel.sendToDriver = true;
//       FirebaseFirestore.instance
//           .collection(PARCELORDER)
//           .doc(element.id)
//           .set(orderModel.toJson(), SetOptions(merge: true))
//           .then((order) {
//         print('Done.');
//       });
//     });
//   }

//   AnimationController? _animationController;

//   setSound() async {
//     await AudioPlayerService.initAudio();
//   }

//   playSound(bool isPlay) async {
//     await AudioPlayerService.playSound(isPlay);
//   }

//   @override
//   void initState() {
//     getDriver();
//     setIcons();
//     updateDriverOrder();
//     setSound();
//     _animationController = new AnimationController(
//       vsync: this,
//       duration: Duration(seconds: 1),
//     );
//     _animationController!.repeat(reverse: true);
//     super.initState();
//   }

//   @override
//   void dispose() {
//     _animationController!.dispose();
//     if (FireStoreUtils().driverStreamSub != null) {
//       FireStoreUtils().driverStreamSub!.cancel();
//     }
//     FireStoreUtils().parcelOrdersStreamController.close();
//     FireStoreUtils().parcelOrdersStreamSub.cancel();
//     if (_timer != null) {
//       _timer!.cancel();
//     }
//     playSound(false);
//     super.dispose();
//   }

//   bool isShow = false;

//   @override
//   Widget build(BuildContext context) {
//     final themeController = Get.find<ThemeController>();

//     return Obx(() {
//       final isDark = themeController.isDark.value;

//       isDark
//           ? _mapController?.setMapStyle(
//               '[{"featureType": "all","'
//               'elementType": "'
//               'geo'
//               'met'
//               'ry","stylers": [{"color": "#242f3e"}]},{"featureType": "all","elementType": "labels.text.stroke","stylers": [{"lightness": -80}]},{"featureType": "administrative","elementType": "labels.text.fill","stylers": [{"color": "#746855"}]},{"featureType": "administrative.locality","elementType": "labels.text.fill","stylers": [{"color": "#d59563"}]},{"featureType": "poi","elementType": "labels.text.fill","stylers": [{"color": "#d59563"}]},{"featureType": "poi.park","elementType": "geometry","stylers": [{"color": "#263c3f"}]},{"featureType": "poi.park","elementType": "labels.text.fill","stylers": [{"color": "#6b9a76"}]},{"featureType": "road","elementType": "geometry.fill","stylers": [{"color": "#2b3544"}]},{"featureType": "road","elementType": "labels.text.fill","stylers": [{"color": "#9ca5b3"}]},{"featureType": "road.arterial","elementType": "geometry.fill","stylers": [{"color": "#38414e"}]},{"featureType": "road.arterial","elementType": "geometry.stroke","stylers": [{"color": "#212a37"}]},{"featureType": "road.highway","elementType": "geometry.fill","stylers": [{"color": "#746855"}]},{"featureType": "road.highway","elementType": "geometry.stroke","stylers": [{"color": "#1f2835"}]},{"featureType": "road.highway","elementType": "labels.text.fill","stylers": [{"color": "#f3d19c"}]},{"featureType": "road.local","elementType": "geometry.fill","stylers": [{"color": "#38414e"}]},{"featureType": "road.local","elementType": "geometry.stroke","stylers": [{"color": "#212a37"}]},{"featureType": "transit","elementType": "geometry","stylers": [{"color": "#2f3948"}]},{"featureType": "transit.station","elementType": "labels.text.fill","stylers": [{"color": "#d59563"}]},{"featureType": "water","elementType": "geometry","stylers": [{"color": "#17263c"}]},{"featureType": "water","elementType": "labels.text.fill","stylers": [{"color": "#515c6d"}]},{"featureType": "water","elementType": "labels.text.stroke","stylers": [{"lightness": -20}]}]',
//             )
//           : _mapController?.setMapStyle(null);

//       return Scaffold(
//         body: Column(
//           children: [
//             Visibility(
//               visible: _driverModel!.inProgressOrderID == null &&
//                   (double.tryParse(_driverModel!.walletAmount.toString()) ??
//                           0) <
//                       (double.tryParse(minimumDepositToRideAccept) ?? 0),
//               child: Align(
//                 alignment: Alignment.topCenter,
//                 child: Container(
//                   color: Colors.black,
//                   child: Padding(
//                     padding: const EdgeInsets.all(8.0),
//                     child: Text(
//                       "${"You have to minimum ".tr()}${amountShow(amount: minimumDepositToRideAccept.toString())} ${"wallet amount to receiving Order".tr()}",
//                       style: TextStyle(color: Colors.white),
//                       textAlign: TextAlign.center,
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//             Expanded(
//               child: GoogleMap(
//                 onMapCreated: (controller) {
//                   _onMapCreated(controller, isDark);
//                 },
//                 myLocationEnabled:
//                     _driverModel!.inProgressOrderID != null ? false : true,
//                 myLocationButtonEnabled: true,
//                 mapType: MapType.terrain,
//                 zoomControlsEnabled: false,
//                 polylines: Set<Polyline>.of(polyLines.values),
//                 markers: _markers.values.toSet(),
//                 initialCameraPosition: CameraPosition(
//                   zoom: 15,
//                   target: LatLng(
//                     _driverModel!.location?.latitude ?? 0,
//                     _driverModel!.location?.longitude ?? 0,
//                   ),
//                 ),
//               ),
//             ),
//             _driverModel!.inProgressOrderID != null &&
//                     currentOrder != null &&
//                     isShow == true
//                 ? buildOrderActionsCard()
//                 : Container(),
//             _driverModel!.orderParcelRequestData != null
//                 ? showDriverBottomSheet()
//                 : Container(),
//           ],
//         ),
//         floatingActionButton: _driverModel!.orderParcelRequestData != null ||
//                 _driverModel!.inProgressOrderID == null
//             ? null
//             : FloatingActionButton(
//                 onPressed: () {
//                   setState(() {
//                     if (isShow == true) {
//                       isShow = false;
//                     } else {
//                       isShow = true;
//                     }
//                   });
//                 },
//                 child: Icon(
//                   isShow ? Icons.close : Icons.remove_red_eye,
//                   color: Colors.white,
//                   size: 29,
//                 ),
//                 backgroundColor: Colors.black,
//                 // backgroundColor: Color(COLOR_PRIMARY),
//                 tooltip: 'Capture Picture',
//                 elevation: 5,
//                 splashColor: Colors.grey,
//               ),
//       );
//     });
//   }

//   void _onMapCreated(GoogleMapController controller, bool isDark) {
//     _mapController = controller;

//     controller.animateCamera(
//       CameraUpdate.newCameraPosition(
//         CameraPosition(
//           target: LatLng(
//             Constant.userModel?.location?.latitude ?? 0.0,
//             Constant.userModel?.location?.longitude ?? 0.0,
//           ),
//           zoom: 14,
//         ),
//       ),
//     );
//     setState(() {});
//     if (isDark)
//       _mapController?.setMapStyle(
//         '[{"featureType": "all","'
//         'elementType": "'
//         'geo'
//         'met'
//         'ry","stylers": [{"color": "#242f3e"}]},{"featureType": "all","elementType": "labels.text.stroke","stylers": [{"lightness": -80}]},{"featureType": "administrative","elementType": "labels.text.fill","stylers": [{"color": "#746855"}]},{"featureType": "administrative.locality","elementType": "labels.text.fill","stylers": [{"color": "#d59563"}]},{"featureType": "poi","elementType": "labels.text.fill","stylers": [{"color": "#d59563"}]},{"featureType": "poi.park","elementType": "geometry","stylers": [{"color": "#263c3f"}]},{"featureType": "poi.park","elementType": "labels.text.fill","stylers": [{"color": "#6b9a76"}]},{"featureType": "road","elementType": "geometry.fill","stylers": [{"color": "#2b3544"}]},{"featureType": "road","elementType": "labels.text.fill","stylers": [{"color": "#9ca5b3"}]},{"featureType": "road.arterial","elementType": "geometry.fill","stylers": [{"color": "#38414e"}]},{"featureType": "road.arterial","elementType": "geometry.stroke","stylers": [{"color": "#212a37"}]},{"featureType": "road.highway","elementType": "geometry.fill","stylers": [{"color": "#746855"}]},{"featureType": "road.highway","elementType": "geometry.stroke","stylers": [{"color": "#1f2835"}]},{"featureType": "road.highway","elementType": "labels.text.fill","stylers": [{"color": "#f3d19c"}]},{"featureType": "road.local","elementType": "geometry.fill","stylers": [{"color": "#38414e"}]},{"featureType": "road.local","elementType": "geometry.stroke","stylers": [{"color": "#212a37"}]},{"featureType": "transit","elementType": "geometry","stylers": [{"color": "#2f3948"}]},{"featureType": "transit.station","elementType": "labels.text.fill","stylers": [{"color": "#d59563"}]},{"featureType": "water","elementType": "geometry","stylers": [{"color": "#17263c"}]},{"featureType": "water","elementType": "labels.text.fill","stylers": [{"color": "#515c6d"}]},{"featureType": "water","elementType": "labels.text.stroke","stylers": [{"lightness": -20}]}]',
//       );
//   }

//   Widget showDriverBottomSheet() {
//     double totalAmount = 0.0;
//     double adminComm = 0.0;

//     totalAmount = (double.parse(
//           _driverModel!.orderParcelRequestData!.subTotal!.toString(),
//         ) -
//         double.parse(
//           _driverModel!.orderParcelRequestData!.discount!.toString(),
//         ));
//     adminComm = (_driverModel!.orderParcelRequestData!.adminCommissionType ==
//             'percentage')
//         ? (totalAmount *
//                 double.parse(
//                   _driverModel!.orderParcelRequestData!.adminCommission!,
//                 )) /
//             100
//         : double.parse(_driverModel!.orderParcelRequestData!.adminCommission!);
//     return Padding(
//       padding: EdgeInsets.all(10),
//       child: Container(
//         padding: EdgeInsets.symmetric(vertical: 16, horizontal: 10),
//         decoration: BoxDecoration(
//           color: Color(0xff212121),
//           borderRadius: BorderRadius.all(Radius.circular(15)),
//         ),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           // crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             SizedBox(height: 5),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//               children: [
//                 Expanded(
//                   child: Text(
//                     "Trip Distance".tr(),
//                     style: TextStyle(
//                       color: Color(0xffADADAD),
//                       fontFamily: "Poppinsr",
//                       letterSpacing: 0.5,
//                     ),
//                   ),
//                 ),
//                 Text(
//                   "${_driverModel!.orderParcelRequestData!.distance.toString()} km",
//                   style: TextStyle(
//                     color: Color(0xffFFFFFF),
//                     fontFamily: "Poppinsm",
//                     letterSpacing: 0.5,
//                   ),
//                 ),
//               ],
//             ),
//             SizedBox(height: 5),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//               children: [
//                 Expanded(
//                   child: Text(
//                     "Delivery charge".tr(),
//                     style: TextStyle(
//                       color: Color(0xffADADAD),
//                       fontFamily: "Poppinsr",
//                       letterSpacing: 0.5,
//                     ),
//                   ),
//                 ),
//                 Text(
//                   "${amountShow(amount: totalAmount.toString())}",
//                   style: TextStyle(
//                     color: Color(0xffFFFFFF),
//                     fontFamily: "Poppinsm",
//                     letterSpacing: 0.5,
//                   ),
//                 ),
//               ],
//             ),
//             SizedBox(height: 5),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//               children: [
//                 Expanded(
//                   child: Text(
//                     'Admin commission'.tr(),
//                     style: TextStyle(
//                       color: Color(0xffADADAD),
//                       fontFamily: "Poppinsr",
//                       letterSpacing: 0.5,
//                     ),
//                   ),
//                 ),
//                 Text(
//                   "(-${amountShow(amount: adminComm.toString())})",
//                   style: TextStyle(
//                     color: Color(0xffFFFFFF),
//                     fontFamily: "Poppinsm",
//                     letterSpacing: 0.5,
//                   ),
//                 ),
//               ],
//             ),
//             SizedBox(height: 5),
//             Card(
//               color: Color(0xffFFFFFF),
//               child: Padding(
//                 padding: const EdgeInsets.symmetric(
//                   vertical: 14.0,
//                   horizontal: 10,
//                 ),
//                 child: Row(
//                   children: [
//                     Image.asset('assets/images/location3x.png', height: 55),
//                     SizedBox(width: 10),
//                     Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         SizedBox(
//                           width: 270,
//                           child: Text(
//                             "${_driverModel!.orderParcelRequestData!.sender!.address} ",
//                             maxLines: 1,
//                             overflow: TextOverflow.ellipsis,
//                             style: TextStyle(
//                               color: Color(0xff333333),
//                               fontFamily: "Poppinsr",
//                               letterSpacing: 0.5,
//                             ),
//                           ),
//                         ),
//                         SizedBox(height: 22),
//                         SizedBox(
//                           width: 270,
//                           child: Text(
//                             "${_driverModel!.orderParcelRequestData!.receiver!.address}",
//                             maxLines: 1,
//                             overflow: TextOverflow.ellipsis,
//                             style: TextStyle(
//                               color: Color(0xff333333),
//                               fontFamily: "Poppinsr",
//                               letterSpacing: 0.5,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//             SizedBox(height: 10),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceAround,
//               children: [
//                 SizedBox(
//                   height: MediaQuery.sizeOf(context).height / 20,
//                   width: MediaQuery.sizeOf(context).width / 2.5,
//                   child: ElevatedButton(
//                     style: ElevatedButton.styleFrom(
//                       padding: const EdgeInsets.symmetric(
//                         vertical: 6,
//                         horizontal: 12,
//                       ),
//                       backgroundColor: Color(COLOR_PRIMARY),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.all(Radius.circular(5)),
//                       ),
//                     ),
//                     child: Text(
//                       'Reject'.tr(),
//                       style: TextStyle(
//                         color: Color(0xffFFFFFF),
//                         fontFamily: "Poppinsm",
//                         letterSpacing: 0.5,
//                       ),
//                     ),
//                     onPressed: () async {
//                       await playSound(false);
//                       showProgress(context, 'Rejecting order...'.tr(), false);
//                       try {
//                         await rejectOrder();
//                         hideProgress();
//                       } catch (e) {
//                         hideProgress();
//                         print('HomeScreenState.showDriverBottomSheet $e');
//                       }
//                     },
//                   ),
//                 ),
//                 SizedBox(
//                   height: MediaQuery.sizeOf(context).height / 20,
//                   width: MediaQuery.sizeOf(context).width / 2.5,
//                   child: ElevatedButton(
//                     style: ElevatedButton.styleFrom(
//                       padding: const EdgeInsets.symmetric(
//                         vertical: 6,
//                         horizontal: 12,
//                       ),
//                       backgroundColor: Color(COLOR_PRIMARY),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.all(Radius.circular(5)),
//                       ),
//                     ),
//                     child: Text(
//                       'Accept'.tr(),
//                       style: TextStyle(
//                         color: Color(0xffFFFFFF),
//                         fontFamily: "Poppinsm",
//                         letterSpacing: 0.5,
//                       ),
//                     ),
//                     onPressed: () async {
//                       await playSound(false);
//                       showProgress(context, 'Accepting order...'.tr(), false);
//                       if (_timer != null) {
//                         _timer!.cancel();
//                       }
//                       // Navigator.pop(context);
//                       try {
//                         await acceptOrder();
//                         hideProgress();
//                         //  setState(() {});
//                       } catch (e) {
//                         hideProgress();
//                         print('HomeScreenState.showDriverBottomSheet $e');
//                       }
//                     },
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   acceptOrder() async {
//     ParcelOrderModel orderModel = _driverModel!.orderParcelRequestData!;

//     _driverModel!.orderParcelRequestData = null;
//     _driverModel!.inProgressOrderID = orderModel.id;

//     Constant.userModel = _driverModel!;

//     await FireStoreUtils.updateCurrentUser(_driverModel!);

//     orderModel.status = ORDER_STATUS_DRIVER_ACCEPTED;
//     orderModel.driverId = _driverModel!.id;
//     orderModel.driver = _driverModel!;
//     await FireStoreUtils.updateParcelOrder(orderModel);

//     if (_driverModel!.inProgressOrderID != null) {
//       getCurrentOrder();
//     }
//     Map<String, dynamic> payLoad = <String, dynamic>{
//       "type": "parcel_order",
//       "orderId": orderModel.id,
//     };
//     await FireStoreUtils.sendFcmMessage(
//       parcelAccepted,
//       orderModel.author!.fcmToken ?? '',
//       payLoad,
//     );

//     setState(() {
//       isShow = true;
//     });
//   }

//   rejectOrder() async {
//     if (_timer != null) {
//       _timer!.cancel();
//     }
//     ParcelOrderModel orderModel = _driverModel!.orderParcelRequestData!;
//     if (orderModel.rejectedByDrivers == null) {
//       orderModel.rejectedByDrivers = [];
//     }
//     orderModel.rejectedByDrivers!.add(_driverModel!.id);
//     orderModel.status = ORDER_STATUS_DRIVER_REJECTED;
//     await FireStoreUtils.updateParcelOrder(orderModel);
//     _driverModel!.orderParcelRequestData = null;

//     await FireStoreUtils.updateCurrentUser(_driverModel!);
//   }

//   String? _lastRouteOrigin;
//   // String? _lastRouteDestination;
//   String? _lastOrderStatus;

//   getDirections() async {
//     if (currentOrder == null) return;

//     // Check if we need to recalculate the route
//     final currentStatus = currentOrder!.status;
//     final shouldRecalculate = _shouldRecalculateRoute(currentStatus!);

//     if (!shouldRecalculate) {
//       return;
//     }

//     LatLng origin;
//     LatLng destination;
//     bool includeDriverMarker = false;

//     if (currentStatus == ORDER_STATUS_SHIPPED ||
//         currentStatus == ORDER_STATUS_DRIVER_ACCEPTED) {
//       origin = LatLng(
//         _driverModel!.location?.latitude ?? 0,
//         _driverModel!.location?.longitude ?? 0,
//       );
//       destination = LatLng(
//         currentOrder!.senderLatLong!.latitude ?? 0,
//         currentOrder!.senderLatLong!.longitude ?? 0,
//       );
//       includeDriverMarker = true;
//     } else if (currentStatus == ORDER_STATUS_IN_TRANSIT) {
//       origin = LatLng(
//         _driverModel!.location?.latitude ?? 0,
//         _driverModel!.location?.longitude ?? 0,
//       );
//       destination = LatLng(
//         currentOrder!.receiverLatLong!.latitude ?? 0,
//         currentOrder!.receiverLatLong!.longitude ?? 0,
//       );
//       includeDriverMarker = true;
//     } else {
//       origin = LatLng(
//         currentOrder!.senderLatLong!.latitude ?? 0,
//         currentOrder!.senderLatLong!.longitude ?? 0,
//       );
//       destination = LatLng(
//         currentOrder!.receiverLatLong!.latitude ?? 0,
//         currentOrder!.receiverLatLong!.longitude ?? 0,
//       );
//     }

//     try {
//       List<LatLng> polylineCoordinates = await _getRouteCoordinates(
//         origin,
//         destination,
//       );

//       _updateMarkers(origin, destination, includeDriverMarker);
//       addPolyLine(polylineCoordinates);

//       // Cache the current route information
//       _lastRouteOrigin = "${origin.latitude},${origin.longitude}";
//       // _lastRouteDestination =
//       //     "${destination.latitude},${destination.longitude}";
//       _lastOrderStatus = currentStatus;
//     } catch (e) {
//       log("Error getting directions: $e");
//     }
//   }

//   bool _shouldRecalculateRoute(String currentStatus) {
//     // Always recalculate if order status changed
//     if (_lastOrderStatus != currentStatus) return true;

//     // Recalculate if driver location changed significantly (more than 100 meters)
//     if (_lastRouteOrigin != null && _driverModel != null) {
//       final currentOrigin =
//           "${_driverModel!.location?.latitude ?? 0},${_driverModel!.location?.longitude ?? 0}";
//       if (_lastRouteOrigin != currentOrigin) {
//         double distance = _calculateDistance(_lastRouteOrigin!, currentOrigin);
//         log("Distance: $distance");
//         return distance > 0.12;
//       }
//     }

//     return false;
//   }

//   double _calculateDistance(String origin1, String origin2) {
//     try {
//       List<String> parts1 = origin1.split(',');
//       List<String> parts2 = origin2.split(',');

//       double lat1 = double.parse(parts1[0]);
//       double lon1 = double.parse(parts1[1]);
//       double lat2 = double.parse(parts2[0]);
//       double lon2 = double.parse(parts2[1]);

//       double dLat = (lat2 - lat1) * 111319.9;
//       double dLon = (lon2 - lon1) * 111319.9 * math.cos(lat1 * 3.14159 / 180);

//       return math.sqrt(dLat * dLat + dLon * dLon) / 1000;
//     } catch (e) {
//       return 1.0;
//     }
//   }

//   Future<List<LatLng>> _getRouteCoordinates(
//     LatLng origin,
//     LatLng destination,
//   ) async {
//     log("Getting coordinates");
//     PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
//       request: PolylineRequest(
//         origin: PointLatLng(origin.latitude, origin.longitude),
//         destination: PointLatLng(destination.latitude, destination.longitude),
//         mode: TravelMode.driving,
//       ),
//     );

//     List<LatLng> polylineCoordinates = [];
//     if (result.points.isNotEmpty) {
//       for (var point in result.points) {
//         polylineCoordinates.add(LatLng(point.latitude, point.longitude));
//       }
//     }

//     log("Route calculated: ${polylineCoordinates.length} points");
//     return polylineCoordinates;
//   }

//   void _updateMarkers(
//     LatLng origin,
//     LatLng destination,
//     bool includeDriverMarker,
//   ) {
//     setState(() {
//       // Clear existing markers
//       _markers.clear();

//       // Add driver marker if needed
//       if (includeDriverMarker && _driverModel != null) {
//         _markers['Driver'] = Marker(
//           markerId: const MarkerId('Driver'),
//           infoWindow: const InfoWindow(title: "Driver"),
//           position: LatLng(
//             _driverModel!.location?.latitude ?? 0,
//             _driverModel!.location?.longitude ?? 0,
//           ),
//           icon: taxiIcon!,
//           rotation: double.parse(_driverModel!.rotation.toString()),
//         );
//       }

//       // Add departure marker
//       _markers['Departure'] = Marker(
//         markerId: const MarkerId('Departure'),
//         infoWindow: const InfoWindow(title: "Departure"),
//         position: LatLng(
//           currentOrder!.senderLatLong!.latitude ?? 0,
//           currentOrder!.senderLatLong!.longitude ?? 0,
//         ),
//         icon: departureIcon!,
//       );

//       // Add destination marker
//       _markers['Destination'] = Marker(
//         markerId: const MarkerId('Destination'),
//         infoWindow: const InfoWindow(title: "Destination"),
//         position: LatLng(
//           currentOrder!.receiverLatLong!.latitude ?? 0,
//           currentOrder!.receiverLatLong!.longitude ?? 0,
//         ),
//         icon: destinationIcon!,
//       );
//     });
//   }

//   addPolyLine(List<LatLng> polylineCoordinates) {
//     PolylineId id = const PolylineId("poly");
//     Polyline polyline = Polyline(
//       polylineId: id,
//       color: Color(COLOR_PRIMARY),
//       points: polylineCoordinates,
//       width: 4,
//       geodesic: true,
//     );
//     polyLines[id] = polyline;
//     setState(() {});
//   }

//   late Stream<ParcelOrderModel?> ordersFuture;
//   ParcelOrderModel? currentOrder;

//   late Stream<UserModel> driverStream;
//   UserModel? _driverModel = UserModel();

//   // Add this variable
//   bool _isFirstOrderLoad = true;

//   getCurrentOrder() async {
//     ordersFuture = FireStoreUtils().getParcelOrderByID(
//       Constant.userModel!.inProgressOrderID.toString(),
//     );

//     ordersFuture.listen((event) {
//       if (event == null) return;

//       final previousStatus = currentOrder?.status;
//       currentOrder = event;

//       if (currentOrder!.status == ORDER_STATUS_DRIVER_REJECTED ||
//           currentOrder!.status == ORDER_STATUS_DRIVER_PENDING ||
//           currentOrder!.status == ORDER_STATUS_ACCEPTED) {
//         currentOrder!.status = ORDER_STATUS_DRIVER_ACCEPTED;
//       }

//       // Only call getDirections if status changed or it's first load
//       if (_isFirstOrderLoad || previousStatus != currentOrder!.status) {
//         _isFirstOrderLoad = false;
//         getDirections();
//       }
//     });
//   }

//   getDriver() async {
//     driverStream = FireStoreUtils().getDriver(FireStoreUtils.getCurrentUid());
//     driverStream.listen((event) async {
//       _driverModel = event;
//       if (mounted) {
//         setState(() {
//           Constant.userModel = _driverModel;
//         });
//       }

//       getDirections();

//       if (_driverModel!.isActive == true) {
//         if (_driverModel!.orderParcelRequestData != null) {
//           playSound(true);
//         }
//       }
//       if (_driverModel!.inProgressOrderID != null) {
//         getCurrentOrder();
//       }
//       if (_driverModel!.orderParcelRequestData == null) {
//         playSound(false);
//         // setState(() {
//         // _markers.clear();
//         // polyLines.clear();
//         // });
//       }
//     });
//   }

//   Widget buildOrderActionsCard({
//     pedding = 10,
//     width = 60,
//     bool isDark = false,
//   }) {
//     bool isPickedUp = false;
//     String? buttonText;
//     String googleMapUrl = '';
//     if (currentOrder!.status == ORDER_STATUS_SHIPPED ||
//         currentOrder!.status == ORDER_STATUS_DRIVER_ACCEPTED) {
//       buttonText = 'Pick up Parcel'.tr();
//       isPickedUp = true;
//       googleMapUrl =
//           'https://www.google.com/maps/dir/?api=1&origin=${_driverModel!.location?.latitude ?? 0},${_driverModel!.location?.longitude ?? 0}&destination=${currentOrder!.senderLatLong!.latitude},${currentOrder!.senderLatLong!.longitude}&travelmode=driving';
//     } else if (currentOrder!.status == ORDER_STATUS_IN_TRANSIT) {
//       buttonText = 'Parcel delivery'.tr();
//       isPickedUp = false;
//       googleMapUrl =
//           'https://www.google.com/maps/dir/?api=1&origin=${_driverModel!.location?.latitude ?? 0},${_driverModel!.location?.longitude ?? 0}&destination=${currentOrder!.receiverLatLong!.latitude},${currentOrder!.receiverLatLong!.longitude}&travelmode=driving';
//     }
//     return Container(
//       margin: EdgeInsets.only(left: 8, right: 8),
//       padding: EdgeInsets.symmetric(vertical: 15),
//       width: MediaQuery.sizeOf(context).width,
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.only(
//           topLeft: Radius.circular(8),
//           topRight: Radius.circular(18),
//         ),
//         color: isDark ? Color(0xff000000) : Color(0xffFFFFFF),
//       ),
//       child: SingleChildScrollView(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Visibility(
//               visible: currentOrder!.paymentCollectByReceiver == true,
//               child: Center(
//                 child: Text(
//                   "Payment Collect by Receiver".tr(),
//                   style: TextStyle(
//                     fontSize: 16,
//                     color: isDark ? Color(0xffFFFFFF) : Color(0xff555555),
//                     fontFamily: "Poppinsr",
//                     fontWeight: FontWeight.bold,
//                     letterSpacing: 0.5,
//                   ),
//                 ),
//               ),
//             ),
//             if (currentOrder!.status == ORDER_STATUS_SHIPPED ||
//                 currentOrder!.status == ORDER_STATUS_DRIVER_ACCEPTED)
//               Column(
//                 children: [
//                   if (currentOrder!.paymentMethod?.toLowerCase() == 'cod' ||
//                       currentOrder!.paymentCollectByReceiver == true)
//                     ListTile(
//                       leading: Icon(
//                         Icons.monetization_on_rounded,
//                         size: 32,
//                         color: Color(COLOR_PRIMARY),
//                       ),
//                       title: Text(
//                         'Payment Collect From ${currentOrder!.paymentCollectByReceiver == true ? 'Receiver' : 'Sender'}: LKR ${(double.parse(currentOrder!.subTotal ?? '0.0') - double.parse(currentOrder!.discount ?? '0.0'))}',
//                         maxLines: 2,
//                         overflow: TextOverflow.ellipsis,
//                         style: TextStyle(
//                           color: isDark ? Color(0xffFFFFFF) : Color(0xff000000),
//                           fontFamily: "Poppinsm",
//                           fontSize: 14,
//                           letterSpacing: 0.5,
//                         ),
//                       ),
//                     ),
//                   ListTile(
//                     leading: Image.asset(
//                       'assets/images/user3x.png',
//                       height: 42,
//                       width: 42,
//                       color: Color(COLOR_PRIMARY),
//                     ),
//                     title: Text(
//                       'Sender Name',
//                       maxLines: 2,
//                       overflow: TextOverflow.ellipsis,
//                       style: TextStyle(
//                         color: isDark ? Color(0xffFFFFFF) : Color(0xff000000),
//                         fontFamily: "Poppinsm",
//                         letterSpacing: 0.5,
//                       ),
//                     ),
//                     subtitle: Padding(
//                       padding: const EdgeInsets.only(top: 4.0),
//                       child: Text(
//                         '${currentOrder!.sender!.name}'.tr(),
//                         style: TextStyle(
//                           color: Color(0xff555555),
//                           fontSize: 12,
//                           fontFamily: "Poppinsr",
//                           letterSpacing: 0.5,
//                         ),
//                       ),
//                     ),
//                     trailing: Column(
//                       mainAxisAlignment: MainAxisAlignment.start,
//                       children: [
//                         TextButton.icon(
//                           style: TextButton.styleFrom(
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(6.0),
//                               side: BorderSide(color: Color(0xff3DAE7D)),
//                             ),
//                             padding: EdgeInsets.zero,
//                             minimumSize: Size(85, 30),
//                             alignment: Alignment.center,
//                             backgroundColor: Color(0xffFFFFFF),
//                           ),
//                           onPressed: () {
//                             UrlLauncher.launchUrl(
//                               Uri.parse("tel://${currentOrder!.sender!.phone}"),
//                             );
//                           },
//                           icon: Image.asset(
//                             'assets/images/call3x.png',
//                             height: 14,
//                             width: 14,
//                           ),
//                           label: Text(
//                             "CALL".tr(),
//                             style: TextStyle(
//                               color: Color(0xff3DAE7D),
//                               fontFamily: "Poppinsm",
//                               letterSpacing: 0.5,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   ListTile(
//                     leading: Image.asset(
//                       'assets/images/user3x.png',
//                       height: 42,
//                       width: 42,
//                       color: Color(COLOR_PRIMARY),
//                     ),
//                     title: Text(
//                       'Receiver Name',
//                       maxLines: 2,
//                       overflow: TextOverflow.ellipsis,
//                       style: TextStyle(
//                         color: isDark ? Color(0xffFFFFFF) : Color(0xff000000),
//                         fontFamily: "Poppinsm",
//                         letterSpacing: 0.5,
//                       ),
//                     ),
//                     subtitle: Padding(
//                       padding: const EdgeInsets.only(top: 4.0),
//                       child: Text(
//                         '${currentOrder!.receiver!.name}'.tr(),
//                         style: TextStyle(
//                           color: Color(0xff555555),
//                           fontSize: 12,
//                           fontFamily: "Poppinsr",
//                           letterSpacing: 0.5,
//                         ),
//                       ),
//                     ),
//                     trailing: Column(
//                       mainAxisAlignment: MainAxisAlignment.start,
//                       children: [
//                         TextButton.icon(
//                           style: TextButton.styleFrom(
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(6.0),
//                               side: BorderSide(color: Color(0xff3DAE7D)),
//                             ),
//                             padding: EdgeInsets.zero,
//                             minimumSize: Size(85, 30),
//                             alignment: Alignment.center,
//                             backgroundColor: Color(0xffFFFFFF),
//                           ),
//                           onPressed: () {
//                             UrlLauncher.launchUrl(
//                               Uri.parse(
//                                 "tel://${currentOrder!.receiver!.phone}",
//                               ),
//                             );
//                           },
//                           icon: Image.asset(
//                             'assets/images/call3x.png',
//                             height: 14,
//                             width: 14,
//                           ),
//                           label: Text(
//                             "CALL".tr(),
//                             style: TextStyle(
//                               color: Color(0xff3DAE7D),
//                               fontFamily: "Poppinsm",
//                               letterSpacing: 0.5,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   ListTile(
//                     leading: Image.asset(
//                       'assets/images/user3x.png',
//                       height: 42,
//                       width: 42,
//                       color: Color(COLOR_PRIMARY),
//                     ),
//                     title: Text(
//                       '${currentOrder!.receiver!.address}',
//                       maxLines: 2,
//                       overflow: TextOverflow.ellipsis,
//                       style: TextStyle(
//                         color: isDark ? Color(0xffFFFFFF) : Color(0xff000000),
//                         fontFamily: "Poppinsm",
//                         letterSpacing: 0.5,
//                       ),
//                     ),
//                     subtitle: Row(
//                       children: [
//                         Padding(
//                           padding: const EdgeInsets.only(top: 4.0),
//                           child: Text(
//                             'ORDER ID '.tr(),
//                             style: TextStyle(
//                               color: Color(0xff555555),
//                               fontSize: 12,
//                               fontFamily: "Poppinsr",
//                               letterSpacing: 0.5,
//                             ),
//                           ),
//                         ),
//                         Padding(
//                           padding: const EdgeInsets.only(top: 4.0),
//                           child: SizedBox(
//                             width: MediaQuery.sizeOf(context).width / 4,
//                             child: Text(
//                               '${currentOrder!.id} ',
//                               maxLines: 1,
//                               overflow: TextOverflow.ellipsis,
//                               style: TextStyle(
//                                 fontSize: 12,
//                                 color: isDark
//                                     ? Color(0xffFFFFFF)
//                                     : Color(0xff000000),
//                                 fontFamily: "Poppinsr",
//                                 letterSpacing: 0.5,
//                               ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                     trailing: Column(
//                       mainAxisAlignment: MainAxisAlignment.start,
//                       children: [
//                         TextButton.icon(
//                           style: TextButton.styleFrom(
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(6.0),
//                               side: BorderSide(color: Color(0xff3DAE7D)),
//                             ),
//                             padding: EdgeInsets.zero,
//                             minimumSize: Size(85, 30),
//                             alignment: Alignment.center,
//                             backgroundColor: Color(0xffFFFFFF),
//                           ),
//                           onPressed: () {
//                             UrlLauncher.launchUrl(
//                               Uri.parse(
//                                 "tel://${currentOrder!.author!.phoneNumber}",
//                               ),
//                             );
//                           },
//                           icon: Image.asset(
//                             'assets/images/call3x.png',
//                             height: 14,
//                             width: 14,
//                           ),
//                           label: Text(
//                             "CALL".tr(),
//                             style: TextStyle(
//                               color: Color(0xff3DAE7D),
//                               fontFamily: "Poppinsm",
//                               letterSpacing: 0.5,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             SizedBox(height: 10),
//             if (currentOrder!.status == ORDER_STATUS_IN_TRANSIT)
//               Column(
//                 children: [
//                   if (currentOrder!.paymentMethod?.toLowerCase() == 'cod' ||
//                       currentOrder!.paymentCollectByReceiver == true)
//                     ListTile(
//                       leading: Icon(
//                         Icons.monetization_on_rounded,
//                         size: 32,
//                         color: Color(COLOR_PRIMARY),
//                       ),
//                       title: Text(
//                         'Payment Collect From ${currentOrder!.paymentCollectByReceiver == true ? 'Receiver' : 'Sender'}: LKR ${(double.parse(currentOrder!.subTotal ?? '0.0') - double.parse(currentOrder!.discount ?? '0.0'))}',
//                         maxLines: 2,
//                         overflow: TextOverflow.ellipsis,
//                         style: TextStyle(
//                           color: isDark ? Color(0xffFFFFFF) : Color(0xff000000),
//                           fontFamily: "Poppinsm",
//                           fontSize: 14,
//                           letterSpacing: 0.5,
//                         ),
//                       ),
//                     ),
//                   ListTile(
//                     leading: Image.asset(
//                       'assets/images/user3x.png',
//                       height: 42,
//                       width: 42,
//                       color: Color(COLOR_PRIMARY),
//                     ),
//                     title: Text(
//                       'Sender Name',
//                       maxLines: 2,
//                       overflow: TextOverflow.ellipsis,
//                       style: TextStyle(
//                         color: isDark ? Color(0xffFFFFFF) : Color(0xff000000),
//                         fontFamily: "Poppinsm",
//                         letterSpacing: 0.5,
//                       ),
//                     ),
//                     subtitle: Padding(
//                       padding: const EdgeInsets.only(top: 4.0),
//                       child: Text(
//                         '${currentOrder!.sender!.name}'.tr(),
//                         style: TextStyle(
//                           color: Color(0xff555555),
//                           fontSize: 12,
//                           fontFamily: "Poppinsr",
//                           letterSpacing: 0.5,
//                         ),
//                       ),
//                     ),
//                     trailing: Column(
//                       mainAxisAlignment: MainAxisAlignment.start,
//                       children: [
//                         TextButton.icon(
//                           style: TextButton.styleFrom(
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(6.0),
//                               side: BorderSide(color: Color(0xff3DAE7D)),
//                             ),
//                             padding: EdgeInsets.zero,
//                             minimumSize: Size(85, 30),
//                             alignment: Alignment.center,
//                             backgroundColor: Color(0xffFFFFFF),
//                           ),
//                           onPressed: () {
//                             UrlLauncher.launchUrl(
//                               Uri.parse("tel://${currentOrder!.sender!.phone}"),
//                             );
//                           },
//                           icon: Image.asset(
//                             'assets/images/call3x.png',
//                             height: 14,
//                             width: 14,
//                           ),
//                           label: Text(
//                             "CALL".tr(),
//                             style: TextStyle(
//                               color: Color(0xff3DAE7D),
//                               fontFamily: "Poppinsm",
//                               letterSpacing: 0.5,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   ListTile(
//                     leading: Image.asset(
//                       'assets/images/user3x.png',
//                       height: 42,
//                       width: 42,
//                       color: Color(COLOR_PRIMARY),
//                     ),
//                     title: Text(
//                       'Receiver Name',
//                       maxLines: 2,
//                       overflow: TextOverflow.ellipsis,
//                       style: TextStyle(
//                         color: isDark ? Color(0xffFFFFFF) : Color(0xff000000),
//                         fontFamily: "Poppinsm",
//                         letterSpacing: 0.5,
//                       ),
//                     ),
//                     subtitle: Padding(
//                       padding: const EdgeInsets.only(top: 4.0),
//                       child: Text(
//                         '${currentOrder!.receiver!.name}'.tr(),
//                         style: TextStyle(
//                           color: Color(0xff555555),
//                           fontSize: 12,
//                           fontFamily: "Poppinsr",
//                           letterSpacing: 0.5,
//                         ),
//                       ),
//                     ),
//                     trailing: Column(
//                       mainAxisAlignment: MainAxisAlignment.start,
//                       children: [
//                         TextButton.icon(
//                           style: TextButton.styleFrom(
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(6.0),
//                               side: BorderSide(color: Color(0xff3DAE7D)),
//                             ),
//                             padding: EdgeInsets.zero,
//                             minimumSize: Size(85, 30),
//                             alignment: Alignment.center,
//                             backgroundColor: Color(0xffFFFFFF),
//                           ),
//                           onPressed: () {
//                             UrlLauncher.launchUrl(
//                               Uri.parse(
//                                 "tel://${currentOrder!.receiver!.phone}",
//                               ),
//                             );
//                           },
//                           icon: Image.asset(
//                             'assets/images/call3x.png',
//                             height: 14,
//                             width: 14,
//                           ),
//                           label: Text(
//                             "CALL".tr(),
//                             style: TextStyle(
//                               color: Color(0xff3DAE7D),
//                               fontFamily: "Poppinsm",
//                               letterSpacing: 0.5,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   ListTile(
//                     leading: Image.asset(
//                       'assets/images/user3x.png',
//                       height: 42,
//                       width: 42,
//                       color: Color(COLOR_PRIMARY),
//                     ),
//                     title: Text(
//                       '${currentOrder!.author!.fullName()}',
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                       style: TextStyle(
//                         color: isDark ? Color(0xffFFFFFF) : Color(0xff000000),
//                         fontFamily: "Poppinsm",
//                         letterSpacing: 0.5,
//                       ),
//                     ),
//                     subtitle: Row(
//                       children: [
//                         Padding(
//                           padding: const EdgeInsets.only(top: 4.0),
//                           child: Text(
//                             'ORDER ID '.tr(),
//                             style: TextStyle(
//                               color: Color(0xff555555),
//                               fontSize: 12,
//                               fontFamily: "Poppinsr",
//                               letterSpacing: 0.5,
//                             ),
//                           ),
//                         ),
//                         Padding(
//                           padding: const EdgeInsets.only(top: 4.0),
//                           child: SizedBox(
//                             width: MediaQuery.sizeOf(context).width / 4,
//                             child: Text(
//                               '${currentOrder!.id} ',
//                               maxLines: 1,
//                               overflow: TextOverflow.ellipsis,
//                               style: TextStyle(
//                                 color: isDark
//                                     ? Color(0xffFFFFFF)
//                                     : Color(0xff000000),
//                                 fontSize: 12,
//                                 fontFamily: "Poppinsr",
//                                 letterSpacing: 0.5,
//                               ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                     trailing: Column(
//                       mainAxisAlignment: MainAxisAlignment.start,
//                       children: [
//                         TextButton.icon(
//                           style: TextButton.styleFrom(
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(6.0),
//                               side: BorderSide(color: Color(0xff3DAE7D)),
//                             ),
//                             padding: EdgeInsets.zero,
//                             minimumSize: Size(85, 30),
//                             alignment: Alignment.center,
//                             backgroundColor: Color(0xffFFFFFF),
//                           ),
//                           onPressed: () {
//                             UrlLauncher.launchUrl(
//                               Uri.parse(
//                                 "tel://${currentOrder!.author!.phoneNumber}",
//                               ),
//                             );
//                           },
//                           icon: Image.asset(
//                             'assets/images/call3x.png',
//                             height: 14,
//                             width: 14,
//                           ),
//                           label: Text(
//                             "CALL".tr(),
//                             style: TextStyle(
//                               color: Color(0xff3DAE7D),
//                               fontFamily: "Poppinsm",
//                               letterSpacing: 0.5,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   ListTile(
//                     leading: Image.asset(
//                       'assets/images/delivery_location3x.png',
//                       height: 42,
//                       width: 42,
//                       color: Color(COLOR_PRIMARY),
//                     ),
//                     title: Text(
//                       'Destination'.tr(),
//                       style: TextStyle(
//                         color: Color(0xff9091A4),
//                         fontFamily: "Poppinsr",
//                         letterSpacing: 0.5,
//                       ),
//                     ),
//                     subtitle: Padding(
//                       padding: const EdgeInsets.only(top: 4.0),
//                       child: Text(
//                         '${currentOrder!.receiver!.address}',
//                         maxLines: 3,
//                         overflow: TextOverflow.ellipsis,
//                         style: TextStyle(
//                           color: isDark ? Color(0xffFFFFFF) : Color(0xff333333),
//                           fontFamily: "Poppinsr",
//                           letterSpacing: 0.5,
//                         ),
//                       ),
//                     ),
//                     trailing: Column(
//                       mainAxisAlignment: MainAxisAlignment.start,
//                       children: [
//                         TextButton.icon(
//                           style: TextButton.styleFrom(
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(6.0),
//                               side: BorderSide(color: Color(0xff3DAE7D)),
//                             ),
//                             padding: EdgeInsets.zero,
//                             minimumSize: Size(100, 30),
//                             alignment: Alignment.center,
//                             backgroundColor: Color(0xffFFFFFF),
//                           ),
//                           onPressed: () => openChatWithCustomer(),
//                           icon: Icon(
//                             Icons.message,
//                             size: 16,
//                             color: Color(0xff3DAE7D),
//                           ),
//                           // Image.asset(
//                           //   'assets/images/call3x.png',
//                           //   height: 14,
//                           //   width: 14,
//                           // ),
//                           label: Text(
//                             "Message".tr(),
//                             style: TextStyle(
//                               color: Color(0xff3DAE7D),
//                               fontFamily: "Poppinsm",
//                               letterSpacing: 0.5,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   SizedBox(height: 25),
//                 ],
//               ),
//             isPickedUp
//                 ? FadeTransition(
//                     opacity: _animationController!,
//                     child: Padding(
//                       padding: const EdgeInsets.symmetric(horizontal: 10),
//                       child: AnimatedContainer(
//                         duration: Duration(seconds: 2),
//                         height: 40,
//                         width: MediaQuery.sizeOf(context).width,
//                         child: ElevatedButton(
//                           style: ElevatedButton.styleFrom(
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.all(
//                                 Radius.circular(4),
//                               ),
//                             ),
//                             backgroundColor: Color(COLOR_PRIMARY),
//                           ),
//                           onPressed: () async {
//                             if (currentOrder!.status == ORDER_STATUS_SHIPPED ||
//                                 currentOrder!.status ==
//                                     ORDER_STATUS_DRIVER_ACCEPTED) {
//                               completePickUp();
//                             } else if (currentOrder!.status ==
//                                 ORDER_STATUS_IN_TRANSIT) {
//                               completeOrder();
//                             }
//                           },
//                           child: Text(
//                             buttonText ?? "",
//                             style: TextStyle(
//                               color: Color(0xffFFFFFF),
//                               fontFamily: "Poppinsm",
//                               letterSpacing: 0.5,
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                   )
//                 : Padding(
//                     padding: const EdgeInsets.symmetric(horizontal: 10),
//                     child: AnimatedContainer(
//                       duration: Duration(seconds: 2),
//                       height: 40,
//                       width: MediaQuery.sizeOf(context).width,
//                       child: ElevatedButton(
//                         style: ElevatedButton.styleFrom(
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.all(Radius.circular(4)),
//                           ),
//                           backgroundColor: Color(COLOR_PRIMARY),
//                         ),
//                         onPressed: () async {
//                           if (currentOrder!.status == ORDER_STATUS_SHIPPED ||
//                               currentOrder!.status ==
//                                   ORDER_STATUS_DRIVER_ACCEPTED) {
//                             completePickUp();
//                           } else if (currentOrder!.status ==
//                               ORDER_STATUS_IN_TRANSIT) {
//                             completeOrder();
//                           }
//                         },
//                         child: Text(
//                           buttonText ?? "",
//                           style: TextStyle(
//                             color: Color(0xffFFFFFF),
//                             fontFamily: "Poppinsm",
//                             letterSpacing: 0.5,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//             if (googleMapUrl.isNotEmpty)
//               Padding(
//                 padding: const EdgeInsets.all(14),
//                 child: SizedBox(
//                   height: 40,
//                   width: MediaQuery.sizeOf(context).width,
//                   child: ElevatedButton(
//                     onPressed: () async {
//                       await UrlLauncher.launchUrl(Uri.parse(googleMapUrl));
//                     },
//                     style: ElevatedButton.styleFrom(
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.all(Radius.circular(4)),
//                       ),
//                       backgroundColor: Color(0xff3DAE7D),
//                     ),
//                     child: Text(
//                       'Direction on Map',
//                       style: TextStyle(
//                         color: Color(0xffFFFFFF),
//                         fontFamily: "Poppinsm",
//                         letterSpacing: 0.5,
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }

//   completePickUp() async {
//     final result = await Navigator.of(context).push(
//       MaterialPageRoute(
//         builder: (context) =>
//             ParcelImagesShow(images: currentOrder!.parcelImages!),
//       ),
//     );

//     if (result != null) {
//       if (result == "pickup") {
//         print('HomeScreenState.completePickUp');
//         showProgress(context, 'Updating order...', false);
//         currentOrder!.status = ORDER_STATUS_IN_TRANSIT;
//         await FireStoreUtils.updateParcelOrder(currentOrder!);

//         hideProgress();
//         setState(() {});
//       } else if (result == "orderCancel") {
//         print('HomeScreenState.completePickUp');
//         showProgress(context, 'Updating order...', false);
//         currentOrder!.status = ORDER_STATUS_REJECTED;
//         await FireStoreUtils.updateParcelOrder(currentOrder!);

//         if (currentOrder!.paymentMethod?.toLowerCase() != "cod") {
//           double totalTax = 0.0;
//           /* if (currentOrder!.taxType!.isNotEmpty) {
//             if (currentOrder!.taxType == "percent") {
//               totalTax = (double.parse(currentOrder!.subTotal.toString()) - double.parse(currentOrder!.discount.toString())) * double.parse(currentOrder!.tax.toString()) / 100;
//             } else {
//               totalTax = double.parse(currentOrder!.tax.toString());
//             }
//           }*/

//           if (currentOrder!.taxSetting != null) {
//             for (var element in currentOrder!.taxSetting!) {
//               totalTax = totalTax +
//                   calculateTax(
//                     amount: (double.parse(currentOrder!.subTotal!.toString()) -
//                             double.parse(
//                               currentOrder!.discount!.toString(),
//                             ))
//                         .toString(),
//                     taxModel: element,
//                   );
//             }
//           }

//           double subTotal = double.parse(currentOrder!.subTotal.toString()) -
//               double.parse(currentOrder!.discount.toString());

//           double userAmount = 0;

//           if (currentOrder!.paymentMethod?.toLowerCase() != "cod") {
//             userAmount = subTotal + totalTax;
//           }

//           await FireStoreUtils.createPaymentId().then((value) async {
//             final paymentID = value;
//             await FireStoreUtils.topUpWalletAmount(
//               userID: currentOrder!.authorID!,
//               paymentMethod: "Refund Amount",
//               amount: userAmount,
//               id: paymentID,
//             ).then((value) async {
//               await FireStoreUtils.updateUserWalletAmount(
//                 userId: currentOrder!.authorID!,
//                 amount: userAmount,
//               ).then((value) {});
//             });
//           });
//         }

//         Position? locationData = await getCurrentLocation();
//         Map<String, dynamic> payLoad = <String, dynamic>{
//           "type": "parcel_order",
//           "orderId": currentOrder!.id,
//         };
//         await FireStoreUtils.sendFcmMessage(
//           parcelRejected,
//           currentOrder!.author!.fcmToken ?? '',
//           payLoad,
//         );

//         Constant.userModel!.location = UserLocation(
//           latitude: locationData.latitude,
//           longitude: locationData.longitude,
//         );
//         Constant.userModel!.geoFireData = GeoFireData(
//           geohash: GeoFlutterFire()
//               .point(
//                 latitude: locationData.latitude,
//                 longitude: locationData.longitude,
//               )
//               .hash,
//           geoPoint: GeoPoint(locationData.latitude, locationData.longitude),
//         );
//         Constant.userModel!.inProgressOrderID = null;
//         currentOrder = null;

//         await FireStoreUtils.updateCurrentUser(Constant.userModel!);

//         _markers.clear();
//         polyLines.clear();

//         _mapController?.moveCamera(
//           CameraUpdate.newCameraPosition(
//             CameraPosition(
//               target: LatLng(locationData.latitude, locationData.longitude),
//               zoom: 15,
//             ),
//           ),
//         );

//         hideProgress();
//         setState(() {});
//       }
//     }
//   }

//   completeOrder() async {
//     showProgress(context, 'Completing Delivery...'.tr(), false);
//     currentOrder!.status = ORDER_STATUS_COMPLETED;
//     updateParcelWalletAmount(currentOrder!);
//     await FireStoreUtils.updateParcelOrder(currentOrder!);
//     Position? locationData = await getCurrentLocation();
//     Map<String, dynamic> payLoad = <String, dynamic>{
//       "type": "parcel_order",
//       "orderId": currentOrder!.id,
//     };
//     await FireStoreUtils.sendFcmMessage(
//       parcelCompleted,
//       currentOrder!.author!.fcmToken ?? '',
//       payLoad,
//     );
//     await FireStoreUtils.getParcelFirstOrderOrNOt(currentOrder!).then((
//       value,
//     ) async {
//       if (value == true) {
//         await FireStoreUtils.updateParcelReferralAmount(currentOrder!);
//       }
//     });
//     _driverModel!.inProgressOrderID = null;
//     _driverModel!.location = UserLocation(
//       latitude: locationData.latitude,
//       longitude: locationData.longitude,
//     );
//     _driverModel!.geoFireData = GeoFireData(
//       geohash: GeoFlutterFire()
//           .point(
//             latitude: locationData.latitude,
//             longitude: locationData.longitude,
//           )
//           .hash,
//       geoPoint: GeoPoint(locationData.latitude, locationData.longitude),
//     );

//     currentOrder = null;

//     await FireStoreUtils.updateCurrentUser(_driverModel!);
//     hideProgress();

//     _markers.clear();
//     polyLines.clear();

//     _mapController?.moveCamera(
//       CameraUpdate.newCameraPosition(
//         CameraPosition(
//           target: LatLng(locationData.latitude, locationData.longitude),
//           zoom: 15,
//         ),
//       ),
//     );
//     setState(() {});
//   }

//   openChatWithCustomer() async {
//     // await showProgress(context, "Please wait".tr(), false);
//     ShowToastDialog.showLoader("Please wait".tr());
//     UserModel? customer = await FireStoreUtils.getCurrentUser(
//       currentOrder!.authorID!,
//     );

//     UserModel? driver = await FireStoreUtils.getCurrentUser(
//       currentOrder!.driverId.toString(),
//     );
//     ShowToastDialog.closeLoader();
//     // hideProgress();
//     push(
//       context,
//       ChatScreens(
//         type: "cab_parcel_chat",
//         customerName:
//             customer!.firstName ?? '' + " " + (customer.lastName ?? ''),
//         restaurantName: driver!.firstName ?? '' + " " + (driver.lastName ?? ''),
//         orderId: currentOrder!.id,
//         restaurantId: driver.id,
//         customerId: customer.id,
//         customerProfileImage: customer.profilePictureURL,
//         restaurantProfileImage: driver.profilePictureURL,
//         token: customer.fcmToken,
//         chatType: 'Driver',
//       ),
//     );
//   }
// }

import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:door_delights_driver/services/show_toast_dialog.dart';
import 'package:door_delights_driver/themes/theme_controller.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:door_delights_driver/constants.dart';
import 'package:door_delights_driver/services/FirebaseHelper.dart';
import 'package:door_delights_driver/services/helper.dart';
import 'package:door_delights_driver/ui/chat_screen/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geoflutterfire2/geoflutterfire2.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/instance_manager.dart';
import 'package:get/state_manager.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart' as UrlLauncher;
import '../../constant/constant.dart';
import '../../constant/global.dart';
import '../../models/parcel_order_model.dart';
import '../../models/user_model.dart';
import '../../services/audio_player_service.dart';
import 'parcel_images_show.dart';

// ─── Helpers ──────────────────────────────────────────────────────────
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

class ParcelHomeScreen extends StatefulWidget {
  const ParcelHomeScreen({Key? key}) : super(key: key);

  @override
  State<ParcelHomeScreen> createState() => _ParcelHomeScreenState();
}

class _ParcelHomeScreenState extends State<ParcelHomeScreen>
    with SingleTickerProviderStateMixin {
  final fireStoreUtils = FireStoreUtils();

  GoogleMapController? _mapController;
  bool canShowSheet = true;

  BitmapDescriptor? departureIcon;
  BitmapDescriptor? destinationIcon;
  BitmapDescriptor? taxiIcon;

  Map<PolylineId, Polyline> polyLines = {};
  PolylinePoints polylinePoints = PolylinePoints(apiKey: GOOGLE_API_KEY);
  final Map<String, Marker> _markers = {};

  // ─── Distance caching per order ────────────────────────────────────
  static final Map<String, Map<String, String>?> _driverToSenderCache = {};
  static final Map<String, Map<String, String>?> _senderToReceiverCache = {};

  // ────────────────────────────────────────────────
  // Smooth driver-marker animation state (matches CabHomeScreen)
  // ────────────────────────────────────────────────
  AnimationController? _markerAnimationController;
  LatLng? _lastKnownDriverLatLng;
  double _lastKnownDriverRotation = 0;
  bool _isFirstDriverUpdate = true;
  bool _followDriverWithCamera = true;
  bool _isAutoCameraMove = false;

  setIcons() async {
    BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(10, 10)),
      "assets/images/pickup.png",
    ).then((value) {
      departureIcon = value;
    });

    BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(10, 10)),
      "assets/images/dropoff.png",
    ).then((value) {
      destinationIcon = value;
    });

    _createDriverArrowIcon().then((value) {
      taxiIcon = value;
      if (mounted) setState(() {});
    });
  }

  Future<BitmapDescriptor> _createDriverArrowIcon({
    double size = 80,
    Color pinColor = const Color(0xFFF15A29),
    Color pinBorderColor = const Color(0xFFB6431A),
    Color arrowColor = Colors.white,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));
    final center = Offset(size / 2, size / 2 - size * 0.06);
    final radius = size * 0.36;

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(center.translate(0, size * 0.05), radius, shadowPaint);

    canvas.drawCircle(center, radius, Paint()..color = pinColor);

    final borderPaint = Paint()
      ..color = pinBorderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.045;
    canvas.drawCircle(
        center, radius - borderPaint.strokeWidth / 2, borderPaint);

    final highlightPaint = Paint()..color = Colors.white.withOpacity(0.18);
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(-radius * 0.35, -radius * 0.4),
        width: radius * 0.7,
        height: radius * 0.4,
      ),
      highlightPaint,
    );

    final arrowPath = Path();
    final double halfWidth = radius * 0.62;
    final double tipY = center.dy - radius * 0.62;
    final double baseY = center.dy + radius * 0.45;
    final double notchY = center.dy + radius * 0.08;
    arrowPath.moveTo(center.dx, tipY);
    arrowPath.lineTo(center.dx + halfWidth, baseY);
    arrowPath.lineTo(center.dx, notchY);
    arrowPath.lineTo(center.dx - halfWidth, baseY);
    arrowPath.close();
    canvas.drawPath(arrowPath, Paint()..color = arrowColor);

    final tailPath = Path();
    final double tailWidth = radius * 0.32;
    final double tailTop = center.dy + radius * 0.78;
    final double tailTip = size * 0.98;
    tailPath.moveTo(center.dx - tailWidth, tailTop);
    tailPath.lineTo(center.dx + tailWidth, tailTop);
    tailPath.lineTo(center.dx, tailTip);
    tailPath.close();
    canvas.drawPath(tailPath, Paint()..color = pinColor);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.round(), size.round());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  Timer? _timer;

  void startTimer(UserModel _driverModel) {
    const oneSec = const Duration(seconds: 1);
    _timer = new Timer.periodic(oneSec, (Timer timer) async {
      if (driverOrderAcceptRejectDuration == 0) {
        timer.cancel();
        if (_driverModel.orderParcelRequestData != null) {
          await rejectOrder();
        }
      } else {
        driverOrderAcceptRejectDuration--;
      }
    });
  }

  updateDriverOrder() async {
    log("Update Driver Order");
    Timestamp startTimestamp = Timestamp.now();
    Timestamp endTimestamp = Timestamp.now();

    DateTime currentDate = startTimestamp.toDate();
    currentDate = currentDate.subtract(Duration(hours: 3));
    startTimestamp = Timestamp.fromDate(currentDate);

    List<ParcelOrderModel> orders = [];

    print('-->startTime${startTimestamp.toDate()}');
    print('-->endTime${endTimestamp.toDate()}');
    await FirebaseFirestore.instance
        .collection(PARCELORDER)
        .where(
          'status',
          whereIn: [ORDER_STATUS_PLACED, ORDER_STATUS_DRIVER_REJECTED],
        )
        .where('senderPickupDateTime', isGreaterThan: startTimestamp)
        .where('senderPickupDateTime', isLessThan: endTimestamp)
        .get()
        .then((value) async {
          print('---->${value.docs.length}');
          await Future.forEach(value.docs, (
            QueryDocumentSnapshot<Map<String, dynamic>> element,
          ) {
            try {
              orders.add(ParcelOrderModel.fromJson(element.data()));
            } catch (e, s) {
              print('watchOrdersStatus parse error ${element.id}$e $s');
            }
          });
        });

    orders.forEach((element) {
      ParcelOrderModel orderModel = element;
      print('---->${orderModel.id}');
      orderModel.triggerDelevery = Timestamp.now();
      orderModel.sendToDriver = true;
      FirebaseFirestore.instance
          .collection(PARCELORDER)
          .doc(element.id)
          .set(orderModel.toJson(), SetOptions(merge: true))
          .then((order) {
        print('Done.');
      });
    });
  }

  AnimationController? _animationController;

  setSound() async {
    await AudioPlayerService.initAudio();
  }

  playSound(bool isPlay) async {
    await AudioPlayerService.playSound(isPlay);
  }

  @override
  void initState() {
    getDriver();
    setIcons();
    updateDriverOrder();
    setSound();
    _animationController = new AnimationController(
      vsync: this,
      duration: Duration(seconds: 1),
    );
    _animationController!.repeat(reverse: true);
    super.initState();
  }

  @override
  void dispose() {
    _animationController!.dispose();
    if (FireStoreUtils().driverStreamSub != null) {
      FireStoreUtils().driverStreamSub!.cancel();
    }
    FireStoreUtils().parcelOrdersStreamController.close();
    FireStoreUtils().parcelOrdersStreamSub.cancel();
    if (_timer != null) {
      _timer!.cancel();
    }
    playSound(false);
    _markerAnimationController?.dispose();
    super.dispose();
  }

  bool isShow = false;

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();

    return Obx(() {
      final isDark = themeController.isDark.value;

      isDark
          ? _mapController?.setMapStyle(
              '[{"featureType": "all","'
              'elementType": "'
              'geo'
              'met'
              'ry","stylers": [{"color": "#242f3e"}]},{"featureType": "all","elementType": "labels.text.stroke","stylers": [{"lightness": -80}]},{"featureType": "administrative","elementType": "labels.text.fill","stylers": [{"color": "#746855"}]},{"featureType": "administrative.locality","elementType": "labels.text.fill","stylers": [{"color": "#d59563"}]},{"featureType": "poi","elementType": "labels.text.fill","stylers": [{"color": "#d59563"}]},{"featureType": "poi.park","elementType": "geometry","stylers": [{"color": "#263c3f"}]},{"featureType": "poi.park","elementType": "labels.text.fill","stylers": [{"color": "#6b9a76"}]},{"featureType": "road","elementType": "geometry.fill","stylers": [{"color": "#2b3544"}]},{"featureType": "road","elementType": "labels.text.fill","stylers": [{"color": "#9ca5b3"}]},{"featureType": "road.arterial","elementType": "geometry.fill","stylers": [{"color": "#38414e"}]},{"featureType": "road.arterial","elementType": "geometry.stroke","stylers": [{"color": "#212a37"}]},{"featureType": "road.highway","elementType": "geometry.fill","stylers": [{"color": "#746855"}]},{"featureType": "road.highway","elementType": "geometry.stroke","stylers": [{"color": "#1f2835"}]},{"featureType": "road.highway","elementType": "labels.text.fill","stylers": [{"color": "#f3d19c"}]},{"featureType": "road.local","elementType": "geometry.fill","stylers": [{"color": "#38414e"}]},{"featureType": "road.local","elementType": "geometry.stroke","stylers": [{"color": "#212a37"}]},{"featureType": "transit","elementType": "geometry","stylers": [{"color": "#2f3948"}]},{"featureType": "transit.station","elementType": "labels.text.fill","stylers": [{"color": "#d59563"}]},{"featureType": "water","elementType": "geometry","stylers": [{"color": "#17263c"}]},{"featureType": "water","elementType": "labels.text.fill","stylers": [{"color": "#515c6d"}]},{"featureType": "water","elementType": "labels.text.stroke","stylers": [{"lightness": -20}]}]',
            )
          : _mapController?.setMapStyle(null);

      return Scaffold(
        body: Column(
          children: [
            Visibility(
              visible: _driverModel!.inProgressOrderID == null &&
                  (double.tryParse(_driverModel!.walletAmount.toString()) ??
                          0) <
                      (double.tryParse(minimumDepositToRideAccept) ?? 0),
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  color: Colors.black,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      "${"You have to minimum ".tr()}${amountShow(amount: minimumDepositToRideAccept.toString())} ${"wallet amount to receiving Order".tr()}",
                      style: TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GoogleMap(
                onMapCreated: (controller) {
                  _onMapCreated(controller, isDark);
                },
                myLocationEnabled:
                    _driverModel!.inProgressOrderID != null ? false : true,
                myLocationButtonEnabled: true,
                mapType: MapType.terrain,
                zoomControlsEnabled: false,
                polylines: Set<Polyline>.of(polyLines.values),
                markers: _markers.values.toSet(),
                onCameraMoveStarted: () {
                  if (!_isAutoCameraMove) {
                    _followDriverWithCamera = false;
                  }
                },
                onCameraIdle: () {
                  _isAutoCameraMove = false;
                },
                initialCameraPosition: CameraPosition(
                  zoom: 15,
                  target: LatLng(
                    _driverModel!.location?.latitude ?? 0,
                    _driverModel!.location?.longitude ?? 0,
                  ),
                ),
              ),
            ),
            _driverModel!.inProgressOrderID != null &&
                    currentOrder != null &&
                    isShow == true
                ? buildOrderActionsCard()
                : Container(),
            _driverModel!.orderParcelRequestData != null
                ? showDriverBottomSheet()
                : Container(),
          ],
        ),
        floatingActionButton: _driverModel!.orderParcelRequestData != null ||
                _driverModel!.inProgressOrderID == null
            ? null
            : FloatingActionButton(
                onPressed: () {
                  setState(() {
                    if (isShow == true) {
                      isShow = false;
                    } else {
                      isShow = true;
                    }
                  });
                },
                child: Icon(
                  isShow ? Icons.close : Icons.remove_red_eye,
                  color: Colors.white,
                  size: 29,
                ),
                backgroundColor: Colors.black,
                tooltip: 'Capture Picture',
                elevation: 5,
                splashColor: Colors.grey,
              ),
      );
    });
  }

  void _onMapCreated(GoogleMapController controller, bool isDark) {
    _mapController = controller;

    _isAutoCameraMove = true;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(
            Constant.userModel?.location?.latitude ?? 0.0,
            Constant.userModel?.location?.longitude ?? 0.0,
          ),
          zoom: 14,
        ),
      ),
    );
    setState(() {});
    if (isDark)
      _mapController?.setMapStyle(
        '[{"featureType": "all","'
        'elementType": "'
        'geo'
        'met'
        'ry","stylers": [{"color": "#242f3e"}]},{"featureType": "all","elementType": "labels.text.stroke","stylers": [{"lightness": -80}]},{"featureType": "administrative","elementType": "labels.text.fill","stylers": [{"color": "#746855"}]},{"featureType": "administrative.locality","elementType": "labels.text.fill","stylers": [{"color": "#d59563"}]},{"featureType": "poi","elementType": "labels.text.fill","stylers": [{"color": "#d59563"}]},{"featureType": "poi.park","elementType": "geometry","stylers": [{"color": "#263c3f"}]},{"featureType": "poi.park","elementType": "labels.text.fill","stylers": [{"color": "#6b9a76"}]},{"featureType": "road","elementType": "geometry.fill","stylers": [{"color": "#2b3544"}]},{"featureType": "road","elementType": "labels.text.fill","stylers": [{"color": "#9ca5b3"}]},{"featureType": "road.arterial","elementType": "geometry.fill","stylers": [{"color": "#38414e"}]},{"featureType": "road.arterial","elementType": "geometry.stroke","stylers": [{"color": "#212a37"}]},{"featureType": "road.highway","elementType": "geometry.fill","stylers": [{"color": "#746855"}]},{"featureType": "road.highway","elementType": "geometry.stroke","stylers": [{"color": "#1f2835"}]},{"featureType": "road.highway","elementType": "labels.text.fill","stylers": [{"color": "#f3d19c"}]},{"featureType": "road.local","elementType": "geometry.fill","stylers": [{"color": "#38414e"}]},{"featureType": "road.local","elementType": "geometry.stroke","stylers": [{"color": "#212a37"}]},{"featureType": "transit","elementType": "geometry","stylers": [{"color": "#2f3948"}]},{"featureType": "transit.station","elementType": "labels.text.fill","stylers": [{"color": "#d59563"}]},{"featureType": "water","elementType": "geometry","stylers": [{"color": "#17263c"}]},{"featureType": "water","elementType": "labels.text.fill","stylers": [{"color": "#515c6d"}]},{"featureType": "water","elementType": "labels.text.stroke","stylers": [{"lightness": -20}]}]',
      );
  }

  // ─── Smooth driver marker update (same as before) ────────────────────
  void _updateDriverMarkerAndCamera() {
    if (_driverModel == null ||
        _driverModel!.location == null ||
        taxiIcon == null) return;

    final lat = _driverModel!.location!.latitude ?? 0;
    final lng = _driverModel!.location!.longitude ?? 0;
    final newPosition = LatLng(lat, lng);

    final fromPosition = _lastKnownDriverLatLng ?? newPosition;

    final movedMeters = Geolocator.distanceBetween(
      fromPosition.latitude,
      fromPosition.longitude,
      newPosition.latitude,
      newPosition.longitude,
    );

    double targetRotation = _lastKnownDriverRotation;
    if (movedMeters > 2) {
      targetRotation = Geolocator.bearingBetween(
        fromPosition.latitude,
        fromPosition.longitude,
        newPosition.latitude,
        newPosition.longitude,
      );
      if (targetRotation < 0) targetRotation += 360;
    } else if (_driverModel!.rotation != null) {
      targetRotation =
          double.tryParse(_driverModel!.rotation.toString()) ?? targetRotation;
    }

    if (_isFirstDriverUpdate) {
      _isFirstDriverUpdate = false;
      _markers['Driver'] = Marker(
        markerId: const MarkerId('Driver'),
        infoWindow: const InfoWindow(title: "Driver"),
        position: newPosition,
        icon: taxiIcon!,
        rotation: targetRotation,
        anchor: const Offset(0.5, 0.5),
        flat: false,
        zIndex: 2,
      );
      _lastKnownDriverLatLng = newPosition;
      _lastKnownDriverRotation = targetRotation;
      if (_mapController != null) {
        _isAutoCameraMove = true;
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: newPosition, zoom: 17),
          ),
        );
      }
      if (mounted) setState(() {});
      return;
    }

    _animateDriverMarker(
      from: fromPosition,
      to: newPosition,
      fromRotation: _lastKnownDriverRotation,
      toRotation: targetRotation,
    );

    _lastKnownDriverLatLng = newPosition;
    _lastKnownDriverRotation = targetRotation;
  }

  void _animateDriverMarker({
    required LatLng from,
    required LatLng to,
    required double fromRotation,
    required double toRotation,
  }) {
    _markerAnimationController?.dispose();
    _markerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    double rotationDelta = toRotation - fromRotation;
    if (rotationDelta > 180) rotationDelta -= 360;
    if (rotationDelta < -180) rotationDelta += 360;
    final adjustedToRotation = fromRotation + rotationDelta;

    final latTween = Tween<double>(begin: from.latitude, end: to.latitude);
    final lngTween = Tween<double>(begin: from.longitude, end: to.longitude);
    final rotationTween =
        Tween<double>(begin: fromRotation, end: adjustedToRotation);

    final curved = CurvedAnimation(
      parent: _markerAnimationController!,
      curve: Curves.easeInOut,
    );

    _markerAnimationController!.addListener(() {
      if (taxiIcon == null) return;
      final animatedPosition =
          LatLng(latTween.evaluate(curved), lngTween.evaluate(curved));
      final animatedRotation = rotationTween.evaluate(curved) % 360;

      _markers['Driver'] = Marker(
        markerId: const MarkerId('Driver'),
        infoWindow: const InfoWindow(title: "Driver"),
        position: animatedPosition,
        icon: taxiIcon!,
        rotation:
            animatedRotation < 0 ? animatedRotation + 360 : animatedRotation,
        anchor: const Offset(0.5, 0.5),
        flat: false,
        zIndex: 2,
      );

      if (mounted) setState(() {});

      if (_mapController != null && _followDriverWithCamera) {
        _isAutoCameraMove = true;
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: animatedPosition,
              zoom: 17,
            ),
          ),
        );
      }
    });

    _markerAnimationController!.forward();
  }

  // ─── Distance helpers with caching ──────────────────────────────────
  Future<Map<String, String>?> _getDriverToSenderInfo(String orderId) async {
    if (_driverModel == null ||
        _driverModel!.location == null ||
        _driverModel!.orderParcelRequestData == null) {
      return null;
    }
    final senderLat =
        _driverModel!.orderParcelRequestData!.senderLatLong!.latitude ?? 0;
    final senderLng =
        _driverModel!.orderParcelRequestData!.senderLatLong!.longitude ?? 0;
    if (senderLat == 0 && senderLng == 0) return null;

    final driverLat = _driverModel!.location!.latitude!;
    final driverLng = _driverModel!.location!.longitude!;

    final result = await getDurationDistance(
      LatLng(driverLat, driverLng),
      LatLng(senderLat, senderLng),
    );
    return _parseDistanceResult(result);
  }

  Future<Map<String, String>?> _getSenderToReceiverInfo(String orderId) async {
    if (_driverModel == null || _driverModel!.orderParcelRequestData == null) {
      return null;
    }
    final senderLat =
        _driverModel!.orderParcelRequestData!.senderLatLong!.latitude ?? 0;
    final senderLng =
        _driverModel!.orderParcelRequestData!.senderLatLong!.longitude ?? 0;
    final receiverLat =
        _driverModel!.orderParcelRequestData!.receiverLatLong!.latitude ?? 0;
    final receiverLng =
        _driverModel!.orderParcelRequestData!.receiverLatLong!.longitude ?? 0;
    if (senderLat == 0 && senderLng == 0) return null;
    if (receiverLat == 0 && receiverLng == 0) return null;

    final result = await getDurationDistance(
      LatLng(senderLat, senderLng),
      LatLng(receiverLat, receiverLng),
    );
    return _parseDistanceResult(result);
  }

  // ─── showDriverBottomSheet with distance & duration ────────────────
  Widget showDriverBottomSheet() {
    double totalAmount = 0.0;
    double adminComm = 0.0;

    final order = _driverModel!.orderParcelRequestData!;
    totalAmount = (double.parse(order.subTotal!.toString()) -
        double.parse(order.discount!.toString()));
    adminComm = (order.adminCommissionType == 'percentage')
        ? (totalAmount * double.parse(order.adminCommission!)) / 100
        : double.parse(order.adminCommission!);

    final orderId = order.id!;

    return Padding(
      padding: EdgeInsets.all(10),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        decoration: BoxDecoration(
          color: Color(0xff212121),
          borderRadius: BorderRadius.all(Radius.circular(15)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: Text(
                    "Trip Distance".tr(),
                    style: TextStyle(
                      color: Color(0xffADADAD),
                      fontFamily: "Poppinsr",
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Text(
                  "${order.distance.toString()} km",
                  style: TextStyle(
                    color: Color(0xffFFFFFF),
                    fontFamily: "Poppinsm",
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: Text(
                    "Delivery charge".tr(),
                    style: TextStyle(
                      color: Color(0xffADADAD),
                      fontFamily: "Poppinsr",
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Text(
                  "${amountShow(amount: totalAmount.toString())}",
                  style: TextStyle(
                    color: Color(0xffFFFFFF),
                    fontFamily: "Poppinsm",
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: Text(
                    'Admin commission'.tr(),
                    style: TextStyle(
                      color: Color(0xffADADAD),
                      fontFamily: "Poppinsr",
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Text(
                  "(-${amountShow(amount: adminComm.toString())})",
                  style: TextStyle(
                    color: Color(0xffFFFFFF),
                    fontFamily: "Poppinsm",
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            SizedBox(height: 5),
            Card(
              color: Color(0xffFFFFFF),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 14.0,
                  horizontal: 10,
                ),
                child: Row(
                  children: [
                    Image.asset('assets/images/location3x.png', height: 55),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Sender address ──
                          Text(
                            order.sender!.address ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xff333333),
                              fontFamily: "Poppinsr",
                              letterSpacing: 0.5,
                            ),
                          ),
                          // Driver → Sender distance
                          FutureBuilder<Map<String, String>?>(
                            future: _getDriverToSenderInfo(orderId),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                );
                              }
                              if (snapshot.hasData && snapshot.data != null) {
                                final info = snapshot.data!;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    "🚗 ${info['duration']} away (${info['distance']})",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                      fontFamily: "Poppinsr",
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                          const SizedBox(height: 22),
                          // ── Receiver address ──
                          Text(
                            order.receiver!.address ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xff333333),
                              fontFamily: "Poppinsr",
                              letterSpacing: 0.5,
                            ),
                          ),
                          // Sender → Receiver distance
                          FutureBuilder<Map<String, String>?>(
                            future: _getSenderToReceiverInfo(orderId),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                );
                              }
                              if (snapshot.hasData && snapshot.data != null) {
                                final info = snapshot.data!;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    "🛣️ ${info['duration']} (${info['distance']})",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                      fontFamily: "Poppinsr",
                                    ),
                                  ),
                                );
                              }
                              // Fallback to the order's distance if available
                              if (order.distance != null &&
                                  order.distance!.isNotEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    "🛣️ ${order.distance} km",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                      fontFamily: "Poppinsr",
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                SizedBox(
                  height: MediaQuery.sizeOf(context).height / 20,
                  width: MediaQuery.sizeOf(context).width / 2.5,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 12,
                      ),
                      backgroundColor: Color(COLOR_PRIMARY),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(5)),
                      ),
                    ),
                    child: Text(
                      'Reject'.tr(),
                      style: TextStyle(
                        color: Color(0xffFFFFFF),
                        fontFamily: "Poppinsm",
                        letterSpacing: 0.5,
                      ),
                    ),
                    onPressed: () async {
                      await playSound(false);
                      showProgress(context, 'Rejecting order...'.tr(), false);
                      try {
                        await rejectOrder();
                        hideProgress();
                      } catch (e) {
                        hideProgress();
                        print('HomeScreenState.showDriverBottomSheet $e');
                      }
                    },
                  ),
                ),
                SizedBox(
                  height: MediaQuery.sizeOf(context).height / 20,
                  width: MediaQuery.sizeOf(context).width / 2.5,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 12,
                      ),
                      backgroundColor: Color(COLOR_PRIMARY),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(5)),
                      ),
                    ),
                    child: Text(
                      'Accept'.tr(),
                      style: TextStyle(
                        color: Color(0xffFFFFFF),
                        fontFamily: "Poppinsm",
                        letterSpacing: 0.5,
                      ),
                    ),
                    onPressed: () async {
                      await playSound(false);
                      showProgress(context, 'Accepting order...'.tr(), false);
                      if (_timer != null) {
                        _timer!.cancel();
                      }
                      try {
                        await acceptOrder();
                        hideProgress();
                      } catch (e) {
                        hideProgress();
                        print('HomeScreenState.showDriverBottomSheet $e');
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Rest of the class unchanged ────────────────────────────────────
  // (acceptOrder, rejectOrder, getDirections, etc. are exactly as before)
  // ─── I'm keeping them identical; no changes needed ────────────────

  acceptOrder() async {
    ParcelOrderModel orderModel = _driverModel!.orderParcelRequestData!;

    _driverModel!.orderParcelRequestData = null;
    _driverModel!.inProgressOrderID = orderModel.id;

    Constant.userModel = _driverModel!;

    await FireStoreUtils.updateCurrentUser(_driverModel!);

    orderModel.status = ORDER_STATUS_DRIVER_ACCEPTED;
    orderModel.driverId = _driverModel!.id;
    orderModel.driver = _driverModel!;
    await FireStoreUtils.updateParcelOrder(orderModel);

    if (_driverModel!.inProgressOrderID != null) {
      getCurrentOrder();
    }
    Map<String, dynamic> payLoad = <String, dynamic>{
      "type": "parcel_order",
      "orderId": orderModel.id,
    };
    await FireStoreUtils.sendFcmMessage(
      parcelAccepted,
      orderModel.author!.fcmToken ?? '',
      payLoad,
    );

    setState(() {
      isShow = true;
    });
  }

  rejectOrder() async {
    if (_timer != null) {
      _timer!.cancel();
    }
    ParcelOrderModel orderModel = _driverModel!.orderParcelRequestData!;
    if (orderModel.rejectedByDrivers == null) {
      orderModel.rejectedByDrivers = [];
    }
    orderModel.rejectedByDrivers!.add(_driverModel!.id);
    orderModel.status = ORDER_STATUS_DRIVER_REJECTED;
    await FireStoreUtils.updateParcelOrder(orderModel);
    _driverModel!.orderParcelRequestData = null;

    await FireStoreUtils.updateCurrentUser(_driverModel!);
  }

  String? _lastRouteOrigin;
  String? _lastOrderStatus;

  getDirections() async {
    if (currentOrder == null) return;

    final currentStatus = currentOrder!.status;
    final shouldRecalculate = _shouldRecalculateRoute(currentStatus!);

    if (!shouldRecalculate) {
      return;
    }

    LatLng origin;
    LatLng destination;
    bool includeDriverMarker = false;

    if (currentStatus == ORDER_STATUS_SHIPPED ||
        currentStatus == ORDER_STATUS_DRIVER_ACCEPTED) {
      origin = LatLng(
        _driverModel!.location?.latitude ?? 0,
        _driverModel!.location?.longitude ?? 0,
      );
      destination = LatLng(
        currentOrder!.senderLatLong!.latitude ?? 0,
        currentOrder!.senderLatLong!.longitude ?? 0,
      );
      includeDriverMarker = true;
    } else if (currentStatus == ORDER_STATUS_IN_TRANSIT) {
      origin = LatLng(
        _driverModel!.location?.latitude ?? 0,
        _driverModel!.location?.longitude ?? 0,
      );
      destination = LatLng(
        currentOrder!.receiverLatLong!.latitude ?? 0,
        currentOrder!.receiverLatLong!.longitude ?? 0,
      );
      includeDriverMarker = true;
    } else {
      origin = LatLng(
        currentOrder!.senderLatLong!.latitude ?? 0,
        currentOrder!.senderLatLong!.longitude ?? 0,
      );
      destination = LatLng(
        currentOrder!.receiverLatLong!.latitude ?? 0,
        currentOrder!.receiverLatLong!.longitude ?? 0,
      );
    }

    try {
      List<LatLng> polylineCoordinates = await _getRouteCoordinates(
        origin,
        destination,
      );

      _updateMarkers(origin, destination, includeDriverMarker);
      addPolyLine(polylineCoordinates);

      _lastRouteOrigin = "${origin.latitude},${origin.longitude}";
      _lastOrderStatus = currentStatus;
    } catch (e) {
      log("Error getting directions: $e");
    }
  }

  bool _shouldRecalculateRoute(String currentStatus) {
    if (_lastOrderStatus != currentStatus) return true;

    if (_lastRouteOrigin != null && _driverModel != null) {
      final currentOrigin =
          "${_driverModel!.location?.latitude ?? 0},${_driverModel!.location?.longitude ?? 0}";
      if (_lastRouteOrigin != currentOrigin) {
        double distance = _calculateDistance(_lastRouteOrigin!, currentOrigin);
        log("Distance: $distance");
        return distance > 0.12;
      }
    }

    return false;
  }

  double _calculateDistance(String origin1, String origin2) {
    try {
      List<String> parts1 = origin1.split(',');
      List<String> parts2 = origin2.split(',');

      double lat1 = double.parse(parts1[0]);
      double lon1 = double.parse(parts1[1]);
      double lat2 = double.parse(parts2[0]);
      double lon2 = double.parse(parts2[1]);

      double dLat = (lat2 - lat1) * 111319.9;
      double dLon = (lon2 - lon1) * 111319.9 * math.cos(lat1 * 3.14159 / 180);

      return math.sqrt(dLat * dLat + dLon * dLon) / 1000;
    } catch (e) {
      return 1.0;
    }
  }

  Future<List<LatLng>> _getRouteCoordinates(
    LatLng origin,
    LatLng destination,
  ) async {
    log("Getting coordinates");
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      request: PolylineRequest(
        origin: PointLatLng(origin.latitude, origin.longitude),
        destination: PointLatLng(destination.latitude, destination.longitude),
        mode: TravelMode.driving,
      ),
    );

    List<LatLng> polylineCoordinates = [];
    if (result.points.isNotEmpty) {
      for (var point in result.points) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      }
    }

    log("Route calculated: ${polylineCoordinates.length} points");
    return polylineCoordinates;
  }

  void _updateMarkers(
    LatLng origin,
    LatLng destination,
    bool includeDriverMarker,
  ) {
    setState(() {
      _markers.clear();

      if (includeDriverMarker && _driverModel != null && taxiIcon != null) {
        final driverLatLng = LatLng(
          _driverModel!.location?.latitude ?? 0,
          _driverModel!.location?.longitude ?? 0,
        );
        _markers['Driver'] = Marker(
          markerId: const MarkerId('Driver'),
          infoWindow: const InfoWindow(title: "Driver"),
          position: driverLatLng,
          icon: taxiIcon!,
          rotation: _lastKnownDriverRotation != 0
              ? _lastKnownDriverRotation
              : double.parse(_driverModel!.rotation.toString()),
          anchor: const Offset(0.5, 0.5),
          flat: false,
          zIndex: 2,
        );
        _lastKnownDriverLatLng = driverLatLng;
      }

      _markers['Departure'] = Marker(
        markerId: const MarkerId('Departure'),
        infoWindow: const InfoWindow(title: "Departure"),
        position: LatLng(
          currentOrder!.senderLatLong!.latitude ?? 0,
          currentOrder!.senderLatLong!.longitude ?? 0,
        ),
        icon: departureIcon!,
      );

      _markers['Destination'] = Marker(
        markerId: const MarkerId('Destination'),
        infoWindow: const InfoWindow(title: "Destination"),
        position: LatLng(
          currentOrder!.receiverLatLong!.latitude ?? 0,
          currentOrder!.receiverLatLong!.longitude ?? 0,
        ),
        icon: destinationIcon!,
      );
    });
  }

  addPolyLine(List<LatLng> polylineCoordinates) {
    PolylineId id = const PolylineId("poly");
    Polyline polyline = Polyline(
      polylineId: id,
      color: Color(COLOR_PRIMARY),
      points: polylineCoordinates,
      width: 4,
      geodesic: true,
    );
    polyLines[id] = polyline;
    setState(() {});
  }

  late Stream<ParcelOrderModel?> ordersFuture;
  ParcelOrderModel? currentOrder;

  late Stream<UserModel> driverStream;
  UserModel? _driverModel = UserModel();

  bool _isFirstOrderLoad = true;

  getCurrentOrder() async {
    ordersFuture = FireStoreUtils().getParcelOrderByID(
      Constant.userModel!.inProgressOrderID.toString(),
    );

    ordersFuture.listen((event) {
      if (event == null) return;

      final previousStatus = currentOrder?.status;
      currentOrder = event;

      if (currentOrder!.status == ORDER_STATUS_DRIVER_REJECTED ||
          currentOrder!.status == ORDER_STATUS_DRIVER_PENDING ||
          currentOrder!.status == ORDER_STATUS_ACCEPTED) {
        currentOrder!.status = ORDER_STATUS_DRIVER_ACCEPTED;
      }

      if (_isFirstOrderLoad || previousStatus != currentOrder!.status) {
        _isFirstOrderLoad = false;
        getDirections();
      }
    });
  }

  getDriver() async {
    driverStream = FireStoreUtils().getDriver(FireStoreUtils.getCurrentUid());
    driverStream.listen((event) async {
      _driverModel = event;
      if (mounted) {
        setState(() {
          Constant.userModel = _driverModel;
        });
      }

      getDirections();

      _updateDriverMarkerAndCamera();

      if (_driverModel!.isActive == true) {
        if (_driverModel!.orderParcelRequestData != null) {
          playSound(true);
        }
      }
      if (_driverModel!.inProgressOrderID != null) {
        getCurrentOrder();
      }
      if (_driverModel!.orderParcelRequestData == null) {
        playSound(false);
      }
    });
  }

  Widget buildOrderActionsCard({
    pedding = 10,
    width = 60,
    bool isDark = false,
  }) {
    bool isPickedUp = false;
    String? buttonText;
    String googleMapUrl = '';
    if (currentOrder!.status == ORDER_STATUS_SHIPPED ||
        currentOrder!.status == ORDER_STATUS_DRIVER_ACCEPTED) {
      buttonText = 'Pick up Parcel'.tr();
      isPickedUp = true;
      googleMapUrl =
          'https://www.google.com/maps/dir/?api=1&origin=${_driverModel!.location?.latitude ?? 0},${_driverModel!.location?.longitude ?? 0}&destination=${currentOrder!.senderLatLong!.latitude},${currentOrder!.senderLatLong!.longitude}&travelmode=driving';
    } else if (currentOrder!.status == ORDER_STATUS_IN_TRANSIT) {
      buttonText = 'Parcel delivery'.tr();
      isPickedUp = false;
      googleMapUrl =
          'https://www.google.com/maps/dir/?api=1&origin=${_driverModel!.location?.latitude ?? 0},${_driverModel!.location?.longitude ?? 0}&destination=${currentOrder!.receiverLatLong!.latitude},${currentOrder!.receiverLatLong!.longitude}&travelmode=driving';
    }
    return Container(
      margin: EdgeInsets.only(left: 8, right: 8),
      padding: EdgeInsets.symmetric(vertical: 15),
      width: MediaQuery.sizeOf(context).width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(18),
        ),
        color: isDark ? Color(0xff000000) : Color(0xffFFFFFF),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Visibility(
              visible: currentOrder!.paymentCollectByReceiver == true,
              child: Center(
                child: Text(
                  "Payment Collect by Receiver".tr(),
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Color(0xffFFFFFF) : Color(0xff555555),
                    fontFamily: "Poppinsr",
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            if (currentOrder!.status == ORDER_STATUS_SHIPPED ||
                currentOrder!.status == ORDER_STATUS_DRIVER_ACCEPTED)
              Column(
                children: [
                  if (currentOrder!.paymentMethod?.toLowerCase() == 'cod' ||
                      currentOrder!.paymentCollectByReceiver == true)
                    ListTile(
                      leading: Icon(
                        Icons.monetization_on_rounded,
                        size: 32,
                        color: Color(COLOR_PRIMARY),
                      ),
                      title: Text(
                        'Payment Collect From ${currentOrder!.paymentCollectByReceiver == true ? 'Receiver' : 'Sender'}: LKR ${(double.parse(currentOrder!.subTotal ?? '0.0') - double.parse(currentOrder!.discount ?? '0.0'))}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? Color(0xffFFFFFF) : Color(0xff000000),
                          fontFamily: "Poppinsm",
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ListTile(
                    leading: Image.asset(
                      'assets/images/user3x.png',
                      height: 42,
                      width: 42,
                      color: Color(COLOR_PRIMARY),
                    ),
                    title: Text(
                      'Sender Name',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Color(0xffFFFFFF) : Color(0xff000000),
                        fontFamily: "Poppinsm",
                        letterSpacing: 0.5,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        '${currentOrder!.sender!.name}'.tr(),
                        style: TextStyle(
                          color: Color(0xff555555),
                          fontSize: 12,
                          fontFamily: "Poppinsr",
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6.0),
                              side: BorderSide(color: Color(0xff3DAE7D)),
                            ),
                            padding: EdgeInsets.zero,
                            minimumSize: Size(85, 30),
                            alignment: Alignment.center,
                            backgroundColor: Color(0xffFFFFFF),
                          ),
                          onPressed: () {
                            UrlLauncher.launchUrl(
                              Uri.parse("tel://${currentOrder!.sender!.phone}"),
                            );
                          },
                          icon: Image.asset(
                            'assets/images/call3x.png',
                            height: 14,
                            width: 14,
                          ),
                          label: Text(
                            "CALL".tr(),
                            style: TextStyle(
                              color: Color(0xff3DAE7D),
                              fontFamily: "Poppinsm",
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    leading: Image.asset(
                      'assets/images/user3x.png',
                      height: 42,
                      width: 42,
                      color: Color(COLOR_PRIMARY),
                    ),
                    title: Text(
                      'Receiver Name',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Color(0xffFFFFFF) : Color(0xff000000),
                        fontFamily: "Poppinsm",
                        letterSpacing: 0.5,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        '${currentOrder!.receiver!.name}'.tr(),
                        style: TextStyle(
                          color: Color(0xff555555),
                          fontSize: 12,
                          fontFamily: "Poppinsr",
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6.0),
                              side: BorderSide(color: Color(0xff3DAE7D)),
                            ),
                            padding: EdgeInsets.zero,
                            minimumSize: Size(85, 30),
                            alignment: Alignment.center,
                            backgroundColor: Color(0xffFFFFFF),
                          ),
                          onPressed: () {
                            UrlLauncher.launchUrl(
                              Uri.parse(
                                "tel://${currentOrder!.receiver!.phone}",
                              ),
                            );
                          },
                          icon: Image.asset(
                            'assets/images/call3x.png',
                            height: 14,
                            width: 14,
                          ),
                          label: Text(
                            "CALL".tr(),
                            style: TextStyle(
                              color: Color(0xff3DAE7D),
                              fontFamily: "Poppinsm",
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    leading: Image.asset(
                      'assets/images/user3x.png',
                      height: 42,
                      width: 42,
                      color: Color(COLOR_PRIMARY),
                    ),
                    title: Text(
                      '${currentOrder!.receiver!.address}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Color(0xffFFFFFF) : Color(0xff000000),
                        fontFamily: "Poppinsm",
                        letterSpacing: 0.5,
                      ),
                    ),
                    subtitle: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'ORDER ID '.tr(),
                            style: TextStyle(
                              color: Color(0xff555555),
                              fontSize: 12,
                              fontFamily: "Poppinsr",
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: SizedBox(
                            width: MediaQuery.sizeOf(context).width / 4,
                            child: Text(
                              '${currentOrder!.id} ',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Color(0xffFFFFFF)
                                    : Color(0xff000000),
                                fontFamily: "Poppinsr",
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6.0),
                              side: BorderSide(color: Color(0xff3DAE7D)),
                            ),
                            padding: EdgeInsets.zero,
                            minimumSize: Size(85, 30),
                            alignment: Alignment.center,
                            backgroundColor: Color(0xffFFFFFF),
                          ),
                          onPressed: () {
                            UrlLauncher.launchUrl(
                              Uri.parse(
                                "tel://${currentOrder!.author!.phoneNumber}",
                              ),
                            );
                          },
                          icon: Image.asset(
                            'assets/images/call3x.png',
                            height: 14,
                            width: 14,
                          ),
                          label: Text(
                            "CALL".tr(),
                            style: TextStyle(
                              color: Color(0xff3DAE7D),
                              fontFamily: "Poppinsm",
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            SizedBox(height: 10),
            if (currentOrder!.status == ORDER_STATUS_IN_TRANSIT)
              Column(
                children: [
                  if (currentOrder!.paymentMethod?.toLowerCase() == 'cod' ||
                      currentOrder!.paymentCollectByReceiver == true)
                    ListTile(
                      leading: Icon(
                        Icons.monetization_on_rounded,
                        size: 32,
                        color: Color(COLOR_PRIMARY),
                      ),
                      title: Text(
                        'Payment Collect From ${currentOrder!.paymentCollectByReceiver == true ? 'Receiver' : 'Sender'}: LKR ${(double.parse(currentOrder!.subTotal ?? '0.0') - double.parse(currentOrder!.discount ?? '0.0'))}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? Color(0xffFFFFFF) : Color(0xff000000),
                          fontFamily: "Poppinsm",
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ListTile(
                    leading: Image.asset(
                      'assets/images/user3x.png',
                      height: 42,
                      width: 42,
                      color: Color(COLOR_PRIMARY),
                    ),
                    title: Text(
                      'Sender Name',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Color(0xffFFFFFF) : Color(0xff000000),
                        fontFamily: "Poppinsm",
                        letterSpacing: 0.5,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        '${currentOrder!.sender!.name}'.tr(),
                        style: TextStyle(
                          color: Color(0xff555555),
                          fontSize: 12,
                          fontFamily: "Poppinsr",
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6.0),
                              side: BorderSide(color: Color(0xff3DAE7D)),
                            ),
                            padding: EdgeInsets.zero,
                            minimumSize: Size(85, 30),
                            alignment: Alignment.center,
                            backgroundColor: Color(0xffFFFFFF),
                          ),
                          onPressed: () {
                            UrlLauncher.launchUrl(
                              Uri.parse("tel://${currentOrder!.sender!.phone}"),
                            );
                          },
                          icon: Image.asset(
                            'assets/images/call3x.png',
                            height: 14,
                            width: 14,
                          ),
                          label: Text(
                            "CALL".tr(),
                            style: TextStyle(
                              color: Color(0xff3DAE7D),
                              fontFamily: "Poppinsm",
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    leading: Image.asset(
                      'assets/images/user3x.png',
                      height: 42,
                      width: 42,
                      color: Color(COLOR_PRIMARY),
                    ),
                    title: Text(
                      'Receiver Name',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Color(0xffFFFFFF) : Color(0xff000000),
                        fontFamily: "Poppinsm",
                        letterSpacing: 0.5,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        '${currentOrder!.receiver!.name}'.tr(),
                        style: TextStyle(
                          color: Color(0xff555555),
                          fontSize: 12,
                          fontFamily: "Poppinsr",
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6.0),
                              side: BorderSide(color: Color(0xff3DAE7D)),
                            ),
                            padding: EdgeInsets.zero,
                            minimumSize: Size(85, 30),
                            alignment: Alignment.center,
                            backgroundColor: Color(0xffFFFFFF),
                          ),
                          onPressed: () {
                            UrlLauncher.launchUrl(
                              Uri.parse(
                                "tel://${currentOrder!.receiver!.phone}",
                              ),
                            );
                          },
                          icon: Image.asset(
                            'assets/images/call3x.png',
                            height: 14,
                            width: 14,
                          ),
                          label: Text(
                            "CALL".tr(),
                            style: TextStyle(
                              color: Color(0xff3DAE7D),
                              fontFamily: "Poppinsm",
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    leading: Image.asset(
                      'assets/images/user3x.png',
                      height: 42,
                      width: 42,
                      color: Color(COLOR_PRIMARY),
                    ),
                    title: Text(
                      '${currentOrder!.author!.fullName()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Color(0xffFFFFFF) : Color(0xff000000),
                        fontFamily: "Poppinsm",
                        letterSpacing: 0.5,
                      ),
                    ),
                    subtitle: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'ORDER ID '.tr(),
                            style: TextStyle(
                              color: Color(0xff555555),
                              fontSize: 12,
                              fontFamily: "Poppinsr",
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: SizedBox(
                            width: MediaQuery.sizeOf(context).width / 4,
                            child: Text(
                              '${currentOrder!.id} ',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDark
                                    ? Color(0xffFFFFFF)
                                    : Color(0xff000000),
                                fontSize: 12,
                                fontFamily: "Poppinsr",
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6.0),
                              side: BorderSide(color: Color(0xff3DAE7D)),
                            ),
                            padding: EdgeInsets.zero,
                            minimumSize: Size(85, 30),
                            alignment: Alignment.center,
                            backgroundColor: Color(0xffFFFFFF),
                          ),
                          onPressed: () {
                            UrlLauncher.launchUrl(
                              Uri.parse(
                                "tel://${currentOrder!.author!.phoneNumber}",
                              ),
                            );
                          },
                          icon: Image.asset(
                            'assets/images/call3x.png',
                            height: 14,
                            width: 14,
                          ),
                          label: Text(
                            "CALL".tr(),
                            style: TextStyle(
                              color: Color(0xff3DAE7D),
                              fontFamily: "Poppinsm",
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    leading: Image.asset(
                      'assets/images/delivery_location3x.png',
                      height: 42,
                      width: 42,
                      color: Color(COLOR_PRIMARY),
                    ),
                    title: Text(
                      'Destination'.tr(),
                      style: TextStyle(
                        color: Color(0xff9091A4),
                        fontFamily: "Poppinsr",
                        letterSpacing: 0.5,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        '${currentOrder!.receiver!.address}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? Color(0xffFFFFFF) : Color(0xff333333),
                          fontFamily: "Poppinsr",
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6.0),
                              side: BorderSide(color: Color(0xff3DAE7D)),
                            ),
                            padding: EdgeInsets.zero,
                            minimumSize: Size(100, 30),
                            alignment: Alignment.center,
                            backgroundColor: Color(0xffFFFFFF),
                          ),
                          onPressed: () => openChatWithCustomer(),
                          icon: Icon(
                            Icons.message,
                            size: 16,
                            color: Color(0xff3DAE7D),
                          ),
                          label: Text(
                            "Message".tr(),
                            style: TextStyle(
                              color: Color(0xff3DAE7D),
                              fontFamily: "Poppinsm",
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 25),
                ],
              ),
            isPickedUp
                ? FadeTransition(
                    opacity: _animationController!,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: AnimatedContainer(
                        duration: Duration(seconds: 2),
                        height: 40,
                        width: MediaQuery.sizeOf(context).width,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(4),
                              ),
                            ),
                            backgroundColor: Color(COLOR_PRIMARY),
                          ),
                          onPressed: () async {
                            if (currentOrder!.status == ORDER_STATUS_SHIPPED ||
                                currentOrder!.status ==
                                    ORDER_STATUS_DRIVER_ACCEPTED) {
                              completePickUp();
                            } else if (currentOrder!.status ==
                                ORDER_STATUS_IN_TRANSIT) {
                              completeOrder();
                            }
                          },
                          child: Text(
                            buttonText ?? "",
                            style: TextStyle(
                              color: Color(0xffFFFFFF),
                              fontFamily: "Poppinsm",
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: AnimatedContainer(
                      duration: Duration(seconds: 2),
                      height: 40,
                      width: MediaQuery.sizeOf(context).width,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(4)),
                          ),
                          backgroundColor: Color(COLOR_PRIMARY),
                        ),
                        onPressed: () async {
                          if (currentOrder!.status == ORDER_STATUS_SHIPPED ||
                              currentOrder!.status ==
                                  ORDER_STATUS_DRIVER_ACCEPTED) {
                            completePickUp();
                          } else if (currentOrder!.status ==
                              ORDER_STATUS_IN_TRANSIT) {
                            completeOrder();
                          }
                        },
                        child: Text(
                          buttonText ?? "",
                          style: TextStyle(
                            color: Color(0xffFFFFFF),
                            fontFamily: "Poppinsm",
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
            if (googleMapUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(14),
                child: SizedBox(
                  height: 40,
                  width: MediaQuery.sizeOf(context).width,
                  child: ElevatedButton(
                    onPressed: () async {
                      await UrlLauncher.launchUrl(Uri.parse(googleMapUrl));
                    },
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                      ),
                      backgroundColor: Color(0xff3DAE7D),
                    ),
                    child: Text(
                      'Direction on Map',
                      style: TextStyle(
                        color: Color(0xffFFFFFF),
                        fontFamily: "Poppinsm",
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  completePickUp() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            ParcelImagesShow(images: currentOrder!.parcelImages!),
      ),
    );

    if (result != null) {
      if (result == "pickup") {
        print('HomeScreenState.completePickUp');
        showProgress(context, 'Updating order...', false);
        currentOrder!.status = ORDER_STATUS_IN_TRANSIT;
        await FireStoreUtils.updateParcelOrder(currentOrder!);

        hideProgress();
        setState(() {});
      } else if (result == "orderCancel") {
        print('HomeScreenState.completePickUp');
        showProgress(context, 'Updating order...', false);
        currentOrder!.status = ORDER_STATUS_REJECTED;
        await FireStoreUtils.updateParcelOrder(currentOrder!);

        if (currentOrder!.paymentMethod?.toLowerCase() != "cod") {
          double totalTax = 0.0;
          if (currentOrder!.taxSetting != null) {
            for (var element in currentOrder!.taxSetting!) {
              totalTax = totalTax +
                  calculateTax(
                    amount: (double.parse(currentOrder!.subTotal!.toString()) -
                            double.parse(
                              currentOrder!.discount!.toString(),
                            ))
                        .toString(),
                    taxModel: element,
                  );
            }
          }

          double subTotal = double.parse(currentOrder!.subTotal.toString()) -
              double.parse(currentOrder!.discount.toString());

          double userAmount = 0;

          if (currentOrder!.paymentMethod?.toLowerCase() != "cod") {
            userAmount = subTotal + totalTax;
          }

          await FireStoreUtils.createPaymentId().then((value) async {
            final paymentID = value;
            await FireStoreUtils.topUpWalletAmount(
              userID: currentOrder!.authorID!,
              paymentMethod: "Refund Amount",
              amount: userAmount,
              id: paymentID,
            ).then((value) async {
              await FireStoreUtils.updateUserWalletAmount(
                userId: currentOrder!.authorID!,
                amount: userAmount,
              ).then((value) {});
            });
          });
        }

        Position? locationData = await getCurrentLocation();
        Map<String, dynamic> payLoad = <String, dynamic>{
          "type": "parcel_order",
          "orderId": currentOrder!.id,
        };
        await FireStoreUtils.sendFcmMessage(
          parcelRejected,
          currentOrder!.author!.fcmToken ?? '',
          payLoad,
        );

        Constant.userModel!.location = UserLocation(
          latitude: locationData.latitude,
          longitude: locationData.longitude,
        );
        Constant.userModel!.geoFireData = GeoFireData(
          geohash: GeoFlutterFire()
              .point(
                latitude: locationData.latitude,
                longitude: locationData.longitude,
              )
              .hash,
          geoPoint: GeoPoint(locationData.latitude, locationData.longitude),
        );
        Constant.userModel!.inProgressOrderID = null;
        currentOrder = null;

        await FireStoreUtils.updateCurrentUser(Constant.userModel!);

        _markers.clear();
        polyLines.clear();

        _mapController?.moveCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(locationData.latitude, locationData.longitude),
              zoom: 15,
            ),
          ),
        );

        hideProgress();
        setState(() {});
      }
    }
  }

  completeOrder() async {
    showProgress(context, 'Completing Delivery...'.tr(), false);
    currentOrder!.status = ORDER_STATUS_COMPLETED;
    updateParcelWalletAmount(currentOrder!);
    await FireStoreUtils.updateParcelOrder(currentOrder!);
    Position? locationData = await getCurrentLocation();
    Map<String, dynamic> payLoad = <String, dynamic>{
      "type": "parcel_order",
      "orderId": currentOrder!.id,
    };
    await FireStoreUtils.sendFcmMessage(
      parcelCompleted,
      currentOrder!.author!.fcmToken ?? '',
      payLoad,
    );
    await FireStoreUtils.getParcelFirstOrderOrNOt(currentOrder!).then((
      value,
    ) async {
      if (value == true) {
        await FireStoreUtils.updateParcelReferralAmount(currentOrder!);
      }
    });
    _driverModel!.inProgressOrderID = null;
    _driverModel!.location = UserLocation(
      latitude: locationData.latitude,
      longitude: locationData.longitude,
    );
    _driverModel!.geoFireData = GeoFireData(
      geohash: GeoFlutterFire()
          .point(
            latitude: locationData.latitude,
            longitude: locationData.longitude,
          )
          .hash,
      geoPoint: GeoPoint(locationData.latitude, locationData.longitude),
    );

    currentOrder = null;

    await FireStoreUtils.updateCurrentUser(_driverModel!);
    hideProgress();

    _markers.clear();
    polyLines.clear();

    _mapController?.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(locationData.latitude, locationData.longitude),
          zoom: 15,
        ),
      ),
    );
    setState(() {});
  }

  openChatWithCustomer() async {
    ShowToastDialog.showLoader("Please wait".tr());
    UserModel? customer = await FireStoreUtils.getCurrentUser(
      currentOrder!.authorID!,
    );

    UserModel? driver = await FireStoreUtils.getCurrentUser(
      currentOrder!.driverId.toString(),
    );
    ShowToastDialog.closeLoader();
    push(
      context,
      ChatScreens(
        type: "cab_parcel_chat",
        customerName:
            customer!.firstName ?? '' + " " + (customer.lastName ?? ''),
        restaurantName: driver!.firstName ?? '' + " " + (driver.lastName ?? ''),
        orderId: currentOrder!.id,
        restaurantId: driver.id,
        customerId: customer.id,
        customerProfileImage: customer.profilePictureURL,
        restaurantProfileImage: driver.profilePictureURL,
        token: customer.fcmToken,
        chatType: 'Driver',
      ),
    );
  }
}

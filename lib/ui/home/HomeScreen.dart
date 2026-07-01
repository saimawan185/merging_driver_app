import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:door_delights_driver/constant/constant.dart';
import 'package:door_delights_driver/services/show_toast_dialog.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:door_delights_driver/constants.dart';
import 'package:door_delights_driver/model/VendorModel.dart';
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

import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../theme/app_them_data.dart';
import '../../themes/theme_controller.dart';
import 'pick_order.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    Key? key,
    required this.isAppBarShow,
  }) : super(key: key);
  final bool isAppBarShow;

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final fireStoreUtils = FireStoreUtils();

  GoogleMapController? _mapController;
  bool canShowSheet = true;

  BitmapDescriptor? departureIcon;
  BitmapDescriptor? destinationIcon;
  BitmapDescriptor? taxiIcon;

  Map<PolylineId, Polyline> polyLines = {};
  PolylinePoints polylinePoints = PolylinePoints(apiKey: GOOGLE_API_KEY);
  final Map<String, Marker> _markers = {};

  // Add route caching variables
  String? _lastRouteOrigin;
  // String? _lastRouteDestination;
  String? _lastOrderStatus;

  setIcons() async {
    BitmapDescriptor.asset(
            const ImageConfiguration(
              size: Size(50, 50),
            ),
            "assets/images/pickup.png")
        .then((value) {
      departureIcon = value;
    });

    BitmapDescriptor.asset(
            const ImageConfiguration(
              size: Size(50, 50),
            ),
            "assets/images/dropoff.png")
        .then((value) {
      destinationIcon = value;
    });

    BitmapDescriptor.asset(
            const ImageConfiguration(
              size: Size(50, 50),
            ),
            "assets/images/food_delivery.png")
        .then((value) {
      taxiIcon = value;
    });
  }

  updateDriverOrder() async {
    Timestamp startTimestamp = Timestamp.now();
    DateTime currentDate = startTimestamp.toDate();
    currentDate = currentDate.subtract(Duration(hours: 3));
    startTimestamp = Timestamp.fromDate(currentDate);

    List<OrderModel> orders = [];

    await FirebaseFirestore.instance
        .collection(ORDERS)
        .where('status',
            whereIn: [ORDER_STATUS_ACCEPTED, ORDER_STATUS_DRIVER_REJECTED])
        .where('createdAt', isGreaterThan: startTimestamp)
        .get()
        .then((value) async {
          print('---->${value.docs.length}');
          await Future.forEach(value.docs,
              (QueryDocumentSnapshot<Map<String, dynamic>> element) {
            try {
              orders.add(OrderModel.fromJson(element.data()));
            } catch (e, s) {
              print('watchOrdersStatus parse error ${element.id}$e $s');
            }
          });
        });

    orders.forEach((element) {
      OrderModel orderModel = element;
      print('---->${orderModel.id}');
      orderModel.triggerDelivery = Timestamp.now();
      FirebaseFirestore.instance
          .collection(ORDERS)
          .doc(element.id)
          .set(orderModel.toJson(), SetOptions(merge: true))
          .then((order) {});
    });
  }

  @override
  void initState() {
    getDriver();
    setIcons();
    getLocation();
    updateDriverOrder();

    super.initState();
  }

  getLocation() async {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(locationDataFinal?.latitude ?? 0.0,
              locationDataFinal?.longitude ?? 0.0),
          zoom: 20,
          bearing: double.parse(_driverModel!.rotation.toString()),
        ),
      ),
    );
    setState(() {});
  }

  bool? deliverExec = false;

  var deliveryCharges = "0.0";
  VendorModel? vendorModel;

  getDeliveryCharges(num km, OrderModel? requestedOrder) async {
    deliverExec = true;

    await FireStoreUtils()
        .getVendorByVendorID(requestedOrder!.vendorID!)
        .then((value) {
      vendorModel = value;
    });
    deliveryCharges = requestedOrder.deliveryCharge ?? '80.0';
    setState(() {});
  }

  late Stream<OrderModel?> ordersFuture;
  OrderModel? currentOrder;

  late Stream<UserModel> driverStream;
  UserModel? _driverModel = UserModel();
  double kilometer = 0.0;

  // Add this variable
  String? previousStatus;
  bool _isFirstOrderLoad = true;

  getCurrentOrder() async {
    ordersFuture = FireStoreUtils()
        .getOrderByID(Constant.userModel!.inProgressOrderID.toString());
    ordersFuture.listen((event) {
      currentOrder = event;
      if (currentOrder!.status == ORDER_STATUS_DRIVER_REJECTED ||
          currentOrder!.status == ORDER_STATUS_DRIVER_PENDING ||
          currentOrder!.status == ORDER_STATUS_ACCEPTED) {
        currentOrder!.status = ORDER_STATUS_DRIVER_ACCEPTED;
      }

      if (currentOrder!.status == ORDER_STATUS_COMPLETED) {
        Constant.userModel!.inProgressOrderID = null;
        FireStoreUtils.updateCurrentUser(Constant.userModel!);
      }

      // Only call getDirections if status changed or it's first load
      if (_isFirstOrderLoad || previousStatus != currentOrder!.status) {
        log("Getting direction");
        _isFirstOrderLoad = false;
        previousStatus = currentOrder?.status;
        getDirections();
      } else {
        log("Order current status: ${currentOrder!.status}");
        log("Order prev status: ${previousStatus}");
      }
    });
  }

  Timer? _timer;

  void startTimer(UserModel _driverModel) {
    const oneSec = const Duration(seconds: 1);
    _timer = new Timer.periodic(
      oneSec,
      (Timer timer) async {
        if (driverOrderAcceptRejectDuration == 0) {
          timer.cancel();
          if (_driverModel.orderRequestData != null) {
            await rejectOrder();
          }
        } else {
          driverOrderAcceptRejectDuration--;
        }
      },
    );
  }

  getDriver() async {
    driverStream = FireStoreUtils().getDriver(Constant.userModel!.id!);
    driverStream.listen((event) async {
      _driverModel = event;
      setState(() {
        Constant.userModel = _driverModel;
      });

      getDirections();
      if (_driverModel!.inProgressOrderID != null) {
        getCurrentOrder();
      }
    });
  }

  @override
  void dispose() {
    _mapController!.dispose();
    if (FireStoreUtils().driverStreamSub != null) {
      FireStoreUtils().driverStreamSub!.cancel();
    }
    FireStoreUtils().ordersStreamController.close();
    FireStoreUtils().ordersStreamSub.cancel();
    if (_timer != null) {
      _timer!.cancel();
    }
    _remaningTimer?.cancel();

    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  bool isShow = false;

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();

    return Obx(() {
      final isDark = themeController.isDark.value;

      isDark
          ? _mapController?.setMapStyle('[{"featureType": "all","'
              'elementType": "'
              'geo'
              'met'
              'ry","stylers": [{"color": "#242f3e"}]},{"featureType": "all","elementType": "labels.text.stroke","stylers": [{"lightness": -80}]},{"featureType": "administrative","elementType": "labels.text.fill","stylers": [{"color": "#746855"}]},{"featureType": "administrative.locality","elementType": "labels.text.fill","stylers": [{"color": "#d59563"}]},{"featureType": "poi","elementType": "labels.text.fill","stylers": [{"color": "#d59563"}]},{"featureType": "poi.park","elementType": "geometry","stylers": [{"color": "#263c3f"}]},{"featureType": "poi.park","elementType": "labels.text.fill","stylers": [{"color": "#6b9a76"}]},{"featureType": "road","elementType": "geometry.fill","stylers": [{"color": "#2b3544"}]},{"featureType": "road","elementType": "labels.text.fill","stylers": [{"color": "#9ca5b3"}]},{"featureType": "road.arterial","elementType": "geometry.fill","stylers": [{"color": "#38414e"}]},{"featureType": "road.arterial","elementType": "geometry.stroke","stylers": [{"color": "#212a37"}]},{"featureType": "road.highway","elementType": "geometry.fill","stylers": [{"color": "#746855"}]},{"featureType": "road.highway","elementType": "geometry.stroke","stylers": [{"color": "#1f2835"}]},{"featureType": "road.highway","elementType": "labels.text.fill","stylers": [{"color": "#f3d19c"}]},{"featureType": "road.local","elementType": "geometry.fill","stylers": [{"color": "#38414e"}]},{"featureType": "road.local","elementType": "geometry.stroke","stylers": [{"color": "#212a37"}]},{"featureType": "transit","elementType": "geometry","stylers": [{"color": "#2f3948"}]},{"featureType": "transit.station","elementType": "labels.text.fill","stylers": [{"color": "#d59563"}]},{"featureType": "water","elementType": "geometry","stylers": [{"color": "#17263c"}]},{"featureType": "water","elementType": "labels.text.fill","stylers": [{"color": "#515c6d"}]},{"featureType": "water","elementType": "labels.text.stroke","stylers": [{"lightness": -20}]}]')
          : _mapController?.setMapStyle(null);

      return Scaffold(
        appBar: widget.isAppBarShow == true
            ? AppBar(
                backgroundColor:
                    isDark ? AppThemeData.grey900 : AppThemeData.grey50,
                centerTitle: false,
                iconTheme:
                    const IconThemeData(color: AppThemeData.grey900, size: 20),
                title: Text(
                  "Order".tr(),
                  style: TextStyle(
                      color:
                          isDark ? AppThemeData.grey50 : AppThemeData.grey900,
                      fontSize: 18,
                      fontFamily: AppThemeData.medium),
                ),
              )
            : null,
        body: Column(
          children: [
            Visibility(
              visible: _driverModel!.inProgressOrderID == null &&
                  (double.tryParse(_driverModel!.walletAmount.toString()) ??
                          0) <
                      double.parse(minimumDepositToRideAccept),
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  color: Colors.black,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                        "${"You have to minimum ".tr()}${amountShow(amount: minimumDepositToRideAccept.toString())} ${"wallet amount to receiving Order".tr()}",
                        style: TextStyle(color: Colors.white),
                        textAlign: TextAlign.center),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GoogleMap(
                onMapCreated: _onMapCreated,
                myLocationEnabled:
                    _driverModel!.inProgressOrderID != null ? false : true,
                myLocationButtonEnabled: true,
                mapType: MapType.terrain,
                zoomControlsEnabled: false,
                polylines: Set<Polyline>.of(polyLines.values),
                markers: _markers.values.toSet(),
                initialCameraPosition: CameraPosition(
                  zoom: 15,
                  target: LatLng(_driverModel!.location?.latitude ?? 0,
                      _driverModel!.location?.longitude ?? 0),
                ),
              ),
            ),
            _driverModel!.inProgressOrderID != null &&
                    currentOrder != null &&
                    isShow == true
                ? buildOrderActionsCard()
                : Container(),
            _driverModel!.orderRequestData != null
                ? showDriverBottomSheet()
                : Container()
          ],
        ),
        floatingActionButton: _driverModel!.orderRequestData != null ||
                _driverModel!.inProgressOrderID == null
            ? null
            : FloatingActionButton(
                onPressed: () {
                  getCurrentOrder();
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

  // OPTIMIZED ROUTE CALCULATION METHODS
  getDirections() async {
    if (currentOrder == null) return;

    // Check if we need to recalculate the route
    final currentStatus = currentOrder?.status ?? "request";
    final shouldRecalculate = _shouldRecalculateRoute(currentStatus);

    if (!shouldRecalculate) {
      log("Skipping route calculation - no significant changes");
      return;
    }

    LatLng origin;
    LatLng destination;
    bool includeDriverMarker = true;

    if (currentOrder != null) {
      if (currentOrder!.status == ORDER_STATUS_SHIPPED ||
          currentOrder!.status == ORDER_STATUS_DRIVER_ACCEPTED) {
        origin = LatLng(_driverModel!.location!.latitude!,
            _driverModel!.location!.longitude!);
        destination = LatLng(
            currentOrder!.vendor!.latitude!, currentOrder!.vendor!.longitude!);
      } else if (currentOrder!.status == ORDER_STATUS_IN_TRANSIT) {
        origin = LatLng(_driverModel!.location!.latitude!,
            _driverModel!.location!.longitude!);
        destination = LatLng(currentOrder!.address!.location!.latitude!,
            currentOrder!.address!.location!.longitude!);
      } else {
        return;
      }
    } else if (_driverModel!.orderRequestData != null) {
      origin = LatLng(_driverModel!.location!.latitude!,
          _driverModel!.location!.longitude!);
      destination = LatLng(_driverModel!.orderRequestData!.vendor!.latitude!,
          _driverModel!.orderRequestData!.vendor!.longitude!);
    } else {
      return;
    }

    try {
      List<LatLng> polylineCoordinates =
          await _getRouteCoordinates(origin, destination);

      _updateMarkers(origin, destination, includeDriverMarker);
      addPolyLine(polylineCoordinates);

      // Cache the current route information
      _lastRouteOrigin = "${origin.latitude},${origin.longitude}";
      // _lastRouteDestination =
      //     "${destination.latitude},${destination.longitude}";
      _lastOrderStatus = currentStatus;
    } catch (e) {
      log("Error getting directions: $e");
    }
  }

  bool _shouldRecalculateRoute(String currentStatus) {
    // Always recalculate if order status changed
    if (_lastOrderStatus != currentStatus) return true;

    // Recalculate if driver location changed significantly (more than 100 meters)
    if (_lastRouteOrigin != null && _driverModel != null) {
      final currentOrigin =
          "${_driverModel!.location!.latitude},${_driverModel!.location!.longitude}";
      if (_lastRouteOrigin != currentOrigin) {
        double distance = _calculateDistance(_lastRouteOrigin!, currentOrigin);
        log("Driver moved: ${distance.toStringAsFixed(2)} km");
        return distance > 0.1;
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
      LatLng origin, LatLng destination) async {
    log("Getting coordinates from ${origin.latitude},${origin.longitude} to ${destination.latitude},${destination.longitude}");

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
      LatLng origin, LatLng destination, bool includeDriverMarker) {
    setState(() {
      // Clear existing markers
      _markers.clear();

      // Add driver marker if needed
      if (includeDriverMarker && _driverModel != null) {
        _markers['Driver'] = Marker(
          markerId: const MarkerId('Driver'),
          infoWindow: const InfoWindow(title: "Driver"),
          position: LatLng(_driverModel!.location!.latitude!,
              _driverModel!.location!.longitude!),
          icon: taxiIcon!,
          rotation: double.parse(_driverModel!.rotation.toString()),
        );
      }

      // Determine which markers to add based on context
      if (currentOrder != null) {
        if (currentOrder!.status == ORDER_STATUS_SHIPPED ||
            currentOrder!.status == ORDER_STATUS_DRIVER_ACCEPTED) {
          // Going to vendor
          _markers['Vendor'] = Marker(
            markerId: const MarkerId('Vendor'),
            infoWindow: InfoWindow(title: currentOrder!.vendor!.title),
            position: LatLng(currentOrder!.vendor!.latitude!,
                currentOrder!.vendor!.longitude!),
            icon: departureIcon!,
          );
        } else if (currentOrder!.status == ORDER_STATUS_IN_TRANSIT) {
          // Going to customer
          _markers['Customer'] = Marker(
            markerId: const MarkerId('Customer'),
            infoWindow: InfoWindow(title: currentOrder!.author!.fullName()),
            position: LatLng(currentOrder!.address!.location!.latitude!,
                currentOrder!.address!.location!.longitude!),
            icon: destinationIcon!,
          );
        }
      } else if (_driverModel!.orderRequestData != null) {
        // New order request - going to vendor
        _markers['Vendor'] = Marker(
          markerId: const MarkerId('Vendor'),
          infoWindow:
              InfoWindow(title: _driverModel!.orderRequestData!.vendor!.title),
          position: LatLng(_driverModel!.orderRequestData!.vendor!.latitude!,
              _driverModel!.orderRequestData!.vendor!.longitude!),
          icon: departureIcon!,
        );
      }
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

    // Update camera to show the route
    if (polylineCoordinates.isNotEmpty) {
      updateCameraLocation(
          polylineCoordinates.first, polylineCoordinates.last, _mapController);
    }

    setState(() {});
  }

  // ... REST OF YOUR EXISTING METHODS REMAIN THE SAME ...
  // (openChatWithCustomer, showDriverBottomSheet, acceptOrder, completeOrder, rejectOrder, etc.)

  // Keep all your existing methods below - they don't need changes
  openChatWithCustomer() async {
    ShowToastDialog.showLoader("Please wait".tr());
    UserModel? customer =
        await FireStoreUtils.getCurrentUser(currentOrder!.authorID!);
    print(currentOrder!.driverID);

    UserModel? driver =
        await FireStoreUtils.getCurrentUser(currentOrder!.driverID.toString());
    ShowToastDialog.closeLoader();
    push(
        context,
        ChatScreens(
          type: "vendor_chat",
          customerName: customer!.firstName! + " " + customer.lastName!,
          restaurantName: driver!.firstName! + " " + driver.lastName!,
          orderId: currentOrder!.id,
          restaurantId: driver.id!,
          customerId: customer.id!,
          customerProfileImage: customer.profilePictureURL!,
          restaurantProfileImage: driver.profilePictureURL,
          token: customer.fcmToken,
          chatType: 'Driver',
        ));
  }

  Widget showDriverBottomSheet() {
    double distanceInMeters = Geolocator.distanceBetween(
      _driverModel!.orderRequestData!.vendor!.latitude!,
      _driverModel!.orderRequestData!.vendor!.longitude!,
      _driverModel!.orderRequestData!.address!.location!.latitude!,
      _driverModel!.orderRequestData!.address!.location!.longitude!,
    );
    double kilometer = distanceInMeters / 1000;

    if (_driverModel!.orderRequestData != null) {
      getDeliveryCharges(kilometer, _driverModel!.orderRequestData);
    }

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
                        letterSpacing: 0.5),
                  ),
                ),
                Text(
                  "${kilometer.toStringAsFixed(currencyData!.decimal)} km",
                  style: TextStyle(
                      color: Color(0xffFFFFFF),
                      fontFamily: "Poppinsm",
                      letterSpacing: 0.5),
                ),
              ],
            ),
            SizedBox(
              height: 5,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: Text(
                    "Delivery charge".tr(),
                    style: TextStyle(
                        color: Color(0xffADADAD),
                        fontFamily: "Poppinsr",
                        letterSpacing: 0.5),
                  ),
                ),
                Text(
                  "${amountShow(amount: deliveryCharges.toString())}",
                  style: TextStyle(
                      color: Color(0xffFFFFFF),
                      fontFamily: "Poppinsm",
                      letterSpacing: 0.5),
                ),
              ],
            ),
            SizedBox(height: 5),
            Card(
              color: Color(0xffFFFFFF),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 14.0, horizontal: 10),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/images/location3x.png',
                      height: 55,
                    ),
                    SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 270,
                          child: Text(
                            "${_driverModel!.orderRequestData!.vendor!.location} ",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Color(0xff333333),
                                fontFamily: "Poppinsr",
                                letterSpacing: 0.5),
                          ),
                        ),
                        SizedBox(height: 22),
                        SizedBox(
                          width: 270,
                          child: Text(
                            "${_driverModel!.orderRequestData!.address!.getFullAddress()} ",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Color(0xff333333),
                                fontFamily: "Poppinsr",
                                letterSpacing: 0.5),
                          ),
                        ),
                      ],
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
                  height: MediaQuery.of(context).size.height / 20,
                  width: MediaQuery.of(context).size.width / 2.5,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 12),
                      backgroundColor: Color(COLOR_PRIMARY),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(
                          Radius.circular(5),
                        ),
                      ),
                    ),
                    child: Text(
                      'Reject',
                      style: TextStyle(
                          color: Color(0xffFFFFFF),
                          fontFamily: "Poppinsm",
                          letterSpacing: 0.5),
                    ),
                    onPressed: () async {
                      showProgress(context, 'Rejecting order...'.tr(), false);
                      try {
                        if (_timer != null) {
                          _timer!.cancel();
                        }
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
                  height: MediaQuery.of(context).size.height / 20,
                  width: MediaQuery.of(context).size.width / 2.5,
                  child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            vertical: 6, horizontal: 12),
                        backgroundColor: Color(COLOR_PRIMARY),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(
                            Radius.circular(5),
                          ),
                        ),
                      ),
                      child: Text(
                        'Accept'.tr(),
                        style: TextStyle(
                            color: Color(0xffFFFFFF),
                            fontFamily: "Poppinsm",
                            letterSpacing: 0.5),
                      ),
                      onPressed: () async {
                        showProgress(context, 'Accepting order...'.tr(), false);
                        if (_timer != null) {
                          _timer!.cancel();
                        }
                        await acceptOrder();
                        hideProgress();
                      }),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  late Duration _remainingTime;
  Timer? _remaningTimer;
  late DateTime _targetTime;

  void _calculateTargetTime(String preparationTime, DateTime orderTime) {
    final parts = preparationTime.split(':');
    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = int.tryParse(parts[1]) ?? 0;

    _targetTime = orderTime.add(Duration(hours: hours, minutes: minutes));

    _remainingTime = _targetTime.difference(DateTime.now());
  }

  void _startTimer() {
    _remaningTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      if (mounted) {
        setState(() {
          _remainingTime = _targetTime.difference(now);

          if (_remainingTime.isNegative) {
            _remainingTime = Duration.zero;
            timer.cancel();
          }
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) return "00:00";

    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    return "$minutes:$seconds";
  }

  Widget buildOrderActionsCard() {
    late String title;
    String? buttonText;
    String googleMapUrl = '';
    double totalPrice = 0.0;
    if (currentOrder!.status == ORDER_STATUS_SHIPPED ||
        currentOrder!.status == ORDER_STATUS_DRIVER_ACCEPTED) {
      if (currentOrder!.estimatedTimeToPrepare != null &&
          currentOrder!.estimatedTimeToPrepare!.isNotEmpty) {
        _calculateTargetTime(
          currentOrder!.estimatedTimeToPrepare!,
          currentOrder!.createdAt!.toDate(),
        );
        _startTimer();
      }
      title = '${currentOrder!.vendor!.title}';
      buttonText = 'REACHED STORE FOR PICKUP'.tr();
      googleMapUrl =
          'https://www.google.com/maps/dir/?api=1&origin=${_driverModel!.location!.latitude},${_driverModel!.location!.longitude}&destination=${currentOrder!.vendor!.latitude},${currentOrder!.vendor!.longitude}&travelmode=driving';
    } else if (currentOrder!.status == ORDER_STATUS_IN_TRANSIT) {
      title = 'Deliver to {}'.tr(args: ['${currentOrder!.author!.firstName}']);
      buttonText = 'REACHED CUSTOMER DOOR STEP'.tr();
      googleMapUrl =
          'https://www.google.com/maps/dir/?api=1&origin=${_driverModel!.location!.latitude},${_driverModel!.location!.longitude}&destination=${currentOrder!.address!.location!.latitude},${currentOrder!.address!.location!.longitude}&travelmode=driving';

      for (var product in currentOrder!.products!) {
        if (product.extras_price != null &&
            product.extras_price!.isNotEmpty &&
            double.parse(product.extras_price!) != 0.0) {
          totalPrice += double.parse(product.extras_price!);
        }
        totalPrice += product.quantity * double.parse(product.price);
      }
      totalPrice =
          totalPrice + double.parse(currentOrder!.deliveryCharge ?? '0.0');

      totalPrice = totalPrice -
          double.parse((currentOrder!.discount.toString() != 'null' &&
                  currentOrder!.discount.toString() != '')
              ? currentOrder!.discount.toString()
              : '0.0');
      totalPrice = totalPrice -
          ((currentOrder!.specialDiscount != null &&
                  currentOrder!.specialDiscount is Map &&
                  currentOrder!.specialDiscount!.containsKey(
                    'special_discount',
                  ))
              ? double.parse(
                  (currentOrder!.specialDiscount!['special_discount'] ?? 0)
                      .toString())
              : 0);
      totalPrice = totalPrice +
          double.parse(currentOrder!.tipAmount ?? '0.0') +
          double.parse(currentOrder!.serviceCharges!.toString());

      totalPrice =
          totalPrice - double.parse(currentOrder!.deliveryCharge!.toString());

      totalPrice = double.parse(totalPrice.toStringAsFixed(2));
    }

    return Container(
      margin: EdgeInsets.only(left: 8, right: 8),
      padding: EdgeInsets.symmetric(vertical: 15),
      width: MediaQuery.of(context).size.width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(8), topRight: Radius.circular(18)),
        color: isDarkMode(context) ? Color(0xff000000) : Color(0xffFFFFFF),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (currentOrder!.status == ORDER_STATUS_SHIPPED ||
                currentOrder!.status == ORDER_STATUS_DRIVER_ACCEPTED)
              Column(
                children: [
                  ListTile(
                    title: Text(
                      title,
                      style: TextStyle(
                          color: isDarkMode(context)
                              ? Color(0xffFFFFFF)
                              : Color(0xff000000),
                          fontFamily: "Poppinsm",
                          letterSpacing: 0.5),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        '${currentOrder!.vendor!.location}',
                        maxLines: 2,
                        style: TextStyle(
                            color: isDarkMode(context)
                                ? Color(0xffFFFFFF)
                                : Color(0xff000000),
                            fontFamily: "Poppinsr",
                            letterSpacing: 0.5),
                      ),
                    ),
                    trailing: TextButton.icon(
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
                          print(
                              "=========Phone Number : ${currentOrder!.vendor!.phonenumber}");

                          UrlLauncher.launchUrl(Uri.parse(
                              "tel://${currentOrder!.vendor!.phonenumber}"));
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
                              letterSpacing: 0.5),
                        )),
                  ),
                  if ((currentOrder!.status == ORDER_STATUS_SHIPPED ||
                          currentOrder!.status ==
                              ORDER_STATUS_DRIVER_ACCEPTED) &&
                      currentOrder!.estimatedTimeToPrepare != null &&
                      currentOrder!.estimatedTimeToPrepare!.isNotEmpty)
                    ListTile(
                      tileColor: Color(0xffF1F4F8),
                      contentPadding: EdgeInsets.symmetric(horizontal: 32),
                      title: Row(
                        children: [
                          Text(
                            'Prepration Time'.tr(),
                            style: TextStyle(
                                color: isDarkMode(context)
                                    ? Color(0xffFFFFFF)
                                    : Color(0xff555555),
                                fontFamily: "Poppinsr",
                                letterSpacing: 0.5),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          _formatDuration(_remainingTime),
                          style: TextStyle(
                              color: isDarkMode(context)
                                  ? Color(0xffFFFFFF)
                                  : Color(0xff333333),
                              fontFamily: "Poppinsm",
                              letterSpacing: 0.5,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ListTile(
                    tileColor: Color(0xffF1F4F8),
                    contentPadding: EdgeInsets.symmetric(horizontal: 32),
                    title: Row(
                      children: [
                        Text(
                          'Payment Type'.tr(),
                          style: TextStyle(
                              color: isDarkMode(context)
                                  ? Color(0xffFFFFFF)
                                  : Color(0xff555555),
                              fontFamily: "Poppinsr",
                              letterSpacing: 0.5),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        '${currentOrder!.paymentMethod!.toUpperCase().toString()}',
                        style: TextStyle(
                            color: isDarkMode(context)
                                ? Color(0xffFFFFFF)
                                : Color(0xff333333),
                            fontFamily: "Poppinsm",
                            letterSpacing: 0.5,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  ListTile(
                    tileColor: Color(0xffF1F4F8),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 32, vertical: 6),
                    title: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ORDER ID '.tr(),
                          style: TextStyle(
                              color: isDarkMode(context)
                                  ? Color(0xffFFFFFF)
                                  : Color(0xff555555),
                              fontFamily: "Poppinsr",
                              letterSpacing: 0.5),
                        ),
                        Expanded(
                          child: Text(
                            ': ${currentOrder!.id}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: isDarkMode(context)
                                    ? Color(0xffFFFFFF)
                                    : Color(0xff000000),
                                fontFamily: "Poppinsr",
                                letterSpacing: 0.5),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        '${currentOrder!.author!.fullName()}',
                        style: TextStyle(
                            color: isDarkMode(context)
                                ? Color(0xffFFFFFF)
                                : Color(0xff333333),
                            fontFamily: "Poppinsm",
                            letterSpacing: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            if (currentOrder!.status == ORDER_STATUS_IN_TRANSIT)
              Column(
                children: [
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
                          color: isDarkMode(context)
                              ? Color(0xffFFFFFF)
                              : Color(0xff000000),
                          fontFamily: "Poppinsm",
                          letterSpacing: 0.5),
                    ),
                    subtitle: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'ORDER ID '.tr(),
                            style: TextStyle(
                                color: Color(0xff555555),
                                fontFamily: "Poppinsr",
                                letterSpacing: 0.5),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width / 4,
                            child: Text(
                              '${currentOrder!.id} ',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: isDarkMode(context)
                                      ? Color(0xffFFFFFF)
                                      : Color(0xff000000),
                                  fontFamily: "Poppinsr",
                                  letterSpacing: 0.5),
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
                              UrlLauncher.launchUrl(Uri.parse(
                                  "tel://${currentOrder!.author!.phoneNumber}"));
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
                                  letterSpacing: 0.5),
                            )),
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
                      'DELIVER'.tr(),
                      style: TextStyle(
                          color: Color(0xff9091A4),
                          fontFamily: "Poppinsr",
                          letterSpacing: 0.5),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        '${currentOrder!.address!.getFullAddress()}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: isDarkMode(context)
                                ? Color(0xffFFFFFF)
                                : Color(0xff333333),
                            fontFamily: "Poppinsr",
                            letterSpacing: 0.5),
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
                                  letterSpacing: 0.5),
                            )),
                      ],
                    ),
                  ),
                  ListTile(
                    title: Text(
                      'Payment Type'.tr(),
                      style: TextStyle(
                        color: Color(0xffffffff),
                        fontFamily: "Poppinsr",
                        letterSpacing: 0.5,
                      ),
                    ),
                    trailing: Text(
                      '${currentOrder!.paymentMethod!.toUpperCase().toString()}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: isDarkMode(context)
                              ? Color(0xffFFFFFF)
                              : Color(0xff333333),
                          fontFamily: "Poppinsr",
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                  ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: SizedBox(
                height: 40,
                width: MediaQuery.of(context).size.width,
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
                        currentOrder!.status == ORDER_STATUS_DRIVER_ACCEPTED) {
                      push(
                        context,
                        PickOrder(currentOrder: currentOrder),
                      );
                    } else if (currentOrder!.status ==
                        ORDER_STATUS_IN_TRANSIT) {
                      push(
                        context,
                        Scaffold(
                          appBar: AppBar(
                            leading: IconButton(
                              icon: Icon(Icons.chevron_left),
                              onPressed: () => Navigator.pop(context),
                            ),
                            titleSpacing: -8,
                            title: Text(
                              "Deliver".tr() + ": ${currentOrder!.id}",
                              style: TextStyle(
                                  color: isDarkMode(context)
                                      ? Color(0xffFFFFFF)
                                      : Color(0xff000000),
                                  fontFamily: "Poppinsr",
                                  letterSpacing: 0.5),
                            ),
                            centerTitle: false,
                          ),
                          body: SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 25.0, vertical: 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 25.0, vertical: 20),
                                    decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(2),
                                        border: Border.all(
                                            color: Colors.grey.shade100,
                                            width: 0.1),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.grey.shade200,
                                            blurRadius: 2.0,
                                            spreadRadius: 0.4,
                                            offset: Offset(0.2, 0.2),
                                          ),
                                        ],
                                        color: Colors.white),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'DELIVER'.tr().toUpperCase(),
                                              style: TextStyle(
                                                  color: Color(0xff9091A4),
                                                  fontFamily: "Poppinsr",
                                                  letterSpacing: 0.5),
                                            ),
                                            TextButton.icon(
                                                style: TextButton.styleFrom(
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6.0),
                                                    side: BorderSide(
                                                        color:
                                                            Color(0xff3DAE7D)),
                                                  ),
                                                  padding: EdgeInsets.zero,
                                                  minimumSize: Size(85, 30),
                                                  alignment: Alignment.center,
                                                  backgroundColor:
                                                      Color(0xffFFFFFF),
                                                ),
                                                onPressed: () {
                                                  UrlLauncher.launchUrl(Uri.parse(
                                                      "tel://${currentOrder!.author!.phoneNumber}"));
                                                },
                                                icon: Image.asset(
                                                  'assets/images/call3x.png',
                                                  height: 14,
                                                  width: 14,
                                                ),
                                                label: Text(
                                                  "CALL".tr().toUpperCase(),
                                                  style: TextStyle(
                                                      color: Color(0xff3DAE7D),
                                                      fontFamily: "Poppinsm",
                                                      letterSpacing: 0.5),
                                                )),
                                          ],
                                        ),
                                        Text(
                                          '${currentOrder!.author!.fullName()}',
                                          style: TextStyle(
                                              color: Color(0xff333333),
                                              fontFamily: "Poppinsm",
                                              letterSpacing: 0.5),
                                        ),
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4.0),
                                          child: Text(
                                            '${currentOrder!.address!.getFullAddress()},',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                color: Color(0xff9091A4),
                                                fontFamily: "Poppinsr",
                                                letterSpacing: 0.5),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 28),
                                  Text(
                                    "ITEMS".tr().toUpperCase(),
                                    style: TextStyle(
                                        color: Color(0xff9091A4),
                                        fontFamily: "Poppinsm",
                                        letterSpacing: 0.5),
                                  ),
                                  SizedBox(height: 24),
                                  ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: currentOrder!.products!.length,
                                      physics: NeverScrollableScrollPhysics(),
                                      itemBuilder: (context, index) {
                                        String adOns = '';
                                        dynamic extra = currentOrder!
                                            .products![index].extras;
                                        for (int i = 0;
                                            i < extra!.length;
                                            i++) {
                                          List adon = extra[i]
                                              .toString()
                                              .replaceAll("\"", "")
                                              .split('_');
                                          adOns +=
                                              '${adon.first} x ${adon.last} ${(i == extra.length - 1) ? "" : ", "}';
                                        }
                                        return Container(
                                            padding:
                                                EdgeInsets.only(bottom: 10),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      flex: 2,
                                                      child: CachedNetworkImage(
                                                          height: 55,
                                                          imageUrl:
                                                              '${currentOrder!.products![index].photo}',
                                                          imageBuilder: (context,
                                                                  imageProvider) =>
                                                              Container(
                                                                decoration:
                                                                    BoxDecoration(
                                                                        borderRadius:
                                                                            BorderRadius.circular(
                                                                                8),
                                                                        image:
                                                                            DecorationImage(
                                                                          image:
                                                                              imageProvider,
                                                                          fit: BoxFit
                                                                              .cover,
                                                                        )),
                                                              )),
                                                    ),
                                                    Expanded(
                                                      flex: 10,
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                                left: 14.0),
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            Text(
                                                              '${currentOrder!.products![index].name}',
                                                              style: TextStyle(
                                                                  fontFamily:
                                                                      'Poppinsr',
                                                                  letterSpacing:
                                                                      0.5,
                                                                  color: isDarkMode(
                                                                          context)
                                                                      ? Color(
                                                                          0xffFFFFFF)
                                                                      : Color(
                                                                          0xff333333)),
                                                            ),
                                                            SizedBox(height: 5),
                                                            Row(
                                                              children: [
                                                                Icon(
                                                                  Icons.close,
                                                                  size: 15,
                                                                  color: Color(
                                                                      COLOR_PRIMARY),
                                                                ),
                                                                Text(
                                                                    '${currentOrder!.products![index].quantity}',
                                                                    style:
                                                                        TextStyle(
                                                                      fontFamily:
                                                                          'Poppinsm',
                                                                      letterSpacing:
                                                                          0.5,
                                                                      color: Color(
                                                                          COLOR_PRIMARY),
                                                                    )),
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    )
                                                  ],
                                                ),
                                                if (adOns.isNotEmpty)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            top: 12, bottom: 6),
                                                    child:
                                                        Text('Addons: ' + adOns,
                                                            style: TextStyle(
                                                              fontFamily:
                                                                  'Poppinsm',
                                                              fontSize: 16,
                                                              color: isDarkMode(
                                                                      context)
                                                                  ? Color(
                                                                      0xffFFFFFF)
                                                                  : Color(
                                                                      0xff333333),
                                                            )),
                                                  ),
                                              ],
                                            ));
                                      }),
                                  SizedBox(height: 28),
                                  Container(
                                    decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                            color: Color(0xffC2C4CE)),
                                        color: Colors.white),
                                    child: ListTile(
                                      minLeadingWidth: 20,
                                      leading: Image.asset(
                                        'assets/images/mark_selected3x.png',
                                        height: 24,
                                        width: 24,
                                      ),
                                      title: Text(
                                        "Given".tr() +
                                            " ${currentOrder!.products!.length} " +
                                            "item to customer".tr(),
                                        style: TextStyle(
                                            color: Color(0xff3DAE7D),
                                            fontFamily: 'Poppinsm',
                                            letterSpacing: 0.5),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 26),
                                  Container(
                                    decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                            color: Color(0xffC2C4CE)),
                                        color: Colors.white),
                                    child: ListTile(
                                      minLeadingWidth: 20,
                                      title: Text(
                                        "Payment Type",
                                        style: TextStyle(
                                            color: Color(0xff3DAE7D),
                                            fontFamily: 'Poppinsm',
                                            letterSpacing: 0.5),
                                      ),
                                      trailing: Text(
                                        "${currentOrder!.paymentMethod!.toUpperCase().toString()}",
                                        style: TextStyle(
                                            color: Color(0xff3DAE7D),
                                            fontFamily: 'Poppinsm',
                                            letterSpacing: 0.5,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16),
                                      ),
                                    ),
                                  ),
                                  if (currentOrder!.paymentMethod!
                                              .toLowerCase() ==
                                          'cod' &&
                                      totalPrice != 0.0)
                                    const SizedBox(height: 26),
                                  if (currentOrder!.paymentMethod!
                                              .toLowerCase() ==
                                          'cod' &&
                                      totalPrice != 0.0)
                                    Container(
                                      decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          border: Border.all(
                                              color: Color(0xffC2C4CE)),
                                          color: Colors.white),
                                      child: ListTile(
                                        minLeadingWidth: 20,
                                        title: Text(
                                          "Collect Cash".tr(),
                                          style: TextStyle(
                                              color: Color(0xff3DAE7D),
                                              fontFamily: 'Poppinsm',
                                              letterSpacing: 0.5),
                                        ),
                                        trailing: Text(
                                          "LKR $totalPrice",
                                          style: TextStyle(
                                              color: Color(0xff3DAE7D),
                                              fontFamily: 'Poppinsm',
                                              letterSpacing: 0.5,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          bottomNavigationBar: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 14.0, horizontal: 26),
                            child: SizedBox(
                              height: 45,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(8),
                                    ),
                                  ),
                                  backgroundColor: Color(0xff3DAE7D),
                                ),
                                child: Text(
                                  "MARK ORDER DELIVER".tr(),
                                  style: TextStyle(
                                    letterSpacing: 0.5,
                                    fontFamily: 'Poppinsm',
                                    color: Colors.white,
                                  ),
                                ),
                                onPressed: () => completeOrder(),
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                  },
                  child: Text(
                    buttonText ?? "",
                    style: TextStyle(
                        color: Color(0xffFFFFFF),
                        fontFamily: "Poppinsm",
                        letterSpacing: 0.5),
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
                      UrlLauncher.launchUrl(
                        Uri.parse(
                          googleMapUrl,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(
                          Radius.circular(4),
                        ),
                      ),
                      backgroundColor: Color(0xff3DAE7D),
                    ),
                    child: Text(
                      'Direction on Map',
                      style: TextStyle(
                          color: Color(0xffFFFFFF),
                          fontFamily: "Poppinsm",
                          letterSpacing: 0.5),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  acceptOrder() async {
    int retryCount = 0;
    const maxRetries = 2;

    while (retryCount <= maxRetries) {
      try {
        OrderModel orderModel = _driverModel!.orderRequestData!;
        _driverModel!.orderRequestData = null;
        _driverModel!.inProgressOrderID = orderModel.id;

        await FireStoreUtils.updateCurrentUser(_driverModel!);

        orderModel.status = ORDER_STATUS_ACCEPTED;
        orderModel.driverID = _driverModel!.id;
        orderModel.driver = _driverModel!;

        await FireStoreUtils.updateOrder(orderModel);

        // Map<String, dynamic> payLoad = {
        //   "type": "vendor_order",
        //   "orderId": orderModel.id,
        // };

        // await FireStoreUtils.sendFcmMessage(
        //   driverAccepted,
        //   orderModel.vendor.fcmToken,
        //   payLoad,
        // );
        if (mounted) {
          setState(() {
            isShow = true;
          });
        }

        break;
      } catch (e) {
        retryCount++;
        if (retryCount > maxRetries) {
          debugPrint("Failed to accept order after $retryCount attempts: $e");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Failed to accept order. Please try again.')),
          );
        } else {
          await Future.delayed(const Duration(milliseconds: 600));
        }
      }
    }
  }

  bool orderProgress = false;

  Future<void> updateWallateAmount(OrderModel orderModel,
      {int maxRetries = 3, int retryDelay = 2}) async {
    try {
      double total = 0.0;
      double discount = 0.0;
      double specialDiscount = 0.0;
      double taxAmount = 0.0;
      orderModel.products!.forEach((element) {
        if (element.extras_price != null &&
            element.extras_price!.isNotEmpty &&
            double.parse(element.extras_price!) != 0.0) {
          total += element.quantity * double.parse(element.extras_price!);
        }
        total += element.quantity * double.parse(element.price);
      });

      if (orderModel.specialDiscount != null ||
          orderModel.specialDiscount!['special_discount'] != null) {
        specialDiscount = double.parse(
            orderModel.specialDiscount!['special_discount'].toString());
      }

      if (orderModel.discount != null) {
        discount = double.parse(orderModel.discount.toString());
      }

      var totalamount = total - discount - specialDiscount;

      if (orderModel.taxSetting != null) {
        for (var element in orderModel.taxSetting!) {
          taxAmount = taxAmount +
              calculateTax(amount: totalamount.toString(), taxModel: element);
        }
      }

      double driverAmount = 0;
      if (orderModel.paymentMethod!.toLowerCase() != "cod") {
        driverAmount += (double.parse(orderModel.deliveryCharge!) +
            double.parse(orderModel.tipAmount ?? '0.0'));
      } else {
        driverAmount += (-totalamount - taxAmount);
      }

      if (orderModel.paymentMethod!.toLowerCase() == "cod") {
        driverAmount =
            driverAmount - orderModel.serviceCharges! + orderModel.discount!;
      }

      await FireStoreUtils.updateWalletAmount(
          userId: orderModel.driverID!,
          amount: double.parse(driverAmount.toStringAsFixed(2)));
    } catch (e) {
      if (maxRetries > 0) {
        await Future.delayed(Duration(seconds: retryDelay));
        await updateWallateAmount(orderModel, maxRetries: maxRetries - 1);
      } else {
        log("Failed to update wallet after 3 attempts: $e");
      }
    }
  }

  completeOrder() async {
    if (orderProgress) return;

    orderProgress = true;
    showProgress(context, 'Completing Delivery...'.tr(), false);
    previousStatus = null;
    int retryCount = 0;
    const maxRetries = 2;

    while (retryCount <= maxRetries) {
      try {
        currentOrder!.status = ORDER_STATUS_COMPLETED;

        await FireStoreUtils.updateOrder(currentOrder!);

        await updateWallateAmount(currentOrder!);

        Position? locationData = await getCurrentLocation();

        Map<String, dynamic> payLoad = {
          "type": "vendor_order",
          "orderId": currentOrder!.id,
        };

        await FireStoreUtils.sendFcmMessage(
          driverCompleted,
          currentOrder!.author!.fcmToken ?? '',
          payLoad,
        );

        await FireStoreUtils.getFirestOrderOrNOt(currentOrder!)
            .then((value) async {
          if (value == true) {
            await FireStoreUtils.updateReferralAmount(currentOrder!);
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

        await FireStoreUtils.updateCurrentUser(_driverModel!);

        hideProgress();
        if (mounted) {
          setState(() {
            _markers.clear();
            polyLines.clear();
            orderProgress = false;
          });
        }

        _mapController?.moveCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(locationData.latitude, locationData.longitude),
              zoom: 15,
            ),
          ),
        );

        Navigator.pop(context);
        break;
      } catch (e) {
        retryCount++;

        if (retryCount > maxRetries) {
          hideProgress();
          setState(() => orderProgress = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text("Failed to complete order. Please try again.")),
          );
          break;
        }

        await Future.delayed(const Duration(milliseconds: 600));
      }
    }
  }

  rejectOrder() async {
    OrderModel orderModel = _driverModel!.orderRequestData!;
    if (orderModel.rejectedByDrivers == null) {
      orderModel.rejectedByDrivers = [];
    }
    orderModel.rejectedByDrivers!.add(_driverModel!.id);
    orderModel.status = ORDER_STATUS_DRIVER_REJECTED;
    await FireStoreUtils.updateOrder(orderModel);
    _driverModel!.orderRequestData = null;
    await FireStoreUtils.updateCurrentUser(_driverModel!);
  }

  Future<void> updateCameraLocation(
    LatLng source,
    LatLng destination,
    GoogleMapController? mapController,
  ) async {
    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: source,
          zoom: 20,
          bearing: double.parse(_driverModel!.rotation.toString()),
        ),
      ),
    );
  }

  Future<void> checkCameraLocation(
      CameraUpdate cameraUpdate, GoogleMapController mapController) async {
    mapController.animateCamera(cameraUpdate);
    LatLngBounds l1 = await mapController.getVisibleRegion();
    LatLngBounds l2 = await mapController.getVisibleRegion();

    if (l1.southwest.latitude == -90 || l2.southwest.latitude == -90) {
      return checkCameraLocation(cameraUpdate, mapController);
    }
  }
}

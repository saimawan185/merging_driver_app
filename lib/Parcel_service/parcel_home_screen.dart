import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:door_delights_driver/services/show_toast_dialog.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:door_delights_driver/Parcel_service/parcel_images_show.dart';
import 'package:door_delights_driver/Parcel_service/parcel_order_model.dart';
import 'package:door_delights_driver/constants.dart';
import 'package:door_delights_driver/main.dart';
import 'package:door_delights_driver/model/User.dart';
import 'package:door_delights_driver/services/FirebaseHelper.dart';
import 'package:door_delights_driver/services/helper.dart';
import 'package:door_delights_driver/ui/chat_screen/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geoflutterfire2/geoflutterfire2.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart' as UrlLauncher;

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

  setIcons() async {
    BitmapDescriptor.fromAssetImage(
            const ImageConfiguration(
              size: Size(10, 10),
            ),
            "assets/images/pickup.png")
        .then((value) {
      departureIcon = value;
    });

    BitmapDescriptor.fromAssetImage(
            const ImageConfiguration(
              size: Size(10, 10),
            ),
            "assets/images/dropoff.png")
        .then((value) {
      destinationIcon = value;
    });

    BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(
        size: Size(10, 10),
      ),
      MyAppState.currentUser?.vehicleType == 'Car'
          ? "assets/images/ic_taxi.png"
          : MyAppState.currentUser?.vehicleType == 'Tuk Tuk'
              ? 'assets/icons/ic_tuk.png'
              : 'assets/icons/ic_bike.png',
    ).then((value) {
      taxiIcon = value;
    });
  }

  Timer? _timer;

  void startTimer(User _driverModel) {
    const oneSec = const Duration(seconds: 1);
    _timer = new Timer.periodic(
      oneSec,
      (Timer timer) async {
        if (driverOrderAcceptRejectDuration == 0) {
          timer.cancel();
          if (_driverModel.orderParcelRequestData != null) {
            await rejectOrder();
            // Navigator.pop(context);
          }
        } else {
          driverOrderAcceptRejectDuration--;
        }
      },
    );
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
        .where('status',
            whereIn: [ORDER_STATUS_PLACED, ORDER_STATUS_DRIVER_REJECTED])
        .where('senderPickupDateTime', isGreaterThan: startTimestamp)
        .where('senderPickupDateTime', isLessThan: endTimestamp)
        .get()
        .then((value) async {
          print('---->${value.docs.length}');
          await Future.forEach(value.docs,
              (QueryDocumentSnapshot<Map<String, dynamic>> element) {
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
      orderModel.trigger_delevery = Timestamp.now();
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
    if (Platform.isAndroid) {
      final path = await rootBundle
          .load("assets/audio/mixkit-happy-bells-notification-937.mp3");

      print("--------->${MyAppState.audioPlayer.state}");
      MyAppState.audioPlayer.setSourceBytes(path.buffer.asUint8List());
      MyAppState.audioPlayer.setReleaseMode(ReleaseMode.loop);
      MyAppState.audioPlayer.play(BytesSource(path.buffer.asUint8List()),
          ctx: AudioContext(
              android: AudioContextAndroid(
                  contentType: AndroidContentType.music,
                  isSpeakerphoneOn: true,
                  stayAwake: false,
                  usageType: AndroidUsageType.notification,
                  audioFocus: AndroidAudioFocus.gainTransient),
              iOS: AudioContextIOS(category: AVAudioSessionCategory.playback)));
    } else {
      await MyAppState.audioPlayer
          .setSourceAsset("audio/mixkit-happy-bells-notification-937.mp3");
      await MyAppState.audioPlayer.setReleaseMode(ReleaseMode.loop);
      await MyAppState.audioPlayer
          .play(AssetSource('audio/mixkit-happy-bells-notification-937.mp3'));
    }

    playSound(false);
  }

  playSound(bool isPlay) async {
    if (isPlay) {
      await MyAppState.audioPlayer.resume();
    } else {
      await MyAppState.audioPlayer.stop();
    }
    print("0--------->${MyAppState.audioPlayer.state}");
  }

  @override
  void initState() {
    getDriver();
    setIcons();
    updateDriverOrder();
    setSound();
    _animationController =
        new AnimationController(vsync: this, duration: Duration(seconds: 1));
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
    super.dispose();
  }

  bool isShow = false;

  @override
  Widget build(BuildContext context) {
    isDarkMode(context)
        ? _mapController?.setMapStyle('[{"featureType": "all","'
            'elementType": "'
            'geo'
            'met'
            'ry","stylers": [{"color": "#242f3e"}]},{"featureType": "all","elementType": "labels.text.stroke","stylers": [{"lightness": -80}]},{"featureType": "administrative","elementType": "labels.text.fill","stylers": [{"color": "#746855"}]},{"featureType": "administrative.locality","elementType": "labels.text.fill","stylers": [{"color": "#d59563"}]},{"featureType": "poi","elementType": "labels.text.fill","stylers": [{"color": "#d59563"}]},{"featureType": "poi.park","elementType": "geometry","stylers": [{"color": "#263c3f"}]},{"featureType": "poi.park","elementType": "labels.text.fill","stylers": [{"color": "#6b9a76"}]},{"featureType": "road","elementType": "geometry.fill","stylers": [{"color": "#2b3544"}]},{"featureType": "road","elementType": "labels.text.fill","stylers": [{"color": "#9ca5b3"}]},{"featureType": "road.arterial","elementType": "geometry.fill","stylers": [{"color": "#38414e"}]},{"featureType": "road.arterial","elementType": "geometry.stroke","stylers": [{"color": "#212a37"}]},{"featureType": "road.highway","elementType": "geometry.fill","stylers": [{"color": "#746855"}]},{"featureType": "road.highway","elementType": "geometry.stroke","stylers": [{"color": "#1f2835"}]},{"featureType": "road.highway","elementType": "labels.text.fill","stylers": [{"color": "#f3d19c"}]},{"featureType": "road.local","elementType": "geometry.fill","stylers": [{"color": "#38414e"}]},{"featureType": "road.local","elementType": "geometry.stroke","stylers": [{"color": "#212a37"}]},{"featureType": "transit","elementType": "geometry","stylers": [{"color": "#2f3948"}]},{"featureType": "transit.station","elementType": "labels.text.fill","stylers": [{"color": "#d59563"}]},{"featureType": "water","elementType": "geometry","stylers": [{"color": "#17263c"}]},{"featureType": "water","elementType": "labels.text.fill","stylers": [{"color": "#515c6d"}]},{"featureType": "water","elementType": "labels.text.stroke","stylers": [{"lightness": -20}]}]')
        : _mapController?.setMapStyle(null);

    return Scaffold(
      body: Column(
        children: [
          Visibility(
            visible: _driverModel!.inProgressOrderID == null &&
                double.parse(_driverModel!.walletAmount.toString()) <
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
                target: LatLng(_driverModel!.location.latitude,
                    _driverModel!.location.longitude),
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
              : Container()
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
              // backgroundColor: Color(COLOR_PRIMARY),
              tooltip: 'Capture Picture',
              elevation: 5,
              splashColor: Colors.grey,
            ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;

    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(locationDataFinal!.latitude ?? 0.0,
              locationDataFinal!.longitude ?? 0.0),
          zoom: 14,
        ),
      ),
    );
    setState(() {});
    if (isDarkMode(context))
      _mapController?.setMapStyle('[{"featureType": "all","'
          'elementType": "'
          'geo'
          'met'
          'ry","stylers": [{"color": "#242f3e"}]},{"featureType": "all","elementType": "labels.text.stroke","stylers": [{"lightness": -80}]},{"featureType": "administrative","elementType": "labels.text.fill","stylers": [{"color": "#746855"}]},{"featureType": "administrative.locality","elementType": "labels.text.fill","stylers": [{"color": "#d59563"}]},{"featureType": "poi","elementType": "labels.text.fill","stylers": [{"color": "#d59563"}]},{"featureType": "poi.park","elementType": "geometry","stylers": [{"color": "#263c3f"}]},{"featureType": "poi.park","elementType": "labels.text.fill","stylers": [{"color": "#6b9a76"}]},{"featureType": "road","elementType": "geometry.fill","stylers": [{"color": "#2b3544"}]},{"featureType": "road","elementType": "labels.text.fill","stylers": [{"color": "#9ca5b3"}]},{"featureType": "road.arterial","elementType": "geometry.fill","stylers": [{"color": "#38414e"}]},{"featureType": "road.arterial","elementType": "geometry.stroke","stylers": [{"color": "#212a37"}]},{"featureType": "road.highway","elementType": "geometry.fill","stylers": [{"color": "#746855"}]},{"featureType": "road.highway","elementType": "geometry.stroke","stylers": [{"color": "#1f2835"}]},{"featureType": "road.highway","elementType": "labels.text.fill","stylers": [{"color": "#f3d19c"}]},{"featureType": "road.local","elementType": "geometry.fill","stylers": [{"color": "#38414e"}]},{"featureType": "road.local","elementType": "geometry.stroke","stylers": [{"color": "#212a37"}]},{"featureType": "transit","elementType": "geometry","stylers": [{"color": "#2f3948"}]},{"featureType": "transit.station","elementType": "labels.text.fill","stylers": [{"color": "#d59563"}]},{"featureType": "water","elementType": "geometry","stylers": [{"color": "#17263c"}]},{"featureType": "water","elementType": "labels.text.fill","stylers": [{"color": "#515c6d"}]},{"featureType": "water","elementType": "labels.text.stroke","stylers": [{"lightness": -20}]}]');
  }

  Widget showDriverBottomSheet() {
    double totalAmount = 0.0;
    double adminComm = 0.0;

    totalAmount = (double.parse(
            _driverModel!.orderParcelRequestData!.subTotal!.toString()) -
        double.parse(
            _driverModel!.orderParcelRequestData!.discount!.toString()));
    adminComm = (_driverModel!.orderParcelRequestData!.adminCommissionType ==
            'percentage')
        ? (totalAmount *
                double.parse(
                    _driverModel!.orderParcelRequestData!.adminCommission!)) /
            100
        : double.parse(_driverModel!.orderParcelRequestData!.adminCommission!);
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
          // crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  "${_driverModel!.orderParcelRequestData!.distance.toString()} km",
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
                  "${amountShow(amount: totalAmount.toString())}",
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
                    'Admin commission'.tr(),
                    style: TextStyle(
                        color: Color(0xffADADAD),
                        fontFamily: "Poppinsr",
                        letterSpacing: 0.5),
                  ),
                ),
                Text(
                  "(-${amountShow(amount: adminComm.toString())})",
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
                            "${_driverModel!.orderParcelRequestData!.sender!.address} ",
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
                            "${_driverModel!.orderParcelRequestData!.receiver!.address}",
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
                      'Reject'.tr(),
                      style: TextStyle(
                          color: Color(0xffFFFFFF),
                          fontFamily: "Poppinsm",
                          letterSpacing: 0.5),
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
                        await playSound(false);
                        showProgress(context, 'Accepting order...'.tr(), false);
                        if (_timer != null) {
                          _timer!.cancel();
                        }
                        // Navigator.pop(context);
                        try {
                          await acceptOrder();
                          hideProgress();
                          //  setState(() {});
                        } catch (e) {
                          hideProgress();
                          print('HomeScreenState.showDriverBottomSheet $e');
                        }
                      }),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  acceptOrder() async {
    ParcelOrderModel orderModel = _driverModel!.orderParcelRequestData!;

    _driverModel!.orderParcelRequestData = null;
    _driverModel!.inProgressOrderID = orderModel.id;

    MyAppState.currentUser = _driverModel!;

    await FireStoreUtils.updateCurrentUser(_driverModel!);

    orderModel.status = ORDER_STATUS_DRIVER_ACCEPTED;
    orderModel.driverID = _driverModel!.userID;
    orderModel.driver = _driverModel!;
    await FireStoreUtils.updateParcelOrder(orderModel);

    if (_driverModel!.inProgressOrderID != null) {
      getCurrentOrder();
    }
    Map<String, dynamic> payLoad = <String, dynamic>{
      "type": "parcel_order",
      "orderId": orderModel.id
    };
    await FireStoreUtils.sendFcmMessage(
        parcelAccepted, orderModel.author!.fcmToken, payLoad);

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
    orderModel.rejectedByDrivers!.add(_driverModel!.userID);
    orderModel.status = ORDER_STATUS_DRIVER_REJECTED;
    await FireStoreUtils.updateParcelOrder(orderModel);
    _driverModel!.orderParcelRequestData = null;

    await FireStoreUtils.updateCurrentUser(_driverModel!);
  }

  String? _lastRouteOrigin;
  String? _lastRouteDestination;
  String? _lastOrderStatus;

  getDirections() async {
    log("Get Direction API Called");

    if (currentOrder == null) return;

    // Check if we need to recalculate the route
    final currentStatus = currentOrder!.status;
    final shouldRecalculate = _shouldRecalculateRoute(currentStatus!);

    if (!shouldRecalculate) {
      log("Skipping route calculation - no significant changes");
      return;
    }

    LatLng origin;
    LatLng destination;
    bool includeDriverMarker = false;

    if (currentStatus == ORDER_STATUS_SHIPPED ||
        currentStatus == ORDER_STATUS_DRIVER_ACCEPTED) {
      origin = LatLng(
          _driverModel!.location.latitude, _driverModel!.location.longitude);
      destination = LatLng(currentOrder!.senderLatLong!.latitude,
          currentOrder!.senderLatLong!.longitude);
      includeDriverMarker = true;
    } else if (currentStatus == ORDER_STATUS_IN_TRANSIT) {
      origin = LatLng(
          _driverModel!.location.latitude, _driverModel!.location.longitude);
      destination = LatLng(currentOrder!.receiverLatLong!.latitude,
          currentOrder!.receiverLatLong!.longitude);
      includeDriverMarker = true;
    } else {
      origin = LatLng(currentOrder!.senderLatLong!.latitude,
          currentOrder!.senderLatLong!.longitude);
      destination = LatLng(currentOrder!.receiverLatLong!.latitude,
          currentOrder!.receiverLatLong!.longitude);
    }

    try {
      List<LatLng> polylineCoordinates =
          await _getRouteCoordinates(origin, destination);

      _updateMarkers(origin, destination, includeDriverMarker);
      addPolyLine(polylineCoordinates);

      // Cache the current route information
      _lastRouteOrigin = "${origin.latitude},${origin.longitude}";
      _lastRouteDestination =
          "${destination.latitude},${destination.longitude}";
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
          "${_driverModel!.location.latitude},${_driverModel!.location.longitude}";
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
      LatLng origin, LatLng destination) async {
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
      LatLng origin, LatLng destination, bool includeDriverMarker) {
    setState(() {
      // Clear existing markers
      _markers.clear();

      // Add driver marker if needed
      if (includeDriverMarker && _driverModel != null) {
        _markers['Driver'] = Marker(
          markerId: const MarkerId('Driver'),
          infoWindow: const InfoWindow(title: "Driver"),
          position: LatLng(_driverModel!.location.latitude,
              _driverModel!.location.longitude),
          icon: taxiIcon!,
          rotation: double.parse(_driverModel!.rotation.toString()),
        );
      }

      // Add departure marker
      _markers['Departure'] = Marker(
        markerId: const MarkerId('Departure'),
        infoWindow: const InfoWindow(title: "Departure"),
        position: LatLng(currentOrder!.senderLatLong!.latitude,
            currentOrder!.senderLatLong!.longitude),
        icon: departureIcon!,
      );

      // Add destination marker
      _markers['Destination'] = Marker(
        markerId: const MarkerId('Destination'),
        infoWindow: const InfoWindow(title: "Destination"),
        position: LatLng(currentOrder!.receiverLatLong!.latitude,
            currentOrder!.receiverLatLong!.longitude),
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

  late Stream<User> driverStream;
  User? _driverModel = User();

  // Add this variable
  bool _isFirstOrderLoad = true;

  getCurrentOrder() async {
    ordersFuture = FireStoreUtils().getParcelOrderByID(
        MyAppState.currentUser!.inProgressOrderID.toString());

    ordersFuture.listen((event) {
      if (event == null) return;

      final previousStatus = currentOrder?.status;
      currentOrder = event;

      if (currentOrder!.status == ORDER_STATUS_DRIVER_REJECTED ||
          currentOrder!.status == ORDER_STATUS_DRIVER_PENDING ||
          currentOrder!.status == ORDER_STATUS_ACCEPTED) {
        currentOrder!.status = ORDER_STATUS_DRIVER_ACCEPTED;
      }

      // Only call getDirections if status changed or it's first load
      if (_isFirstOrderLoad || previousStatus != currentOrder!.status) {
        _isFirstOrderLoad = false;
        getDirections();
      }
    });
  }

  getDriver() {
    driverStream = FireStoreUtils().getDriver(MyAppState.currentUser!.userID);
    driverStream.listen((event) async {
      _driverModel = event;
      setState(() {
        MyAppState.currentUser = _driverModel;
      });
      log("Driver get");

      getDirections();

      if (_driverModel!.isActive) {
        if (_driverModel!.orderParcelRequestData != null) {
          playSound(true);
        }
      }
      if (_driverModel!.inProgressOrderID != null) {
        getCurrentOrder();
      }
      if (_driverModel!.orderParcelRequestData == null) {
        playSound(false);
        // setState(() {
        // _markers.clear();
        // polyLines.clear();
        // });
      }
    });
  }

  Widget buildOrderActionsCard({pedding = 10, width = 60}) {
    bool isPickedUp = false;
    String? buttonText;
    String googleMapUrl = '';
    if (currentOrder!.status == ORDER_STATUS_SHIPPED ||
        currentOrder!.status == ORDER_STATUS_DRIVER_ACCEPTED) {
      buttonText = 'Pick up Parcel'.tr();
      isPickedUp = true;
      googleMapUrl =
          'https://www.google.com/maps/dir/?api=1&origin=${_driverModel!.location.latitude},${_driverModel!.location.longitude}&destination=${currentOrder!.senderLatLong!.latitude},${currentOrder!.senderLatLong!.longitude}&travelmode=driving';
    } else if (currentOrder!.status == ORDER_STATUS_IN_TRANSIT) {
      buttonText = 'Parcel delivery'.tr();
      isPickedUp = false;
      googleMapUrl =
          'https://www.google.com/maps/dir/?api=1&origin=${_driverModel!.location.latitude},${_driverModel!.location.longitude}&destination=${currentOrder!.receiverLatLong!.latitude},${currentOrder!.receiverLatLong!.longitude}&travelmode=driving';
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
            Visibility(
              visible: currentOrder!.paymentCollectByReceiver == true,
              child: Center(
                child: Text(
                  "Payment Collect by Receiver".tr(),
                  style: TextStyle(
                      fontSize: 16,
                      color: isDarkMode(context)
                          ? Color(0xffFFFFFF)
                          : Color(0xff555555),
                      fontFamily: "Poppinsr",
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5),
                ),
              ),
            ),
            if (currentOrder!.status == ORDER_STATUS_SHIPPED ||
                currentOrder!.status == ORDER_STATUS_DRIVER_ACCEPTED)
              Column(
                children: [
                  if (currentOrder!.paymentMethod.toLowerCase() == 'cod' ||
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
                            color: isDarkMode(context)
                                ? Color(0xffFFFFFF)
                                : Color(0xff000000),
                            fontFamily: "Poppinsm",
                            fontSize: 14,
                            letterSpacing: 0.5),
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
                          color: isDarkMode(context)
                              ? Color(0xffFFFFFF)
                              : Color(0xff000000),
                          fontFamily: "Poppinsm",
                          letterSpacing: 0.5),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        '${currentOrder!.sender!.name}'.tr(),
                        style: TextStyle(
                            color: Color(0xff555555),
                            fontSize: 12,
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
                              minimumSize: Size(85, 30),
                              alignment: Alignment.center,
                              backgroundColor: Color(0xffFFFFFF),
                            ),
                            onPressed: () {
                              UrlLauncher.launchUrl(Uri.parse(
                                  "tel://${currentOrder!.sender!.phone}"));
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
                          color: isDarkMode(context)
                              ? Color(0xffFFFFFF)
                              : Color(0xff000000),
                          fontFamily: "Poppinsm",
                          letterSpacing: 0.5),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        '${currentOrder!.receiver!.name}'.tr(),
                        style: TextStyle(
                            color: Color(0xff555555),
                            fontSize: 12,
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
                              minimumSize: Size(85, 30),
                              alignment: Alignment.center,
                              backgroundColor: Color(0xffFFFFFF),
                            ),
                            onPressed: () {
                              UrlLauncher.launchUrl(Uri.parse(
                                  "tel://${currentOrder!.receiver!.phone}"));
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
                                fontSize: 12,
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
                                  fontSize: 12,
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
                ],
              ),
            SizedBox(
              height: 10,
            ),
            if (currentOrder!.status == ORDER_STATUS_IN_TRANSIT)
              Column(
                children: [
                  if (currentOrder!.paymentMethod.toLowerCase() == 'cod' ||
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
                            color: isDarkMode(context)
                                ? Color(0xffFFFFFF)
                                : Color(0xff000000),
                            fontFamily: "Poppinsm",
                            fontSize: 14,
                            letterSpacing: 0.5),
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
                          color: isDarkMode(context)
                              ? Color(0xffFFFFFF)
                              : Color(0xff000000),
                          fontFamily: "Poppinsm",
                          letterSpacing: 0.5),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        '${currentOrder!.sender!.name}'.tr(),
                        style: TextStyle(
                            color: Color(0xff555555),
                            fontSize: 12,
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
                              minimumSize: Size(85, 30),
                              alignment: Alignment.center,
                              backgroundColor: Color(0xffFFFFFF),
                            ),
                            onPressed: () {
                              UrlLauncher.launchUrl(Uri.parse(
                                  "tel://${currentOrder!.sender!.phone}"));
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
                          color: isDarkMode(context)
                              ? Color(0xffFFFFFF)
                              : Color(0xff000000),
                          fontFamily: "Poppinsm",
                          letterSpacing: 0.5),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        '${currentOrder!.receiver!.name}'.tr(),
                        style: TextStyle(
                            color: Color(0xff555555),
                            fontSize: 12,
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
                              minimumSize: Size(85, 30),
                              alignment: Alignment.center,
                              backgroundColor: Color(0xffFFFFFF),
                            ),
                            onPressed: () {
                              UrlLauncher.launchUrl(Uri.parse(
                                  "tel://${currentOrder!.receiver!.phone}"));
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
                                fontSize: 12,
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
                                  fontSize: 12,
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
                      'Destination'.tr(),
                      style: TextStyle(
                          color: Color(0xff9091A4),
                          fontFamily: "Poppinsr",
                          letterSpacing: 0.5),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        '${currentOrder!.receiver!.address}',
                        maxLines: 3,
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
                            // Image.asset(
                            //   'assets/images/call3x.png',
                            //   height: 14,
                            //   width: 14,
                            // ),
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
                                letterSpacing: 0.5),
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
                      await UrlLauncher.launchUrl(
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

  completePickUp() async {
    final result = await Navigator.of(context).push(MaterialPageRoute(
        builder: (context) =>
            ParcelImagesShow(images: currentOrder!.parcelImages!)));

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

        if (currentOrder!.paymentMethod.toLowerCase() != "cod") {
          double totalTax = 0.0;
          /* if (currentOrder!.taxType!.isNotEmpty) {
            if (currentOrder!.taxType == "percent") {
              totalTax = (double.parse(currentOrder!.subTotal.toString()) - double.parse(currentOrder!.discount.toString())) * double.parse(currentOrder!.tax.toString()) / 100;
            } else {
              totalTax = double.parse(currentOrder!.tax.toString());
            }
          }*/

          if (currentOrder!.taxModel != null) {
            for (var element in currentOrder!.taxModel!) {
              totalTax = totalTax +
                  calculateTax(
                      amount: (double.parse(
                                  currentOrder!.subTotal!.toString()) -
                              double.parse(currentOrder!.discount!.toString()))
                          .toString(),
                      taxModel: element);
            }
          }

          double subTotal = double.parse(currentOrder!.subTotal.toString()) -
              double.parse(currentOrder!.discount.toString());

          double userAmount = 0;

          if (currentOrder!.paymentMethod.toLowerCase() != "cod") {
            userAmount = subTotal + totalTax;
          }

          await FireStoreUtils.createPaymentId().then((value) async {
            final paymentID = value;
            await FireStoreUtils.topUpWalletAmount(
                    userID: currentOrder!.authorID,
                    paymentMethod: "Refund Amount",
                    amount: userAmount,
                    id: paymentID)
                .then((value) async {
              await FireStoreUtils.updateUserWalletAmount(
                      userId: currentOrder!.authorID, amount: userAmount)
                  .then((value) {});
            });
          });
        }

        Position? locationData = await getCurrentLocation();
        Map<String, dynamic> payLoad = <String, dynamic>{
          "type": "parcel_order",
          "orderId": currentOrder!.id
        };
        await FireStoreUtils.sendFcmMessage(
            parcelRejected, currentOrder!.author!.fcmToken, payLoad);

        MyAppState.currentUser!.location = UserLocation(
            latitude: locationData.latitude, longitude: locationData.longitude);
        MyAppState.currentUser!.geoFireData = GeoFireData(
            geohash: GeoFlutterFire()
                .point(
                    latitude: locationData.latitude,
                    longitude: locationData.longitude)
                .hash,
            geoPoint: GeoPoint(locationData.latitude, locationData.longitude));
        MyAppState.currentUser!.inProgressOrderID = null;
        currentOrder = null;

        await FireStoreUtils.updateCurrentUser(MyAppState.currentUser!);

        _markers.clear();
        polyLines.clear();

        _mapController?.moveCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
                target: LatLng(locationData.latitude, locationData.longitude),
                zoom: 15),
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
      "orderId": currentOrder!.id
    };
    await FireStoreUtils.sendFcmMessage(
        parcelCompleted, currentOrder!.author!.fcmToken, payLoad);
    await FireStoreUtils.getParcelFirstOrderOrNOt(currentOrder!)
        .then((value) async {
      if (value == true) {
        await FireStoreUtils.updateParcelReferralAmount(currentOrder!);
      }
    });
    _driverModel!.inProgressOrderID = null;
    _driverModel!.location = UserLocation(
        latitude: locationData.latitude, longitude: locationData.longitude);
    _driverModel!.geoFireData = GeoFireData(
        geohash: GeoFlutterFire()
            .point(
                latitude: locationData.latitude,
                longitude: locationData.longitude)
            .hash,
        geoPoint: GeoPoint(locationData.latitude, locationData.longitude));

    currentOrder = null;

    await FireStoreUtils.updateCurrentUser(_driverModel!);
    hideProgress();

    _markers.clear();
    polyLines.clear();

    _mapController?.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
            target: LatLng(locationData.latitude, locationData.longitude),
            zoom: 15),
      ),
    );
    setState(() {});
  }

  openChatWithCustomer() async {
    // await showProgress(context, "Please wait".tr(), false);
    ShowToastDialog.showLoader("Please wait".tr());
    User? customer =
        await FireStoreUtils.getCurrentUser(currentOrder!.authorID);
    print(currentOrder!.driverID);

    User? driver =
        await FireStoreUtils.getCurrentUser(currentOrder!.driverID.toString());
    ShowToastDialog.closeLoader();
    // hideProgress();
    push(
        context,
        ChatScreens(
          type: "cab_parcel_chat",
          customerName: customer!.firstName + " " + customer.lastName,
          restaurantName: driver!.firstName + " " + driver.lastName,
          orderId: currentOrder!.id,
          restaurantId: driver.userID,
          customerId: customer.userID,
          customerProfileImage: customer.profilePictureURL,
          restaurantProfileImage: driver.profilePictureURL,
          token: customer.fcmToken,
          chatType: 'Driver',
        ));
  }
}

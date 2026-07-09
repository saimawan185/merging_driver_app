import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:developer' as log;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:door_delights_driver/constant/constant.dart';
import 'package:door_delights_driver/models/user_model.dart';
import 'package:door_delights_driver/services/show_toast_dialog.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:door_delights_driver/constants.dart';
import 'package:door_delights_driver/services/FirebaseHelper.dart';
import 'package:door_delights_driver/services/helper.dart';
import 'package:door_delights_driver/ui/chat_screen/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geoflutterfire2/geoflutterfire2.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart' as UrlLauncher;
import 'package:http/http.dart' as http;
import '../../constant/global.dart';
import '../../models/cab_order_model.dart';
import '../../models/vehicle_type.dart';
import '../../services/audio_player_service.dart';
import '../home_screen/home_screen_multiple_order.dart';
import 'verify_otp_screen.dart';

class CabHomeScreen extends StatefulWidget {
  final VoidCallback refresh;

  const CabHomeScreen({Key? key, required this.refresh}) : super(key: key);

  @override
  State<CabHomeScreen> createState() => _CabHomeScreenState();
}

class _CabHomeScreenState extends State<CabHomeScreen>
    with SingleTickerProviderStateMixin {
  final fireStoreUtils = FireStoreUtils();

  GoogleMapController? _mapController;
  bool canShowSheet = true;

  BitmapDescriptor? departureIcon;
  BitmapDescriptor? destinationIcon;
  BitmapDescriptor? taxiIcon;
  BitmapDescriptor? stopOneIcon, stopTwoIcon, stopThreeIcon;

  Map<PolylineId, Polyline> polyLines = {};
  PolylinePoints polylinePoints = PolylinePoints(apiKey: GOOGLE_API_KEY);
  final Map<String, Marker> _markers = {};

  String? _lastRouteOrigin;
  // String? _lastRouteDestination;
  String? _lastOrderStatus;
  List<String>? _lastStopCoordinates;
  bool _isFirstOrderLoad = true;

  // ────────────────────────────────────────────────
  // Smooth driver-marker animation state
  // ────────────────────────────────────────────────
  AnimationController? _markerAnimationController;
  LatLng? _lastKnownDriverLatLng;
  double _lastKnownDriverRotation = 0;
  bool _isFirstDriverUpdate = true;
  bool _followDriverWithCamera = true;
  bool _isAutoCameraMove = false;

  // Modern, clean "silver" style map used in light mode so the map feels
  // premium instead of the plain default Google style.
  static const String _lightModernMapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#f5f5f5"}]},
  {"elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#616161"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#f5f5f5"}]},
  {"featureType": "administrative.land_parcel", "stylers": [{"visibility": "off"}]},
  {"featureType": "administrative.land_parcel", "elementType": "labels.text.fill", "stylers": [{"color": "#bdbdbd"}]},
  {"featureType": "poi", "elementType": "geometry", "stylers": [{"color": "#eeeeee"}]},
  {"featureType": "poi", "elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
  {"featureType": "poi.park", "elementType": "geometry", "stylers": [{"color": "#e5f5e0"}]},
  {"featureType": "poi.park", "elementType": "labels.text.fill", "stylers": [{"color": "#9e9e9e"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#ffffff"}]},
  {"featureType": "road.arterial", "elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#ffd54f"}]},
  {"featureType": "road.highway", "elementType": "geometry.stroke", "stylers": [{"color": "#ffca28"}]},
  {"featureType": "road.highway", "elementType": "labels.text.fill", "stylers": [{"color": "#8d6e00"}]},
  {"featureType": "road.local", "elementType": "labels.text.fill", "stylers": [{"color": "#9e9e9e"}]},
  {"featureType": "transit.line", "elementType": "geometry", "stylers": [{"color": "#e5e5e5"}]},
  {"featureType": "transit.station", "elementType": "geometry", "stylers": [{"color": "#eeeeee"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#bfe9ff"}]},
  {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#5f9ea0"}]}
]
''';

  setIcons() async {
    BitmapDescriptor.asset(const ImageConfiguration(size: Size(36, 36)),
            "assets/images/pickup.png")
        .then((value) {
      departureIcon = value;
    });

    BitmapDescriptor.asset(const ImageConfiguration(size: Size(36, 36)),
            "assets/icons/drop.png")
        .then((value) {
      destinationIcon = value;
    });

    // Code-drawn driver arrow marker. Generating this ourselves (instead of
    // loading a PNG asset) guarantees the arrow is drawn perfectly straight
    // up at rotation 0, which is what makes `Marker.rotation` line up
    // exactly with the driver's real compass heading. No dependency on an
    // external image being pixel-perfectly aligned.
    _createDriverArrowIcon().then((value) {
      taxiIcon = value;
      if (mounted) setState(() {});
    });

    // Old asset-based icon, kept for reference / easy revert:
    // BitmapDescriptor.asset(const ImageConfiguration(size: Size(36, 36)),
    //         'assets/icons/driver_marker.png')
    //     .then((value) {
    //   taxiIcon = value;
    // });

    stopOneIcon = await BitmapDescriptor.asset(
      ImageConfiguration(size: const Size(26, 26)),
      "assets/icons/drop_1.png",
    );

    stopTwoIcon = await BitmapDescriptor.asset(
      ImageConfiguration(size: const Size(26, 26)),
      "assets/icons/drop_2.png",
    );

    stopThreeIcon = await BitmapDescriptor.asset(
      ImageConfiguration(size: const Size(26, 26)),
      "assets/icons/drop_3.png",
    );
  }

  // ────────────────────────────────────────────────
  // Code-drawn driver marker (orange pin + white arrow, matching the
  // uploaded reference icon) rendered straight up (0° = north). Because we
  // control every pixel, we know for certain the arrow's tip is perfectly
  // vertical and centered, so rotating the marker by the driver's compass
  // bearing always points it the correct way — no PNG-alignment guesswork.
  // ────────────────────────────────────────────────
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

    // Soft drop shadow under the pin for a bit of depth.
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(center.translate(0, size * 0.05), radius, shadowPaint);

    // Circular pin body.
    canvas.drawCircle(center, radius, Paint()..color = pinColor);

    // Pin border ring.
    final borderPaint = Paint()
      ..color = pinBorderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.045;
    canvas.drawCircle(
        center, radius - borderPaint.strokeWidth / 2, borderPaint);

    // Small glossy highlight, purely cosmetic.
    final highlightPaint = Paint()..color = Colors.white.withOpacity(0.18);
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(-radius * 0.35, -radius * 0.4),
        width: radius * 0.7,
        height: radius * 0.4,
      ),
      highlightPaint,
    );

    // Arrow pointing straight up — this is rotation = 0.
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

    // Little pin "tail" underneath the circle, like a map-pin drop shadow tip.
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

  updateDriverOrder() async {
    await FireStoreUtils.getDriverOrderSetting();
    if (mounted) {
      setState(() {});
    }
    Timestamp startTimestamp = Timestamp.now();
    DateTime currentDate = startTimestamp.toDate();
    currentDate = currentDate.subtract(Duration(hours: 3));
    startTimestamp = Timestamp.fromDate(currentDate);

    List<CabOrderModel> orders = [];

    print('-->startTime${startTimestamp.toDate()}');
    await FirebaseFirestore.instance
        .collection(RIDESORDER)
        .where('status',
            whereIn: [ORDER_STATUS_PLACED, ORDER_STATUS_DRIVER_REJECTED])
        .where('createdAt', isGreaterThan: startTimestamp)
        .get()
        .then((value) async {
          print('---->${value.docs.length}');
          await Future.forEach(value.docs,
              (QueryDocumentSnapshot<Map<String, dynamic>> element) {
            try {
              orders.add(CabOrderModel.fromJson(element.data()));
            } catch (e, s) {
              print('watchOrdersStatus parse error ${element.id}$e $s');
            }
          });
        });

    orders.forEach((element) {
      CabOrderModel orderModel = element;
      print('---->${orderModel.id}');
      orderModel.triggerDelevery = Timestamp.now();
      FirebaseFirestore.instance
          .collection(RIDESORDER)
          .doc(element.id)
          .set(orderModel.toJson(), SetOptions(merge: true))
          .then((order) {
        print('Done.');
      });
    });
  }

  AnimationController? _animationController;

  playSound(bool isPlay) async {
    await AudioPlayerService.playSound(isPlay);
  }

  VehicleType? vehicleModel;

  @override
  void initState() {
    super.initState();
    getDriver();
    setIcons();
    updateDriverOrder();

    _animationController = new AnimationController(
        vsync: this, duration: Duration(milliseconds: 700));
    _animationController!.repeat(reverse: true);
  }

  Future<void> dispose() async {
    _mapController!.dispose();
    // await FireStoreUtils().driverStreamController.close();
    // FireStoreUtils().driverStreamSub?.cancel();

    FireStoreUtils().cabOrdersStreamController?.close();
    FireStoreUtils().cabOrdersStreamSub?.cancel();
    _markerAnimationController?.dispose();
    if (_timer != null) {
      _timer!.cancel();
    }
    playSound(false);

    super.dispose();
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool isShow = false;

  @override
  Widget build(BuildContext context) {
    isDarkMode(context)
        ? _mapController?.setMapStyle('[{"featureType": "all","'
            'elementType": "'
            'geo'
            'met'
            'ry","stylers": [{"color": "#242f3e"}]},{"featureType": "all","elementType": "labels.text.stroke","stylers": [{"lightness": -80}]},{"featureType": "administrative","elementType": "labels.text.fill","stylers": [{"color": "#746855"}]},{"featureType": "administrative.locality","elementType": "labels.text.fill","stylers": [{"color": "#d59563"}]},{"featureType": "poi","elementType": "labels.text.fill","stylers": [{"color": "#d59563"}]},{"featureType": "poi.park","elementType": "geometry","stylers": [{"color": "#263c3f"}]},{"featureType": "poi.park","elementType": "labels.text.fill","stylers": [{"color": "#6b9a76"}]},{"featureType": "road","elementType": "geometry.fill","stylers": [{"color": "#2b3544"}]},{"featureType": "road","elementType": "labels.text.fill","stylers": [{"color": "#9ca5b3"}]},{"featureType": "road.arterial","elementType": "geometry.fill","stylers": [{"color": "#38414e"}]},{"featureType": "road.arterial","elementType": "geometry.stroke","stylers": [{"color": "#212a37"}]},{"featureType": "road.highway","elementType": "geometry.fill","stylers": [{"color": "#746855"}]},{"featureType": "road.highway","elementType": "geometry.stroke","stylers": [{"color": "#1f2835"}]},{"featureType": "road.highway","elementType": "labels.text.fill","stylers": [{"color": "#f3d19c"}]},{"featureType": "road.local","elementType": "geometry.fill","stylers": [{"color": "#38414e"}]},{"featureType": "road.local","elementType": "geometry.stroke","stylers": [{"color": "#212a37"}]},{"featureType": "transit","elementType": "geometry","stylers": [{"color": "#2f3948"}]},{"featureType": "transit.station","elementType": "labels.text.fill","stylers": [{"color": "#d59563"}]},{"featureType": "water","elementType": "geometry","stylers": [{"color": "#17263c"}]},{"featureType": "water","elementType": "labels.text.fill","stylers": [{"color": "#515c6d"}]},{"featureType": "water","elementType": "labels.text.stroke","stylers": [{"lightness": -20}]}]')
        : _mapController?.setMapStyle(_lightModernMapStyle);

    return Scaffold(
      key: _scaffoldKey,
      body: (_driverModel == null)
          ? Center(
              child: CircularProgressIndicator(
                color: Color(COLOR_PRIMARY),
              ),
            )
          : Column(
              children: [
                Visibility(
                  visible: (_driverModel!.inProgressOrderID == null ||
                          _driverModel!.inProgressOrderID!.isEmpty) &&
                      ((double.tryParse(
                                  _driverModel!.walletAmount.toString()) ??
                              0) <
                          double.parse(minimumDepositToRideAccept)),
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
                        (_driverModel!.inProgressOrderID != null &&
                                _driverModel!.inProgressOrderID!.isNotEmpty)
                            ? false
                            : true,
                    myLocationButtonEnabled: true,
                    mapType: MapType.normal,
                    buildingsEnabled: true,
                    trafficEnabled: false,
                    indoorViewEnabled: false,
                    compassEnabled: true,
                    rotateGesturesEnabled: true,
                    tiltGesturesEnabled: true,
                    zoomGesturesEnabled: true,
                    scrollGesturesEnabled: true,
                    zoomControlsEnabled: false,
                    padding: const EdgeInsets.only(bottom: 16, top: 8),
                    polylines: Set<Polyline>.of(polyLines.values),
                    markers: _markers.values.toSet(),
                    onCameraMoveStarted: () {
                      // This also fires for our own animateCamera() calls,
                      // so only treat it as a manual drag when we didn't
                      // just trigger a programmatic move ourselves.
                      if (!_isAutoCameraMove) {
                        _followDriverWithCamera = false;
                      }
                    },
                    onCameraIdle: () {
                      _isAutoCameraMove = false;
                    },
                    initialCameraPosition: CameraPosition(
                      zoom: 17,
                      tilt: 30,
                      target: LatLng(
                        _driverModel!.location?.latitude ?? 0.0,
                        _driverModel!.location?.longitude ?? 0.0,
                      ),
                    ),
                  ),
                ),
                (_driverModel!.inProgressOrderID != null &&
                            _driverModel!.inProgressOrderID!.isNotEmpty) &&
                        currentOrder != null &&
                        isShow == true
                    ? buildOrderActionsCard()
                    : const SizedBox.shrink(),
                (_driverModel!.orderCabRequestData != null && isShow)
                    ? showDriverBottomSheet()
                    : const SizedBox.shrink(),
              ],
            ),
      floatingActionButton: (_driverModel!.orderCabRequestData == null &&
              (_driverModel!.inProgressOrderID == null ||
                  _driverModel!.inProgressOrderID!.trim().isEmpty))
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

  void _onMapCreated(GoogleMapController controller) async {
    _mapController = controller;
    await Future.delayed(const Duration(seconds: 1));
    _isAutoCameraMove = true;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(_driverModel!.location?.latitude ?? 0.0,
              _driverModel!.location?.longitude ?? 0.0),
          zoom: 15,
        ),
      ),
    );
    if (mounted) {
      setState(() {});
    }
    if (isDarkMode(context)) {
      _mapController?.setMapStyle('[{"featureType": "all","'
          'elementType": "'
          'geo'
          'met'
          'ry","stylers": [{"color": "#242f3e"}]},{"featureType": "all","elementType": "labels.text.stroke","stylers": [{"lightness": -80}]},{"featureType": "administrative","elementType": "labels.text.fill","stylers": [{"color": "#746855"}]},{"featureType": "administrative.locality","elementType": "labels.text.fill","stylers": [{"color": "#d59563"}]},{"featureType": "poi","elementType": "labels.text.fill","stylers": [{"color": "#d59563"}]},{"featureType": "poi.park","elementType": "geometry","stylers": [{"color": "#263c3f"}]},{"featureType": "poi.park","elementType": "labels.text.fill","stylers": [{"color": "#6b9a76"}]},{"featureType": "road","elementType": "geometry.fill","stylers": [{"color": "#2b3544"}]},{"featureType": "road","elementType": "labels.text.fill","stylers": [{"color": "#9ca5b3"}]},{"featureType": "road.arterial","elementType": "geometry.fill","stylers": [{"color": "#38414e"}]},{"featureType": "road.arterial","elementType": "geometry.stroke","stylers": [{"color": "#212a37"}]},{"featureType": "road.highway","elementType": "geometry.fill","stylers": [{"color": "#746855"}]},{"featureType": "road.highway","elementType": "geometry.stroke","stylers": [{"color": "#1f2835"}]},{"featureType": "road.highway","elementType": "labels.text.fill","stylers": [{"color": "#f3d19c"}]},{"featureType": "road.local","elementType": "geometry.fill","stylers": [{"color": "#38414e"}]},{"featureType": "road.local","elementType": "geometry.stroke","stylers": [{"color": "#212a37"}]},{"featureType": "transit","elementType": "geometry","stylers": [{"color": "#2f3948"}]},{"featureType": "transit.station","elementType": "labels.text.fill","stylers": [{"color": "#d59563"}]},{"featureType": "water","elementType": "geometry","stylers": [{"color": "#17263c"}]},{"featureType": "water","elementType": "labels.text.fill","stylers": [{"color": "#515c6d"}]},{"featureType": "water","elementType": "labels.text.stroke","stylers": [{"lightness": -20}]}]');
    } else {
      _mapController?.setMapStyle(_lightModernMapStyle);
    }
  }

  // ────────────────────────────────────────────────
  // Smooth driver marker update + camera follow
  //
  // Instead of snapping the marker straight to the new coordinate, this
  // tweens lat/lng/rotation over a short duration so the car glides across
  // the map, and it points the arrow icon in the *actual* direction of
  // travel (computed from the last known point to the new one) rather than
  // trusting a raw rotation value that may be stale or noisy.
  // ────────────────────────────────────────────────
  void _updateDriverMarkerAndCamera() {
    if (_driverModel == null ||
        _driverModel!.location == null ||
        taxiIcon == null) return;

    final lat = _driverModel!.location!.latitude!;
    final lng = _driverModel!.location!.longitude!;
    final newPosition = LatLng(lat, lng);

    final fromPosition = _lastKnownDriverLatLng ?? newPosition;

    // Distance moved since last update (meters), used to decide whether we
    // trust a freshly computed bearing or keep the previous heading (avoids
    // the arrow jittering/spinning when the driver is stationary at a light).
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
      // Fall back to the server-provided heading if we haven't moved enough
      // to compute a reliable bearing ourselves (e.g. right after app start).
      targetRotation =
          double.tryParse(_driverModel!.rotation.toString()) ?? targetRotation;
    }

    if (_isFirstDriverUpdate) {
      // First update: place the marker immediately, nothing to animate from.
      _isFirstDriverUpdate = false;
      _markers['Driver'] = Marker(
        markerId: const MarkerId('Driver'),
        infoWindow: const InfoWindow(title: "Driver"),
        position: newPosition,
        icon: taxiIcon!,
        rotation: targetRotation,
        anchor: const Offset(0.5, 0.5),
        // Screen-relative rotation: the map stays north-up and the arrow
        // itself rotates to the driver's true compass heading, so what you
        // see always matches the direction the driver is actually facing.
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

    // Take the shortest rotational path (e.g. 350° -> 10° should turn +20,
    // not -340) so the arrow never does a full unnecessary spin.
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

  Widget showDriverBottomSheet() {
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
            if (_driverModel!.orderCabRequestData!.stops.isNotEmpty)
              Row(
                children: [
                  Text(
                    "This trip includes ${_driverModel!.orderCabRequestData!.stops.length} stop(s)"
                        .tr(),
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            if (_driverModel!.orderCabRequestData!.stops.isNotEmpty)
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
                  "${_driverModel!.orderCabRequestData!.distance.toString()} km",
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
                  "${amountShow(amount: _driverModel!.orderCabRequestData!.subTotal.toString())}",
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
                      height: 80,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${_driverModel!.orderCabRequestData!.sourceLocationName} ",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Color(0xff333333),
                                fontFamily: "Poppinsr",
                                letterSpacing: 0.5),
                          ),
                          FutureBuilder<Map<String, String>?>(
                            future: _getDriverToPickupInfo(),
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
                          Text(
                            "${_driverModel!.orderCabRequestData!.destinationLocationName}",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Color(0xff333333),
                                fontFamily: "Poppinsr",
                                letterSpacing: 0.5),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              "🛣️ ${_driverModel!.orderCabRequestData!.duration ?? '0'} (${_driverModel!.orderCabRequestData!.distance ?? '0'} km)",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                                fontFamily: "Poppinsr",
                              ),
                            ),
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
                      playSound(false);
                      await FireStoreUtils.getCabOrderByOrderId(
                              currentCabOrderID)
                          .then((value) async {
                        print("----->1111${value!.status}");
                        if (value.status == ORDER_STATUS_REJECTED) {
                          Navigator.pop(context);

                          Constant.userModel!.orderCabRequestData = null;
                          Constant.userModel!.inProgressOrderID = null;
                          await FireStoreUtils.updateCurrentUser(
                              Constant.userModel!);
                          final snack = SnackBar(
                            content: Text(
                              "This Ride is already reject by customer.".tr(),
                              style: TextStyle(color: Colors.white),
                            ),
                            duration: Duration(seconds: 2),
                            backgroundColor: Colors.black,
                          );
                          ScaffoldMessenger.of(_scaffoldKey.currentContext!)
                              .showSnackBar(snack);
                          if (mounted) {
                            setState(() {});
                          }
                        } else {
                          //Navigator.pop(context);
                          showProgress(
                              context, "Rejecting Ride...".tr(), false);
                          try {
                            await rejectOrder();
                            hideProgress();
                          } catch (e) {
                            hideProgress();
                            print('HomeScreenState.showDriverBottomSheet $e');
                          }
                        }
                      });
                    },
                  ),
                ),
                SizedBox(
                  height: MediaQuery.sizeOf(context).height / 20,
                  width: MediaQuery.sizeOf(context).width / 2.5,
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
                          letterSpacing: 0.5,
                        ),
                      ),
                      onPressed: () async {
                        playSound(false);
                        await FireStoreUtils.getCabOrderByOrderId(
                                currentCabOrderID)
                            .then((value) async {
                          if (value!.status == ORDER_STATUS_REJECTED) {
                            Navigator.pop(context);

                            Constant.userModel!.orderCabRequestData = null;
                            Constant.userModel!.inProgressOrderID = null;

                            await FireStoreUtils.updateCurrentUser(
                                Constant.userModel!);
                            final snack = SnackBar(
                              content: Text(
                                "This Ride is reject by customer.".tr(),
                                style: TextStyle(color: Colors.white),
                              ),
                              duration: Duration(seconds: 2),
                              backgroundColor: Colors.black,
                            );
                            ScaffoldMessenger.of(_scaffoldKey.currentContext!)
                                .showSnackBar(snack);
                            if (mounted) {
                              setState(() {});
                            }
                          } else {
                            showProgress(
                                context, 'Accepting Ride....'.tr(), false);
                            try {
                              if (_timer != null) {
                                _timer!.cancel();
                              }
                              print("Accepting order");
                              await acceptOrder();
                              hideProgress();
                            } catch (e) {
                              hideProgress();
                            }
                          }
                        });
                      }),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, String>?> _getDriverToPickupInfo() async {
    if (_driverModel == null ||
        _driverModel!.location == null ||
        _driverModel!.orderCabRequestData == null) {
      return null;
    }

    final driverLat = _driverModel!.location!.latitude!;
    final driverLng = _driverModel!.location!.longitude!;
    final pickupLat =
        _driverModel!.orderCabRequestData!.sourceLocation!.latitude;
    final pickupLng =
        _driverModel!.orderCabRequestData!.sourceLocation!.longitude;

    final result = await getDurationDistance(
      LatLng(driverLat, driverLng),
      LatLng(pickupLat, pickupLng),
    );

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

  acceptOrder() async {
    try {
      CabOrderModel orderModel = _driverModel!.orderCabRequestData!;

      _driverModel!.orderCabRequestData = null;
      _driverModel!.inProgressOrderID = orderModel.id!;
      _followDriverWithCamera = true;

      orderModel.status = ORDER_STATUS_DRIVER_ACCEPTED;
      orderModel.driverId = _driverModel!.id;
      orderModel.driver = _driverModel!;

      if (enableOTPTripStart) {
        orderModel.otpCode = (Random().nextInt(900000) + 100000).toString();
      }

      await Future.wait([
        FireStoreUtils.updateCurrentUser(_driverModel!),
        FireStoreUtils.updateCabOrder(orderModel),
      ]);

      await getCurrentOrder();

      Map<String, dynamic> payLoad = <String, dynamic>{
        "type": "cab_order",
        "orderId": currentOrder!.id
      };

      FireStoreUtils.sendFcmMessage(
        cabAccepted,
        orderModel.author!.fcmToken ?? '',
        payLoad,
      );

      if (mounted) {
        setState(() {
          isShow = true;
        });
      }
    } catch (e) {
      print("Error while accepting: $e");
    }
  }

  rejectOrder() async {
    if (_timer != null) {
      _timer!.cancel();
    }
    CabOrderModel orderModel = _driverModel!.orderCabRequestData!;
    if (orderModel.rejectedByDrivers == null) {
      orderModel.rejectedByDrivers = [];
    }
    orderModel.rejectedByDrivers!.add(_driverModel!.id);
    orderModel.status = ORDER_STATUS_DRIVER_REJECTED;
    await FireStoreUtils.updateCabOrder(orderModel);
    _driverModel!.orderCabRequestData = null;

    await FireStoreUtils.updateCurrentUser(_driverModel!);
  }

  getDirections() async {
    if (currentOrder == null) return;

    // Check if we need to recalculate the route
    final currentStatus = currentOrder?.status ?? "request";
    final shouldRecalculate = _shouldRecalculateRoute(currentStatus);

    if (!shouldRecalculate) {
      log.log("Skipping route calculation - no significant changes");
      return;
    }

    LatLng origin;
    LatLng destination;
    bool includeDriverMarker = true;
    List<PolylineWayPoint> waypoints = [];

    if (currentOrder != null) {
      if (currentOrder!.status == ORDER_STATUS_SHIPPED ||
          currentOrder!.status == ORDER_STATUS_DRIVER_ACCEPTED) {
        // Driver going to pickup customer
        origin = LatLng(_driverModel!.location!.latitude!,
            _driverModel!.location!.longitude!);
        destination = LatLng(currentOrder!.sourceLocation!.latitude,
            currentOrder!.sourceLocation!.longitude);
      } else if (currentOrder!.status == ORDER_STATUS_IN_TRANSIT ||
          currentOrder!.status == ORDER_REACHED_DESTINATION) {
        // Driver is en route with customer (may have stops)
        origin = LatLng(_driverModel!.location!.latitude!,
            _driverModel!.location!.longitude!);
        destination = LatLng(currentOrder!.destinationLocation!.latitude,
            currentOrder!.destinationLocation!.longitude);

        // Add waypoints for stops
        if (currentOrder!.stops.isNotEmpty) {
          for (var stop in currentOrder!.stops) {
            waypoints.add(PolylineWayPoint(
                location: '${stop.latitude},${stop.longitude}'));
          }
        }
      } else {
        return;
      }
    } else if (_driverModel!.orderCabRequestData != null) {
      // New order request
      origin = LatLng(_driverModel!.location!.latitude!,
          _driverModel!.location!.longitude!);
      destination = LatLng(
          _driverModel!.orderCabRequestData!.sourceLocation!.latitude,
          _driverModel!.orderCabRequestData!.sourceLocation!.longitude);
    } else {
      return;
    }

    try {
      List<LatLng> polylineCoordinates =
          await _getRouteCoordinates(origin, destination, waypoints);

      _updateMarkers(origin, destination, includeDriverMarker, waypoints);
      addPolyLine(polylineCoordinates);

      // Cache the current route information
      _lastRouteOrigin = "${origin.latitude},${origin.longitude}";
      // _lastRouteDestination =
      //     "${destination.latitude},${destination.longitude}";
      _lastOrderStatus = currentStatus;
      _lastStopCoordinates = waypoints.map((wp) => wp.location).toList();
    } catch (e) {
      log.log("Error getting directions: $e");
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
        log.log("Driver moved: ${distance.toStringAsFixed(2)} km");
        return distance > 0.1;
      }
    }

    // Recalculate if stops changed
    if (currentOrder != null && currentOrder!.stops.isNotEmpty) {
      final currentStops = currentOrder!.stops
          .map((stop) => "${stop.latitude},${stop.longitude}")
          .toList();
      if (_lastStopCoordinates == null ||
          !_listEquals(_lastStopCoordinates!, currentStops)) {
        return true;
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
      double dLon = (lon2 - lon1) * 111319.9 * cos(lat1 * 3.14159 / 180);

      return sqrt(dLat * dLat + dLon * dLon) / 1000;
    } catch (e) {
      return 1.0;
    }
  }

  bool _listEquals(List<String> list1, List<String> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
  }

  Future<List<LatLng>> _getRouteCoordinates(LatLng origin, LatLng destination,
      List<PolylineWayPoint> waypoints) async {
    log.log(
        "Getting coordinates from ${origin.latitude},${origin.longitude} to ${destination.latitude},${destination.longitude} with ${waypoints.length} waypoints");

    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      request: PolylineRequest(
        origin: PointLatLng(origin.latitude, origin.longitude),
        destination: PointLatLng(destination.latitude, destination.longitude),
        wayPoints: waypoints,
        mode: TravelMode.driving,
      ),
    );

    List<LatLng> polylineCoordinates = [];
    if (result.points.isNotEmpty) {
      for (var point in result.points) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      }
    }

    log.log("Route calculated: ${polylineCoordinates.length} points");
    return polylineCoordinates;
  }

  void _updateMarkers(LatLng origin, LatLng destination,
      bool includeDriverMarker, List<PolylineWayPoint> waypoints) {
    if (mounted) {
      setState(() {
        _markers.clear();

        // Add driver marker if needed
        if (includeDriverMarker && _driverModel != null) {
          final driverLatLng = LatLng(_driverModel!.location!.latitude!,
              _driverModel!.location!.longitude!);
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

        // Add departure marker
        if (currentOrder != null) {
          _markers['Departure'] = Marker(
            markerId: const MarkerId('Departure'),
            infoWindow: const InfoWindow(title: "Departure"),
            position: LatLng(currentOrder!.sourceLocation!.latitude,
                currentOrder!.sourceLocation!.longitude),
            icon: departureIcon!,
          );

          // Add destination marker
          _markers['Destination'] = Marker(
            markerId: const MarkerId('Destination'),
            infoWindow: const InfoWindow(title: "Destination"),
            position: LatLng(currentOrder!.destinationLocation!.latitude,
                currentOrder!.destinationLocation!.longitude),
            icon: destinationIcon!,
          );

          // Add markers for stops if they exist
          if (currentOrder!.stops.isNotEmpty) {
            for (int i = 0; i < currentOrder!.stops.length; i++) {
              _markers['Stop${i}'] = Marker(
                markerId: MarkerId('Stop${i}'),
                infoWindow: InfoWindow(title: "Stop ${i + 1}"),
                position: LatLng(currentOrder!.stops[i].latitude,
                    currentOrder!.stops[i].longitude),
                icon: i == 0
                    ? stopOneIcon!
                    : i == 1
                        ? stopTwoIcon!
                        : stopTwoIcon!,
              );
            }
          }
        } else if (_driverModel!.orderCabRequestData != null) {
          // New order request markers
          _markers['Departure'] = Marker(
            markerId: const MarkerId('Departure'),
            infoWindow: const InfoWindow(title: "Departure"),
            position: LatLng(
                _driverModel!.orderCabRequestData!.sourceLocation!.latitude,
                _driverModel!.orderCabRequestData!.sourceLocation!.longitude),
            icon: departureIcon!,
          );

          _markers['Destination'] = Marker(
            markerId: const MarkerId('Destination'),
            infoWindow: const InfoWindow(title: "Destination"),
            position: LatLng(
                _driverModel!
                    .orderCabRequestData!.destinationLocation!.latitude,
                _driverModel!
                    .orderCabRequestData!.destinationLocation!.longitude),
            icon: destinationIcon!,
          );
        }
      });
    }
  }

  Future<void> updateCameraLocation(
    LatLng source,
    LatLng destination,
    GoogleMapController? mapController,
  ) async {
    _isAutoCameraMove = true;
    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: source,
          zoom: 20,
        ),
      ),
    );
    //   if (mapController == null) return;
    //
    //   LatLngBounds bounds;
    //
    //   if (source.latitude > destination.latitude &&
    //       source.longitude > destination.longitude) {
    //     bounds = LatLngBounds(southwest: destination, northeast: source);
    //   } else if (source.longitude > destination.longitude) {
    //     bounds = LatLngBounds(
    //         southwest: LatLng(source.latitude, destination.longitude),
    //         northeast: LatLng(destination.latitude, source.longitude));
    //   } else if (source.latitude > destination.latitude) {
    //     bounds = LatLngBounds(
    //         southwest: LatLng(destination.latitude, source.longitude),
    //         northeast: LatLng(source.latitude, destination.longitude));
    //   } else {
    //     bounds = LatLngBounds(southwest: source, northeast: destination);
    //   }
    //
    //   CameraUpdate cameraUpdate = CameraUpdate.newLatLngBounds(bounds, 100);
    //
    //   return checkCameraLocation(cameraUpdate, mapController);
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
    updateCameraLocation(
        polylineCoordinates.first, polylineCoordinates.last, _mapController);
    if (mounted) {
      setState(() {});
    }
  }

  late Stream<CabOrderModel?> ordersFuture;
  CabOrderModel? currentOrder;

  late Stream<UserModel> driverStream;
  UserModel? _driverModel = UserModel();
  String? previousStatus;

  getCurrentOrder() async {
    ordersFuture = FireStoreUtils()
        .getCabOrderByID(Constant.userModel!.inProgressOrderID.toString());
    ordersFuture.listen((event) {
      if (mounted) {
        setState(() {
          currentOrder = event;
          log.log("Status: ${currentOrder!.status}");
          if (currentOrder!.status == ORDER_STATUS_DRIVER_REJECTED ||
              currentOrder!.status == ORDER_STATUS_DRIVER_PENDING ||
              currentOrder!.status == ORDER_STATUS_ACCEPTED) {
            currentOrder!.status = ORDER_STATUS_DRIVER_ACCEPTED;
            currentCabOrderID = currentOrder!.id!;
          }

          if (_isFirstOrderLoad || previousStatus != currentOrder!.status) {
            _isFirstOrderLoad = false;
            previousStatus = currentOrder?.status;
            getDirections();
          }
        });
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
          if (_driverModel.orderCabRequestData != null) {
            await rejectOrder();
            // Navigator.pop(context);
          }
        } else {
          driverOrderAcceptRejectDuration--;
        }
      },
    );
  }

  getDriver() async {
    driverStream = FireStoreUtils().getDriver(Constant.userModel!.id!);
    driverStream.listen((event) {
      playSound(false);
      _driverModel = event;
      FireStoreUtils.getVehicle(_driverModel!.vehicleId).then((value) {
        if (mounted) {
          setState(() {
            vehicleModel = value;
          });
        }
      });
      if (mounted) {
        setState(() {
          Constant.userModel = _driverModel;
        });
      }

      log.log("Get current driver data");

      // Reset first load flag when driver data changes
      _isFirstOrderLoad = true;
      getDirections();

      // ─── Smooth driver movement ──────────────────────────
      _updateDriverMarkerAndCamera();

      if (_driverModel!.isActive == true) {
        if (_driverModel!.orderCabRequestData != null) {
          playSound(true);
          currentCabOrderID = _driverModel!.orderCabRequestData!.id!;
        }
      }
      if (_driverModel!.inProgressOrderID != null &&
          _driverModel!.inProgressOrderID!.isNotEmpty) {
        getCurrentOrder();
      }

      if (_driverModel!.orderCabRequestData == null) {
        playSound(false);
        // setState(() {
        //   _markers.clear();
        //   polyLines.clear();
        // });
      }
      if (mounted) {
        setState(() {});
      }
    });
  }

  Widget buildOrderActionsCard({pedding = 10, width = 60}) {
    bool isPickedUp = false;
    String googleMapUrl = '';
    String? buttonText;
    // double discountAmount = 0.0;
    if (currentOrder!.status == ORDER_STATUS_SHIPPED ||
        currentOrder!.status == ORDER_STATUS_DRIVER_ACCEPTED) {
      buttonText = enableOTPTripStart
          ? "Verify Code to customer".tr()
          : "Pickup Customer".tr();
      googleMapUrl =
          'https://www.google.com/maps/dir/?api=1&origin=${_driverModel!.location!.latitude},${_driverModel!.location!.longitude}&destination=${currentOrder!.sourceLocation!.latitude},${currentOrder!.sourceLocation!.longitude}&travelmode=driving';
      isPickedUp = true;
    } else if (currentOrder!.status == ORDER_STATUS_IN_TRANSIT) {
      buttonText = "Reached To destination".tr();
      if (currentOrder!.stops.isNotEmpty) {
        if (currentOrder!.currentStopIndex < currentOrder!.stops.length) {
          buttonText =
              "Reached Stop ${currentOrder!.currentStopIndex + 1}".tr();
        }
      }

      String waypoints = '';
      if (currentOrder!.stops.isNotEmpty) {
        List<String> waypointsList = [];
        for (int i = 0; i < currentOrder!.stops.length; i++) {
          waypointsList.add(
              '${currentOrder!.stops[i].latitude},${currentOrder!.stops[i].longitude}');
        }
        waypoints = '&waypoints=' + waypointsList.join('|');
      }

      googleMapUrl =
          'https://www.google.com/maps/dir/?api=1&origin=${_driverModel!.location!.latitude},${_driverModel!.location!.longitude}&destination=${currentOrder!.destinationLocation!.latitude},${currentOrder!.destinationLocation!.longitude}&travelmode=driving$waypoints';
      isPickedUp = false;
    } else if (currentOrder!.status == ORDER_REACHED_DESTINATION) {
      buttonText = "Complete Ride".tr();
      isPickedUp = false;
    }

    return Container(
      margin: EdgeInsets.only(left: 8, right: 8),
      padding: EdgeInsets.symmetric(vertical: 15),
      width: MediaQuery.sizeOf(context).width,
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
                    tileColor: Color(0xffF1F4F8),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    title: Row(
                      children: [
                        Text(
                          "ORDER ID ".tr(),
                          style: TextStyle(
                              fontSize: 14,
                              color: isDarkMode(context)
                                  ? Color(0xffFFFFFF)
                                  : Color(0xff555555),
                              fontFamily: "Poppinsr",
                              letterSpacing: 0.5),
                        ),
                        Expanded(
                          child: Text(
                            '${currentOrder!.id}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 14,
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
                        '${currentOrder!.author?.firstName} ${currentOrder!.author?.lastName}',
                        style: TextStyle(
                            color: isDarkMode(context)
                                ? Color(0xffFFFFFF)
                                : Color(0xff333333),
                            fontFamily: "Poppinsm",
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
                  ListTile(
                    leading: Image.asset(
                      'assets/images/user3x.png',
                      height: 42,
                      width: 42,
                      color: Color(COLOR_PRIMARY),
                    ),
                    title: Text(
                      '${currentOrder!.author?.fullName()}',
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
                            width: MediaQuery.sizeOf(context).width / 4,
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
                                  "tel://${currentOrder!.author?.phoneNumber}"));
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
                      '${currentOrder!.sourceLocationName}',
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
                            "ORDER ID ".tr(),
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
                            width: MediaQuery.sizeOf(context).width / 4,
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
                                  "tel://${currentOrder!.author?.phoneNumber}"));
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
                        '${currentOrder!.destinationLocationName}',
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
                  if (currentOrder!.stops.isNotEmpty)
                    Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            "Stops:".tr(),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: isDarkMode(context)
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),

                  // List of stops
                  if (currentOrder!.stops.isNotEmpty)
                    for (int i = 0; i < currentOrder!.stops.length; i++)
                      ListTile(
                        leading: Icon(
                          Icons.location_on,
                          color: i < currentOrder!.currentStopIndex
                              ? Colors.green
                              : (i == currentOrder!.currentStopIndex
                                  ? Colors.orange
                                  : Colors.white70),
                        ),
                        title: Text(
                          currentOrder!.stopNames[i],
                          style: TextStyle(
                            color: i < currentOrder!.currentStopIndex
                                ? Colors.green
                                : (i == currentOrder!.currentStopIndex
                                    ? Colors.orange
                                    : Colors.grey),
                          ),
                        ),
                        subtitle: Text(
                          "Stop ${i + 1}".tr(),
                          style: TextStyle(
                            color: i < currentOrder!.currentStopIndex
                                ? Colors.green
                                : (i == currentOrder!.currentStopIndex
                                    ? Colors.orange
                                    : Colors.grey),
                          ),
                        ),
                      ),
                ],
              ),
            if (currentOrder!.status == ORDER_REACHED_DESTINATION)
              ListTile(
                leading: Icon(
                  Icons.payments_outlined,
                  color: Color(COLOR_PRIMARY),
                ),
                title: Text(
                  'Total Amount: '.tr() + currentOrder!.subTotal.toString(),
                  style: TextStyle(
                      color: isDarkMode(context) ? Colors.white : Colors.black,
                      fontFamily: "Poppinsr",
                      letterSpacing: 0.5),
                ),
              ),
            if (currentOrder!.status == ORDER_REACHED_DESTINATION &&
                currentOrder!.discount != null &&
                currentOrder!.discount != 0)
              ListTile(
                leading: Icon(
                  Icons.payments_outlined,
                  color: Color(COLOR_PRIMARY),
                ),
                title: Text(
                  'Collect Cash from Customer: '.tr() +
                      (double.parse(currentOrder!.subTotal.toString()) -
                              double.parse(currentOrder!.discount.toString()))
                          .toStringAsFixed(2),
                  style: TextStyle(
                      color: isDarkMode(context) ? Colors.white : Colors.black,
                      fontFamily: "Poppinsr",
                      letterSpacing: 0.5),
                ),
              ),
            if (currentOrder!.status == ORDER_REACHED_DESTINATION)
              ListTile(
                leading: Icon(
                  Icons.payments_outlined,
                  color: Color(COLOR_PRIMARY),
                ),
                title: Text(
                  currentOrder!.paymentStatus == true
                      ? ('Custome Paid amount through '.tr() +
                          (currentOrder!.paymentMethod == 'cod'
                              ? 'Cash'
                              : currentOrder!.paymentMethod ?? 'cod'))
                      : "Customer payment is pending.".tr(),
                  style: TextStyle(
                      color: isDarkMode(context) ? Colors.white : Colors.black,
                      fontFamily: "Poppinsr",
                      letterSpacing: 0.5),
                ),
              ),
            if (currentOrder!.status == ORDER_STATUS_IN_TRANSIT ||
                currentOrder!.status == ORDER_REACHED_DESTINATION)
              SizedBox(height: 25),
            isPickedUp
                ? FadeTransition(
                    opacity: _animationController!,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
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
                            playSound(false);
                            if (currentOrder!.status == ORDER_STATUS_SHIPPED ||
                                currentOrder!.status ==
                                    ORDER_STATUS_DRIVER_ACCEPTED) {
                              completePickUp();
                            } else if (currentOrder!.status ==
                                ORDER_STATUS_IN_TRANSIT) {
                              reachedDestination();
                            } else if (currentOrder!.status ==
                                ORDER_REACHED_DESTINATION) {
                              if (currentOrder!.paymentStatus == true) {
                                completeOrder();
                              } else {
                                final snack = SnackBar(
                                  content: Text(
                                    "Customer payment is pending.".tr(),
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  duration: Duration(seconds: 2),
                                  backgroundColor: Colors.black,
                                );
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(snack);
                              }
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
                    padding: const EdgeInsets.symmetric(horizontal: 14),
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
                            reachedDestination();
                          } else if (currentOrder!.status ==
                              ORDER_REACHED_DESTINATION) {
                            if (currentOrder!.paymentStatus == true) {
                              completeOrder();
                            } else {
                              final snack = SnackBar(
                                content: Text(
                                  "Customer payment is pending.".tr(),
                                  style: TextStyle(color: Colors.white),
                                ),
                                duration: Duration(seconds: 2),
                                backgroundColor: Colors.black,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(snack);
                            }
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
            if (currentOrder!.status == ORDER_STATUS_SHIPPED ||
                currentOrder!.status == ORDER_STATUS_DRIVER_ACCEPTED)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
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
                  onPressed: () {
                    showCancelRideDialog(context);
                  },
                  child: Text(
                    'Cancel Ride'.tr(),
                    style: TextStyle(
                        color: Color(0xffFFFFFF),
                        fontFamily: "Poppinsm",
                        letterSpacing: 0.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String? _selectedCancellationReason;
  String _otherReason = '';

  void showCancelRideDialog(BuildContext context) {
    _selectedCancellationReason = null;
    _otherReason = '';

    final List<String> cancellationReasons = [
      'Vehicle breakdown',
      'Mistakenly Accepted',
      'Customer location is wrong',
      'Customer requested to cancel',
      'Customer doesn\'t answer calls',
      'Other'
    ];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text("Cancel Ride".tr()),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Please select a reason for cancellation:".tr()),
                    SizedBox(height: 16),
                    ...cancellationReasons.map((reason) {
                      return RadioListTile<String>(
                        title: Text(reason.tr()),
                        value: reason,
                        groupValue: _selectedCancellationReason,
                        onChanged: (String? value) {
                          setState(() {
                            _selectedCancellationReason = value;
                          });
                        },
                      );
                    }).toList(),

                    // Show text field only when "Other" is selected
                    if (_selectedCancellationReason == 'Other')
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: TextField(
                          decoration: InputDecoration(
                            labelText: "Please specify".tr(),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            _otherReason = value;
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text("No".tr()),
                ),
                TextButton(
                  onPressed: _selectedCancellationReason == null ||
                          (_selectedCancellationReason == 'Other' &&
                              _otherReason.isEmpty)
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          final reason = _selectedCancellationReason == 'Other'
                              ? _otherReason
                              : _selectedCancellationReason!;
                          _cancelRide(reason);
                        },
                  child: Text(
                    "Confirm Cancel".tr(),
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _cancelRide(String reason) async {
    playSound(false);
    await FireStoreUtils.getCabOrderByOrderId(
      currentCabOrderID.isEmpty ? currentOrder!.id! : currentCabOrderID,
    ).then((value) async {
      print("----->1111${value!.status}");
      if (value.status == ORDER_STATUS_REJECTED ||
          value.status == ORDER_STATUS_CANCELLED) {
        Navigator.pop(context);

        Constant.userModel!.orderCabRequestData = null;
        Constant.userModel!.inProgressOrderID = null;

        await FireStoreUtils.updateCurrentUser(Constant.userModel!);
        final snack = SnackBar(
          content: Text(
            "This Ride is already cancelled by customer.".tr(),
            style: TextStyle(color: Colors.white),
          ),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.black,
        );
        ScaffoldMessenger.of(_scaffoldKey.currentContext!).showSnackBar(snack);
        setState(() {});
      } else {
        //Navigator.pop(context);
        showProgress(context, "Cancelling Ride...".tr(), false);
        try {
          await cancelOrder();
        } catch (e) {}
      }
    });
  }

  Future<void> cancelOrder() async {
    try {
      if (_timer != null) {
        _timer!.cancel();
      }

      CabOrderModel orderModel = currentOrder!;

      if (orderModel.rejectedByDrivers == null) {
        orderModel.rejectedByDrivers = [];
      }

      orderModel.rejectedByDrivers!.add(_driverModel!.id);

      orderModel.driver = null;
      orderModel.driverId = null;

      orderModel.status = ORDER_STATUS_DRIVER_REJECTED;

      await FireStoreUtils.updateCabOrder(orderModel);

      _driverModel!.orderCabRequestData = null;
      _driverModel!.inProgressOrderID = null;

      await FireStoreUtils.updateCurrentUser(_driverModel!);
      Map<String, dynamic> payLoad = <String, dynamic>{
        "type": "cab_order",
        "orderId": currentOrder!.id
      };
      await FireStoreUtils.sendFcmMessage(
        cabCancelled,
        orderModel.author?.fcmToken ?? '',
        payLoad,
      );
      hideProgress();
    } catch (e) {
      log.log("Cancel error: $e");
      hideProgress();
    }
  }

  Future<dynamic> getDurationDistanceWithWaypoints(LatLng departureLatLong,
      LatLng destinationLatLong, List<LatLng> stops) async {
    log.log("Get duration with way points");
    double originLat, originLong, destLat, destLong;
    originLat = departureLatLong.latitude;
    originLong = departureLatLong.longitude;
    destLat = destinationLatLong.latitude;
    destLong = destinationLatLong.longitude;

    // Build waypoints parameter
    String waypoints = "";
    if (stops.isNotEmpty) {
      waypoints = "&waypoints=";
      for (int i = 0; i < stops.length; i++) {
        waypoints += "${stops[i].latitude},${stops[i].longitude}";
        if (i < stops.length - 1) {
          waypoints += "|";
        }
      }
    }

    String url = 'https://maps.googleapis.com/maps/api/distancematrix/json';
    http.Response restaurantToCustomerTime = await http.get(Uri.parse(
        '$url?units=metric&origins=$originLat,'
        '$originLong&destinations=$destLat,$destLong$waypoints&key=$GOOGLE_API_KEY'));

    var decodedResponse = jsonDecode(restaurantToCustomerTime.body);

    if (decodedResponse['status'] == 'OK' &&
        decodedResponse['rows'].first['elements'].first['status'] == 'OK') {
      return decodedResponse;
    }
    return null;
  }

  completePickUp() async {
    if (enableOTPTripStart) {
      final isComplete = await Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => VerifyOtpScreen(
                otp: currentOrder!.otpCode,
              )));
      if (isComplete != null) {
        if (isComplete == true) {
          //showProgress(context, "Updating Ride...".tr(), false);
          currentOrder!.status = ORDER_STATUS_IN_TRANSIT;
          currentOrder!.startTime = Timestamp.now();
          currentOrder!.currentStopIndex = 0;
          currentOrder!.customerPickupTime = Timestamp.now();

          await FireStoreUtils.updateCabOrder(currentOrder!);

          //hideProgress();
          setState(() {});
        }
      }
    } else {
      showProgress(context, 'Updating Ride...'.tr(), false);
      currentOrder!.status = ORDER_STATUS_IN_TRANSIT;
      currentOrder!.startTime = Timestamp.now();
      currentOrder!.currentStopIndex = 0;
      currentOrder!.customerPickupTime = Timestamp.now();

      await FireStoreUtils.updateCabOrder(currentOrder!);

      hideProgress();
      setState(() {});
    }
  }

  reachedDestination() async {
    try {
      showProgress(context, "Ride update...".tr(), false);
      if (currentOrder!.stops.isNotEmpty &&
          currentOrder!.currentStopIndex < currentOrder!.stops.length) {
        currentOrder!.currentStopIndex++;

        await FireStoreUtils.updateCabOrder(currentOrder!);

        getDirections();
      } else {
        currentOrder!.status = ORDER_REACHED_DESTINATION;
        currentOrder!.arrivalTime = Timestamp.now();

        final List<LatLng> stops = [];
        for (var stop in currentOrder!.stops) {
          stops.add(LatLng(stop.latitude, stop.longitude));
        }

        await getDurationDistanceWithWaypoints(
          LatLng(currentOrder!.sourceLocation!.latitude,
              currentOrder!.sourceLocation!.longitude),
          LatLng(
            _driverModel!.location!.latitude!,
            _driverModel!.location!.longitude!,
          ),
          stops,
        ).then((durationValue) async {
          if (durationValue != null) {
            double distance = durationValue['rows']
                    .first['elements']
                    .first['distance']['value'] /
                1000.00;
            String duration = durationValue['rows']
                .first['elements']
                .first['duration']['text']
                .toString();
            if (vehicleModel != null &&
                distance > ((double.tryParse(currentOrder!.distance!) ?? 0))) {
              currentOrder!.subTotal =
                  (vehicleModel!.delivery_charges_per_km! * distance)
                      .toString();
              currentOrder!.actualDistance = distance.toString();
            }
            if (duration.isNotEmpty && duration != "null") {
              // currentOrder!.actualDuration = duration.toString();

              int minuts = currentOrder!.arrivalTime!
                  .toDate()
                  .difference(currentOrder!.startTime!.toDate())
                  .inMinutes;
              int driveDuration = convertDurationToMinutes(duration) + 8;

              if (minuts > driveDuration) {
                currentOrder!.actualDuration = "$minuts min";
                currentOrder!.subTotal =
                    (double.parse(currentOrder!.subTotal!) +
                            (vehicleModel!.delivery_charges_per_minute! *
                                (minuts - driveDuration)))
                        .toString();
              }
            }
          }
          await FireStoreUtils.updateCabOrder(currentOrder!);
        });
      }
    } catch (e) {
      log.log("Error: $e");
    } finally {
      hideProgress();
      setState(() {});
    }
  }

  int convertDurationToMinutes(String durationString) {
    int totalMinutes = 0;

    if (durationString.contains('hour')) {
      final hourMatch = RegExp(r'(\d+)\s*hour').firstMatch(durationString);
      if (hourMatch != null) {
        totalMinutes += int.parse(hourMatch.group(1)!) * 60;
      }
    }

    if (durationString.contains('hours')) {
      final hourMatch = RegExp(r'(\d+)\s*hours').firstMatch(durationString);
      if (hourMatch != null) {
        totalMinutes += int.parse(hourMatch.group(1)!) * 60;
      }
    }

    if (durationString.contains('min')) {
      final minuteMatch = RegExp(r'(\d+)\s*min').firstMatch(durationString);
      if (minuteMatch != null) {
        totalMinutes += int.parse(minuteMatch.group(1)!);
      }
    }

    if (durationString.contains('mint')) {
      final minuteMatch = RegExp(r'(\d+)\s*mint').firstMatch(durationString);
      if (minuteMatch != null) {
        totalMinutes += int.parse(minuteMatch.group(1)!);
      }
    }

    if (durationString.contains('mints')) {
      final minuteMatch = RegExp(r'(\d+)\s*mints').firstMatch(durationString);
      if (minuteMatch != null) {
        totalMinutes += int.parse(minuteMatch.group(1)!);
      }
    }

    return totalMinutes;
  }

  completeOrder() async {
    showProgress(context, 'Completing Delivery...'.tr(), false);
    currentOrder!.status = ORDER_STATUS_COMPLETED;
    previousStatus = null;
    updateCabWalletAmount(currentOrder!);
    await FireStoreUtils.updateCabOrder(currentOrder!);
    Position? locationData = await getCurrentLocation();
    await FireStoreUtils.getFirestOrderOrNOtCabService(currentOrder!)
        .then((value) async {
      if (value == true) {
        await FireStoreUtils.updateReferralAmountCabService(currentOrder!);
      }
    });
    Map<String, dynamic> payLoad = <String, dynamic>{
      "type": "cab_order",
      "orderId": currentOrder!.id
    };
    await FireStoreUtils.sendFcmMessage(
        cabCompleted, currentOrder!.author?.fcmToken ?? '', payLoad);
    await FireStoreUtils.getCabFirstOrderOrNOt(currentOrder!)
        .then((value) async {
      if (value == true) {
        await FireStoreUtils.updateCabReferralAmount(currentOrder!);
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

    _isAutoCameraMove = true;
    _followDriverWithCamera = true;
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
    ShowToastDialog.showLoader('Please wait...'.tr());
    UserModel? customer =
        await FireStoreUtils.getCurrentUser(currentOrder!.authorID!);
    print(currentOrder!.driverId);
    UserModel? driver =
        await FireStoreUtils.getCurrentUser(currentOrder!.driverId.toString());
    ShowToastDialog.closeLoader();
    // hideProgress();
    push(
        context,
        ChatScreens(
          type: "cab_parcel_chat",
          customerName:
              (customer!.firstName ?? '') + " " + (customer.lastName ?? ''),
          restaurantName:
              (driver!.firstName ?? '') + " " + (driver.lastName ?? ''),
          orderId: currentOrder!.id,
          restaurantId: driver.id,
          customerId: customer.id,
          customerProfileImage: customer.profilePictureURL,
          restaurantProfileImage: driver.profilePictureURL,
          token: customer.fcmToken,
          chatType: 'Driver',
        ));
  }

  goOnline(UserModel user) async {
    await showProgress(context, 'Going online...'.tr(), false);
    Position locationData = await getCurrentLocation();
    user.isActive = true;
    user.location = UserLocation(
        latitude: locationData.latitude, longitude: locationData.longitude);
    user.geoFireData = GeoFireData(
        geohash: GeoFlutterFire()
            .point(
                latitude: locationData.latitude,
                longitude: locationData.longitude)
            .hash,
        geoPoint: GeoPoint(locationData.latitude, locationData.longitude));
    Constant.userModel = user;

    await FireStoreUtils.updateCurrentUser(user);
    updateDriverOrder();
    await hideProgress();
  }
}

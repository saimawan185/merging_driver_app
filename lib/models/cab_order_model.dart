import 'package:cloud_firestore/cloud_firestore.dart';
import 'tax_model.dart';
import 'user_model.dart';
import 'vehicle_type.dart';

// ──────────────────────────────────────────────────────────────
// UserLocationData – used for source/destination and stops
// ──────────────────────────────────────────────────────────────
class UserLocationData {
  double latitude;
  double longitude;

  UserLocationData({this.latitude = 0.01, this.longitude = 0.01});

  factory UserLocationData.fromJson(Map<String, dynamic> parsedJson) {
    return UserLocationData(
      latitude: double.parse((parsedJson['latitude'] ?? 0.01).toString()),
      longitude: double.parse((parsedJson['longitude'] ?? 0.01).toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

// ──────────────────────────────────────────────────────────────
// DestinationLocation – kept for backward compatibility
// (same structure as UserLocationData, but can be removed later)
// ──────────────────────────────────────────────────────────────
class DestinationLocation {
  double? longitude;
  double? latitude;

  DestinationLocation({this.longitude, this.latitude});

  DestinationLocation.fromJson(Map<String, dynamic> json) {
    longitude = json['longitude'];
    latitude = json['latitude'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['longitude'] = longitude;
    data['latitude'] = latitude;
    return data;
  }
}

// ──────────────────────────────────────────────────────────────
// Unified CabOrderModel – contains ALL fields from both models
// ──────────────────────────────────────────────────────────────
class CabOrderModel {
  // ── Base fields ──────────────────────────────────────────────
  String? id;
  String? authorID;
  UserModel? author;
  UserModel? driver;
  String? driverId;
  String? status;
  String? paymentMethod;
  bool? paymentStatus;
  Timestamp? createdAt;
  Timestamp? triggerDelevery; // from second model (trigger_delevery)
  String? otpCode;

  // ── Location fields ─────────────────────────────────────────
  UserLocationData? sourceLocation;
  UserLocationData? destinationLocation;
  String? sourceLocationName;
  String? destinationLocationName;

  // ── Ride details ────────────────────────────────────────────
  String? rideType; // from first model
  String? vehicleId;
  VehicleType? vehicleType;
  String? distance;
  String? duration;
  String? actualDistance; // second model
  String? actualDuration; // second model
  String? subTotal;
  num? discount; // first model (num in second but stored as string)
  String? couponCode;
  String? couponId;

  // ── Timestamps ──────────────────────────────────────────────
  Timestamp? scheduleDateTime; // first model
  Timestamp? scheduleReturnDateTime; // first model
  Timestamp? startTime; // second model
  Timestamp? arrivalTime; // second model
  Timestamp? acceptTime; // second model
  Timestamp? customerPickupTime; // second model
  Timestamp? customerDropTime; // second model

  // ── Admin commission ────────────────────────────────────────
  String? adminCommission;
  String? adminCommissionType;

  // ── Tip ─────────────────────────────────────────────────────
  String? tipValue; // second model (parsed from 'tip_amount')

  // ── Multi‑stop support ──────────────────────────────────────
  List<UserLocationData> stops = [];
  List<String> stopNames = [];
  int currentStopIndex = 0;

  // ── Rejected drivers ────────────────────────────────────────
  List<dynamic>? rejectedByDrivers = [];

  // ── Taxes ───────────────────────────────────────────────────
  List<TaxModel>? taxModel; // second model (serializes as 'taxSetting')

  // ── Miscellaneous ───────────────────────────────────────────
  String? sectionId;
  String? platformFee; // first model
  bool? roundTrip; // first model
  // note: duration is already defined above, but second model uses String? as well.

  // ── Constructor ──────────────────────────────────────────────
  CabOrderModel({
    this.id,
    this.authorID,
    this.author,
    this.driver,
    this.driverId,
    this.status,
    this.paymentMethod,
    this.paymentStatus,
    this.createdAt,
    this.triggerDelevery,
    this.otpCode,
    this.sourceLocation,
    this.destinationLocation,
    this.sourceLocationName,
    this.destinationLocationName,
    this.rideType,
    this.vehicleId,
    this.vehicleType,
    this.distance,
    this.duration,
    this.actualDistance,
    this.actualDuration,
    this.subTotal,
    this.discount = 0,
    this.couponCode,
    this.couponId,
    this.scheduleDateTime,
    this.scheduleReturnDateTime,
    this.startTime,
    this.arrivalTime,
    this.acceptTime,
    this.customerPickupTime,
    this.customerDropTime,
    this.adminCommission,
    this.adminCommissionType,
    this.tipValue,
    this.stops = const [],
    this.stopNames = const [],
    this.currentStopIndex = 0,
    this.rejectedByDrivers,
    this.taxModel,
    this.sectionId,
    this.platformFee,
    this.roundTrip,
  });

  // ── fromJson ──────────────────────────────────────────────────
  factory CabOrderModel.fromJson(Map<String, dynamic> json) {
    num discountVal = 0;

    if (json['discount'] == null) {
      discountVal = 0;
    } else if (json['discount'] is String) {
      discountVal = double.parse(json['discount']);
    } else {
      discountVal = json['discount'];
    }
    // Parse taxSetting into taxModel
    List<TaxModel>? taxList;
    if (json['taxSetting'] != null) {
      taxList = <TaxModel>[];
      (json['taxSetting'] as List).forEach((v) {
        taxList!.add(TaxModel.fromJson(v));
      });
    }

    // Parse stops
    List<UserLocationData> stopsList = [];
    if (json['stops'] != null) {
      (json['stops'] as List).forEach((v) {
        stopsList.add(UserLocationData.fromJson(v));
      });
    }

    List<String> stopNamesList = [];
    if (json['stopNames'] != null) {
      stopNamesList = List<String>.from(json['stopNames']);
    }

    return CabOrderModel(
      id: json['id'],
      authorID: json['authorID'],
      author: json.containsKey('author')
          ? UserModel.fromJson(json['author'])
          : null,
      driver: json.containsKey('driver')
          ? UserModel.fromJson(json['driver'])
          : null,
      driverId: json['driverId'] ?? json['driverID'], // handle both keys
      status: json['status'],
      paymentMethod: json['paymentMethod'],
      paymentStatus: json['paymentStatus'],
      createdAt: json['createdAt'],
      triggerDelevery: json['trigger_delevery'] ?? json['triggerDelevery'],
      otpCode: json['otpCode'],
      sourceLocation: json.containsKey('sourceLocation')
          ? UserLocationData.fromJson(json['sourceLocation'])
          : null,
      destinationLocation: json.containsKey('destinationLocation')
          ? UserLocationData.fromJson(json['destinationLocation'])
          : null,
      sourceLocationName: json['sourceLocationName'],
      destinationLocationName: json['destinationLocationName'],
      rideType: json['rideType'],
      vehicleId: json['vehicleId'],
      vehicleType: json.containsKey('vehicleType')
          ? VehicleType.fromJson(json['vehicleType'])
          : null,
      distance: json['distance']?.toString(),
      duration: json['duration']?.toString(),
      actualDistance: json['actualDistance']?.toString(),
      actualDuration: json['actualDuration']?.toString(),
      subTotal: json['subTotal']?.toString(),
      discount: discountVal,
      couponCode: json['couponCode'],
      couponId: json['couponId'],
      scheduleDateTime: json['scheduleDateTime'],
      scheduleReturnDateTime: json['scheduleReturnDateTime'],
      startTime: json['startTime'],
      arrivalTime: json['arrivalTime'],
      acceptTime: json['acceptTime'],
      customerPickupTime: json['customerPickupTime'],
      customerDropTime: json['customerDropTime'],
      adminCommission: json['adminCommission'],
      adminCommissionType: json['adminCommissionType'],
      tipValue: json['tip_amount']?.toString() ?? json['tipValue']?.toString(),
      stops: stopsList,
      stopNames: stopNamesList,
      currentStopIndex: json['currentStopIndex'] ?? 0,
      rejectedByDrivers: json['rejectedByDrivers'] ?? [],
      taxModel: taxList,
      sectionId: json['sectionId'],
      platformFee: json['platformFee']?.toString(),
      roundTrip: json['roundTrip'],
    );
  }

  // ── toJson ──────────────────────────────────────────────────
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};

    data['id'] = id;
    data['authorID'] = authorID;
    if (author != null) data['author'] = author!.toJson();
    if (driver != null) {
      data['driver'] = driver!.toJson();
      data['driverID'] = driverId;
    } else {
      data['driverID'] = driverId;
    }
    data['status'] = status;
    data['paymentMethod'] = paymentMethod;
    data['paymentStatus'] = paymentStatus;
    data['createdAt'] = createdAt;
    data['trigger_delevery'] = triggerDelevery;
    data['otpCode'] = otpCode;

    if (sourceLocation != null)
      data['sourceLocation'] = sourceLocation!.toJson();
    if (destinationLocation != null)
      data['destinationLocation'] = destinationLocation!.toJson();
    data['sourceLocationName'] = sourceLocationName;
    data['destinationLocationName'] = destinationLocationName;

    data['rideType'] = rideType;
    data['vehicleId'] = vehicleId;
    if (vehicleType != null) data['vehicleType'] = vehicleType!.toJson();
    data['distance'] = distance;
    data['duration'] = duration;
    data['actualDistance'] = actualDistance;
    data['actualDuration'] = actualDuration;
    data['subTotal'] = subTotal;
    data['discount'] = discount;
    data['couponCode'] = couponCode;
    data['couponId'] = couponId;

    data['scheduleDateTime'] = scheduleDateTime;
    data['scheduleReturnDateTime'] = scheduleReturnDateTime;
    data['startTime'] = startTime;
    data['arrivalTime'] = arrivalTime;
    data['acceptTime'] = acceptTime;
    data['customerPickupTime'] = customerPickupTime;
    data['customerDropTime'] = customerDropTime;

    data['adminCommission'] = adminCommission;
    data['adminCommissionType'] = adminCommissionType;
    data['tip_amount'] = tipValue;

    data['stops'] = stops.map((v) => v.toJson()).toList();
    data['stopNames'] = stopNames;
    data['currentStopIndex'] = currentStopIndex;

    data['rejectedByDrivers'] = rejectedByDrivers ?? [];
    if (taxModel != null) {
      data['taxSetting'] = taxModel!.map((v) => v.toJson()).toList();
    }
    data['sectionId'] = sectionId;
    data['platformFee'] = platformFee;
    data['roundTrip'] = roundTrip;

    return data;
  }
}

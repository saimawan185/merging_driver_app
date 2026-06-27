import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:door_delights_driver/model/VehicleType.dart';

import '../models/tax_model.dart';
import '../models/user_model.dart';

class CabOrderModel {
  String authorID;
  String paymentMethod;
  bool paymentStatus;
  UserModel author;
  UserModel? driver;
  String? driverID;
  String? otpCode;
  Timestamp createdAt;
  Timestamp? trigger_delevery;
  String status;
  String id;
  num? discount;
  String? couponCode;
  String? couponId;
  String? tipValue;
  String? adminCommission;
  String? adminCommissionType;
  // String? tax;
  //String? taxType;
  List<TaxModel>? taxModel;
  String? subTotal;
  UserLocationData sourceLocation;
  UserLocationData destinationLocation;

  VehicleType? vehicleType;
  String? vehicleId;
  String? distance;
  String? duration;
  String? actualDistance;
  String? actualDuration;

  List<dynamic>? rejectedByDrivers = [];

  String? sourceLocationName;
  String? destinationLocationName;
  String? sectionId;

  Timestamp? startTime;
  Timestamp? arrivalTime;

  List<UserLocationData> stops = [];
  List<String> stopNames = [];

  int currentStopIndex;

  Timestamp? acceptTime;
  Timestamp? customerPickupTime;
  Timestamp? customerDropTime;

  CabOrderModel({
    author,
    this.acceptTime,
    this.customerPickupTime,
    this.customerDropTime,
    this.startTime,
    this.arrivalTime,
    this.driver,
    this.driverID,
    this.authorID = '',
    this.otpCode = '',
    this.paymentMethod = '',
    this.paymentStatus = false,
    createdAt,
    trigger_delevery,
    sourceLocation,
    destinationLocation,
    this.id = '',
    this.status = '',
    this.discount = 0,
    this.couponCode = '',
    this.couponId = '',
    this.tipValue,
    this.adminCommission,
    this.adminCommissionType,
    this.sourceLocationName,
    this.destinationLocationName,
    this.subTotal = "0.0",
    this.vehicleType,
    this.vehicleId,
    this.distance,
    this.duration,
    this.actualDistance,
    this.actualDuration,
    this.sectionId,
    this.taxModel,
    this.rejectedByDrivers,
    this.stops = const [],
    this.stopNames = const [],
    int this.currentStopIndex = 0,
  })  : author = author ?? UserModel(),
        sourceLocation = sourceLocation ?? UserLocationData(),
        this.trigger_delevery = trigger_delevery ?? Timestamp.now(),
        destinationLocation = destinationLocation ?? UserLocationData(),
        createdAt = createdAt ?? Timestamp.now();

  factory CabOrderModel.fromJson(Map<String, dynamic> parsedJson) {
    num discountVal = 0;

    if (parsedJson['discount'] == null) {
      discountVal = 0;
    } else if (parsedJson['discount'] is String) {
      discountVal = double.parse(parsedJson['discount']);
    } else {
      discountVal = parsedJson['discount'];
    }
    List<TaxModel>? taxList;
    if (parsedJson['taxSetting'] != null) {
      taxList = <TaxModel>[];
      parsedJson['taxSetting'].forEach((v) {
        taxList!.add(TaxModel.fromJson(v));
      });
    }

    List<UserLocationData>? stops;
    if (parsedJson['stops'] != null) {
      stops = <UserLocationData>[];
      parsedJson['stops'].forEach((v) {
        stops!.add(UserLocationData.fromJson(v));
      });
    }

    List<String>? stopNames;
    if (parsedJson['stopNames'] != null) {
      stopNames = <String>[];
      parsedJson['stopNames'].forEach((v) {
        stopNames!.add(v);
      });
    }

    return CabOrderModel(
      stops: stops ?? [],
      stopNames: stopNames ?? [],
      currentStopIndex: parsedJson['currentStopIndex'] ?? 0,
      author: parsedJson.containsKey('author')
          ? UserModel.fromJson(parsedJson['author'])
          : UserModel(),
      authorID: parsedJson['authorID'] ?? '',
      createdAt: parsedJson['createdAt'] ?? Timestamp.now(),
      startTime: parsedJson['startTime'] ?? Timestamp.now(),
      arrivalTime: parsedJson['arrivalTime'] ?? Timestamp.now(),
      acceptTime: parsedJson['acceptTime'],
      customerDropTime: parsedJson['customerDropTime'],
      customerPickupTime: parsedJson['customerPickupTime'],
      trigger_delevery: parsedJson['trigger_delevery'] ?? Timestamp.now(),
      id: parsedJson['id'] ?? '',
      paymentStatus: parsedJson['paymentStatus'] ?? false,
      status: parsedJson['status'] ?? '',
      discount: discountVal,
      couponCode: parsedJson['couponCode'] ?? '',
      couponId: parsedJson['couponId'] ?? '',
      driver: parsedJson.containsKey('driver')
          ? UserModel.fromJson(parsedJson['driver'])
          : null,
      driverID:
          parsedJson.containsKey('driverID') ? parsedJson['driverID'] : null,
      adminCommission: parsedJson["adminCommission"] ?? "",
      otpCode: parsedJson["otpCode"] ?? "",
      adminCommissionType: parsedJson["adminCommissionType"] ?? "",
      tipValue: parsedJson["tip_amount"] ?? "",
      paymentMethod: parsedJson['paymentMethod'] ?? '',
      taxModel: taxList,
      subTotal: parsedJson['subTotal'] ?? '0.0',
      sourceLocationName: parsedJson['sourceLocationName'] ?? '',
      destinationLocationName: parsedJson['destinationLocationName'] ?? '',
      vehicleType: parsedJson.containsKey('vehicleType')
          ? VehicleType.fromJson(parsedJson['vehicleType'])
          : null,
      vehicleId: parsedJson['vehicleId'] ?? '',
      distance: parsedJson['distance'] ?? '0',
      duration: parsedJson['duration'] ?? '',
      actualDistance: parsedJson['actualDistance'] ?? '0',
      actualDuration: parsedJson['actualDuration'] ?? '',
      sectionId: parsedJson['sectionId'] ?? "",
      rejectedByDrivers: parsedJson["rejectedByDrivers"],
      sourceLocation: parsedJson.containsKey('sourceLocation')
          ? UserLocationData.fromJson(parsedJson['sourceLocation'])
          : UserLocationData(),
      destinationLocation: parsedJson.containsKey('destinationLocation')
          ? UserLocationData.fromJson(parsedJson['destinationLocation'])
          : UserLocationData(),
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {
      'author': author.toJson(),
      'authorID': authorID,
      "currentStopIndex": currentStopIndex,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'createdAt': createdAt,
      'startTime': startTime,
      'arrivalTime': arrivalTime,
      'id': id,
      'status': status,
      'driverID': driverID,
      'discount': discount,
      'couponCode': couponCode,
      'couponId': couponId,
      'adminCommission': adminCommission,
      'adminCommissionType': adminCommissionType,
      "tip_amount": tipValue,
      "taxSetting":
          taxModel != null ? taxModel!.map((v) => v.toJson()).toList() : null,
      "sourceLocation": sourceLocation.toJson(),
      "destinationLocation": destinationLocation.toJson(),
      "vehicleType": vehicleType!.toJson(),
      "vehicleId": vehicleId,
      "distance": distance,
      "duration": duration,
      'actualDuration': actualDuration,
      'actualDistance': actualDistance,
      "subTotal": subTotal,
      "otpCode": otpCode,
      "rejectedByDrivers": this.rejectedByDrivers,
      "trigger_delevery": this.trigger_delevery,
      "sourceLocationName": this.sourceLocationName,
      "destinationLocationName": this.destinationLocationName,
      "sectionId": sectionId,
      "stops": stops.map((v) => v.toJson()).toList(),
      "stopNames": stopNames,
      "acceptTime": acceptTime,
      'customerPickupTime': customerPickupTime,
      'customerDropTime': customerDropTime,
    };
    if (this.driver != null) {
      json.addAll({'driverID': this.driverID, 'driver': this.driver!.toJson()});
    }
    return json;
  }
}

class UserLocationData {
  double latitude;
  double longitude;

  UserLocationData({this.latitude = 0.01, this.longitude = 0.01});

  factory UserLocationData.fromJson(Map<dynamic, dynamic> parsedJson) {
    return UserLocationData(
      latitude: double.parse((parsedJson['latitude'] ?? 00.1).toString()),
      longitude: double.parse((parsedJson['longitude'] ?? 00.1).toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

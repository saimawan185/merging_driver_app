import 'package:cloud_firestore/cloud_firestore.dart';
import '../constant/constant.dart';
import 'admin_commission.dart';
import 'cab_order_model.dart';
import 'order_model.dart';
import 'subscription_plan_model.dart';
import 'parcel_order_model.dart';

class UserModel {
  // ── Base fields ──────────────────────────────────────────────
  String? id;
  String? firstName;
  String? lastName;
  String? email;
  String? profilePictureURL;
  String? fcmToken;
  String? countryCode;
  String? countryISOCode;
  String? phoneNumber;
  num? walletAmount;
  bool? active;
  bool? isActive;
  bool? isDocumentVerify;
  Timestamp? createdAt;
  String? role;
  UserLocation? location;
  UserBankDetails? userBankDetails;
  List<ShippingAddress>? shippingAddress;
  String? carPictureURL;
  String? inProgressOrderID;
  OrderModel? orderRequestData;
  String? vendorID;
  String? zoneId;
  num? rotation;
  String? appIdentifier;
  String? provider;
  String? subscriptionPlanId;
  Timestamp? subscriptionExpiryDate;
  SubscriptionPlanModel? subscriptionPlan;

  // ── Multi‑section support ──────────────────────────────────
  List<String>? serviceTypes; // derived from selected sections
  List<String>? sectionIds; // selected section IDs

  // ── Section metadata ───────────────────────────────────────
  Map<String, dynamic>? vehicleDetails; // per‑section vehicle info
  String? serviceType; // legacy single section type
  String? sectionId; // legacy single section ID

  // ── Driver specific ────────────────────────────────────────
  String? carProofPictureURL;
  String? driverProofPictureURL;
  Timestamp? lastOnlineTimestamp;
  UserSettings? settings;
  String? carName;
  String? carNumber;
  String? carColor;
  String? vehicleType;
  String? vehicleId;
  String? carMakes;
  GeoFireData? geoFireData;
  GeoPoint? coordinates;
  String? driverRate;
  String? carRate;
  List<dynamic>? rentalBookingDate;
  CarInfo? carInfo;
  ParcelOrderModel? orderParcelRequestData;
  String? paymentCutomerId;

  // ── Vendor specific ────────────────────────────────────────
  num? reviewsCount;
  num? reviewsSum;
  AdminCommission? adminCommissionModel;
  CabOrderModel? orderCabRequestData;
  String? rideType;
  String? ownerId;
  bool? isOwner;
  bool? isAutoVerify;

  // ── Constructor ─────────────────────────────────────────────
  UserModel({
    this.id,
    this.firstName,
    this.lastName,
    this.active,
    this.isActive,
    this.isDocumentVerify,
    this.email,
    this.profilePictureURL,
    this.fcmToken,
    this.countryCode,
    this.countryISOCode,
    this.phoneNumber,
    this.walletAmount,
    this.createdAt,
    this.role,
    this.location,
    this.shippingAddress,
    this.carPictureURL,
    this.inProgressOrderID,
    this.orderRequestData,
    this.vendorID,
    this.zoneId,
    this.rotation,
    this.appIdentifier,
    this.provider,
    this.subscriptionPlanId,
    this.subscriptionExpiryDate,
    this.subscriptionPlan,
    this.serviceTypes,
    this.sectionIds,
    this.vehicleDetails,
    this.reviewsCount = 0,
    this.reviewsSum = 0,
    this.adminCommissionModel,
    this.orderCabRequestData,
    this.rideType,
    this.ownerId,
    this.isOwner,
    this.isAutoVerify,
    this.carProofPictureURL,
    this.driverProofPictureURL,
    this.lastOnlineTimestamp,
    this.settings,
    this.carName,
    this.carNumber,
    this.carColor,
    this.vehicleType,
    this.vehicleId,
    this.carMakes,
    this.geoFireData,
    this.coordinates,
    this.driverRate,
    this.carRate,
    this.rentalBookingDate,
    this.carInfo,
    this.orderParcelRequestData,
    this.paymentCutomerId,
    this.serviceType,
    this.sectionId,
    this.userBankDetails,
  });

  String fullName() => "${firstName ?? ''} ${lastName ?? ''}".trim();

  double get averageRating {
    final sum = double.tryParse(reviewsSum.toString()) ?? 0.0;
    final count = double.tryParse(reviewsCount.toString()) ?? 0.0;
    return count > 0 ? sum / count : 0.0;
  }

  // ── fromJson ─────────────────────────────────────────────────
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      email: json['email'],
      firstName: json['firstName'],
      lastName: json['lastName'],
      profilePictureURL: json['profilePictureURL'],
      fcmToken: json['fcmToken'],
      countryCode: json['countryCode'],
      countryISOCode: json['countryISOCode'],
      phoneNumber: json['phoneNumber'],
      walletAmount: json['wallet_amount'] ?? 0,
      createdAt: json['createdAt'],
      active: json['active'],
      isActive: json['isActive'],
      isDocumentVerify: json['isDocumentVerify'] ?? false,
      role: json['role'] ?? 'user',
      location: json['location'] != null
          ? UserLocation.fromJson(json['location'])
          : null,
      userBankDetails: json['userBankDetails'] != null
          ? UserBankDetails.fromJson(json['userBankDetails'])
          : null,
      shippingAddress: json['shippingAddress'] != null
          ? (json['shippingAddress'] as List)
              .map((v) => ShippingAddress.fromJson(v))
              .toList()
          : null,
      carPictureURL: json['carPictureURL'],
      inProgressOrderID: json['inProgressOrderID'],
      orderRequestData: json.containsKey('orderRequestData') &&
              json['orderRequestData'] != null
          ? OrderModel.fromJson(json['orderRequestData'])
          : null,
      vendorID: json['vendorID'] ?? '',
      zoneId: json['zoneId'] ?? '',
      rotation: json['rotation'],
      appIdentifier: json['appIdentifier'],
      provider: json['provider'],
      subscriptionPlanId: json['subscriptionPlanId'],
      subscriptionExpiryDate: json['subscriptionExpiryDate'],
      subscriptionPlan: json['subscription_plan'] != null
          ? SubscriptionPlanModel.fromJson(json['subscription_plan'])
          : null,
      // Multi‑section fields
      serviceTypes: json['serviceTypes'] != null
          ? List<String>.from(json['serviceTypes'])
          : (json['serviceType'] != null
              ? [json['serviceType'] as String]
              : null),
      sectionIds: json['sectionIds'] != null
          ? List<String>.from(json['sectionIds'])
          : (json['sectionId'] != null &&
                  json['sectionId'].toString().isNotEmpty
              ? [json['sectionId'].toString()]
              : null),
      vehicleDetails: json['vehicleDetails'] != null
          ? Map<String, dynamic>.from(json['vehicleDetails'])
          : null,
      reviewsCount: num.tryParse(json['reviewsCount']?.toString() ?? '0') ?? 0,
      reviewsSum: num.tryParse(json['reviewsSum']?.toString() ?? '0') ?? 0,
      adminCommissionModel: json['adminCommission'] != null
          ? AdminCommission.fromJson(json['adminCommission'])
          : null,
      orderCabRequestData: json['ordercabRequestData'] != null
          ? CabOrderModel.fromJson(json['ordercabRequestData'])
          : null,
      rideType: json['rideType'],
      ownerId: json['ownerId'],
      isOwner: json['isOwner'],
      isAutoVerify: json['isAutoVerify'],
      // Driver fields
      carProofPictureURL: json['carProofPictureURL'],
      driverProofPictureURL: json['driverProofPictureURL'],
      lastOnlineTimestamp: json['lastOnlineTimestamp'],
      settings: json['settings'] != null
          ? UserSettings.fromJson(json['settings'])
          : null,
      carName: json['carName'],
      carNumber: json['carNumber'],
      carColor: json['carColor'],
      vehicleType: json['vehicleType'],
      vehicleId: json['vehicleId'],
      carMakes: json['carMakes'],
      geoFireData: json['g'] != null ? GeoFireData.fromJson(json['g']) : null,
      coordinates: json['coordinates'],
      driverRate: json['driverRate']?.toString() ?? '0',
      carRate: json['carRate']?.toString() ?? '0',
      rentalBookingDate: json['rentalBookingDate'] ?? [],
      carInfo:
          json['carInfo'] != null ? CarInfo.fromJson(json['carInfo']) : null,
      orderParcelRequestData: json['orderParcelRequestData'] != null
          ? ParcelOrderModel.fromJson(json['orderParcelRequestData'])
          : null,
      paymentCutomerId: json['paymentCutomerId'],
      serviceType: json['serviceType'],
      sectionId: json['sectionId'],
    );
  }

  // ── toJson ───────────────────────────────────────────────────
  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};

    // Base fields
    data['id'] = id;
    data['email'] = email;
    data['firstName'] = firstName;
    data['lastName'] = lastName;
    data['profilePictureURL'] = profilePictureURL;
    data['fcmToken'] = fcmToken;
    data['countryCode'] = countryCode;
    data['countryISOCode'] = countryISOCode;
    data['phoneNumber'] = phoneNumber;
    data['wallet_amount'] = walletAmount ?? 0;
    data['createdAt'] = createdAt;
    data['active'] = active;
    data['isActive'] = isActive;
    data['role'] = role;
    data['isDocumentVerify'] = isDocumentVerify;
    data['zoneId'] = zoneId;
    data['rotation'] = rotation;
    data['appIdentifier'] = appIdentifier;
    data['provider'] = provider;
    data['reviewsCount'] = reviewsCount;
    data['reviewsSum'] = reviewsSum;
    data['isAutoVerify'] = isAutoVerify;
    data['inProgressOrderID'] = inProgressOrderID;

    // Nested objects
    if (location != null) data['location'] = location!.toJson();
    if (userBankDetails != null)
      data['userBankDetails'] = userBankDetails!.toJson();
    if (shippingAddress != null) {
      data['shippingAddress'] =
          shippingAddress!.map((v) => v.toJson()).toList();
    }
    if (subscriptionPlan != null)
      data['subscription_plan'] = subscriptionPlan!.toJson();
    if (adminCommissionModel != null)
      data['adminCommission'] = adminCommissionModel!.toJson();

    // Multi‑section fields
    data['serviceTypes'] = serviceTypes ?? ['delivery-service'];
    data['sectionIds'] = sectionIds ?? [];
    if (vehicleDetails != null) data['vehicleDetails'] = vehicleDetails;
    if (serviceType != null) data['serviceType'] = serviceType;
    if (sectionId != null) data['sectionId'] = sectionId;

    // Vendor fields
    if (role == Constant.userRoleVendor) {
      data['vendorID'] = vendorID;
      data['subscriptionPlanId'] = subscriptionPlanId;
      data['subscriptionExpiryDate'] = subscriptionExpiryDate;
    }

    // Driver fields
    if (role == Constant.userRoleDriver) {
      data['vendorID'] = vendorID;
      data['carPictureURL'] = carPictureURL;
      data['orderRequestData'] = this.orderRequestData?.toJson();
      if (orderCabRequestData != null)
        data['ordercabRequestData'] = orderCabRequestData!.toJson();
      data['ownerId'] = ownerId;
      data['isOwner'] = isOwner;
      data['carProofPictureURL'] = carProofPictureURL;
      data['driverProofPictureURL'] = driverProofPictureURL;
      data['lastOnlineTimestamp'] = lastOnlineTimestamp;
      if (settings != null) data['settings'] = settings!.toJson();
      data['carName'] = carName;
      data['carNumber'] = carNumber;
      data['carColor'] = carColor;
      data['vehicleType'] = vehicleType;
      data['vehicleId'] = vehicleId;
      data['carMakes'] = carMakes;
      if (geoFireData != null) data['g'] = geoFireData!.toJson();
      data['coordinates'] = coordinates;
      data['driverRate'] = driverRate;
      data['carRate'] = carRate;
      data['rentalBookingDate'] = rentalBookingDate;
      if (carInfo != null) data['carInfo'] = carInfo!.toJson();
      if (orderParcelRequestData != null)
        data['orderParcelRequestData'] = orderParcelRequestData!.toJson();
      data['paymentCutomerId'] = paymentCutomerId;
      data['rideType'] = rideType;
    }

    return data;
  }
}

// -----------------------------------------------------------------
// Supporting classes (already exist in your project, but defined here for completeness)
// -----------------------------------------------------------------

class UserLocation {
  double? latitude;
  double? longitude;
  UserLocation({this.latitude, this.longitude});
  UserLocation.fromJson(Map<String, dynamic> json) {
    latitude = json['latitude'];
    longitude = json['longitude'];
  }
  Map<String, dynamic> toJson() {
    return {'latitude': latitude, 'longitude': longitude};
  }
}

class ShippingAddress {
  String? id;
  String? address;
  String? addressAs;
  String? landmark;
  String? locality;
  UserLocation? location;
  bool? isDefault;
  ShippingAddress(
      {this.id,
      this.address,
      this.landmark,
      this.locality,
      this.location,
      this.isDefault,
      this.addressAs});
  ShippingAddress.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    address = json['address'];
    landmark = json['landmark'];
    locality = json['locality'];
    isDefault = json['isDefault'];
    addressAs = json['addressAs'];
    location = json['location'] != null
        ? UserLocation.fromJson(json['location'])
        : null;
  }
  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['id'] = id;
    data['address'] = address;
    data['landmark'] = landmark;
    data['locality'] = locality;
    data['isDefault'] = isDefault;
    data['addressAs'] = addressAs;
    if (location != null) data['location'] = location!.toJson();
    return data;
  }

  String getFullAddress() {
    return '${address ?? ''} ${locality ?? ''} ${landmark ?? ''}'.trim();
  }
}

class UserBankDetails {
  String bankName;
  String branchName;
  String holderName;
  String accountNumber;
  String otherDetails;
  UserBankDetails(
      {this.bankName = '',
      this.otherDetails = '',
      this.branchName = '',
      this.accountNumber = '',
      this.holderName = ''});
  factory UserBankDetails.fromJson(Map<String, dynamic> json) {
    return UserBankDetails(
      bankName: json['bankName'] ?? '',
      branchName: json['branchName'] ?? '',
      holderName: json['holderName'] ?? '',
      accountNumber: json['accountNumber'] ?? '',
      otherDetails: json['otherDetails'] ?? '',
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'bankName': bankName,
      'branchName': branchName,
      'holderName': holderName,
      'accountNumber': accountNumber,
      'otherDetails': otherDetails,
    };
  }
}

// If you don't have these classes already, define them here (or import them):

class UserSettings {
  bool pushNewMessages;
  bool orderUpdates;
  bool newArrivals;
  bool promotions;
  UserSettings(
      {this.pushNewMessages = true,
      this.orderUpdates = true,
      this.newArrivals = true,
      this.promotions = true});
  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      pushNewMessages: json['pushNewMessages'] ?? true,
      orderUpdates: json['orderUpdates'] ?? true,
      newArrivals: json['newArrivals'] ?? true,
      promotions: json['promotions'] ?? true,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'pushNewMessages': pushNewMessages,
      'orderUpdates': orderUpdates,
      'newArrivals': newArrivals,
      'promotions': promotions,
    };
  }
}

class GeoFireData {
  String? geohash;
  GeoPoint? geoPoint;
  GeoFireData({this.geohash, this.geoPoint});
  factory GeoFireData.fromJson(Map<String, dynamic> json) {
    return GeoFireData(
      geohash: json['geohash'] ?? '',
      geoPoint: json['geopoint'] ?? GeoPoint(0.0, 0.0),
    );
  }
  Map<String, dynamic> toJson() {
    return {'geohash': geohash, 'geopoint': geoPoint};
  }
}

class CarInfo {
  String? passenger;
  String? doors;
  String? carName;
  String? airConditioning;
  String? gear;
  String? mileage;
  String? fuelFilling;
  String? fuelType;
  List<dynamic>? carImage;
  String? maxPower;
  String? mph;
  String? topSpeed;
  CarInfo(
      {this.passenger,
      this.doors,
      this.carName,
      this.airConditioning,
      this.gear,
      this.mileage,
      this.fuelFilling,
      this.fuelType,
      this.carImage,
      this.maxPower,
      this.mph,
      this.topSpeed});
  factory CarInfo.fromJson(Map<String, dynamic> json) {
    return CarInfo(
      passenger: json['passenger'] ?? '',
      doors: json['doors'] ?? '',
      carName: json['carName'] ?? '',
      airConditioning: json['air_conditioning'] ?? '',
      gear: json['gear'] ?? '',
      mileage: json['mileage'] ?? '',
      fuelFilling: json['fuel_filling'] ?? '',
      fuelType: json['fuel_type'] ?? '',
      carImage: json['car_image'] ?? [],
      maxPower: json['maxPower'] ?? '',
      mph: json['mph'] ?? '',
      topSpeed: json['topSpeed'] ?? '',
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'passenger': passenger,
      'doors': doors,
      'carName': carName,
      'air_conditioning': airConditioning,
      'gear': gear,
      'mileage': mileage,
      'fuel_filling': fuelFilling,
      'fuel_type': fuelType,
      'car_image': carImage,
      'maxPower': maxPower,
      'mph': mph,
      'topSpeed': topSpeed,
    };
  }
}

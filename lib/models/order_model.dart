import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:door_delights_driver/model/ProductModel.dart';
import 'package:door_delights_driver/models/user_model.dart';
import 'cashbackModel.dart';
import 'tax_model.dart';
import 'vendor_model.dart';

class OrderModel {
  ShippingAddress? address;
  String? status;
  String? couponId;
  String? vendorID;
  String? driverID;
  num? discount;
  String? authorID;
  String? estimatedTimeToPrepare;
  Timestamp? createdAt;
  Timestamp? triggerDelivery;
  String? paymentMethod;
  List<ProductModel>? products;
  String? adminCommissionType;
  VendorModel? vendor;
  String? id;
  String? adminCommission;
  String? couponCode;
  String? sectionId;
  Map<String, dynamic>? specialDiscount;
  String? deliveryCharge;
  Timestamp? scheduleTime;
  String? tipAmount;
  String? notes;
  UserModel? author;
  UserModel? driver;
  bool? takeAway;
  List<dynamic>? rejectedByDrivers;
  CashbackModel? cashback;
  String? courierCompanyName;
  String? courierTrackingId;
  List<TaxModel>? taxSetting;
  List<TaxModel>? driverDeliveryTax;
  List<TaxModel>? packagingTax;
  List<TaxModel>? platformTax;
  String? taxScope;
  String? platformFee;
  bool? isPosOrder;
  bool? isFreeDelivery;
  bool? packagingChargeEnable;
  double? serviceCharges, deliveryDiscount = 0.0;

  OrderModel({
    this.address,
    this.status,
    this.couponId,
    this.vendorID,
    this.driverID,
    this.discount,
    this.authorID,
    this.estimatedTimeToPrepare,
    this.createdAt,
    this.triggerDelivery,
    this.paymentMethod,
    this.products,
    this.adminCommissionType,
    this.vendor,
    this.id,
    this.adminCommission,
    this.couponCode,
    this.sectionId,
    this.specialDiscount,
    this.deliveryCharge,
    this.scheduleTime,
    this.tipAmount,
    this.notes,
    this.author,
    this.driver,
    this.takeAway,
    this.rejectedByDrivers,
    this.cashback,
    this.courierCompanyName,
    this.courierTrackingId,
    this.taxSetting,
    this.driverDeliveryTax,
    this.packagingTax,
    this.platformTax,
    this.taxScope,
    this.platformFee,
    this.isPosOrder,
    this.isFreeDelivery,
    this.packagingChargeEnable,
    this.deliveryDiscount,
    this.serviceCharges,
  });

  OrderModel.fromJson(Map<String, dynamic> json) {
    address = json['address'] != null
        ? ShippingAddress.fromJson(json['address'])
        : null;
    deliveryDiscount = double.parse(
      json['deliveryDiscount'] != null
          ? json['deliveryDiscount'].toString()
          : '0.0',
    );
    serviceCharges = double.parse(
      json['serviceCharges'] == null
          ? '0.0'
          : json['serviceCharges'].toString(),
    );
    status = json['status'];
    couponId = json['couponId'];
    vendorID = json['vendorID'];
    driverID = json['driverID'];
    discount = json['discount'];
    authorID = json['authorID'];
    estimatedTimeToPrepare = json['estimatedTimeToPrepare'];
    createdAt = json['createdAt'];
    courierCompanyName = json['courierCompanyName'];
    courierTrackingId = json['courierTrackingId'];
    triggerDelivery = json['triggerDelevery'] ?? Timestamp.now();

    paymentMethod = json['payment_method'];
    if (json['products'] != null) {
      products = <ProductModel>[];
      json['products'].forEach((v) {
        products!.add(ProductModel.fromJson(v));
      });
    }
    adminCommissionType = json['adminCommissionType'];
    vendor =
        json['vendor'] != null ? VendorModel.fromJson(json['vendor']) : null;
    id = json['id'];
    adminCommission = json['adminCommission'];
    couponCode = json['couponCode'];
    sectionId = json['section_id'];
    specialDiscount = json['specialDiscount'];
    deliveryCharge = json['deliveryCharge'].toString().trim().isEmpty
        ? "0.0"
        : json['deliveryCharge'] ?? '0.0';
    scheduleTime = json['scheduleTime'];
    tipAmount = json['tip_amount'].toString().isEmpty
        ? "0.0"
        : json['tip_amount'] ?? "0.0";
    notes = json['notes'];
    author = json['author'] != null ? UserModel.fromJson(json['author']) : null;
    driver = json['driver'] != null ? UserModel.fromJson(json['driver']) : null;
    takeAway = json['takeAway'];
    rejectedByDrivers = json['rejectedByDrivers'] ?? [];
    cashback = json['cashback'] != null
        ? CashbackModel.fromJson(json['cashback'])
        : null;
    if (json['taxSetting'] != null) {
      taxSetting = <TaxModel>[];
      json['taxSetting'].forEach((v) {
        taxSetting!.add(TaxModel.fromJson(v));
      });
    }
    if (json['platformTax'] != null) {
      platformTax = <TaxModel>[];
      json['platformTax'].forEach((v) {
        platformTax!.add(TaxModel.fromJson(v));
      });
    }
    if (json['packagingTax'] != null) {
      packagingTax = <TaxModel>[];
      json['packagingTax'].forEach((v) {
        packagingTax!.add(TaxModel.fromJson(v));
      });
    }

    if (json['driverDeliveryTax'] != null) {
      driverDeliveryTax = <TaxModel>[];
      json['driverDeliveryTax'].forEach((v) {
        driverDeliveryTax!.add(TaxModel.fromJson(v));
      });
    }
    taxScope = json['taxScope'];
    platformFee = json['platformFee'];
    isFreeDelivery = json['isFreeDelivery'] ?? false;
    isPosOrder = json['isPosOrder'] ?? false;
    packagingChargeEnable = json['packagingChargeEnable'] ?? false;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (address != null) {
      data['address'] = address!.toJson();
    }
    data['deliveryDiscount'] = deliveryDiscount;
    data['serviceCharges'] = serviceCharges ?? 0.0;
    data['status'] = status;
    data['couponId'] = couponId;
    data['vendorID'] = vendorID;
    data['driverID'] = driverID;
    data['discount'] = discount;
    data['authorID'] = authorID;
    data['estimatedTimeToPrepare'] = estimatedTimeToPrepare;
    data['createdAt'] = createdAt;
    data['triggerDelivery'] = triggerDelivery;

    data['payment_method'] = paymentMethod;
    if (products != null) {
      data['products'] = products!.map((v) => v.toJson()).toList();
    }
    data['adminCommissionType'] = adminCommissionType;
    if (vendor != null) {
      data['vendor'] = vendor!.toJson();
    }
    data['id'] = id;
    data['adminCommission'] = adminCommission;
    data['couponCode'] = couponCode;
    data['section_id'] = sectionId;
    data['specialDiscount'] = specialDiscount;
    data['deliveryCharge'] = deliveryCharge;
    data['scheduleTime'] = scheduleTime;
    data['tip_amount'] = tipAmount;
    data['courierCompanyName'] = courierCompanyName;
    data['courierTrackingId'] = courierTrackingId;
    data['notes'] = notes;
    if (author != null) {
      data['author'] = author!.toJson();
    }
    if (driver != null) {
      data['driver'] = driver!.toJson();
    }
    data['takeAway'] = takeAway;
    data['rejectedByDrivers'] = rejectedByDrivers;
    data['cashback'] = cashback?.toJson();
    if (taxSetting != null) {
      data['taxSetting'] = taxSetting!.map((v) => v.toJson()).toList();
    }
    if (platformTax != null) {
      data['platformTax'] = platformTax!.map((v) => v.toJson()).toList();
    }
    if (packagingTax != null) {
      data['packagingTax'] = packagingTax!.map((v) => v.toJson()).toList();
    }
    if (driverDeliveryTax != null) {
      data['driverDeliveryTax'] =
          driverDeliveryTax!.map((v) => v.toJson()).toList();
    }
    data['taxScope'] = taxScope;
    data['platformFee'] = platformFee;
    data['isFreeDelivery'] = isFreeDelivery ?? false;
    data['isPosOrder'] = isPosOrder ?? false;
    data['packagingChargeEnable'] = packagingChargeEnable ?? false;
    return data;
  }
}

import 'admin_commission.dart';
import 'platform_fee_model.dart';
import 'package:easy_localization/easy_localization.dart';

class SectionModel {
  String? referralAmount;
  String? serviceType;
  String? color;
  String? name;
  String? sectionImage;
  String? markerIcon;
  String? id;
  bool? isActive;
  bool? dineInActive;
  bool? isProductDetails;
  String? serviceTypeFlag;
  String? delivery_charge;
  String? rideType;
  String? theme;
  int? nearByRadius;
  AdminCommission? adminCommision;
  PlatformFeeModel? platformFee;
  bool? packagingChargeEnable;

  SectionModel({
    this.referralAmount,
    this.serviceType,
    this.color,
    this.name,
    this.sectionImage,
    this.markerIcon,
    this.id,
    this.isActive,
    this.theme,
    this.adminCommision,
    this.dineInActive,
    this.delivery_charge,
    this.nearByRadius,
    this.isProductDetails,
    this.serviceTypeFlag,
    this.rideType,
    this.platformFee,
    this.packagingChargeEnable,
  });

  SectionModel.fromJson(Map<String, dynamic> json) {
    referralAmount = json['referralAmount'] ?? '';
    serviceType = json['serviceType'] ?? '';
    color = json['color'];
    name = json['name'];
    sectionImage = json['sectionImage'];
    markerIcon = json['markerIcon'];
    id = json['id'];
    adminCommision = json.containsKey('adminCommision')
        ? AdminCommission.fromJson(json['adminCommision'])
        : null;
    isActive = json['isActive'];
    theme = json['theme'] ?? "theme_2";
    dineInActive = json['dine_in_active'] ?? false;
    isProductDetails = json['is_product_details'] ?? false;
    serviceTypeFlag = json['serviceTypeFlag'] ?? '';
    delivery_charge = json['delivery_charge'] ?? '';
    rideType = json['rideType'] ?? 'ride';

    // ✅ FIX: Safe parse nearByRadius (handles String, num, int, double, null)
    final rawRadius = json['nearByRadius'];
    if (rawRadius != null) {
      // Convert to string first, then parse
      final String radiusStr = rawRadius.toString().trim();
      if (radiusStr.isNotEmpty) {
        // Use tryParse to handle both "15" and 15.0
        final parsed = double.tryParse(radiusStr);
        if (parsed != null && !parsed.isNaN) {
          nearByRadius = parsed.toInt();
        } else {
          nearByRadius = 5000; // default
        }
      } else {
        nearByRadius = 5000; // default
      }
    } else {
      nearByRadius = 5000; // default
    }

    platformFee = json['platformFee'] != null
        ? PlatformFeeModel.fromJson(json['platformFee'])
        : null;
    packagingChargeEnable = json['packagingChargeEnable'] ?? false;
  }
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['referralAmount'] = referralAmount;
    data['serviceType'] = serviceType;
    data['color'] = color;
    data['name'] = name;
    data['sectionImage'] = sectionImage;
    data['markerIcon'] = markerIcon;
    data['rideType'] = rideType;
    data['theme'] = theme;
    if (adminCommision != null) {
      data['adminCommision'] = adminCommision!.toJson();
    }
    data['id'] = id;
    data['isActive'] = isActive;
    data['dine_in_active'] = dineInActive;
    data['is_product_details'] = isProductDetails;
    data['serviceTypeFlag'] = serviceTypeFlag;
    data['delivery_charge'] = delivery_charge;
    data['nearByRadius'] = nearByRadius;

    if (platformFee?.enable == true) {
      data['platformFee'] = platformFee?.toJson();
    }
    data['packagingChargeEnable'] = packagingChargeEnable;

    return data;
  }
}

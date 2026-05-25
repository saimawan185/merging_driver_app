class CardModel {
  final String id;
  final String token;
  final String brand;
  final String paddedCardNumber;
  final String tokenExpiryMonth;
  final String tokenExpiryYear;
  final bool isDefault;

  CardModel({
    required this.id,
    required this.token,
    required this.brand,
    required this.paddedCardNumber,
    required this.tokenExpiryMonth,
    required this.tokenExpiryYear,
    required this.isDefault,
  });

  factory CardModel.fromJson(Map<String, dynamic> json) {
    return CardModel(
      id: json['id'] ?? json['_id'] ?? '',
      token: json['token'] ?? '',
      brand: json['brand'] ?? '',
      paddedCardNumber: json['paddedCardNumber'] ?? '',
      tokenExpiryMonth: json['tokenExpiryMonth'] ?? '',
      tokenExpiryYear: json['tokenExpiryYear'] ?? '',
      isDefault: json['defaultToken'] ?? false,
    );
  }

  String get lastFourDigits {
    if (paddedCardNumber.length >= 4) {
      return paddedCardNumber.substring(paddedCardNumber.length - 4);
    }
    return paddedCardNumber;
  }

  String get expiryDate {
    return '$tokenExpiryMonth/$tokenExpiryYear';
  }

  String get displayBrand {
    switch (brand.toLowerCase()) {
      case 'master':
        return 'Mastercard';
      case 'visa':
        return 'Visa';
      default:
        return brand;
    }
  }
}

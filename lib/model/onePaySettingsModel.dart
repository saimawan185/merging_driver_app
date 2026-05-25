class OnePaySettingData {
  String appId;
  String appToken;
  String hashSalt;
  String redirectUrl;
  bool isEnabled;
  bool isSandbox;

  OnePaySettingData({
    this.appId = '',
    this.appToken = '',
    this.hashSalt = '',
    this.redirectUrl = '',
    required this.isSandbox,
    required this.isEnabled,
  });

  factory OnePaySettingData.fromJson(Map<String, dynamic> parsedJson) {
    return OnePaySettingData(
      appId: parsedJson['appId'] ?? '',
      appToken: parsedJson['appToken'] ?? '',
      hashSalt: parsedJson['hashSalt'] ?? '',
      redirectUrl: parsedJson['redirectUrl'] ?? '',
      isEnabled: parsedJson['isEnabled'],
      isSandbox: parsedJson['isSandbox'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'appId': this.appId,
      'appToken': this.appToken,
      'hashSalt': this.hashSalt,
      'redirectUrl': this.redirectUrl,
      'isEnabled': this.isEnabled,
      'isSandbox': this.isSandbox,
    };
  }
}

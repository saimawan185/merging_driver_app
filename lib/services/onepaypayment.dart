import 'dart:convert';
import 'package:door_delights_driver/constants.dart';
import 'package:door_delights_driver/model/onePaySettingsModel.dart';
import 'package:door_delights_driver/models/user_model.dart';
// import 'package:flutterwave_standard/view/view_utils.dart';
import 'package:crypto/crypto.dart';

class OnePayPayment {
  static var app_id = 'XEFR118C36094B2E23019';
  static var app_token =
      '86e769927af85edae94953728474228c00a0cb90430cb16822a5216575d9fda40be59a6c8f36e979.CHNQ118E511564AA0891F';
  static var hashSalt = 'FE1Y118C36094B2E2305F';
  static var redirect_url = 'https://doordelights.lk/';
  static var referenceId = '';

  static String generateSha256Hash(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static String createRequestBody(
      {required String amount, required UserModel user}) {
    final body = {
      'amount': '${amount}',
      'currency': currencyData?.code ?? 'LKR',
      'app_id': app_id,
      'reference': referenceId,
      'customer_first_name': user.firstName,
      'customer_last_name': user.lastName,
      'customer_phone_number': user.phoneNumber,
      'customer_email': user.email,
      'transaction_redirect_url': redirect_url,
      'additional_data': 'sample',
    };
    String bodyString = jsonEncode(body).replaceAll(' ', '');
    return bodyString + hashSalt;
  }

  static Future<String> makeApiCall(context,
      {required String amount,
      required UserModel user,
      required OnePaySettingData? onePaySettingData}) async {
    app_id = onePaySettingData?.appId ?? '';
    app_token = onePaySettingData?.appToken ?? '';
    hashSalt = onePaySettingData?.hashSalt ?? '';
    redirect_url = onePaySettingData?.redirectUrl ?? '';
    referenceId = generateId();
    final requestBodyWithSalt = createRequestBody(amount: amount, user: user);
    final hash = generateSha256Hash(requestBodyWithSalt);

    final url = Uri.parse(
        'https://merchant-api-live-v2.onepay.lk/api/ipg/gateway/request-payment-link/?hash=$hash');
    final headers = {
      'Authorization': app_token,
      'Content-Type': 'application/json',
    };
    final body = jsonEncode({
      'amount': '${amount}',
      'currency': currencyData?.code ?? 'LKR',
      'app_id': app_id,
      'reference': referenceId,
      'customer_first_name': user.firstName,
      'customer_last_name': user.lastName,
      'customer_phone_number': user.phoneNumber,
      'customer_email': user.email,
      'transaction_redirect_url': redirect_url,
      'additional_data': 'sample',
    });
    return '';

    // try {
    //   final response = await http.post(url, headers: headers, body: body);

    //   final Map<String, dynamic> responseBody = jsonDecode(response.body);
    //   if (responseBody['status'].toString() != '1000') {
    //     FlutterwaveViewUtils.showToast(context, '${responseBody['message']}');
    //     return '';
    //   } else {
    //     return responseBody['data']['gateway']['redirect_url'] ?? '';
    //   }
    // } catch (e) {
    //   FlutterwaveViewUtils.showToast(context, '${e}');
    //   return '';
    // }
  }
}

import 'dart:convert';
import 'dart:developer';
import 'package:door_delights_driver/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../constants.dart';
import '../../model/card_model.dart';
import '../../model/onePaySettingsModel.dart';

class GeniePayment {
  static var redirect_url =
      'https://us-central1-doordelights-423407.cloudfunctions.net/paymentCallback';

  static var apiUrl = 'https://api.geniebiz.lk';
  //Test URL
  // static var apiUrl = 'https://api.uat.geniebiz.lk';

//Test API Key
  // final String apiKey =
  //     'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhcHBJZCI6IjllODAwZWE1LTY0OGEtNDE0MS05NGI5LTJiMGI2ZDM3NTJlYiIsImNvbXBhbnlJZCI6IjY4ZTc5YTYxYzcwMGE4Njk3MDc0ZTFlMSIsImlhdCI6MTc2MDAwODgwMSwiZXhwIjo0OTE1NjgyNDAxfQ.npNtGKhxHAloeiSlhWyL1iUbYEtKnP9-0PXV1pmBn7g';

  //Real API Key
  final String apiKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhcHBJZCI6ImFjYjhmMzI2LThlMjItNGU0MC05YWQ1LTEzYmFmMzliYTczZSIsImNvbXBhbnlJZCI6IjY4ZGJhZDhhZGE4ZjVlMmYyM2RmNWFmZCIsImlhdCI6MTc1OTkzODEyNSwiZXhwIjo0OTE1NjExNzI1fQ.ddIQ_sitBrLADbskk_ueBy3_JeK7D3XUtiWTpcKf6dM';

  // Create customer if doesn't exist
  Future<String?> createCustomerIfNeeded({required UserModel user}) async {
    try {
      // If user already has customer ID, return it
      if (user.paymentCutomerId != null && user.paymentCutomerId!.isNotEmpty) {
        return user.paymentCutomerId;
      }

      // Create new customer
      final customerId = await createCustomer(user: user);
      if (customerId != null) {
        log('Created new customer: $customerId');
      } else {
        log('Failed to create customer');
      }

      return customerId;
    } catch (e) {
      log('Error creating customer: $e');
      return null;
    }
  }

  Future<String?> createCustomer({required UserModel user}) async {
    try {
      final url = Uri.parse('$apiUrl/public-customers/');
      final headers = {
        'Accept': 'application/json',
        'Authorization': apiKey,
        'Content-Type': 'application/json',
      };

      final bodyMap = {
        "name": user.fullName(),
        "email": user.email,
        "billingEmail": user.email,
      };

      final body = jsonEncode(bodyMap);

      log('Creating customer: $body');

      final response = await http.post(url, headers: headers, body: body);
      final Map<String, dynamic> responseBody = jsonDecode(response.body);

      log('Create Customer Response: ${response.statusCode}, ${response.body}');

      if (response.statusCode == 201) {
        return responseBody['id'] as String?;
      } else {
        log('Customer creation failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      log('Error creating customer: $e');
      return null;
    }
  }

  Future<Map<String, String>?> addCard({required String customerId}) async {
    try {
      final url = Uri.parse('$apiUrl/public/v2/transactions');
      final headers = {
        'Accept': 'application/json',
        'Authorization': apiKey,
        'Content-Type': 'application/json',
      };

      final bodyMap = {
        'redirectUrl': redirect_url,
        'amount': 1000,
        'currency': currencyData?.code ?? 'LKR',
        "customerId": customerId,
        "addCardToVault": true,
        "provider": "card_payments",
        "tokenizationDetails": {
          "tokenize": true,
          "paymentType": "UNSCHEDULED",
          "recurringFrequency": "UNSCHEDULED",
        },
        "paymentPortalExperience": {
          "externalWebsiteTermsAccepted": true,
          "externalWebsiteTermsUrl": "https://doordelights.lk/set-location",
          "skipCustomerForm": true,
          "skipProviderSelection": true,
          "hideTermsAndConditions": true
        }
      };

      final body = jsonEncode(bodyMap);

      log('Add Card Request: $body');

      final response = await http.post(url, headers: headers, body: body);
      final Map<String, dynamic> responseBody = jsonDecode(response.body);

      log("Add Card Response: ${response.statusCode}, ${response.body}");

      if (response.statusCode == 201) {
        return {
          'url': responseBody['url'] ?? '',
          'transaction_id': responseBody['id'] ?? '',
          'customerId': responseBody['customerId'] ?? '',
        };
      } else {
        log('Card addition failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      log('Error adding card: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getTransaction(String transactionId) async {
    if (transactionId.isEmpty) {
      log('Transaction ID is empty');
      return null;
    }

    final url = Uri.parse('$apiUrl/public/transactions/$transactionId');
    final headers = {
      'Accept': 'application/json',
      'Authorization': apiKey,
    };

    try {
      log('Fetching transaction: $transactionId');
      final response = await http.get(url, headers: headers);

      log('Transaction API Response: ${response.statusCode}, ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> transactionData = jsonDecode(response.body);
        log('Transaction fetched successfully');
        return transactionData;
      } else if (response.statusCode == 404) {
        log('Transaction not found: $transactionId');
        return null;
      } else {
        log('Failed to fetch transaction: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      log('Error fetching transaction: $e');
      return null;
    }
  }

  Future<Map<String, String>?> createPayment({
    required BuildContext context,
    required String amount,
    required UserModel user,
    required OnePaySettingData? onePaySettingData,
    String? customerId,
  }) async {
    redirect_url = onePaySettingData?.redirectUrl ?? '';

    final url = Uri.parse('$apiUrl/public/v2/transactions');
    final headers = {
      'Accept': 'application/json',
      'Authorization': apiKey,
      'Content-Type': 'application/json',
    };

    final bodyMap = {
      'redirectUrl': redirect_url,
      'amount': int.parse((double.parse(amount) * 100).toStringAsFixed(0)),
      'currency': currencyData?.code ?? 'LKR',
    };

    // Add customerId if available
    if (customerId != null && customerId.isNotEmpty) {
      bodyMap['customerId'] = customerId;
    }

    // DO NOT include card token here when using chargeCard separately
    // if (cardToken != null && cardToken.isNotEmpty) {
    //   bodyMap['tokenId'] = cardToken;
    // }

    final body = jsonEncode(bodyMap);

    try {
      log('Payment Request URL: $url');
      log('Payment Request Body: $body');

      final response = await http.post(url, headers: headers, body: body);
      final Map<String, dynamic> responseBody = jsonDecode(response.body);

      log("Payment Response: ${response.statusCode}, ${response.body}");

      if (response.statusCode == 201) {
        return {
          'url': responseBody['url'] ?? '',
          'transaction_id': responseBody['id'] ?? '',
          'customerId': responseBody['customerId'] ?? customerId ?? '',
        };
      } else {
        log('Payment creation failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      log('Error creating payment: $e');
      return null;
    }
  }

  Future<Map<String, String>?> chargeCard(
    String customerId,
    String transactionId,
    String tokenId,
  ) async {
    try {
      final url = Uri.parse('$apiUrl/public-customers/charge');

      final headers = {
        'Accept': 'application/json',
        'Authorization': apiKey,
      };

      final bodyMap = {
        "customerId": customerId,
        "transactionId": transactionId,
        "tokenId": tokenId,
        "payerIpAddress": "192.168.10.1",
        "javaEnabled": true,
        "language": "string",
        "javascriptEnabled": true,
        "colorDepth": 0,
        "screenHeight": 0,
        "screenWidth": 0,
        "tz": 0,
      };

      final body = jsonEncode(bodyMap);

      log("Charge Card Request: URL: $url, Headers: $headers, Body: $body");

      final response = await http.post(url, headers: headers, body: body);
      final Map<String, dynamic> responseBody = jsonDecode(response.body);
      log("Charge Card Response: ${response.statusCode}, ${response.body}");

      if (response.statusCode == 200) {
        log('Card charged successfully');
        return {
          'vendorUrl': responseBody['vendorUrl'] ?? '',
          'transaction_id': transactionId,
          'customerId': customerId,
        };
      } else {
        log('Failed to charge card: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      log('Error charging card: $e');
      return null;
    }
  }

  Future<List<CardModel>> getSavedCards(String customerId) async {
    if (customerId.isEmpty) {
      return [];
    }

    final url = Uri.parse('$apiUrl/public-customers/$customerId/tokens');
    final headers = {
      'Accept': 'application/json',
      'Authorization': apiKey,
    };

    try {
      log('Fetching cards for customer: $customerId');
      final response = await http.get(url, headers: headers);

      log('Cards API Response: ${response.statusCode}, ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = jsonDecode(response.body);
        final List<dynamic> items = responseBody['items'] ?? [];

        List<CardModel> cards = items
            .where((item) {
              final isDeleted = item['deleted'] == true;
              final hasValidToken =
                  item['token'] != null && (item['token'] as String).isNotEmpty;
              final hasValidCardNumber = item['paddedCardNumber'] != null &&
                  (item['paddedCardNumber'] as String).isNotEmpty;

              return !isDeleted && hasValidToken && hasValidCardNumber;
            })
            .map((item) => CardModel.fromJson(item))
            .toList();

        return cards;
      } else {
        log('Failed to fetch cards: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      log('Error fetching saved cards: $e');
      return [];
    }
  }

  Future<bool> deleteCard(String customerId, String tokenId) async {
    if (customerId.isEmpty || tokenId.isEmpty) {
      log('Customer ID or Token ID is empty');
      return false;
    }

    final url =
        Uri.parse('$apiUrl/public-customers/$customerId/tokens/$tokenId');
    final headers = {
      'Accept': 'application/json',
      'Authorization': apiKey,
    };

    try {
      log('Deleting card: $tokenId for customer: $customerId');
      final response = await http.delete(url, headers: headers);

      log('Delete Card API Response: ${response.statusCode}, ${response.body}');

      if (response.statusCode == 204) {
        log('Card deleted successfully');
        return true;
      } else if (response.statusCode == 404) {
        log('Card not found: $tokenId');
        return false;
      } else {
        log('Failed to delete card: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      log('Error deleting card: $e');
      return false;
    }
  }
}

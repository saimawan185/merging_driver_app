import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Trans;

import '../models/language_model.dart';
import '../themes/theme_controller.dart';
import '../utils/preferences.dart';

/// Bridges language changes with easy_localization + GetX.
class LocalizationService {
  static const supportedCodes = {'en', 'si', 'ta'};

  /// Normalize Firestore / prefs slugs to asset language codes.
  static String normalizeLang(String? lang) {
    final code = (lang ?? 'en').trim().toLowerCase();
    if (supportedCodes.contains(code)) return code;
    if (code.startsWith('si') || code.contains('sinhala')) return 'si';
    if (code.startsWith('ta') || code.contains('tamil')) return 'ta';
    if (code.startsWith('en') || code.contains('english')) return 'en';
    return 'en';
  }

  Future<void> changeLocale(BuildContext context, String lang) async {
    final code = normalizeLang(lang);
    final locale = Locale(code);

    await context.setLocale(locale);
    Get.updateLocale(locale);

    if (Get.isRegistered<ThemeController>()) {
      Get.find<ThemeController>().setLocaleCode(code);
    }

    final model = LanguageModel(
      slug: code,
      isRtl: false,
      title: code == 'si'
          ? 'Sinhala'
          : code == 'ta'
              ? 'Tamil'
              : 'English',
      isActive: true,
    );
    await Preferences.setString(
      Preferences.languageCodeKey,
      jsonEncode(model.toJson()),
    );
    await Preferences.setString('languageCode', code);
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Trans;

import '../utils/preferences.dart';

class ThemeController extends GetxController {
  RxBool isDark = false.obs;

  /// Bumped when language changes so Obx UIs rebuild without remounting the app.
  RxString localeCode = 'en'.obs;

  @override
  void onInit() {
    super.onInit();
    loadTheme();
    final saved = Preferences.getString('languageCode', defaultValue: '');
    if (saved.isNotEmpty) {
      localeCode.value = saved;
    }
  }

  void loadTheme() {
    try {
      isDark.value = Preferences.getBoolean(Preferences.themKey);
    } catch (e) {
      Preferences.setBoolean(Preferences.themKey, false);
    }
  }

  void toggleTheme() {
    isDark.value = !isDark.value;
    Preferences.setBoolean(Preferences.themKey, isDark.value);
  }

  void setLocaleCode(String code) {
    localeCode.value = code;
  }

  ThemeMode get themeMode => isDark.value ? ThemeMode.dark : ThemeMode.light;
}

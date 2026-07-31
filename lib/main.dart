import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/instance_manager.dart';
import 'package:get/route_manager.dart';
import 'package:get/state_manager.dart';
import 'package:in_app_update/in_app_update.dart';
import 'app/splash_screen.dart';
import 'constant/constant.dart';
import 'controllers/global_setting_controller.dart';
import 'firebase_options.dart';
import 'models/language_model.dart';
import 'services/audio_player_service.dart';
import 'services/localization_service.dart';
import 'theme/app_them_data.dart';
import 'themes/easy_loading_config.dart';
import 'themes/theme_controller.dart';
import 'userPrefrence.dart';
import 'utils/fire_store_utils.dart';
import 'utils/preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseApp firebaseApp = await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (currentEnv == FirebaseEnv.defaultDb) {
    FireStoreUtils.instance.init(firebaseApp);
  } else {
    FireStoreUtils.instance.init(firebaseApp, databaseId: 'staging');
  }
  await Future.wait([
    EasyLocalization.ensureInitialized(),
    Preferences.initPref(),
  ]);
  Get.put(ThemeController());

  await Future.wait([
    FirebaseAppCheck.instance.activate(
      webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'),
      androidProvider: AndroidProvider.playIntegrity,
      appleProvider: AppleProvider.appAttest,
    ),
    UserPreference.init(),
    AudioPlayerService.initAudio(),
    configEasyLoading(),
  ]);

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ta'), Locale('si')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      saveLocale: true,
      useOnlyLangCode: true,
      useFallbackTranslations: true,
      child: MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => MyAppState();
}

class MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final themeController = Get.find<ThemeController>();

  Future<void> checkForUpdate() async {
    try {
      if (Platform.isAndroid) {
        final FirebaseRemoteConfig remoteConfig = FirebaseRemoteConfig.instance;

        await remoteConfig.setDefaults(<String, dynamic>{
          'driverForceUpdate': false,
        });
        await remoteConfig.setConfigSettings(
          RemoteConfigSettings(
            fetchTimeout: const Duration(seconds: 10),
            minimumFetchInterval: const Duration(seconds: 10),
          ),
        );
        await remoteConfig.fetchAndActivate();
        bool forceUpdate = remoteConfig.getBool('driverForceUpdate');

        if (forceUpdate) {
          AppUpdateInfo info = await InAppUpdate.checkForUpdate();

          if (info.updateAvailability == UpdateAvailability.updateAvailable) {
            await InAppUpdate.performImmediateUpdate().catchError((e) {
              return AppUpdateResult.inAppUpdateFailed;
            });
          }
        }
      }
    } catch (e) {
      log("Error checking for update: $e");
    }
  }

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefsCode = Preferences.getString('languageCode', defaultValue: '');
      String code;
      if (prefsCode.isNotEmpty) {
        code = LocalizationService.normalizeLang(prefsCode);
      } else if (Preferences.getString(
        Preferences.languageCodeKey,
      ).toString().isNotEmpty) {
        code = LocalizationService.normalizeLang(
          Constant.getLanguage().slug.toString(),
        );
      } else {
        code = LocalizationService.normalizeLang(context.locale.languageCode);
      }

      if (context.locale.languageCode != code) {
        await LocalizationService().changeLocale(context, code);
      } else {
        // Keep Preferences.languageCodeKey in sync with the active locale.
        await Preferences.setString(
          Preferences.languageCodeKey,
          jsonEncode(
            LanguageModel(
              slug: code,
              isRtl: false,
              title: code == 'si'
                  ? 'Sinhala'
                  : code == 'ta'
                      ? 'Tamil'
                      : 'English',
              isActive: true,
            ).toJson(),
          ),
        );
      }
    });
    checkForUpdate();

    super.initState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.paused) {
      AudioPlayerService.initAudio();
    }
  }

  @override
  Widget build(BuildContext context) {
    Get.put(ThemeController());
    return Obx(() {
      // Watch locale so translations refresh without remounting GetMaterialApp.
      final _ = themeController.localeCode.value;
      return GetMaterialApp(
        title: 'Driver'.tr(),
        localizationsDelegates: context.localizationDelegates,
        locale: context.locale,
        supportedLocales: context.supportedLocales,
        debugShowCheckedModeBanner: false,
        themeMode: themeController.themeMode,
        theme: ThemeData(
          scaffoldBackgroundColor: AppThemeData.surface,
          textTheme: TextTheme(
            bodyLarge: TextStyle(color: AppThemeData.grey900),
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: AppThemeData.surface,
            foregroundColor: AppThemeData.grey900,
            iconTheme: IconThemeData(color: AppThemeData.grey900),
          ),
        ),
        darkTheme: ThemeData(
          scaffoldBackgroundColor: AppThemeData.surfaceDark,
          textTheme: TextTheme(
            bodyLarge: TextStyle(color: AppThemeData.greyDark900),
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: AppThemeData.surfaceDark,
            foregroundColor: AppThemeData.greyDark900,
            iconTheme: IconThemeData(color: AppThemeData.greyDark900),
          ),
        ),
        builder: (context, child) {
          return SafeArea(
            bottom: true,
            top: false,
            child: EasyLoading.init()(context, child),
          );
        },
        home: GetBuilder<GlobalSettingController>(
          init: GlobalSettingController(),
          builder: (context) {
            return const SplashScreen();
          },
        ),
      );
    });
  }
}

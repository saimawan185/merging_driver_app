import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:door_delights_driver/CabService/dashboard_cab_service.dart';
import 'package:door_delights_driver/Parcel_service/parcel_service_dashboard.dart';
import 'package:door_delights_driver/constants.dart';
import 'package:door_delights_driver/firebase_options.dart';
import 'package:door_delights_driver/model/mail_setting.dart';
import 'package:door_delights_driver/rental_service/rental_service_dashboard.dart';
import 'package:door_delights_driver/services/FirebaseHelper.dart';
import 'package:door_delights_driver/services/helper.dart';
import 'package:door_delights_driver/services/notification_service.dart';
import 'package:door_delights_driver/ui/auth/AuthScreen.dart';
import 'package:door_delights_driver/ui/container/ContainerScreen.dart';
import 'package:door_delights_driver/ui/onBoarding/OnBoardingScreen.dart';
import 'package:door_delights_driver/userPrefrence.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'model/User.dart';
import 'ui/Language/language_model.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseAppCheck.instance.activate(
    webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'),
    androidProvider: AndroidProvider.playIntegrity,
    appleProvider: AppleProvider.appAttest,
  );
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await UserPreference.init();

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
  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey(
    debugLabel: 'Main Navigator',
  );

  static User? currentUser;

  NotificationService notificationService = NotificationService();

  static AudioPlayer audioPlayer = AudioPlayer(playerId: "playerId");

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    audioPlayer.stop();
    print("0000000000--------->${MyAppState.audioPlayer.state}");
  }

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

  notificationInit() {
    notificationService.initInfo().then((value) async {
      String token = await NotificationService.getToken();
      if (currentUser != null) {
        await FireStoreUtils.getCurrentUser(currentUser!.userID).then((value) {
          if (value != null) {
            currentUser = value;
            currentUser!.fcmToken = token;
            print("Hello ");
            FireStoreUtils.updateCurrentUser(currentUser!);
          }
        });
      }
    });
  }

  // Define an async function to initialize FlutterFire
  void initializeFlutterFire() async {
    try {
      await FirebaseFirestore.instance
          .collection(Setting)
          .doc("globalSettings")
          .get()
          .then((dineinresult) {
            if (dineinresult.exists &&
                dineinresult.data() != null &&
                dineinresult.data()!.containsKey("website_color")) {
              COLOR_PRIMARY = int.parse(
                dineinresult.data()!["website_color"].replaceFirst("#", "0xff"),
              );
            }
          });

      await FirebaseFirestore.instance
          .collection(Setting)
          .doc("Version")
          .get()
          .then((value) {
            print(value.data());
            appVersion = value.data()!['app_version'].toString();
          });
      await FirebaseFirestore.instance
          .collection(Setting)
          .doc("emailSetting")
          .get()
          .then((value) {
            if (value.exists) {
              mailSettings = MailSettings.fromJson(value.data()!);
            }
          });
      await FirebaseFirestore.instance
          .collection(Setting)
          .doc("googleMapKey")
          .get()
          .then((value) {
            GOOGLE_API_KEY = value.data()!['driverAppKey'].toString();
          });

      await FirebaseFirestore.instance
          .collection(Setting)
          .doc("serverKey")
          .get()
          .then((value) {
            print(value.data());
            SERVER_KEY = value.data()!['serverKey'].toString();
          });

      await FireStoreUtils().getplaceholderimage();
      await FireStoreUtils.getDriverOrderSetting();
    } catch (e) {}
  }

  setUpToken() async {
    if (MyAppState.currentUser != null) {
      await FireStoreUtils.firebaseMessaging.getToken().then((value) {
        MyAppState.currentUser!.fcmToken = value!;
        FireStoreUtils.updateCurrentUser(currentUser!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      navigatorKey: notificationService.navigatorKey,
      localizationsDelegates: context.localizationDelegates,
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      title: 'DoorDelights Driver App'.tr(),
      builder: EasyLoading.init(),
      theme: ThemeData(
        appBarTheme: AppBarTheme(
          centerTitle: true,
          color: Colors.transparent,
          elevation: 0,
          actionsIconTheme: IconThemeData(color: Color(COLOR_PRIMARY)),
          iconTheme: IconThemeData(color: Color(COLOR_PRIMARY)),
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          toolbarTextStyle: TextTheme(
            titleLarge: TextStyle(
              color: Colors.black,
              fontSize: 17.0,
              letterSpacing: 0,
              fontWeight: FontWeight.w700,
            ),
          ).bodyMedium,
          titleTextStyle: TextTheme(
            titleLarge: TextStyle(
              color: Colors.black,
              fontSize: 17.0,
              letterSpacing: 0,
              fontWeight: FontWeight.w700,
            ),
          ).titleLarge,
        ),
        bottomSheetTheme: BottomSheetThemeData(backgroundColor: Colors.white),
        primaryColor: Color(COLOR_PRIMARY),
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        appBarTheme: AppBarTheme(
          centerTitle: true,
          color: Colors.transparent,
          elevation: 0,
          actionsIconTheme: IconThemeData(color: Color(COLOR_PRIMARY)),
          iconTheme: IconThemeData(color: Color(COLOR_PRIMARY)),
          toolbarTextStyle: TextTheme(
            titleLarge: TextStyle(
              color: Colors.grey[200],
              fontSize: 17.0,
              letterSpacing: 0,
              fontWeight: FontWeight.w700,
            ),
          ).bodyMedium,
          titleTextStyle: TextTheme(
            titleLarge: TextStyle(
              color: Colors.grey[200],
              fontSize: 17.0,
              letterSpacing: 0,
              fontWeight: FontWeight.w700,
            ),
          ).titleLarge,
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: Colors.grey.shade900,
        ),
        primaryColor: Color(COLOR_PRIMARY),
        brightness: Brightness.dark,
      ),
      debugShowCheckedModeBanner: false,
      color: Color(COLOR_PRIMARY),
      home: OnBoarding(),
    );
  }

  @override
  void initState() {
    notificationInit();
    initializeFlutterFire();
    WidgetsBinding.instance.addObserver(this);
    setUpToken();

    checkForUpdate();

    super.initState();
  }

  @override
  void dispose() {
    MyAppState.audioPlayer.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /*  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (auth.FirebaseAuth.instance.currentUser != null && currentUser != null) {
      await FireStoreUtils.getCurrentUser(MyAppState.currentUser!.userID).then((value) {
        MyAppState.currentUser = value;
        if (state == AppLifecycleState.paused) {
          //user offline
          MyAppState.currentUser!.lastOnlineTimestamp = Timestamp.now();
          if (MyAppState.currentUser!.inProgressOrderID != null) {
            MyAppState.currentUser!.isActive = false;
          } else {
            MyAppState.currentUser!.isActive = MyAppState.currentUser!.isActive == true ? false : true;
          }
          FireStoreUtils.updateCurrentUser(MyAppState.currentUser!);
        } else if (state == AppLifecycleState.resumed) {
          //user online
          if (MyAppState.currentUser!.inProgressOrderID != null) {
            MyAppState.currentUser!.isActive = false;
          } else {
            MyAppState.currentUser!.isActive = MyAppState.currentUser!.isActive == false ? true : false;
          }
          FireStoreUtils.updateCurrentUser(MyAppState.currentUser!);
        }
      });
    }
  }*/
}

class OnBoarding extends StatefulWidget {
  @override
  State createState() {
    return OnBoardingState();
  }
}

class OnBoardingState extends State<OnBoarding> {
  String selectedLanguage = "en";

  var languageList = <LanguageModel>[];

  Future hasFinishedOnBoarding() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool finishedOnBoarding = (prefs.getBool(FINISHED_ON_BOARDING) ?? false);

    if (finishedOnBoarding) {
      auth.User? firebaseUser = auth.FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        User? user = await FireStoreUtils.getCurrentUser(firebaseUser.uid);
        if (user != null && user.role == USER_ROLE_DRIVER) {
          if (user.active) {
            user.isActive = true;
            user.role = USER_ROLE_DRIVER;
            try {
              user.fcmToken =
                  await FireStoreUtils.firebaseMessaging.getToken() ?? '';
            } catch (e) {
              user.fcmToken = '';
            }

            await FireStoreUtils.updateCurrentUser(user);
            MyAppState.currentUser = user;
            if (user.serviceType == "cab-service") {
              pushAndRemoveUntil(
                context,
                DashBoardCabService(user: user),
                false,
              );
            } else if (user.serviceType == "parcel_delivery") {
              pushAndRemoveUntil(
                context,
                ParcelServiceDashBoard(user: user),
                false,
              );
            } else if (user.serviceType == "rental-service") {
              pushAndRemoveUntil(
                context,
                RentalServiceDashBoard(user: user),
                false,
              );
            } else {
              pushAndRemoveUntil(context, ContainerScreen(user: user), false);
            }
          } else {
            user.isActive = false;
            user.lastOnlineTimestamp = Timestamp.now();
            await FireStoreUtils.updateCurrentUser(user);
            await auth.FirebaseAuth.instance.signOut();
            MyAppState.currentUser = null;
            pushAndRemoveUntil(context, AuthScreen(), false);
          }
        } else {
          pushReplacement(context, AuthScreen());
        }
      } else {
        pushReplacement(context, AuthScreen());
      }
    } else {
      pushReplacement(context, OnBoardingScreen());
    }
  }

  void loadLanguageData() async {
    try {
      SharedPreferences sp = await SharedPreferences.getInstance();

      bool selectLanguage = sp.getBool('selectLanguage') ?? false;
      if (selectLanguage) {
        hasFinishedOnBoarding();
        return;
      }
      languageList.clear();
      await FireStoreUtils.firestore
          .collection(Setting)
          .doc("languages")
          .get()
          .then((value) {
            List list = value.data()!["list"];
            for (int i = 0; i < list.length; i++) {
              if (list[i]['isActive'] == true) {
                LanguageModel languageModel = LanguageModel.fromJson(list[i]);
                languageList.add(languageModel);
              }
            }
            selectLanguageBottomSheet();
          });
      if (sp.containsKey("languageCode")) {
        selectedLanguage = sp.getString("languageCode")!;
      }
    } catch (e) {
      languageList = [
        LanguageModel(
          isRtl: false,
          slug: 'en',
          title: 'English',
          isActive: true,
          flag:
              'https://firebasestorage.googleapis.com/v0/b/emart-8d99f.appspot.com/o/images%2Fimages%20(3)_1706875344002.png?alt=media&token=8ec60cd5-fc30-4f82-85eb-b4e038329a1c',
        ),
        LanguageModel(
          isRtl: false,
          slug: 'ta',
          title: 'සිංහල',
          isActive: true,
          flag:
              'https://firebasestorage.googleapis.com/v0/b/doordelights-423407.appspot.com/o/images%2FIMG_7438_1732042913911.png?alt=media&token=3ba39936-e872-4e94-a5f6-557e177a94a2',
        ),
        LanguageModel(
          isRtl: false,
          slug: 'si',
          title: 'தமிழ்',
          isActive: true,
          flag:
              'https://firebasestorage.googleapis.com/v0/b/doordelights-423407.appspot.com/o/images%2FIMG_7438_1732042977553.png?alt=media&token=a1d224cd-4000-4f5c-be7a-f3b4e1afd3fb',
        ),
      ];

      selectLanguageBottomSheet();

      SharedPreferences sp = await SharedPreferences.getInstance();
      if (sp.containsKey("languageCode")) {
        selectedLanguage = sp.getString("languageCode")!;
      }
    }
  }

  selectLanguageBottomSheet() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    preferences.setBool('selectLanguage', true);

    await showCupertinoModalPopup(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return CupertinoActionSheet(
          title: Text(
            'Select your language',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          actions: languageList.map((lang) {
            return CupertinoActionSheetAction(
              onPressed: () async {
                selectedLanguage = lang.slug.toString();
                SharedPreferences sp = await SharedPreferences.getInstance();
                sp.setString("languageCode", selectedLanguage);
                await context.setLocale(Locale(selectedLanguage));

                Navigator.pop(context);
                if (mounted) {
                  setState(() {});
                }
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  lang.flag != null
                      ? Image.network(
                          lang.flag.toString(),
                          height: 30,
                          width: 30,
                        )
                      : Image.network(placeholderImage, height: 30, width: 30),
                  const SizedBox(width: 8),
                  Text(
                    lang.title.toString(),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );

    hasFinishedOnBoarding();
  }

  @override
  void initState() {
    super.initState();
    loadLanguageData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: CircularProgressIndicator.adaptive(
          valueColor: AlwaysStoppedAnimation(Color(COLOR_PRIMARY)),
        ),
      ),
    );
  }
}

Future<dynamic> backgroundMessageHandler(RemoteMessage remoteMessage) async {
  Map<dynamic, dynamic> message = remoteMessage.data;
  if (message.containsKey('data')) {
    // Handle data message
    print('backgroundMessageHandler message.containsKey(data)');
  }

  if (message.containsKey('notification')) {
    // Handle notification message
  }
}

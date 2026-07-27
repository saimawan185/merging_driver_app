import 'package:cached_network_image/cached_network_image.dart';
import 'package:door_delights_driver/services/localization_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:door_delights_driver/constants.dart';
import 'package:door_delights_driver/services/FirebaseHelper.dart';
import 'package:door_delights_driver/services/helper.dart';
import 'package:flutter/material.dart';
import 'package:get/instance_manager.dart';
import 'package:get/state_manager.dart';
import '../../models/language_model.dart';
import '../../themes/theme_controller.dart';

class LanguageChooseScreen extends StatefulWidget {
  final bool isContainer;

  LanguageChooseScreen({Key? key, required this.isContainer}) : super(key: key);

  @override
  State<LanguageChooseScreen> createState() => _LanguageChooceScreenState();
}

class _LanguageChooceScreenState extends State<LanguageChooseScreen> {
  var languageList = <LanguageModel>[];
  String selectedLanguage = "en";

  @override
  void initState() {
    loadData();
    super.initState();
  }

  void loadData() async {
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
          final code =
              LocalizationService.normalizeLang(languageModel.slug.toString());
          // Only keep languages we ship translation files for.
          if (LocalizationService.supportedCodes.contains(code)) {
            languageModel.slug = code;
            languageList.add(languageModel);
          }
        }
      }
    });

    if (!mounted) return;
    selectedLanguage = LocalizationService.normalizeLang(
      context.locale.languageCode,
    );
    setState(() {});
  }

  final themeController = Get.find<ThemeController>();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ListView.builder(
            itemCount: languageList.length,
            shrinkWrap: true,
            itemBuilder: (context, index) {
              return InkWell(
                onTap: () {
                  setState(() {
                    selectedLanguage = LocalizationService.normalizeLang(
                      languageList[index].slug.toString(),
                    );
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Container(
                    decoration: languageList[index].slug == selectedLanguage
                        ? BoxDecoration(
                            border: Border.all(color: Color(COLOR_PRIMARY)),
                            borderRadius:
                                const BorderRadius.all(Radius.circular(5.0)),
                          )
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          languageList[index].flag != null
                              ? Image.network(
                                  languageList[index].flag.toString(),
                                  height: 60,
                                  width: 60,
                                )
                              : CachedNetworkImage(
                                  imageUrl: placeholderImage,
                                  height: 60,
                                  width: 60,
                                ),
                          Padding(
                            padding: const EdgeInsets.only(left: 10, right: 10),
                            child: Obx(() {
                              final isDark = themeController.isDark.value;
                              return Text(languageList[index].title.toString(),
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: isDark ? Colors.white : Colors.black,
                                  ));
                            }),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.all(20.0),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(COLOR_PRIMARY),
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
                side: BorderSide(
                  color: Color(COLOR_PRIMARY),
                ),
              ),
            ),
            onPressed: () async {
              await LocalizationService().changeLocale(
                context,
                selectedLanguage,
              );

              if (!mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Language change successfully'.tr(),
                    style: const TextStyle(color: Colors.white),
                  ),
                  duration: const Duration(seconds: 2),
                  backgroundColor: Colors.black,
                ),
              );

              setState(() {});
            },
            child: Text(
              'Save'.tr(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode(context) ? Colors.white : Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

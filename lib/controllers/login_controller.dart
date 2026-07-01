import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:door_delights_driver/app/auth_screen/signup_screen.dart';
import 'package:door_delights_driver/app/cab_screen/cab_dashboard_screen.dart';
import 'package:door_delights_driver/app/dash_board_screen/dash_board_screen.dart';
import 'package:door_delights_driver/app/owner_screen/owner_dashboard_screen.dart';
import 'package:door_delights_driver/app/parcel_screen/parcel_dashboard_screen.dart';
import 'package:door_delights_driver/app/rental_service/rental_dashboard_screen.dart';
import 'package:door_delights_driver/constant/constant.dart';
import 'package:door_delights_driver/constant/show_toast_dialog.dart';
import 'package:door_delights_driver/models/user_model.dart';
import 'package:door_delights_driver/utils/fire_store_utils.dart';
import 'package:door_delights_driver/utils/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
// import 'package:google_sign_in/google_sign_in.dart';

class LoginController extends GetxController {
  Rx<TextEditingController> emailEditingController =
      TextEditingController().obs;
  Rx<TextEditingController> passwordEditingController =
      TextEditingController().obs;

  RxBool passwordVisible = true.obs;

  @override
  void onInit() {
    super.onInit();
  }

  Future<void> loginWithEmailAndPassword() async {
    ShowToastDialog.showLoader("Please wait".tr);
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailEditingController.value.text.toLowerCase().trim(),
        password: passwordEditingController.value.text.trim(),
      );
      UserModel? userModel =
          await FireStoreUtils.getUserProfile(credential.user!.uid);
      if (userModel?.role == Constant.userRoleDriver) {
        if (userModel?.active == true) {
          userModel?.fcmToken = await NotificationService.getToken();
          await FireStoreUtils.updateUser(userModel!);
          if (Constant.autoApproveDriver == true) {
            _navigateByUserModel(userModel);
          }
        } else {
          await FirebaseAuth.instance.signOut();
          ShowToastDialog.showToast(
              "This user is disable please contact to administrator".tr);
        }
      } else {
        await FirebaseAuth.instance.signOut();
        ShowToastDialog.showToast(
            "This user is not created in driver application.".tr);
      }
    } on FirebaseAuthException catch (e) {
      print(e.code);
      if (e.code == 'user-not-found') {
        ShowToastDialog.showToast("No user found for that email.".tr);
      } else if (e.code == 'wrong-password') {
        ShowToastDialog.showToast("Wrong password provided for that user.".tr);
      } else if (e.code == 'invalid-email') {
        ShowToastDialog.showToast("Invalid Email.".tr);
      }
    }
    ShowToastDialog.closeLoader();
  }

  Future<void> loginWithGoogle() async {
    ShowToastDialog.showLoader("Please wait".tr);
    await signInWithGoogle().then((value) async {
      ShowToastDialog.closeLoader();
      if (value != null) {
        if (value.additionalUserInfo!.isNewUser) {
          UserModel userModel = UserModel();
          userModel.id = value.user!.uid;
          userModel.email = value.user!.email;
          userModel.firstName = value.user!.displayName?.split(' ').first;
          userModel.lastName = value.user!.displayName?.split(' ').last;
          userModel.provider = 'google';

          ShowToastDialog.closeLoader();
          Get.to(const SignupScreen(), arguments: {
            "userModel": userModel,
            "type": "google",
          });
        } else {
          await FireStoreUtils.userExistOrNot(value.user!.uid)
              .then((userExit) async {
            ShowToastDialog.closeLoader();
            if (userExit == true) {
              UserModel? userModel =
                  await FireStoreUtils.getUserProfile(value.user!.uid);
              if (userModel != null &&
                  userModel.role == Constant.userRoleDriver) {
                if (userModel.active == true) {
                  userModel.fcmToken = await NotificationService.getToken();
                  await FireStoreUtils.updateUser(userModel);
                  _navigateByUserModel(userModel);
                } else {
                  await FirebaseAuth.instance.signOut();
                  ShowToastDialog.showToast(
                      "This user is disable please contact to administrator"
                          .tr);
                }
              } else {
                await FirebaseAuth.instance.signOut();
              }
            } else {
              UserModel userModel = UserModel();
              userModel.id = value.user!.uid;
              userModel.email = value.user!.email;
              userModel.firstName = value.user!.displayName?.split(' ').first;
              userModel.lastName = value.user!.displayName?.split(' ').last;
              userModel.provider = 'google';

              Get.to(const SignupScreen(), arguments: {
                "userModel": userModel,
                "type": "google",
              });
            }
          });
        }
      }
    });
  }

  Future<UserCredential?> signInWithGoogle() async {
    return null;
    // try {
    //   final GoogleSignIn googleSignIn = GoogleSignIn.instance;

    //   await googleSignIn.initialize();

    //   final GoogleSignInAccount googleUser = await googleSignIn.authenticate();
    //   if (googleUser.id.isEmpty) return null;

    //   final GoogleSignInAuthentication googleAuth = googleUser.authentication;

    //   final credential =
    //       GoogleAuthProvider.credential(idToken: googleAuth.idToken);
    //   final userCredential =
    //       await FirebaseAuth.instance.signInWithCredential(credential);

    //   return userCredential;
    // } catch (e) {
    //   print("Google Sign-In Error: $e");
    //   return null;
    // }
  }

  String sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static void _navigateByUserModel(UserModel userModel) {
    if (userModel.isOwner == true) {
      Get.offAll(OwnerDashboardScreen());
    }
    // else if ((userModel.serviceTypes?.length ?? 0) > 1) {
    //   Get.offAll(const MultiServiceDashboardScreen());
    // }
    else {
      switch (userModel.serviceType) {
        case 'cab-service':
          Get.offAll(const CabDashboardScreen());
          break;
        case 'parcel_delivery':
          Get.offAll(const ParcelDashboardScreen());
          break;
        case 'rental-service':
          Get.offAll(const RentalDashboardScreen());
          break;
        default:
          Get.offAll(const DashBoardScreen());
      }
    }
  }
}

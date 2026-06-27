import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:door_delights_driver/services/show_toast_dialog.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:door_delights_driver/constants.dart';
import 'package:door_delights_driver/main.dart';
import 'package:door_delights_driver/model/inbox_model.dart';
import 'package:door_delights_driver/services/FirebaseHelper.dart';
import 'package:door_delights_driver/services/helper.dart';
import 'package:door_delights_driver/ui/chat_screen/chat_screen.dart';
import 'package:flutterflow_paginate_firestore/paginate_firestore.dart';

import '../../constant/constant.dart';
import '../../models/user_model.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({Key? key}) : super(key: key);

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PaginateFirestore(
        //item builder type is compulsory.
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, documentSnapshots, index) {
          final data = documentSnapshots[index].data() as Map<String, dynamic>?;
          InboxModel inboxModel = InboxModel.fromJson(data!);
          return InkWell(
            onTap: () async {
              ShowToastDialog.showLoader('Please wait...'.tr());

              UserModel? customer = await FireStoreUtils.getCurrentUser(
                  inboxModel.customerId.toString());
              UserModel? driver = await FireStoreUtils.getCurrentUser(
                  inboxModel.restaurantId.toString());
              // hideProgress();
              ShowToastDialog.closeLoader();
              push(
                  context,
                  ChatScreens(
                    customerName:
                        '${(customer!.firstName ?? '') + " " + (customer.lastName ?? '')}',
                    restaurantName:
                        '${(driver!.firstName ?? '') + " " + (driver.lastName ?? '')}',
                    orderId: inboxModel.orderId,
                    restaurantId: driver.id,
                    customerId: customer.id,
                    customerProfileImage: customer.profilePictureURL,
                    restaurantProfileImage: driver.profilePictureURL,
                    token: customer.fcmToken,
                    chatType: inboxModel.chatType,
                  ));
            },
            child: ListTile(
              leading: ClipOval(
                child: CachedNetworkImage(
                    width: 50,
                    height: 50,
                    imageUrl: inboxModel.customerProfileImage.toString(),
                    imageBuilder: (context, imageProvider) => Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                              image: DecorationImage(
                            image: imageProvider,
                            fit: BoxFit.cover,
                          )),
                        ),
                    errorWidget: (context, url, error) => ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: Image.network(
                          placeholderImage,
                          fit: BoxFit.cover,
                        ))),
              ),
              title: Row(
                children: [
                  Expanded(child: Text(inboxModel.customerName.toString())),
                  Text(
                      DateFormat('MMM d, yyyy').format(
                          DateTime.fromMillisecondsSinceEpoch(
                              inboxModel.createdAt!.millisecondsSinceEpoch)),
                      style: TextStyle(color: Colors.grey, fontSize: 14)),
                ],
              ),
              subtitle: Text("Order Id : #" + inboxModel.orderId.toString()),
            ),
          );
        },
        shrinkWrap: true,
        onEmpty: Center(child: Text("No Conversion found")),
        // orderBy is compulsory to enable pagination
        query: FirebaseFirestore.instance
            .collection('chat_driver')
            .where("restaurantId", isEqualTo: Constant.userModel!.id)
            .orderBy('createdAt', descending: true),
        //Change types customerId
        itemBuilderType: PaginateBuilderType.listView,
        initialLoader: CircularProgressIndicator(),
        // to fetch real-time data
        isLive: true,
      ),
    );
  }
}

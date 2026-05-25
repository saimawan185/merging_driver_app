import 'dart:async';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PaymentURLScreen extends StatefulWidget {
  final String initialURl;
  final String? returnUrl;
  final String? transactionId;

  const PaymentURLScreen({
    Key? key,
    required this.initialURl,
    this.transactionId,
    this.returnUrl,
  }) : super(key: key);

  @override
  State<PaymentURLScreen> createState() => _PaymentURLScreenState();
}

class _PaymentURLScreenState extends State<PaymentURLScreen> {
  WebViewController controller = WebViewController();

  final CollectionReference _collection =
      FirebaseFirestore.instance.collection('temp_transactions');

  @override
  void initState() {
    createTempTransaction();
    initController();
    super.initState();
  }

  @override
  void dispose() {
    deleteTempTransaction();
    super.dispose();
  }

  createTempTransaction() async {
    log("Tra: ${widget.transactionId}");
    await _collection.doc(widget.transactionId).set({
      'transaction_id': widget.transactionId,
    });
    listenTempTransaction();
  }

  listenTempTransaction() async {
    await _collection.doc(widget.transactionId).snapshots().listen((data) {
      if (data.exists) {
        var json = data.data() as Map;
        if (json.containsKey('paymentStatus')) {
          Future.delayed(const Duration(seconds: 3), () {
            if (json['paymentStatus'].toString() == '1') {
              Navigator.pop(context, true);
            }
            {
              Navigator.pop(context, false);
            }
          });
        }
      }
    });
  }

  deleteTempTransaction() {
    Future.delayed(const Duration(milliseconds: 1500), () async {
      await _collection.doc(widget.transactionId).delete();
    });
  }

  initController() {
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {},
          onPageStarted: (String url) {},
          onWebResourceError: (WebResourceError error) {},
          onNavigationRequest: (NavigationRequest navigation) async {
            log("redirect URL: ${navigation.url}");

            if (widget.returnUrl != null) {
              if (navigation.url.contains(widget.returnUrl!)) {
                Navigator.pop(context, true);
              }
              // else {
              //     Navigator.pop(context, false);
              //   }
              // if (navigation.url.contains('/session_timeout')) {
              //   Navigator.pop(context, false);
              // }
            }
            // if (navigation.url.contains("${GlobalURL}payment/success")) {
            //   Navigator.pop(context, true);
            // }
            // if (navigation.url.contains("${GlobalURL}payment/failure") ||
            //     navigation.url.contains("${GlobalURL}payment/pending")) {
            //   Navigator.pop(context, false);
            // }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialURl));
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _showMyDialog();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
            title: const Text("Payment").tr(),
            centerTitle: false,
            leading: GestureDetector(
              onTap: () {
                _showMyDialog();
              },
              child: const Icon(
                Icons.arrow_back,
              ),
            )),
        // body: WebView(
        //   initialUrl: widget.initialURl,
        //   javascriptMode: JavascriptMode.unrestricted,
        //   gestureNavigationEnabled: true,
        //   userAgent:
        //       'Mozilla/5.0 (iPhone; CPU iPhone OS 9_3 like Mac OS X) AppleWebKit/601.1.46 (KHTML, like Gecko) Version/9.0 Mobile/13E233 Safari/601.1',
        //   onWebViewCreated: (WebViewController webViewController) {
        //     _controller.future.then((value) => controllerGlobal = value);
        //     _controller.complete(webViewController);
        //   },
        //   navigationDelegate: (navigation) async {
        //     debugPrint("--->2 ${navigation.url}");
        //     if (navigation.url.contains("${GlobalURL}payment/success")) {
        //       Navigator.pop(context, true);
        //     }
        //     if (navigation.url.contains("${GlobalURL}payment/failure") || navigation.url.contains("${GlobalURL}payment/pending")) {
        //       Navigator.pop(context, false);
        //     }
        //     return NavigationDecision.navigate;
        //   },
        // ),
        body: WebViewWidget(controller: controller),
      ),
    );
  }

  Future<void> _showMyDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cancel Payment').tr(),
          content: SingleChildScrollView(
            child: Text("Are you sure you want to cancel payment?").tr(),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'Yes',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text(
                'No',
                style: TextStyle(color: Colors.green),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}

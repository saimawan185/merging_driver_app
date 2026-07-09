import 'package:flutter/material.dart';

class Responsive {
  static double width(double size, BuildContext context) {
    return MediaQuery.sizeOf(context).width * (size / 100);
  }

  static double height(double size, BuildContext context) {
    return MediaQuery.sizeOf(context).height * (size / 100);
  }
}

import 'package:flutter/material.dart';

class Responsive {
  static width(double size, BuildContext context) {
    return MediaQuery.sizeOf(context).width * (size / 100);
  }

  static height(double size, BuildContext context) {
    return MediaQuery.sizeOf(context).height * (size / 100);
  }
}

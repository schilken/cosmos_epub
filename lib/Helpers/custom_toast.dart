import 'package:flutter/material.dart';

class CustomToast {
  static void showToast(String text) {
    // fluttertoast removed for macOS compatibility; no-op without a context.
    // Use the Snack() helper when a BuildContext is available.
  }
}

Snack(String msg, BuildContext ctx, Color color) {
  var snackBar = SnackBar(
      backgroundColor: color,
      content: Text(
        msg,
        textAlign: TextAlign.center,
      ));
  ScaffoldMessenger.of(ctx).showSnackBar(snackBar);
}

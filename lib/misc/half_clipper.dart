import 'package:flutter/material.dart';

class HalfClipper extends CustomClipper<Rect> {
  final bool rightHalf;

  HalfClipper({required this.rightHalf});

  @override
  Rect getClip(Size size) {
    if (rightHalf) {
      return Rect.fromLTRB(size.width / 2, 0, size.width, size.height);
    } else {
      return Rect.fromLTRB(0, 0, size.width / 2, size.height);
    }
  }

  @override
  bool shouldReclip(CustomClipper<Rect> oldClipper) => true;
}

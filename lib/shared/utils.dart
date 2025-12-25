import 'package:flutter/material.dart';

Widget buildSeatsLeftText(int seatsLeft) {
  return Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: seatsLeft == 0 ? 'No' : '$seatsLeft',
        ),
        TextSpan(
          text: seatsLeft == 1 ? ' seat left' : ' seats left',
        ),
      ],
    ),
    maxLines: 1,
    overflow: TextOverflow.fade,
  );
}

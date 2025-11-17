import 'package:flutter/material.dart';

Widget buildSeatsLeftText(int seatsLeft) {
  return Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: seatsLeft == 0 ? 'No' : '$seatsLeft',
        ),
        const TextSpan(
          text: ' seats left',
        ),
      ],
    ),
    maxLines: 1,
    overflow: TextOverflow.fade,
  );
}

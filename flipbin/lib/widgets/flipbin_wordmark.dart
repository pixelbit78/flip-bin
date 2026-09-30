import 'package:flutter/material.dart';

/// Option B in-app wordmark: two-tone Flip|Bin.
///
/// "Flip" uses [flipColor] (default white for dark theme);
/// "Bin" is always brand primary `#2196F3`.
class FlipBinWordmark extends StatelessWidget {
  const FlipBinWordmark({
    super.key,
    this.fontSize = 24,
    this.fontWeight = FontWeight.w700,
    this.letterSpacing = -0.2,
    this.flipColor = Colors.white,
    this.binColor = const Color(0xFF2196F3),
  });

  final double fontSize;
  final FontWeight fontWeight;
  final double letterSpacing;
  final Color flipColor;
  final Color binColor;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontWeight: fontWeight,
      fontSize: fontSize,
      letterSpacing: letterSpacing,
      height: 1.0,
    );
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: 'Flip', style: TextStyle(color: flipColor)),
          TextSpan(text: 'Bin', style: TextStyle(color: binColor)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.visible,
      softWrap: false,
    );
  }
}

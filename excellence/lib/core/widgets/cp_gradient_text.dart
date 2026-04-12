import 'package:flutter/material.dart';

/// Gradient text using ShaderMask.
/// Wraps any Text widget to render it with a gradient fill.
class CPGradientText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Gradient gradient;
  final TextAlign? textAlign;

  const CPGradientText({
    super.key,
    required this.text,
    required this.style,
    required this.gradient,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(
        text,
        style: style,
        textAlign: textAlign,
      ),
    );
  }
}

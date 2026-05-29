import 'package:flutter/material.dart';

import '../layout/scada_style.dart';

class ScadaGradient extends StatelessWidget {
  final Widget child;

  const ScadaGradient({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: ScadaStyle.gradient),
      child: child,
    );
  }
}

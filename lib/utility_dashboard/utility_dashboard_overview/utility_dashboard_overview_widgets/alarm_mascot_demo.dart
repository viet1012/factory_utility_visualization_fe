// import 'package:flutter/material.dart';
//
// enum MascotMood { happy, angry }
//
// class AlarmMascotCard extends StatefulWidget {
//   final int alarmCount;
//   final double alertPulse;
//
//   const AlarmMascotCard({
//     super.key,
//     required this.alarmCount,
//     required this.alertPulse,
//   });
//
//   @override
//   State<AlarmMascotCard> createState() => _AlarmMascotCardState();
// }
//
// class _AlarmMascotCardState extends State<AlarmMascotCard>
//     with TickerProviderStateMixin {
//   late final AnimationController _idleController;
//   late final AnimationController _alarmController;
//   late final AnimationController _blinkController;
//
//   late final Animation<double> _floatY;
//   late final Animation<double> _shakeX;
//   late final Animation<double> _antennaPulse;
//   late final Animation<double> _blinkScale;
//   late final Animation<double> _eyeMoveX;
//   late final Animation<double> _eyeMoveY;
//   late final Animation<double> _angryBrow;
//   late final Animation<double> _armSwing;
//
//   bool _mini = false;
//
//   MascotMood get mood =>
//       widget.alarmCount == 0 ? MascotMood.happy : MascotMood.angry;
//
//   bool get hasAlarm => widget.alarmCount > 0;
//
//   @override
//   void initState() {
//     super.initState();
//
//     _idleController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 1700),
//     );
//
//     _alarmController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 650),
//     );
//
//     _blinkController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 1800),
//     );
//
//     _floatY = Tween<double>(begin: 0, end: -6).animate(
//       CurvedAnimation(parent: _idleController, curve: Curves.easeInOut),
//     );
//
//     _shakeX =
//         TweenSequence<double>([
//           TweenSequenceItem(tween: Tween(begin: 0, end: -3), weight: 1),
//           TweenSequenceItem(tween: Tween(begin: -3, end: 3), weight: 2),
//           TweenSequenceItem(tween: Tween(begin: 3, end: -2), weight: 2),
//           TweenSequenceItem(tween: Tween(begin: -2, end: 2), weight: 2),
//           TweenSequenceItem(tween: Tween(begin: 2, end: 0), weight: 1),
//         ]).animate(
//           CurvedAnimation(parent: _alarmController, curve: Curves.easeInOut),
//         );
//
//     _antennaPulse = Tween<double>(begin: 0.9, end: 1.18).animate(
//       CurvedAnimation(parent: _alarmController, curve: Curves.easeInOut),
//     );
//
//     _blinkScale =
//         TweenSequence<double>([
//           TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 82),
//           TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.15), weight: 6),
//           TweenSequenceItem(tween: Tween(begin: 0.15, end: 1.0), weight: 12),
//         ]).animate(
//           CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
//         );
//
//     _eyeMoveX =
//         TweenSequence<double>([
//           TweenSequenceItem(tween: Tween(begin: 0, end: -2.8), weight: 1),
//           TweenSequenceItem(tween: Tween(begin: -2.8, end: 2.8), weight: 1),
//           TweenSequenceItem(tween: Tween(begin: 2.8, end: 0), weight: 1),
//         ]).animate(
//           CurvedAnimation(parent: _alarmController, curve: Curves.easeInOut),
//         );
//
//     _eyeMoveY =
//         TweenSequence<double>([
//           TweenSequenceItem(tween: Tween(begin: 0, end: -1.2), weight: 1),
//           TweenSequenceItem(tween: Tween(begin: -1.2, end: 1.2), weight: 1),
//           TweenSequenceItem(tween: Tween(begin: 1.2, end: 0), weight: 1),
//         ]).animate(
//           CurvedAnimation(parent: _alarmController, curve: Curves.easeInOut),
//         );
//
//     _angryBrow = Tween<double>(begin: -0.08, end: 0.08).animate(
//       CurvedAnimation(parent: _alarmController, curve: Curves.easeInOut),
//     );
//
//     _armSwing = Tween<double>(begin: -0.12, end: 0.12).animate(
//       CurvedAnimation(parent: _alarmController, curve: Curves.easeInOut),
//     );
//
//     _syncAnim();
//   }
//
//   @override
//   void didUpdateWidget(covariant AlarmMascotCard oldWidget) {
//     super.didUpdateWidget(oldWidget);
//     if (oldWidget.alarmCount != widget.alarmCount) {
//       _syncAnim();
//     }
//   }
//
//   void _syncAnim() {
//     _blinkController.repeat();
//
//     if (hasAlarm) {
//       _idleController.stop();
//       _alarmController.repeat(reverse: true);
//     } else {
//       _alarmController.stop();
//       _alarmController.reset();
//       _idleController.repeat(reverse: true);
//     }
//   }
//
//   @override
//   void dispose() {
//     _idleController.dispose();
//     _alarmController.dispose();
//     _blinkController.dispose();
//     super.dispose();
//   }
//
//   Color get accentColor {
//     switch (mood) {
//       case MascotMood.happy:
//         return const Color(0xFF22C55E);
//       case MascotMood.angry:
//         return const Color(0xFFEF4444);
//     }
//   }
//
//   Color get accentSoft {
//     switch (mood) {
//       case MascotMood.happy:
//         return const Color(0xFFD1FAE5);
//       case MascotMood.angry:
//         return const Color(0xFFFEE2E2);
//     }
//   }
//
//   String get statusText {
//     switch (mood) {
//       case MascotMood.happy:
//         return 'SYSTEM OK';
//       case MascotMood.angry:
//         return 'ALARM';
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final merged = Listenable.merge([
//       _idleController,
//       _alarmController,
//       _blinkController,
//     ]);
//
//     return GestureDetector(
//       onDoubleTap: () => setState(() => _mini = !_mini),
//       child: AnimatedBuilder(
//         animation: merged,
//         builder: (_, __) {
//           final dx = hasAlarm ? _shakeX.value : 0.0;
//           final dy = hasAlarm ? 0.0 : _floatY.value;
//           final scale = hasAlarm ? 1 + widget.alertPulse * 0.045 : 1.0;
//
//           return Transform.translate(
//             offset: Offset(dx, dy),
//             child: AnimatedScale(
//               scale: _mini ? scale * 0.82 : scale,
//               duration: const Duration(milliseconds: 150),
//               child: Container(
//                 width: _mini ? 120 : 190,
//                 height: _mini ? 150 : 235,
//                 padding: const EdgeInsets.all(12),
//                 decoration: BoxDecoration(
//                   borderRadius: BorderRadius.circular(24),
//                   gradient: const LinearGradient(
//                     begin: Alignment.topLeft,
//                     end: Alignment.bottomRight,
//                     colors: [
//                       Color(0xFF0F172A),
//                       Color(0xFF1E293B),
//                       Color(0xFF0B1220),
//                     ],
//                   ),
//                   border: Border.all(
//                     color: accentColor.withOpacity(0.95),
//                     width: 2,
//                   ),
//                   boxShadow: [
//                     BoxShadow(
//                       color: accentColor.withOpacity(0.22),
//                       blurRadius: 20,
//                       spreadRadius: 2,
//                     ),
//                     BoxShadow(
//                       color: Colors.black.withOpacity(0.25),
//                       blurRadius: 16,
//                       offset: const Offset(0, 8),
//                     ),
//                   ],
//                 ),
//                 child: Stack(
//                   children: [
//                     Positioned(
//                       top: 0,
//                       left: 0,
//                       right: 0,
//                       child: _HeaderBar(
//                         statusText: statusText,
//                         accentColor: accentColor,
//                         accentSoft: accentSoft,
//                       ),
//                     ),
//                     Positioned.fill(
//                       top: 34,
//                       bottom: hasAlarm && !_mini ? 26 : 0,
//                       child: _IndustrialRobotFace(
//                         mood: mood,
//                         accentColor: accentColor,
//                         accentSoft: accentSoft,
//                         pulse: _antennaPulse.value,
//                         blinkScale: _blinkScale.value,
//                         eyeMoveX: _eyeMoveX.value,
//                         eyeMoveY: _eyeMoveY.value,
//                         angryBrow: _angryBrow.value,
//                         armSwing: _armSwing.value,
//                       ),
//                     ),
//                     if (hasAlarm && !_mini)
//                       Positioned(
//                         left: 0,
//                         right: 0,
//                         bottom: 0,
//                         child: Center(
//                           child: Container(
//                             padding: const EdgeInsets.symmetric(
//                               horizontal: 12,
//                               vertical: 5,
//                             ),
//                             decoration: BoxDecoration(
//                               color: const Color(0xFF020617),
//                               borderRadius: BorderRadius.circular(999),
//                               border: Border.all(
//                                 color: accentColor.withOpacity(0.9),
//                                 width: 1.2,
//                               ),
//                             ),
//                             child: Text(
//                               'ALARM ${widget.alarmCount}',
//                               style: TextStyle(
//                                 color: accentColor,
//                                 fontSize: 11,
//                                 fontWeight: FontWeight.w800,
//                                 letterSpacing: 0.8,
//                               ),
//                             ),
//                           ),
//                         ),
//                       ),
//                   ],
//                 ),
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }
// }
//
// class _HeaderBar extends StatelessWidget {
//   final String statusText;
//   final Color accentColor;
//   final Color accentSoft;
//
//   const _HeaderBar({
//     required this.statusText,
//     required this.accentColor,
//     required this.accentSoft,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       children: [
//         Container(
//           width: 10,
//           height: 10,
//           decoration: BoxDecoration(
//             color: accentColor,
//             shape: BoxShape.circle,
//             boxShadow: [
//               BoxShadow(color: accentColor.withOpacity(0.6), blurRadius: 8),
//             ],
//           ),
//         ),
//         const SizedBox(width: 8),
//         Expanded(
//           child: Text(
//             statusText,
//             style: TextStyle(
//               color: accentSoft,
//               fontSize: 12,
//               fontWeight: FontWeight.w800,
//               letterSpacing: 1.0,
//             ),
//           ),
//         ),
//         Container(
//           width: 34,
//           height: 6,
//           decoration: BoxDecoration(
//             color: accentColor.withOpacity(0.22),
//             borderRadius: BorderRadius.circular(99),
//           ),
//         ),
//       ],
//     );
//   }
// }
//
// class _IndustrialRobotFace extends StatelessWidget {
//   final MascotMood mood;
//   final Color accentColor;
//   final Color accentSoft;
//   final double pulse;
//   final double blinkScale;
//   final double eyeMoveX;
//   final double eyeMoveY;
//   final double angryBrow;
//   final double armSwing;
//
//   const _IndustrialRobotFace({
//     required this.mood,
//     required this.accentColor,
//     required this.accentSoft,
//     required this.pulse,
//     required this.blinkScale,
//     required this.eyeMoveX,
//     required this.eyeMoveY,
//     required this.angryBrow,
//     required this.armSwing,
//   });
//
//   bool get isHappy => mood == MascotMood.happy;
//
//   bool get isAngry => mood == MascotMood.angry;
//
//   @override
//   Widget build(BuildContext context) {
//     final eyeOuterWidth = isHappy ? 24.0 : 26.0;
//     final eyeOuterHeight = isHappy ? 14.0 : 12.0;
//
//     return Stack(
//       children: [
//         Align(
//           alignment: const Alignment(0, -0.82),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Transform.scale(
//                 scale: pulse,
//                 child: Container(
//                   width: 12,
//                   height: 12,
//                   decoration: BoxDecoration(
//                     color: accentColor,
//                     shape: BoxShape.circle,
//                     boxShadow: [
//                       BoxShadow(
//                         color: accentColor.withOpacity(0.55),
//                         blurRadius: 10,
//                         spreadRadius: 1,
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//               Container(
//                 width: 3,
//                 height: 18,
//                 color: accentColor.withOpacity(0.75),
//               ),
//             ],
//           ),
//         ),
//         Align(
//           alignment: const Alignment(0, -0.05),
//           child: Container(
//             width: 122,
//             height: 90,
//
//             decoration: BoxDecoration(
//               borderRadius: BorderRadius.circular(24),
//               gradient: const LinearGradient(
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//                 colors: [Color(0xFF334155), Color(0xFF1E293B)],
//               ),
//               border: Border.all(
//                 color: accentColor.withOpacity(0.95),
//                 width: 2,
//               ),
//               boxShadow: [
//                 BoxShadow(color: accentColor.withOpacity(0.18), blurRadius: 14),
//               ],
//             ),
//           ),
//         ),
//
//         Align(
//           alignment: const Alignment(0, 0.78),
//           child: Container(
//             width: 80,
//             height: 52,
//             decoration: BoxDecoration(
//               borderRadius: BorderRadius.circular(14),
//               gradient: const LinearGradient(
//                 begin: Alignment.topCenter,
//                 end: Alignment.bottomCenter,
//                 colors: [Color(0xFF475569), Color(0xFF1E293B)],
//               ),
//               border: Border.all(color: accentColor.withOpacity(0.7)),
//             ),
//           ),
//         ),
//
//         Align(
//           alignment: const Alignment(-0.25, -0.18),
//           child: _robotEye(
//             accentColor,
//             outerWidth: eyeOuterWidth,
//             outerHeight: eyeOuterHeight,
//           ),
//         ),
//         Align(
//           alignment: const Alignment(0.25, -0.18),
//           child: _robotEye(
//             accentColor,
//             outerWidth: eyeOuterWidth,
//             outerHeight: eyeOuterHeight,
//           ),
//         ),
//
//         if (isAngry) ...[
//           Align(
//             alignment: const Alignment(-0.24, -0.34),
//             child: Transform.rotate(angle: -0.40 + angryBrow, child: _brow()),
//           ),
//           Align(
//             alignment: const Alignment(0.24, -0.34),
//             child: Transform.rotate(angle: 0.40 - angryBrow, child: _brow()),
//           ),
//         ],
//
//         Align(alignment: const Alignment(0, 0.18), child: _mouth(accentColor)),
//
//         Align(
//           alignment: const Alignment(-0.62, 0.2),
//           child: _arm(
//             accentColor,
//             left: true,
//             swing: isHappy ? armSwing * 0.25 : armSwing,
//           ),
//         ),
//         Align(
//           alignment: const Alignment(0.62, 0.2),
//           child: _arm(
//             accentColor,
//             left: false,
//             swing: isHappy ? -armSwing * 0.25 : -armSwing,
//           ),
//         ),
//
//         Align(alignment: const Alignment(-0.22, 1.0), child: _leg(accentSoft)),
//         Align(alignment: const Alignment(0.22, 1.0), child: _leg(accentSoft)),
//       ],
//     );
//   }
//
//   Widget _robotEye(
//     Color color, {
//     required double outerWidth,
//     required double outerHeight,
//   }) {
//     final pupilDx = isHappy ? 0.0 : eyeMoveX;
//     final pupilDy = isHappy ? 0.0 : eyeMoveY;
//     final pupilSize = isHappy ? 6.0 : 7.0;
//
//     return Container(
//       width: outerWidth,
//       height: outerHeight,
//       decoration: BoxDecoration(
//         color: color.withOpacity(0.16),
//         borderRadius: BorderRadius.circular(99),
//         boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 8)],
//       ),
//       child: Center(
//         child: Transform.scale(
//           scaleY: blinkScale,
//           child: AnimatedContainer(
//             duration: const Duration(milliseconds: 120),
//             transform: Matrix4.translationValues(pupilDx, pupilDy, 0),
//             width: pupilSize,
//             height: pupilSize,
//             decoration: BoxDecoration(
//               color: color,
//               shape: BoxShape.circle,
//               boxShadow: [
//                 BoxShadow(
//                   color: color.withOpacity(isAngry ? 0.95 : 0.75),
//                   blurRadius: isAngry ? 10 : 7,
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _brow() {
//     return Container(
//       width: 24,
//       height: 3.5,
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(99),
//       ),
//     );
//   }
//
//   Widget _mouth(Color color) {
//     if (isHappy) {
//       return SizedBox(
//         width: 30,
//         height: 16,
//         child: CustomPaint(painter: _HappyMouthPainter(color)),
//       );
//     }
//
//     return SizedBox(
//       width: 30,
//       height: 16,
//       child: CustomPaint(painter: _AngryMouthPainter(color)),
//     );
//   }
// }
//
// class _HappyMouthPainter extends CustomPainter {
//   final Color color;
//
//   const _HappyMouthPainter(this.color);
//
//   @override
//   void paint(Canvas canvas, Size size) {
//     final paint = Paint()
//       ..color = color
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 2.4
//       ..strokeCap = StrokeCap.round
//       ..strokeJoin = StrokeJoin.round;
//
//     final path = Path()
//       ..moveTo(size.width * 0.20, size.height * 0.45)
//       ..quadraticBezierTo(
//         size.width * 0.50,
//         size.height * 0.80,
//         size.width * 0.80,
//         size.height * 0.45,
//       );
//     canvas.drawPath(path, paint);
//   }
//
//   @override
//   bool shouldRepaint(covariant _HappyMouthPainter oldDelegate) {
//     return oldDelegate.color != color;
//   }
// }
//
// class _AngryMouthPainter extends CustomPainter {
//   final Color color;
//
//   const _AngryMouthPainter(this.color);
//
//   @override
//   void paint(Canvas canvas, Size size) {
//     final paint = Paint()
//       ..color = color
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 2.4
//       ..strokeCap = StrokeCap.round
//       ..strokeJoin = StrokeJoin.round;
//
//     final path = Path()
//       ..moveTo(size.width * 0.16, size.height * 0.72)
//       ..quadraticBezierTo(
//         size.width * 0.50,
//         size.height * 0.16,
//         size.width * 0.84,
//         size.height * 0.72,
//       );
//
//     canvas.drawPath(path, paint);
//   }
//
//   @override
//   bool shouldRepaint(covariant _AngryMouthPainter oldDelegate) {
//     return oldDelegate.color != color;
//   }
// }
//
// Widget _arm(Color color, {required bool left, required double swing}) {
//   final baseAngle = left ? 0.16 : -0.16;
//
//   const limbColor = Color(0xFFE2E8F0);
//   const jointColor = Color(0xFFCBD5E1);
//   const borderColor = Color(0xFF94A3B8);
//
//   return Transform.rotate(
//     angle: baseAngle + swing,
//     alignment: left ? Alignment.topRight : Alignment.topLeft,
//     child: Column(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Container(
//           width: 12,
//           height: 42,
//           decoration: BoxDecoration(
//             color: limbColor,
//             borderRadius: BorderRadius.circular(999),
//             border: Border.all(
//               color: borderColor.withOpacity(0.45),
//               width: 1.1,
//             ),
//             boxShadow: const [
//               BoxShadow(
//                 color: Color(0x12000000),
//                 blurRadius: 4,
//                 offset: Offset(0, 2),
//               ),
//             ],
//           ),
//         ),
//         const SizedBox(height: 3),
//         Container(
//           width: 10,
//           height: 10,
//           decoration: BoxDecoration(
//             color: jointColor,
//             shape: BoxShape.circle,
//             border: Border.all(color: borderColor.withOpacity(0.75), width: 1),
//           ),
//         ),
//       ],
//     ),
//   );
// }
//
// Widget _leg(Color color) {
//   const limbColor = Color(0xFFE2E8F0);
//   const footColor = Color(0xFFCBD5E1);
//   const borderColor = Color(0xFF94A3B8);
//
//   return Column(
//     mainAxisSize: MainAxisSize.min,
//     children: [
//       Container(
//         width: 14,
//         height: 36,
//         decoration: BoxDecoration(
//           color: limbColor,
//           borderRadius: BorderRadius.circular(999),
//           border: Border.all(color: borderColor.withOpacity(0.45), width: 1.1),
//           boxShadow: const [
//             BoxShadow(
//               color: Color(0x12000000),
//               blurRadius: 4,
//               offset: Offset(0, 2),
//             ),
//           ],
//         ),
//       ),
//       const SizedBox(height: 4),
//       Container(
//         width: 20,
//         height: 8,
//         decoration: BoxDecoration(
//           color: footColor,
//           borderRadius: BorderRadius.circular(999),
//           border: Border.all(color: borderColor.withOpacity(0.75), width: 1),
//         ),
//       ),
//     ],
//   );
// }

import 'dart:math' as math;

import 'package:flutter/material.dart';

class VoltageMonitoringMascot extends StatefulWidget {
  final int alarmCount;
  final double size;

  const VoltageMonitoringMascot({
    super.key,
    required this.alarmCount,
    this.size = 260,
  });

  @override
  State<VoltageMonitoringMascot> createState() =>
      _VoltageMonitoringMascotState();
}

class _VoltageMonitoringMascotState extends State<VoltageMonitoringMascot>
    with TickerProviderStateMixin {
  late final AnimationController idleController;
  late final AnimationController alarmController;
  late final AnimationController blinkController;

  late final Animation<double> floatY;
  late final Animation<double> shakeX;
  late final Animation<double> antennaPulse;
  late final Animation<double> eyeTrackX;
  late final Animation<double> eyeTrackY;
  late final Animation<double> blinkScale;
  late final Animation<double> angryBrow;

  late final Animation<double> armSwing;
  late final Animation<double> legSwing;

  bool get isAlarm => widget.alarmCount > 0;

  Color get accentColor =>
      isAlarm ? const Color(0xFFEF4444) : const Color(0xFF22C55E);

  Color get bodyColor => const Color(0xFF111827);

  @override
  void initState() {
    super.initState();

    idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    alarmController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    floatY = Tween<double>(
      begin: -5,
      end: 5,
    ).animate(CurvedAnimation(parent: idleController, curve: Curves.easeInOut));

    shakeX =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0, end: -3), weight: 1),
          TweenSequenceItem(tween: Tween(begin: -3, end: 3), weight: 1),
          TweenSequenceItem(tween: Tween(begin: 3, end: -2), weight: 1),
          TweenSequenceItem(tween: Tween(begin: -2, end: 2), weight: 1),
          TweenSequenceItem(tween: Tween(begin: 2, end: 0), weight: 1),
        ]).animate(
          CurvedAnimation(parent: alarmController, curve: Curves.easeInOut),
        );

    antennaPulse = Tween<double>(begin: 1.0, end: 1.28).animate(
      CurvedAnimation(parent: alarmController, curve: Curves.easeInOut),
    );

    eyeTrackX = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -3), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -3, end: 3), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 3, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: alarmController, curve: Curves.linear));

    eyeTrackY = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -1.5), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -1.5, end: 1.5), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.5, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: alarmController, curve: Curves.linear));

    blinkScale =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 1, end: 1), weight: 86),
          TweenSequenceItem(tween: Tween(begin: 1, end: 0.08), weight: 6),
          TweenSequenceItem(tween: Tween(begin: 0.08, end: 1), weight: 8),
        ]).animate(
          CurvedAnimation(parent: blinkController, curve: Curves.easeInOut),
        );

    angryBrow = Tween<double>(begin: 0.0, end: 0.12).animate(
      CurvedAnimation(parent: alarmController, curve: Curves.easeInOut),
    );

    armSwing = Tween<double>(begin: 0.0, end: 0.22).animate(
      CurvedAnimation(parent: alarmController, curve: Curves.easeInOut),
    );

    legSwing = Tween<double>(begin: 0.0, end: 0.10).animate(
      CurvedAnimation(parent: alarmController, curve: Curves.easeInOut),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant VoltageMonitoringMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.alarmCount != widget.alarmCount) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (!blinkController.isAnimating) {
      blinkController.repeat();
    }

    if (isAlarm) {
      idleController.stop();
      idleController.reset();
      if (!alarmController.isAnimating) {
        alarmController.repeat(reverse: true);
      }
    } else {
      alarmController.stop();
      alarmController.reset();
      if (!idleController.isAnimating) {
        idleController.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    idleController.dispose();
    alarmController.dispose();
    blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final merged = Listenable.merge([
      idleController,
      alarmController,
      blinkController,
    ]);

    final robotSize = widget.size;
    final robotWidth = robotSize * 0.62;

    return AnimatedBuilder(
      animation: merged,
      builder: (_, __) {
        final dx = isAlarm ? shakeX.value : 0.0;
        final dy = isAlarm ? 0.0 : floatY.value;

        return SizedBox(
          width: robotWidth,
          height: robotSize,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Transform.translate(
                offset: Offset(dx, dy),
                child: SizedBox(
                  width: robotWidth,
                  height: robotSize,
                  child: CustomPaint(
                    painter: _RobotPainter(
                      bodyColor: bodyColor,
                      accentColor: accentColor,
                      isAlarm: isAlarm,
                      blinkScale: blinkScale.value,
                      eyeTrackX: isAlarm ? eyeTrackX.value : 0,
                      eyeTrackY: isAlarm ? eyeTrackY.value : 0,
                      antennaScale: isAlarm ? antennaPulse.value : 1.0,
                      angryBrow: isAlarm ? angryBrow.value : 0.0,
                      armSwing: isAlarm ? armSwing.value : 0.0,
                      legSwing: isAlarm ? legSwing.value : 0.0,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: -6,
                child: _StatusBadge(
                  count: widget.alarmCount,
                  isAlarm: isAlarm,
                  accentColor: accentColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final int count;
  final bool isAlarm;
  final Color accentColor;

  const _StatusBadge({
    required this.count,
    required this.isAlarm,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final label = isAlarm ? (count > 1 ? 'ALARM $count' : 'ALARM') : 'OK';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accentColor.withOpacity(0.95), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.28),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: accentColor.withOpacity(0.8), blurRadius: 6),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: accentColor,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _RobotPainter extends CustomPainter {
  final Color bodyColor;
  final Color accentColor;
  final bool isAlarm;
  final double blinkScale;
  final double eyeTrackX;
  final double eyeTrackY;
  final double antennaScale;
  final double angryBrow;
  final double armSwing;
  final double legSwing;

  const _RobotPainter({
    required this.bodyColor,
    required this.accentColor,
    required this.isAlarm,
    required this.blinkScale,
    required this.eyeTrackX,
    required this.eyeTrackY,
    required this.antennaScale,
    required this.angryBrow,
    required this.armSwing,
    required this.legSwing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final headW = w * 0.54;
    final headH = h * 0.26;
    final bodyW = w * 0.48;
    final bodyH = h * 0.26;

    final headX = (w - headW) / 2;
    final headY = h * 0.12;

    final bodyX = (w - bodyW) / 2;
    final bodyY = headY + headH + h * 0.04;

    final paintBody = Paint()..color = bodyColor;
    final paintStroke = Paint()
      ..color = accentColor.withOpacity(0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final metalPaint = Paint()..color = const Color(0xFFB8C4D6);
    final metalDark = Paint()..color = const Color(0xFF94A3B8);
    final footPaint = Paint()..color = const Color(0xFF64748B);
    final cheekPaint = Paint()
      ..color = const Color(0xFFFCA5A5).withOpacity(isAlarm ? 0.0 : 0.32);

    final antennaBaseX = w / 2;
    final antennaTopY = headY - 24;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(antennaBaseX, antennaTopY + 12),
          width: 3,
          height: 24,
        ),
        const Radius.circular(99),
      ),
      Paint()..color = accentColor.withOpacity(0.78),
    );
    canvas.save();
    canvas.translate(antennaBaseX, antennaTopY);
    canvas.scale(antennaScale, antennaScale);
    canvas.drawCircle(
      Offset.zero,
      9,
      Paint()..color = accentColor.withOpacity(0.12),
    );
    canvas.drawCircle(
      Offset.zero,
      7,
      Paint()..color = accentColor.withOpacity(0.22),
    );
    canvas.drawCircle(Offset.zero, 5, Paint()..color = accentColor);
    canvas.restore();

    _drawArm(
      canvas: canvas,
      shoulder: Offset(bodyX + 6, bodyY + 18),
      upperLen: 34,
      foreLen: 28,
      upperAngle: -2.35 + armSwing,
      foreAngle: -1.95 + armSwing * 0.7,
      limbPaint: metalPaint,
      jointPaint: metalDark,
      strokeColor: accentColor,
    );

    _drawArm(
      canvas: canvas,
      shoulder: Offset(bodyX + bodyW - 6, bodyY + 18),
      upperLen: 34,
      foreLen: 28,
      upperAngle: -0.80 - armSwing,
      foreAngle: -1.25 - armSwing * 0.7,
      limbPaint: metalPaint,
      jointPaint: metalDark,
      strokeColor: accentColor,
    );

    _drawLeg(
      canvas: canvas,
      hip: Offset(bodyX + bodyW * 0.35, bodyY + bodyH - 2),
      thighLen: 34,
      shinLen: 24,
      thighAngle: 1.56 - legSwing,
      shinAngle: 1.56 + legSwing,
      limbPaint: metalPaint,
      jointPaint: metalDark,
      footPaint: footPaint,
      left: true,
    );

    _drawLeg(
      canvas: canvas,
      hip: Offset(bodyX + bodyW * 0.65, bodyY + bodyH - 2),
      thighLen: 34,
      shinLen: 24,
      thighAngle: 1.58 + legSwing,
      shinAngle: 1.58 - legSwing,
      limbPaint: metalPaint,
      jointPaint: metalDark,
      footPaint: footPaint,
      left: false,
    );

    final headRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(headX, headY, headW, headH),
      const Radius.circular(20),
    );
    canvas.drawShadow(
      Path()..addRRect(headRect),
      accentColor.withOpacity(0.2),
      16,
      false,
    );
    canvas.drawRRect(headRect, paintBody);
    canvas.drawRRect(headRect, paintStroke);

    final visorRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(headX + 18, headY + 14, headW - 36, 10),
      const Radius.circular(99),
    );
    canvas.drawRRect(visorRect, Paint()..color = accentColor.withOpacity(0.18));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(headX + 20, headY + 16, headW - 40, 6),
        const Radius.circular(99),
      ),
      Paint()..color = accentColor,
    );

    final eyeY = headY + headH * 0.55;
    final leftEye = Offset(headX + headW * 0.36, eyeY);
    final rightEye = Offset(headX + headW * 0.64, eyeY);

    _drawEye(
      canvas,
      leftEye,
      accentColor,
      blinkScale,
      isAlarm,
      eyeTrackX,
      eyeTrackY,
    );
    _drawEye(
      canvas,
      rightEye,
      accentColor,
      blinkScale,
      isAlarm,
      eyeTrackX,
      eyeTrackY,
    );

    if (!isAlarm) {
      canvas.drawCircle(Offset(leftEye.dx - 16, leftEye.dy + 8), 7, cheekPaint);
      canvas.drawCircle(
        Offset(rightEye.dx + 16, rightEye.dy + 8),
        7,
        cheekPaint,
      );
    }

    if (isAlarm) {
      final browPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(leftEye.dx - 16, leftEye.dy - 14),
        Offset(leftEye.dx + 10, leftEye.dy - 16 - (angryBrow * 24)),
        browPaint,
      );
      canvas.drawLine(
        Offset(rightEye.dx - 10, rightEye.dy - 16 - (angryBrow * 24)),
        Offset(rightEye.dx + 16, rightEye.dy - 14),
        browPaint,
      );
    }

    _drawMouth(
      canvas: canvas,
      center: Offset(headX + headW / 2, headY + headH * 0.78),
      color: accentColor,
      sad: isAlarm,
    );

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(bodyX, bodyY, bodyW, bodyH),
      const Radius.circular(16),
    );
    canvas.drawShadow(
      Path()..addRRect(bodyRect),
      accentColor.withOpacity(0.16),
      12,
      false,
    );
    canvas.drawRRect(bodyRect, paintBody);
    canvas.drawRRect(bodyRect, paintStroke);

    canvas.drawCircle(
      Offset(bodyX + bodyW / 2, bodyY + 18),
      5,
      Paint()..color = accentColor,
    );
    canvas.drawCircle(
      Offset(bodyX + bodyW / 2, bodyY + 18),
      8,
      Paint()..color = accentColor.withOpacity(0.25),
    );
  }

  void _drawEye(
    Canvas canvas,
    Offset center,
    Color accent,
    double blink,
    bool alarm,
    double trackX,
    double trackY,
  ) {
    final outer = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 22, height: 12),
      const Radius.circular(99),
    );
    canvas.drawRRect(outer, Paint()..color = accent.withOpacity(0.14));

    canvas.save();
    canvas.translate(alarm ? trackX : 0, alarm ? trackY : 0);
    canvas.translate(center.dx, center.dy);
    canvas.scale(1, blink);

    canvas.drawCircle(
      Offset.zero,
      (alarm ? 4.5 : 5) + 4,
      Paint()..color = accent.withOpacity(0.14),
    );
    canvas.drawCircle(
      Offset.zero,
      (alarm ? 4.5 : 5) + 2,
      Paint()..color = accent.withOpacity(0.24),
    );
    canvas.drawCircle(Offset.zero, alarm ? 3.8 : 4.2, Paint()..color = accent);

    canvas.restore();
  }

  void _drawMouth({
    required Canvas canvas,
    required Offset center,
    required Color color,
    required bool sad,
  }) {
    final path = Path();
    if (sad) {
      path.moveTo(center.dx - 12, center.dy + 3);
      path.quadraticBezierTo(
        center.dx,
        center.dy - 5,
        center.dx + 12,
        center.dy + 3,
      );
    } else {
      path.moveTo(center.dx - 12, center.dy - 1);
      path.quadraticBezierTo(
        center.dx,
        center.dy + 7,
        center.dx + 12,
        center.dy - 1,
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawArm({
    required Canvas canvas,
    required Offset shoulder,
    required double upperLen,
    required double foreLen,
    required double upperAngle,
    required double foreAngle,
    required Paint limbPaint,
    required Paint jointPaint,
    required Color strokeColor,
  }) {
    final upperColor = const Color(0xFF9AA4B2);
    final foreColor = const Color(0xFF7B8794);
    final handColor = const Color(0xFF5B6572);

    final elbow = Offset(
      shoulder.dx + math.cos(upperAngle) * upperLen,
      shoulder.dy + math.sin(upperAngle) * upperLen,
    );

    final wrist = Offset(
      elbow.dx + math.cos(foreAngle) * foreLen,
      elbow.dy + math.sin(foreAngle) * foreLen,
    );

    // shoulder hub
    canvas.drawCircle(shoulder, 5, Paint()..color = const Color(0xFF626D7A));

    // upper arm
    canvas.drawLine(
      shoulder,
      elbow,
      Paint()
        ..color = upperColor
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );

    // elbow halo
    canvas.drawCircle(elbow, 8, Paint()..color = strokeColor.withOpacity(0.10));

    // elbow joint
    canvas.drawCircle(elbow, 5.5, Paint()..color = const Color(0xFF5E6875));

    // forearm
    canvas.drawLine(
      elbow,
      wrist,
      Paint()
        ..color = foreColor
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );

    // wrist
    canvas.drawCircle(wrist, 3, Paint()..color = const Color(0xFF8B97A5));

    // tiny hand pad
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(wrist.dx, wrist.dy + 2),
          width: 10,
          height: 5,
        ),
        const Radius.circular(99),
      ),
      Paint()..color = handColor,
    );
  }

  void _drawLeg({
    required Canvas canvas,
    required Offset hip,
    required double thighLen,
    required double shinLen,
    required double thighAngle,
    required double shinAngle,
    required Paint limbPaint,
    required Paint jointPaint,
    required Paint footPaint,
    required bool left,
  }) {
    final knee = Offset(
      hip.dx + math.cos(thighAngle) * thighLen,
      hip.dy + math.sin(thighAngle) * thighLen,
    );

    final ankle = Offset(
      knee.dx + math.cos(shinAngle) * shinLen,
      knee.dy + math.sin(shinAngle) * shinLen,
    );

    canvas.drawLine(
      hip,
      knee,
      Paint()
        ..color = limbPaint.color
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawLine(
      knee,
      ankle,
      Paint()
        ..color = const Color(0xFFCBD5E1)
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawCircle(knee, 6, jointPaint);

    final footRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(ankle.dx + (left ? -2 : 2), ankle.dy + 4),
        width: 22,
        height: 12,
      ),
      const Radius.circular(99),
    );
    canvas.drawRRect(footRect, footPaint);
  }

  @override
  bool shouldRepaint(covariant _RobotPainter oldDelegate) {
    return oldDelegate.bodyColor != bodyColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.isAlarm != isAlarm ||
        oldDelegate.blinkScale != blinkScale ||
        oldDelegate.eyeTrackX != eyeTrackX ||
        oldDelegate.eyeTrackY != eyeTrackY ||
        oldDelegate.antennaScale != antennaScale ||
        oldDelegate.angryBrow != angryBrow;
  }
}

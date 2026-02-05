// import 'dart:math' as math;
// import 'package:flutter/material.dart';
// import '../model/facility_data.dart';
// import '../widgets/facility_info_box.dart';
//
// class FactoryMapWithArrows extends StatefulWidget {
//   final List<FacilityData> facilities;
//   final String mainImageUrl;
//   final double screenWidth;
//   final double screenHeight;
//
//   const FactoryMapWithArrows({
//     Key? key,
//     required this.facilities,
//     required this.mainImageUrl,
//     required this.screenWidth,
//     required this.screenHeight,
//   }) : super(key: key);
//
//   @override
//   State<FactoryMapWithArrows> createState() => _FactoryMapWithArrowsState();
// }
//
// class _FactoryMapWithArrowsState extends State<FactoryMapWithArrows>
//     with TickerProviderStateMixin {
//   late AnimationController _arrowAnimationController;
//   late Animation<double> _arrowAnimation;
//
//   @override
//   void initState() {
//     super.initState();
//
//     _arrowAnimationController = AnimationController(
//       duration: const Duration(seconds: 2),
//       vsync: this,
//     )..repeat(reverse: true);
//
//     _arrowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
//       CurvedAnimation(
//         parent: _arrowAnimationController,
//         curve: Curves.easeInOut,
//       ),
//     );
//   }
//
//   @override
//   void dispose() {
//     _arrowAnimationController.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return ClipRRect(
//       borderRadius: BorderRadius.circular(16),
//       child: Stack(
//         alignment: AlignmentDirectional.center,
//         children: [
//           // Background Image
//           Image.asset(
//             widget.mainImageUrl,
//             fit: BoxFit.fill,
//             width: widget.screenWidth / 2,
//           ),
//
//           // Gradient Overlay
//           Container(
//             decoration: BoxDecoration(
//               gradient: LinearGradient(
//                 begin: Alignment.topCenter,
//                 end: Alignment.bottomCenter,
//                 colors: [
//                   Colors.black.withOpacity(0.1),
//                   Colors.transparent,
//                   Colors.black.withOpacity(0.15),
//                 ],
//               ),
//             ),
//           ),
//
//           // Animated Connection Arrows
//           AnimatedBuilder(
//             animation: _arrowAnimation,
//             builder: (context, child) {
//               return CustomPaint(
//                 painter: ConnectionArrowsPainter(
//                   facilities: widget.facilities,
//                   screenWidth: widget.screenWidth,
//                   screenHeight: widget.screenHeight,
//                   animationValue: _arrowAnimation.value,
//                 ),
//                 size: Size(widget.screenWidth / 2, double.infinity),
//               );
//             },
//           ),
//
//           // Central Hub/Node
//           _buildCentralHub(),
//
//           // Facility A
//           Positioned(
//             top: widget.screenHeight * 0.05,
//             right: widget.screenWidth * 0.7,
//             child: FacilityInfoBox(facility: widget.facilities[0]),
//           ),
//
//           // Facility B
//           Positioned(
//             top: widget.screenHeight * 0,
//             right: widget.screenWidth * 0.05,
//             child: FacilityInfoBox(facility: widget.facilities[1]),
//           ),
//
//           // Facility C
//           Positioned(
//             top: widget.screenHeight * 0.6,
//             right: widget.screenWidth * 0.17,
//             child: FacilityInfoBox(facility: widget.facilities[2]),
//           ),
//
//           // Connection Status Indicators
//           _buildConnectionStatusIndicators(),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildCentralHub() {
//     return Container(
//       width: 80,
//       height: 80,
//       decoration: BoxDecoration(
//         gradient: RadialGradient(
//           colors: [
//             Colors.blue.withOpacity(0.8),
//             Colors.blue.withOpacity(0.4),
//             Colors.transparent,
//           ],
//           stops: [0.3, 0.7, 1.0],
//         ),
//         shape: BoxShape.circle,
//         border: Border.all(color: Colors.blue, width: 3),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.blue.withOpacity(0.5),
//             blurRadius: 20,
//             spreadRadius: 5,
//           ),
//         ],
//       ),
//       child: Center(child: Icon(Icons.hub, color: Colors.white, size: 32)),
//     );
//   }
//
//   Widget _buildConnectionStatusIndicators() {
//     return Stack(
//       children: [
//         // Status indicators tại các điểm kết nối
//         Positioned(
//           top: widget.screenHeight * 0.1,
//           left: widget.screenWidth * 0.15,
//           child: _buildStatusDot(Colors.green, 'Active'),
//         ),
//         Positioned(
//           top: widget.screenHeight * 0.05,
//           right: widget.screenWidth * 0.25,
//           child: _buildStatusDot(Colors.orange, 'Warning'),
//         ),
//         Positioned(
//           bottom: widget.screenHeight * 0.15,
//           right: widget.screenWidth * 0.25,
//           child: _buildStatusDot(Colors.green, 'Active'),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildStatusDot(Color color, String status) {
//     return Container(
//       padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//       decoration: BoxDecoration(
//         color: color.withOpacity(0.2),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: color, width: 2),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Container(
//             width: 8,
//             height: 8,
//             decoration: BoxDecoration(color: color, shape: BoxShape.circle),
//           ),
//           SizedBox(width: 4),
//           Text(
//             status,
//             style: TextStyle(
//               color: color,
//               fontSize: 10,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// class ConnectionArrowsPainter extends CustomPainter {
//   final List<FacilityData> facilities;
//   final double screenWidth;
//   final double screenHeight;
//   final double animationValue;
//
//   ConnectionArrowsPainter({
//     required this.facilities,
//     required this.screenWidth,
//     required this.screenHeight,
//     required this.animationValue,
//   });
//
//   @override
//   void paint(Canvas canvas, Size size) {
//     final paint = Paint()
//       ..strokeWidth = 3
//       ..style = PaintingStyle.stroke;
//
//     final arrowPaint = Paint()..style = PaintingStyle.fill;
//
//     // Tọa độ trung tâm hub
//     final centerX = size.width * 0.5;
//     final centerY = size.height * 0.5;
//
//     // Tọa độ các facilities (điều chỉnh theo vị trí thực tế)
//     final List<Offset> facilityPositions = [
//       // Fac A - top left
//       Offset(size.width * 0.2, size.height * 0.2),
//       // Fac B - top right
//       Offset(size.width * 0.8, size.height * 0.15),
//       // Fac C - bottom right
//       Offset(size.width * 0.8, size.height * 0.4),
//     ];
//
//     final List<Color> facilityColors = [
//       Colors.blue,
//       Colors.green,
//       Colors.purple,
//     ];
//
//     // Vẽ arrows từ mỗi facility đến center
//     for (int i = 0; i < facilityPositions.length; i++) {
//       final startPoint = facilityPositions[i];
//       final endPoint = Offset(centerX, centerY);
//
//       paint.color = facilityColors[i];
//       arrowPaint.color = facilityColors[i];
//
//       // Tính toán animated progress
//       final animatedEndPoint = Offset(
//         startPoint.dx + (endPoint.dx - startPoint.dx) * animationValue,
//         startPoint.dy + (endPoint.dy - startPoint.dy) * animationValue,
//       );
//
//       // Vẽ đường thẳng chính
//       _drawAnimatedLine(canvas, paint, startPoint, animatedEndPoint);
//
//       // Vẽ mũi tên
//       if (animationValue > 0.7) {
//         _drawArrowHead(
//           canvas,
//           arrowPaint,
//           startPoint,
//           endPoint,
//           facilityColors[i],
//         );
//       }
//
//       // Vẽ data flow particles
//       _drawDataFlowParticles(canvas, startPoint, endPoint, facilityColors[i]);
//     }
//
//     // Vẽ connecting lines giữa các facilities
//     _drawInterFacilityConnections(canvas, facilityPositions);
//   }
//
//   void _drawAnimatedLine(Canvas canvas, Paint paint, Offset start, Offset end) {
//     // Vẽ đường cơ bản
//     paint.strokeWidth = 3;
//     canvas.drawLine(start, end, paint);
//
//     // Vẽ glow effect
//     paint.strokeWidth = 6;
//     paint.color = paint.color.withOpacity(0.3);
//     canvas.drawLine(start, end, paint);
//
//     // Vẽ animated dash line
//     final dashPaint = Paint()
//       ..color = Colors.white
//       ..strokeWidth = 2
//       ..style = PaintingStyle.stroke;
//
//     _drawDashedLine(canvas, dashPaint, start, end);
//   }
//
//   void _drawDashedLine(Canvas canvas, Paint paint, Offset start, Offset end) {
//     const dashLength = 10.0;
//     const gapLength = 5.0;
//
//     final distance = (end - start).distance;
//     final dashCount = (distance / (dashLength + gapLength)).floor();
//
//     final direction = (end - start) / distance;
//
//     for (int i = 0; i < dashCount; i++) {
//       final dashStart =
//           start +
//           direction *
//               (i * (dashLength + gapLength) + animationValue * 20) %
//               distance;
//       final dashEnd = dashStart + direction * dashLength;
//
//       canvas.drawLine(dashStart, dashEnd, paint);
//     }
//   }
//
//   void _drawArrowHead(
//     Canvas canvas,
//     Paint paint,
//     Offset start,
//     Offset end,
//     Color color,
//   ) {
//     final direction = (end - start).direction;
//     final arrowLength = 15.0;
//     final arrowAngle = 0.5;
//
//     final arrowTip = end;
//     final arrowLeft = Offset(
//       arrowTip.dx - arrowLength * math.cos(direction - arrowAngle),
//       arrowTip.dy - arrowLength * math.sin(direction - arrowAngle),
//     );
//     final arrowRight = Offset(
//       arrowTip.dx - arrowLength * math.cos(direction + arrowAngle),
//       arrowTip.dy - arrowLength * math.sin(direction + arrowAngle),
//     );
//
//     final path = Path()
//       ..moveTo(arrowTip.dx, arrowTip.dy)
//       ..lineTo(arrowLeft.dx, arrowLeft.dy)
//       ..lineTo(arrowRight.dx, arrowRight.dy)
//       ..close();
//
//     paint.color = color;
//     canvas.drawPath(path, paint);
//   }
//
//   void _drawDataFlowParticles(
//     Canvas canvas,
//     Offset start,
//     Offset end,
//     Color color,
//   ) {
//     final particlePaint = Paint()
//       ..color = color
//       ..style = PaintingStyle.fill;
//
//     // Vẽ 3 particles di chuyển dọc đường line
//     for (int i = 0; i < 3; i++) {
//       final progress = (animationValue + i * 0.3) % 1.0;
//       final particlePosition = Offset(
//         start.dx + (end.dx - start.dx) * progress,
//         start.dy + (end.dy - start.dy) * progress,
//       );
//
//       canvas.drawCircle(particlePosition, 4, particlePaint);
//
//       // Glow effect cho particles
//       particlePaint.color = color.withOpacity(0.3);
//       canvas.drawCircle(particlePosition, 8, particlePaint);
//       particlePaint.color = color;
//     }
//   }
//
//   void _drawInterFacilityConnections(Canvas canvas, List<Offset> positions) {
//     final connectionPaint = Paint()
//       ..color = Colors.grey.withOpacity(0.3)
//       ..strokeWidth = 2
//       ..style = PaintingStyle.stroke;
//
//     // Vẽ kết nối giữa Fac A và Fac B
//     canvas.drawLine(positions[0], positions[1], connectionPaint);
//
//     // Vẽ kết nối giữa Fac B và Fac C
//     canvas.drawLine(positions[1], positions[2], connectionPaint);
//   }
//
//   @override
//   bool shouldRepaint(ConnectionArrowsPainter oldDelegate) {
//     return oldDelegate.animationValue != animationValue;
//   }
// }

// import 'package:flutter/material.dart';
// import 'dart:math' as math;
//
// class VisualDashboard extends StatefulWidget {
//   @override
//   _VisualDashboardState createState() => _VisualDashboardState();
// }
//
// class _VisualDashboardState extends State<VisualDashboard>
//     with TickerProviderStateMixin {
//   late AnimationController _animationController;
//   late Animation<double> _animation;
//
//   // Sample data
//   double temperature = 23.5;
//   double humidity = 65.0;
//   double pressure = 1013.25;
//   int rpm = 1450;
//   double voltage = 220.5;
//   List<double> chartData = [20, 35, 40, 80, 60, 55, 70];
//
//   @override
//   void initState() {
//     super.initState();
//     _animationController = AnimationController(
//       duration: Duration(seconds: 2),
//       vsync: this,
//     );
//     _animation = Tween<double>(begin: 0, end: 1).animate(
//       CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
//     );
//     _animationController.forward();
//
//     // Simulate real-time data updates
//     _startDataUpdates();
//   }
//
//   void _startDataUpdates() {
//     Future.delayed(Duration(seconds: 3), () {
//       if (mounted) {
//         _updateData();
//         _startDataUpdates();
//       }
//     });
//   }
//
//   void _updateData() {
//     setState(() {
//       temperature = 20 + math.Random().nextDouble() * 10;
//       humidity = 50 + math.Random().nextDouble() * 30;
//       pressure = 1000 + math.Random().nextDouble() * 50;
//       rpm = 1200 + math.Random().nextInt(600);
//       voltage = 210 + math.Random().nextDouble() * 20;
//
//       // Update chart data
//       chartData.removeAt(0);
//       chartData.add(20 + math.Random().nextDouble() * 60);
//     });
//   }
//
//   @override
//   void dispose() {
//     _animationController.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Color(0xFF0F0F23),
//       body: SafeArea(
//         child: SingleChildScrollView(
//           padding: EdgeInsets.all(16),
//           child: Column(
//             children: [
//               _buildHeader(),
//               SizedBox(height: 20),
//               _buildMetricsGrid(),
//               SizedBox(height: 20),
//               _buildChartsSection(),
//               SizedBox(height: 20),
//               _buildGaugesSection(),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildHeader() {
//     return Container(
//       padding: EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           colors: [Color(0xFF1E1E3F), Color(0xFF2A2A4A)],
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//         borderRadius: BorderRadius.circular(15),
//         border: Border.all(color: Colors.cyan.withOpacity(0.3)),
//       ),
//       child: Row(
//         children: [
//           Icon(Icons.dashboard, color: Colors.cyan, size: 32),
//           SizedBox(width: 16),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   "System Dashboard",
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 24,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 Text(
//                   "Real-time monitoring",
//                   style: TextStyle(color: Colors.grey[400], fontSize: 14),
//                 ),
//               ],
//             ),
//           ),
//           _buildStatusDot("ONLINE", Colors.green),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildStatusDot(String status, Color color) {
//     return AnimatedBuilder(
//       animation: _animation,
//       builder: (context, child) {
//         return Container(
//           padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//           decoration: BoxDecoration(
//             color: color.withOpacity(0.2),
//             borderRadius: BorderRadius.circular(20),
//             border: Border.all(color: color.withOpacity(0.5)),
//           ),
//           child: Row(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Container(
//                 width: 8,
//                 height: 8,
//                 decoration: BoxDecoration(
//                   shape: BoxShape.circle,
//                   color: color,
//                   boxShadow: [
//                     BoxShadow(
//                       color: color,
//                       blurRadius: 8 * _animation.value,
//                       spreadRadius: 2,
//                     ),
//                   ],
//                 ),
//               ),
//               SizedBox(width: 8),
//               Text(
//                 status,
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: 12,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }
//
//   Widget _buildMetricsGrid() {
//     return GridView.count(
//       crossAxisCount: 2,
//       shrinkWrap: true,
//       physics: NeverScrollableScrollPhysics(),
//       crossAxisSpacing: 16,
//       mainAxisSpacing: 16,
//       childAspectRatio: 1.5,
//       children: [
//         _buildMetricCard(
//           "Temperature",
//           "${temperature.toStringAsFixed(1)}°C",
//           Icons.thermostat,
//           Colors.orange,
//           temperature / 40,
//         ),
//         _buildMetricCard(
//           "Humidity",
//           "${humidity.toStringAsFixed(1)}%",
//           Icons.water_drop,
//           Colors.blue,
//           humidity / 100,
//         ),
//         _buildMetricCard(
//           "Pressure",
//           "${pressure.toStringAsFixed(1)} hPa",
//           Icons.speed,
//           Colors.green,
//           (pressure - 980) / 80,
//         ),
//         _buildMetricCard(
//           "RPM",
//           "$rpm",
//           Icons.rotate_right,
//           Colors.purple,
//           rpm / 2000,
//         ),
//       ],
//     );
//   }
//
//   Widget _buildMetricCard(
//     String title,
//     String value,
//     IconData icon,
//     Color color,
//     double progress,
//   ) {
//     return AnimatedBuilder(
//       animation: _animation,
//       builder: (context, child) {
//         return Container(
//           padding: EdgeInsets.all(20),
//           decoration: BoxDecoration(
//             gradient: LinearGradient(
//               colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//             ),
//             borderRadius: BorderRadius.circular(15),
//             border: Border.all(color: color.withOpacity(0.3)),
//             boxShadow: [
//               BoxShadow(
//                 color: color.withOpacity(0.2),
//                 blurRadius: 10,
//                 offset: Offset(0, 5),
//               ),
//             ],
//           ),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 children: [
//                   Icon(icon, color: color, size: 24),
//                   Spacer(),
//                   Text(
//                     title,
//                     style: TextStyle(
//                       color: Colors.grey[400],
//                       fontSize: 12,
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                 ],
//               ),
//               Spacer(),
//               Text(
//                 value,
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: 24,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               SizedBox(height: 8),
//               LinearProgressIndicator(
//                 value: progress * _animation.value,
//                 backgroundColor: Colors.grey[800],
//                 valueColor: AlwaysStoppedAnimation<Color>(color),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }
//
//   Widget _buildChartsSection() {
//     return Container(
//       padding: EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//         borderRadius: BorderRadius.circular(15),
//         border: Border.all(color: Colors.cyan.withOpacity(0.3)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             children: [
//               Icon(Icons.show_chart, color: Colors.cyan, size: 24),
//               SizedBox(width: 12),
//               Text(
//                 "Performance Chart",
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ],
//           ),
//           SizedBox(height: 20),
//           Container(
//             height: 200,
//             child: CustomPaint(
//               painter: ChartPainter(chartData, _animation.value),
//               size: Size.infinite,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildGaugesSection() {
//     return Row(
//       children: [
//         Expanded(
//           child: _buildGauge("Voltage", voltage, 240, "V", Colors.yellow),
//         ),
//         SizedBox(width: 16),
//         Expanded(
//           child: _buildGauge("Power", voltage * 2.5, 600, "W", Colors.red),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildGauge(
//     String title,
//     double value,
//     double max,
//     String unit,
//     Color color,
//   ) {
//     return Container(
//       padding: EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//         borderRadius: BorderRadius.circular(15),
//         border: Border.all(color: color.withOpacity(0.3)),
//       ),
//       child: Column(
//         children: [
//           Text(
//             title,
//             style: TextStyle(
//               color: Colors.grey[400],
//               fontSize: 14,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//           SizedBox(height: 20),
//           Container(
//             width: 120,
//             height: 120,
//             child: CustomPaint(
//               painter: GaugePainter(value / max, color, _animation.value),
//               child: Center(
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Text(
//                       value.toStringAsFixed(1),
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 20,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     Text(
//                       unit,
//                       style: TextStyle(color: Colors.grey[400], fontSize: 12),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// class ChartPainter extends CustomPainter {
//   final List<double> data;
//   final double animationValue;
//
//   ChartPainter(this.data, this.animationValue);
//
//   @override
//   void paint(Canvas canvas, Size size) {
//     final paint = Paint()
//       ..color = Colors.cyan
//       ..strokeWidth = 3
//       ..style = PaintingStyle.stroke;
//
//     final fillPaint = Paint()
//       ..shader = LinearGradient(
//         colors: [
//           Colors.cyan.withOpacity(0.3),
//           Colors.cyan.withOpacity(0.1),
//           Colors.transparent,
//         ],
//         begin: Alignment.topCenter,
//         end: Alignment.bottomCenter,
//       ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
//
//     final path = Path();
//     final fillPath = Path();
//
//     final maxValue = data.reduce(math.max);
//     final stepX = size.width / (data.length - 1);
//
//     for (int i = 0; i < data.length; i++) {
//       final x = i * stepX * animationValue;
//       final y =
//           size.height - (data[i] / maxValue * size.height * animationValue);
//
//       if (i == 0) {
//         path.moveTo(x, y);
//         fillPath.moveTo(x, size.height);
//         fillPath.lineTo(x, y);
//       } else {
//         path.lineTo(x, y);
//         fillPath.lineTo(x, y);
//       }
//     }
//
//     fillPath.lineTo(size.width * animationValue, size.height);
//     fillPath.close();
//
//     canvas.drawPath(fillPath, fillPaint);
//     canvas.drawPath(path, paint);
//
//     // Draw data points
//     for (int i = 0; i < data.length; i++) {
//       final x = i * stepX * animationValue;
//       final y =
//           size.height - (data[i] / maxValue * size.height * animationValue);
//
//       if (x <= size.width * animationValue) {
//         canvas.drawCircle(Offset(x, y), 4, Paint()..color = Colors.cyan);
//       }
//     }
//   }
//
//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
// }
//
// class GaugePainter extends CustomPainter {
//   final double progress;
//   final Color color;
//   final double animationValue;
//
//   GaugePainter(this.progress, this.color, this.animationValue);
//
//   @override
//   void paint(Canvas canvas, Size size) {
//     final center = Offset(size.width / 2, size.height / 2);
//     final radius = size.width / 2 - 10;
//
//     // Background arc
//     final backgroundPaint = Paint()
//       ..color = Colors.grey[800]!
//       ..strokeWidth = 8
//       ..style = PaintingStyle.stroke
//       ..strokeCap = StrokeCap.round;
//
//     canvas.drawArc(
//       Rect.fromCircle(center: center, radius: radius),
//       -math.pi * 0.75,
//       math.pi * 1.5,
//       false,
//       backgroundPaint,
//     );
//
//     // Progress arc
//     final progressPaint = Paint()
//       ..shader = SweepGradient(
//         colors: [color.withOpacity(0.3), color],
//         stops: [0.0, 1.0],
//       ).createShader(Rect.fromCircle(center: center, radius: radius))
//       ..strokeWidth = 8
//       ..style = PaintingStyle.stroke
//       ..strokeCap = StrokeCap.round;
//
//     canvas.drawArc(
//       Rect.fromCircle(center: center, radius: radius),
//       -math.pi * 0.75,
//       math.pi * 1.5 * progress * animationValue,
//       false,
//       progressPaint,
//     );
//
//     // Glow effect
//     final glowPaint = Paint()
//       ..color = color.withOpacity(0.3)
//       ..strokeWidth = 12
//       ..style = PaintingStyle.stroke
//       ..strokeCap = StrokeCap.round
//       ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3);
//
//     canvas.drawArc(
//       Rect.fromCircle(center: center, radius: radius),
//       -math.pi * 0.75,
//       math.pi * 1.5 * progress * animationValue,
//       false,
//       glowPaint,
//     );
//   }
//
//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
// }
//
// class DashboardApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Visual Dashboard',
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData.dark(),
//       home: VisualDashboard(),
//     );
//   }
// }
//
// void main() {
//   runApp(DashboardApp());
// }
import 'package:factory_utility_visualization/provider/facility_range_provider.dart';
import 'package:factory_utility_visualization/provider/facility_realtime_provider.dart';
import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FacilityRealtimeProvider()),
        ChangeNotifierProvider(
          create: (_) => FacilityRangeProvider(
            facList: const ['Fac A', 'Fac B', 'Fac C'],
            from: DateTime.now().subtract(const Duration(hours: 3)),
            to: DateTime.now(),
          ),
        ),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Facility Dashboard',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: UtilityDashboardScreen(),
      // home: MockTablesPage(),
    );
  }
}

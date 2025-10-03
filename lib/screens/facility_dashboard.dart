import 'dart:async';
import 'dart:math' as math;
import 'package:factory_utility_visualization/api/ApiService.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../kvh_widgets/air_pressure/air_pressure_circular_gauge.dart';
import '../kvh_widgets/electricity/power_circular_gauge.dart';
import '../kvh_widgets/summary_widgets/summary_metric_card.dart';
import '../kvh_widgets/temperature/temperature_thermometer.dart';
import '../kvh_widgets/water/water_gauge_grid.dart';
import '../model/facility_data.dart';
import '../widgets/arrow_painter.dart';
import '../widgets/facility_info_box.dart';
import '../widgets/line_chart_painter.dart';
import '../widgets/rain_effect_image_realtime.dart';
import '../widgets/summary_card.dart';

import 'package:flutter/material.dart';

class FacilityDashboard extends StatefulWidget {
  FacilityDashboard({super.key});

  @override
  State<FacilityDashboard> createState() => _FacilityDashboardState();
}

class _FacilityDashboardState extends State<FacilityDashboard> {
  final String mainImageUrl = 'assets/images/SPC2.png';

  final ApiService api = ApiService();
  List<double> chartData1 = [];
  List<double> chartData2 = [];
  List<double> chartData3 = [];
  double? _lastElectricValue;
  double? _nextElectricValue;
  Timer? _chartTimer;

  Future<void> _fetchAndUpdate() async {
    final value = await ApiService().fetchElectricValue();
    if (value != null && mounted) {
      print("⚡ API trả về: $value");

      _lastElectricValue = _nextElectricValue ?? value;
      _nextElectricValue = value;

      print("🔹 _lastElectricValue = $_lastElectricValue");
      print("🔹 _nextElectricValue = $_nextElectricValue");
    } else {
      print("❌ Không lấy được dữ liệu từ API");
    }
  }

  // Nội suy chart mượt hơn
  void _startChartAnimation() {
    _chartTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) return;

      setState(() {
        if (_lastElectricValue != null && _nextElectricValue != null) {
          // nội suy tuyến tính
          final step = (_nextElectricValue! - _lastElectricValue!) / 10;
          final newVal =
              (chartData1.isEmpty ? _lastElectricValue! : chartData1.last) +
              step;

          chartData1.add(newVal);

          print("📈 Giá trị thêm vào chart: $newVal");

          if (chartData1.length > 30) chartData1.removeAt(0);
        }
      });
    });
  }

  late final Stream<List<FacilityData>> facilityStream;

  @override
  void initState() {
    super.initState();
    // _fetchAndUpdate(); // lần đầu
    _generateChartData();
    _startChartAnimation1();
    facilityStream = getFacilityStream(); // chỉ tạo 1 lần
  }

  @override
  void dispose() {
    _chartTimer?.cancel();
    super.dispose();
  }

  void _generateChartData() {
    final random = math.Random();
    chartData1 = List.generate(50, (i) => random.nextDouble() * 100);
    chartData2 = List.generate(50, (i) => 50 + random.nextDouble() * 50);
    chartData3 = List.generate(50, (i) => 30 + random.nextDouble() * 40);
  }

  void _startChartAnimation1() {
    _chartTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) return;
      setState(() {
        final random = math.Random();
        chartData1
          ..removeAt(0)
          ..add(random.nextDouble() * 100);
        chartData2
          ..removeAt(0)
          ..add(50 + random.nextDouble() * 50);
        chartData3
          ..removeAt(0)
          ..add(30 + random.nextDouble() * 40);
      });
    });
  }

  Stream<List<FacilityData>> getFacilityStream() async* {
    // 👉 emit dữ liệu mặc định ngay khi mở app
    List<FacilityData> lastData = [
      FacilityData(
        name: 'Fac A',
        electricPower: 200000,
        waterFlow: 2000,
        compressedAirPressure: 1.2, // MPa
        temperature: 35, // °C
      ),
      FacilityData(
        name: 'Fac B',
        electricPower: 190000,
        waterFlow: 2200,
        compressedAirPressure: 1.23,
        temperature: 36,
      ),
      FacilityData(
        name: 'Fac C',
        electricPower: 210000,
        waterFlow: 2100,
        compressedAirPressure: 1.25,
        temperature: 34,
      ),
    ];

    yield lastData; // emit lần đầu → UI có data liền

    // 👉 loop gọi API mỗi 5 giây
    while (true) {
      try {
        await Future.delayed(const Duration(seconds: 5));

        final now = DateTime.now().second;

        // call API thật (giả sử chỉ có 1 cái cần gọi API)
        final powerA = await api.fetchElectricValue();
        print("electricPower A: $powerA");
        print("electricPower A: $powerA (${powerA.runtimeType})");

        lastData = [
          FacilityData(
            name: 'Fac A',
            electricPower:
                powerA ?? (200000 + (now * 80)), // fallback nếu API fail
            waterFlow: 2000 + now.toDouble(),
            compressedAirPressure:
                1.2 + (now % 50) * 0.01, // giả lập thay đổi áp suất
            temperature: 35 + (now % 5), // giả lập nhiệt độ thay đổi
          ),
          FacilityData(
            name: 'Fac B',
            electricPower:
                powerA ?? (200000 + (now * 80)), // fallback nếu API fail
            waterFlow: 2200 + (now % 30),
            compressedAirPressure: 1.23 + (now % 20) * 0.01,
            temperature: 36 + (now % 4),
          ),
          FacilityData(
            name: 'Fac C',
            electricPower: 210000 + (now * 50),
            waterFlow: 2100 + (now % 25),
            compressedAirPressure: 1.25 + (now % 40) * 0.01,
            temperature: 34 + (now % 6),
          ),
        ];

        print(
          "👉 Emit data: Fac A = ${lastData[0].electricPower} (${lastData[0].electricPower.runtimeType})",
        );
        yield lastData; // emit data mới
      } catch (e) {
        print("⚠️ Lỗi khi fetch API: $e");
        yield lastData; // nếu lỗi thì vẫn trả data cũ → UI ko đứng
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF121111), // dark blue
              Color(0xFF0D47A1), // blue
              Color(0xFF311B92), // purple
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: StreamBuilder<List<FacilityData>>(
            stream: facilityStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final facilities = snapshot.data!;
              print("🟢 UI rebuild: Fac A = ${facilities[0].electricPower}");

              return Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildHeader(),
                  // _buildTimeNow(context),
                  const SizedBox(height: 10),
                  // Expanded(child: _buildFactoryMap(context, facilities)),
                  _buildFactoryMap(context, facilities),
                  const SizedBox(height: 20),
                  Expanded(child: _buildBottomChartsSection()),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final now = DateTime.now();
    final timeString =
        "${now.hour.toString().padLeft(2, '0')}:"
        "${now.minute.toString().padLeft(2, '0')}:"
        "${now.second.toString().padLeft(2, '0')}";

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Color(0xFF000000),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFF1A237E).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Factory Control System",
            style: TextStyle(
              color: Color(0xFF1157C5),
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            timeString,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFactoryMapWithAdvancedRain() {
    final WeatherApiService weatherService = WeatherApiService(); // Dùng mock
    // final WeatherApiService weatherService = MockWeatherService();
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.35),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // AdvancedRainEffect(imageUrl: mainImageUrl, fit: BoxFit.fill),
            // Trong _buildFactoryMap():
            ApiControlledRainImage(
              imageUrl: mainImageUrl,
              weatherService: weatherService,
              fit: BoxFit.fill,
            ),
            // ... overlay và facility boxes ...
          ],
        ),
      ),
    );
  }

  Widget _buildFactoryMap(BuildContext context, List<FacilityData> facilities) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final totalPower = facilities.fold(0.0, (sum, f) => sum + f.electricPower);
    final totalVolume = facilities.fold(0.0, (sum, f) => sum + f.waterFlow);
    final avgPressure =
        facilities.fold(0.0, (sum, f) => sum + f.compressedAirPressure) /
        facilities.length;
    return Container(
      width: screenWidth,
      height: screenHeight / 1.5,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: _buildSummaryCharts(facilities),
            ),
          ),
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                alignment: AlignmentDirectional.center,
                children: [
                  // Image.asset(
                  //   mainImageUrl,
                  //   fit: BoxFit.fill,
                  //   // width: screenWidth / 2,
                  // ),
                  _buildFactoryMapWithAdvancedRain(),
                  // ModelViewer(
                  //   src: 'assets/images/AnyConv.glb',
                  //   alt: "A 3D model",
                  //   autoRotate: true,
                  //   cameraControls: true,
                  //   ar: true,
                  // ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.1),
                          Colors.transparent,
                          Colors.black.withOpacity(0.15),
                        ],
                      ),
                    ),
                  ),

                  //Fac A
                  Positioned(
                    top: screenHeight * 0,
                    right: screenWidth * 0.05,
                    child: FacilityInfoBox(facility: facilities[0]),
                  ),
                  // Fac B
                  Positioned(
                    top: screenHeight * 0.4,
                    right: screenWidth * 0.05,
                    child: FacilityInfoBox(facility: facilities[1]),
                  ),
                  //Fac C
                  Positioned(
                    top: screenHeight * 0.01,
                    left: screenWidth * 0.12,
                    child: FacilityInfoBox(facility: facilities[2]),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Column(
              children: [
                _buildSummaryColumn(totalPower, totalVolume, avgPressure),
                Flexible(
                  child: FactorySummaryWidget(
                    totalPower,
                    totalVolume,
                    avgPressure,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCharts(List<FacilityData> facilities) {
    return GridView.builder(
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.16, // giữ tỷ lệ ô đồng nhất
        crossAxisSpacing: 18,
        mainAxisSpacing: 12,
      ),
      itemCount: facilities.length,
      itemBuilder: (context, index) {
        return Column(
          children: [
            // Header
            Container(
              height: 36,
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blueAccent.withOpacity(0.6),
                    Colors.black.withOpacity(0.3),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Center(
                child: Text(
                  facilities[index].name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            // Các gauge (cho co giãn loose thay vì ép cứng Expanded)
            SizedBox(
              height: 120,
              child: PowerCircularGauge(facility: facilities[index]),
            ),
            SizedBox(height: 10),
            SizedBox(
              height: 120,
              child: CustomWaterWaveGauge(
                facility: facilities[index],
                maxVolume: 6000,
              ),
            ),
            SizedBox(height: 10),
            SizedBox(
              height: 150,
              child: AirTankIndicator(facility: facilities[index]),
            ),
            SizedBox(height: 10),
            SizedBox(
              height: 150,
              child: TemperatureThermometer(facility: facilities[index]),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryColumn(
    double totalPower,
    double totalVolume,
    double avgPressure,
  ) {
    return Column(
      children: [
        Text("Total KVH", style: TextStyle(fontSize: 18, color: Colors.grey)),
        SummaryCard(
          title: 'Total electricPower',
          value: '${(totalPower / 1000).toStringAsFixed(0)}k kWh',
          icon: Icons.flash_on,
          color: Colors.orange,
        ),
        const SizedBox(height: 8),
        SummaryCard(
          title: 'Total Volume',
          value: '${totalVolume.toStringAsFixed(0)} m³',
          icon: Icons.water_drop,
          color: Colors.blue,
        ),
        const SizedBox(height: 8),
        SummaryCard(
          title: 'Avg Pressure',
          value: '${avgPressure.toStringAsFixed(0)} MPa',
          icon: Icons.speed,
          color: Colors.red,
        ),
      ],
    );
  }

  Widget _buildBottomChartsSection() {
    return Row(
      children: [
        Expanded(
          child: _buildChart('ElectricPower Output', chartData1, Colors.orange),
        ),
        Expanded(child: _buildChart('Temperature', chartData2, Colors.red)),
        SizedBox(width: 8),
        Expanded(child: _buildChart('Flow Rate', chartData3, Colors.blue)),
      ],
    );
  }

  Widget _buildChart(String title, List<double> data, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Expanded(
            child: CustomPaint(
              painter: LineChartPainter(data, color),
              size: Size.infinite,
            ),
          ),
        ],
      ),
    );
  }
}

// import 'dart:async';
// import 'dart:math' as math;
// import 'package:factory_utility_visualization/api/ApiService.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_cube/flutter_cube.dart';
// import 'package:model_viewer_plus/model_viewer_plus.dart';
//
// import '../model/facility_data.dart';
// import '../widgets/facility_info_box.dart';
// import '../widgets/summary_card.dart';
//
// class FacilityDashboard extends StatefulWidget {
//   const FacilityDashboard({super.key});
//
//   @override
//   State<FacilityDashboard> createState() => _FacilityDashboardState();
// }
//
// class _FacilityDashboardState extends State<FacilityDashboard> {
//   final String mainImageUrl = 'images/factory.jpg';
//   final ApiService api = ApiService();
//
//   // Mock data cho charts
//   List<double> chartData1 = [];
//   List<double> chartData2 = [];
//   List<double> chartData3 = [];
//   List<double> chartData4 = [];
//
//   Timer? _chartTimer;
//
//   @override
//   void initState() {
//     super.initState();
//     _generateChartData();
//     _startChartAnimation();
//   }
//
//   @override
//   void dispose() {
//     _chartTimer?.cancel();
//     super.dispose();
//   }
//
//   void _generateChartData() {
//     final random = math.Random();
//     chartData1 = List.generate(50, (i) => random.nextDouble() * 100);
//     chartData2 = List.generate(50, (i) => 50 + random.nextDouble() * 50);
//     chartData3 = List.generate(50, (i) => 30 + random.nextDouble() * 40);
//     chartData4 = List.generate(50, (i) => 60 + random.nextDouble() * 30);
//   }
//
//   void _startChartAnimation() {
//     _chartTimer = Timer.periodic(Duration(milliseconds: 500), (timer) {
//       if (mounted) {
//         setState(() {
//           final random = math.Random();
//           // Shift data và thêm point mới
//           chartData1.removeAt(0);
//           chartData1.add(random.nextDouble() * 100);
//
//           chartData2.removeAt(0);
//           chartData2.add(50 + random.nextDouble() * 50);
//
//           chartData3.removeAt(0);
//           chartData3.add(30 + random.nextDouble() * 40);
//
//           chartData4.removeAt(0);
//           chartData4.add(60 + random.nextDouble() * 30);
//         });
//       }
//     });
//   }
//
//   Stream<List<FacilityData>> getFacilityStream() async* {
//     while (true) {
//       await Future.delayed(const Duration(seconds: 2));
//       final now = DateTime.now().second;
//
//       yield [
//         FacilityData(
//           name: 'Facility A',
//           electricPower: 190000 + (now * 100),
//           volume: 2000 + now.toDouble(),
//           pressure: 1200 + (now % 50),
//           position: Alignment.topRight,
//         ),
//         FacilityData(
//           name: 'Facility B',
//           electricPower: await api.fetchElectricValue() ?? (200000 + (now * 80)),
//           volume: 2200 + (now % 30),
//           pressure: 1230 + (now % 20),
//           position: Alignment.bottomRight,
//         ),
//         FacilityData(
//           name: 'Facility C',
//           electricPower: 210000 + (now * 50),
//           volume: 2100 + (now % 25),
//           pressure: 1250 + (now % 40),
//           position: Alignment.topLeft,
//         ),
//       ];
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Color(0xFF1A1A1A), // Dark background như trong hình
//       body: StreamBuilder<List<FacilityData>>(
//         stream: getFacilityStream(),
//         builder: (context, snapshot) {
//           if (!snapshot.hasData) {
//             return const Center(
//               child: CircularProgressIndicator(color: Colors.green),
//             );
//           }
//
//           final facilities = snapshot.data!;
//
//           return Container(
//             padding: EdgeInsets.all(8),
//             child: Row(
//               children: [
//                 // LEFT PANEL - Factory Map & Info Boxes
//                 Expanded(
//                   flex: 5,
//                   child: Column(
//                     children: [
//                       // Header với time
//                       _buildHeader(),
//                       SizedBox(height: 8),
//
//                       // Main factory map với facility info boxes
//                       Expanded(
//                         flex: 6,
//                         child: _buildFactoryMapSection(facilities),
//                       ),
//
//                       // SizedBox(height: 8),
//                       //
//                       // // Bottom charts section
//                       // Expanded(flex: 4, child: _buildBottomChartsSection()),
//                     ],
//                   ),
//                 ),
//
//                 // SizedBox(width: 8),
//                 //
//                 // // RIGHT PANEL - Status & Charts
//                 // Expanded(flex: 3, child: _buildRightPanel(facilities)),
//               ],
//             ),
//           );
//         },
//       ),
//     );
//   }
//
//   Widget _buildHeader() {
//     final now = DateTime.now();
//     final timeString =
//         "${now.hour.toString().padLeft(2, '0')}:"
//         "${now.minute.toString().padLeft(2, '0')}:"
//         "${now.second.toString().padLeft(2, '0')}";
//
//     return Container(
//       padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//       decoration: BoxDecoration(
//         color: Color(0xFF2A2A2A),
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: Colors.green.withOpacity(0.3)),
//       ),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(
//             "Factory Control System",
//             style: TextStyle(
//               color: Colors.green,
//               fontSize: 18,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           Text(
//             timeString,
//             style: TextStyle(
//               color: Colors.white,
//               fontSize: 16,
//               fontFamily: 'monospace',
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildFactoryMapSection(List<FacilityData> facilities) {
//     return Container(
//       decoration: BoxDecoration(
//         color: Color(0xFF2A2A2A),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.green.withOpacity(0.3)),
//       ),
//       child: ClipRRect(
//         borderRadius: BorderRadius.circular(12),
//         child: Stack(
//           children: [
//             // Background - Factory layout
//             Container(
//               width: double.infinity,
//               height: double.infinity,
//               color: Color(0xFF1E1E1E),
//               child: _buildFactoryLayout(),
//             ),
//
//             // Facility info boxes - positioned absolutely
//             Positioned(
//               top: 20,
//               right: 20,
//               child: _buildCompactInfoBox(facilities[0], Colors.blue),
//             ),
//             Positioned(
//               bottom: 60,
//               right: 20,
//               child: _buildCompactInfoBox(facilities[1], Colors.green),
//             ),
//             Positioned(
//               top: 20,
//               left: 20,
//               child: _buildCompactInfoBox(facilities[2], Colors.purple),
//             ),
//
//             // Alert/Status overlay
//             Positioned(
//               top: 10,
//               left: MediaQuery.of(context).size.width * 0.3,
//               child: _buildAlertBox(),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildFactoryLayout() {
//     return CustomPaint(painter: FactoryLayoutPainter(), child: Container());
//   }
//
//   Widget _buildCompactInfoBox(FacilityData facility, Color color) {
//     return Container(
//       width: 200,
//       padding: EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: Color(0xFF2A2A2A).withOpacity(0.95),
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: color, width: 2),
//         boxShadow: [
//           BoxShadow(
//             color: color.withOpacity(0.3),
//             blurRadius: 8,
//             spreadRadius: 1,
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Row(
//             children: [
//               Icon(Icons.factory, color: color, size: 16),
//               SizedBox(width: 8),
//               Text(
//                 facility.name,
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontWeight: FontWeight.bold,
//                   fontSize: 14,
//                 ),
//               ),
//             ],
//           ),
//           SizedBox(height: 8),
//           _buildCompactMetric(
//             'electricPower',
//             '${(facility.electricPower / 1000).toInt()}kW',
//             Colors.orange,
//           ),
//           _buildCompactMetric(
//             'Volume',
//             '${facility.volume.toInt()}m³',
//             Colors.blue,
//           ),
//           _buildCompactMetric(
//             'Pressure',
//             '${facility.pressure.toInt()}MPa',
//             Colors.red,
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildCompactMetric(String label, String value, Color color) {
//     return Padding(
//       padding: EdgeInsets.symmetric(vertical: 2),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
//           Text(
//             value,
//             style: TextStyle(
//               color: color,
//               fontSize: 12,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildAlertBox() {
//     return Container(
//       padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//       decoration: BoxDecoration(
//         color: Colors.yellow.withOpacity(0.2),
//         borderRadius: BorderRadius.circular(6),
//         border: Border.all(color: Colors.yellow, width: 2),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Icon(Icons.warning, color: Colors.yellow, size: 16),
//           SizedBox(width: 8),
//           Text(
//             'System Alert: High Temperature',
//             style: TextStyle(
//               color: Colors.yellow,
//               fontSize: 12,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildBottomChartsSection() {
//     return Row(
//       children: [
//         Expanded(child: _buildChart('electricPower Output', chartData1, Colors.orange)),
//         SizedBox(width: 8),
//         Expanded(child: _buildChart('Temperature', chartData2, Colors.red)),
//         SizedBox(width: 8),
//         Expanded(child: _buildChart('Flow Rate', chartData3, Colors.blue)),
//         SizedBox(width: 8),
//         Expanded(child: _buildChart('Pressure', chartData4, Colors.green)),
//       ],
//     );
//   }
//
//   Widget _buildChart(String title, List<double> data, Color color) {
//     return Container(
//       padding: EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: Color(0xFF2A2A2A),
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: color.withOpacity(0.3)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             title,
//             style: TextStyle(
//               color: Colors.white,
//               fontSize: 12,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           SizedBox(height: 8),
//           Expanded(
//             child: CustomPaint(
//               painter: LineChartPainter(data, color),
//               size: Size.infinite,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildRightPanel(List<FacilityData> facilities) {
//     return Column(
//       children: [
//         // System status
//         _buildSystemStatus(),
//         SizedBox(height: 8),
//
//         // Facility list
//         _buildFacilityList(facilities),
//         SizedBox(height: 8),
//
//         // Real-time values
//         Expanded(child: _buildRealTimeValues(facilities)),
//       ],
//     );
//   }
//
//   Widget _buildSystemStatus() {
//     return Container(
//       padding: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Color(0xFF2A2A2A),
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: Colors.green.withOpacity(0.3)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             'System Status',
//             style: TextStyle(
//               color: Colors.white,
//               fontSize: 16,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           SizedBox(height: 12),
//           _buildStatusItem('electricPower Grid', 'Online', Colors.green),
//           _buildStatusItem('Water System', 'Online', Colors.green),
//           _buildStatusItem('Cooling System', 'Warning', Colors.orange),
//           _buildStatusItem('Safety Systems', 'Online', Colors.green),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildStatusItem(String system, String status, Color color) {
//     return Padding(
//       padding: EdgeInsets.symmetric(vertical: 4),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(system, style: TextStyle(color: Colors.grey[300], fontSize: 12)),
//           Container(
//             padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
//             decoration: BoxDecoration(
//               color: color.withOpacity(0.2),
//               borderRadius: BorderRadius.circular(4),
//               border: Border.all(color: color, width: 1),
//             ),
//             child: Text(status, style: TextStyle(color: color, fontSize: 10)),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildFacilityList(List<FacilityData> facilities) {
//     return Container(
//       padding: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Color(0xFF2A2A2A),
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: Colors.blue.withOpacity(0.3)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             'Facility Overview',
//             style: TextStyle(
//               color: Colors.white,
//               fontSize: 16,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           SizedBox(height: 12),
//           ...facilities.map((facility) => _buildFacilityListItem(facility)),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildFacilityListItem(FacilityData facility) {
//     final colors = [Colors.blue, Colors.green, Colors.purple];
//     final colorIndex = facility.name.hashCode % colors.length;
//     final color = colors[colorIndex];
//
//     return Container(
//       margin: EdgeInsets.only(bottom: 8),
//       padding: EdgeInsets.all(8),
//       decoration: BoxDecoration(
//         color: Color(0xFF1E1E1E),
//         borderRadius: BorderRadius.circular(6),
//         border: Border.all(color: color.withOpacity(0.3)),
//       ),
//       child: Row(
//         children: [
//           Container(
//             width: 8,
//             height: 8,
//             decoration: BoxDecoration(color: color, shape: BoxShape.circle),
//           ),
//           SizedBox(width: 8),
//           Expanded(
//             child: Text(
//               facility.name,
//               style: TextStyle(color: Colors.white, fontSize: 12),
//             ),
//           ),
//           Text(
//             '${(facility.electricPower / 1000).toInt()}kW',
//             style: TextStyle(
//               color: color,
//               fontSize: 12,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildRealTimeValues(List<FacilityData> facilities) {
//     return Container(
//       padding: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Color(0xFF2A2A2A),
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: Colors.purple.withOpacity(0.3)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             'Real-time Values',
//             style: TextStyle(
//               color: Colors.white,
//               fontSize: 16,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           SizedBox(height: 12),
//           Expanded(
//             child: ListView(
//               children: [
//                 _buildRealTimeItem(
//                   'Temperature',
//                   '${75 + (DateTime.now().second % 10)}°C',
//                   Colors.red,
//                 ),
//                 _buildRealTimeItem(
//                   'Humidity',
//                   '${45 + (DateTime.now().second % 20)}%',
//                   Colors.blue,
//                 ),
//                 _buildRealTimeItem(
//                   'Vibration',
//                   '${0.1 + (DateTime.now().second % 5) * 0.1}Hz',
//                   Colors.orange,
//                 ),
//                 _buildRealTimeItem(
//                   'Flow Rate',
//                   '${150 + (DateTime.now().second % 30)} L/min',
//                   Colors.green,
//                 ),
//                 _buildRealTimeItem(
//                   'RPM',
//                   '${1800 + (DateTime.now().second % 200)}',
//                   Colors.purple,
//                 ),
//                 _buildRealTimeItem(
//                   'Efficiency',
//                   '${85 + (DateTime.now().second % 10)}%',
//                   Colors.cyan,
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildRealTimeItem(String label, String value, Color color) {
//     return Container(
//       margin: EdgeInsets.only(bottom: 8),
//       padding: EdgeInsets.all(8),
//       decoration: BoxDecoration(
//         color: Color(0xFF1E1E1E),
//         borderRadius: BorderRadius.circular(4),
//       ),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 11)),
//           Text(
//             value,
//             style: TextStyle(
//               color: color,
//               fontSize: 12,
//               fontWeight: FontWeight.bold,
//               fontFamily: 'monospace',
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// // Custom painter cho factory layout
// class FactoryLayoutPainter extends CustomPainter {
//   @override
//   void paint(Canvas canvas, Size size) {
//     final paint = Paint()
//       ..color = Colors.green.withOpacity(0.3)
//       ..strokeWidth = 2
//       ..style = PaintingStyle.stroke;
//
//     final fillPaint = Paint()
//       ..color = Colors.grey.withOpacity(0.1)
//       ..style = PaintingStyle.fill;
//
//     // Draw factory buildings
//     final buildings = [
//       Rect.fromLTWH(
//         size.width * 0.1,
//         size.height * 0.2,
//         size.width * 0.25,
//         size.height * 0.3,
//       ),
//       Rect.fromLTWH(
//         size.width * 0.4,
//         size.height * 0.15,
//         size.width * 0.3,
//         size.height * 0.4,
//       ),
//       Rect.fromLTWH(
//         size.width * 0.75,
//         size.height * 0.25,
//         size.width * 0.2,
//         size.height * 0.25,
//       ),
//     ];
//
//     for (final building in buildings) {
//       canvas.drawRect(building, fillPaint);
//       canvas.drawRect(building, paint);
//     }
//
//     // Draw connecting lines
//     paint.color = Colors.yellow.withOpacity(0.5);
//     paint.strokeWidth = 3;
//
//     final lines = [
//       [
//         Offset(size.width * 0.35, size.height * 0.35),
//         Offset(size.width * 0.4, size.height * 0.35),
//       ],
//       [
//         Offset(size.width * 0.7, size.height * 0.35),
//         Offset(size.width * 0.75, size.height * 0.37),
//       ],
//     ];
//
//     for (final line in lines) {
//       canvas.drawLine(line[0], line[1], paint);
//     }
//   }
//
//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
// }
//
// // Custom painter cho line charts

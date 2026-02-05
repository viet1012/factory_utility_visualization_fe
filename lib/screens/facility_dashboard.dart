import 'dart:async';
import 'dart:math' as math;
import 'package:factory_utility_visualization/api/ApiService.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../kvh_widgets/electricity/power_circular_gauge.dart';
import '../kvh_widgets/water/water_gauge_grid.dart';
import '../model/facility_data.dart';
import '../model/facility_filtered.dart';
import '../model/signal.dart';
import '../provider/facility_provider_base.dart';
import '../provider/facility_range_provider.dart';
import '../provider/facility_realtime_provider.dart';
import '../widgets/arrow_painter.dart';
import '../widgets/facility_info_box.dart';
import '../widgets/line_chart_painter.dart';
import '../widgets/overview/FacilityChart.dart';
import '../widgets/overview/factory_map_dashboard.dart';
import '../widgets/overview/header_overview.dart';
import '../widgets/rain_effect_image_realtime.dart';
import '../widgets/overview/summary_card.dart';

import 'package:flutter/material.dart';
// screens/facility_dashboard.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../widgets/facility_info_box.dart';
import '../widgets/weather/api/weather_api_service.dart';

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

  Timer? _chartTimer;

  late final Stream<List<FacilityData>> facilityStream;

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      context.read<FacilityRealtimeProvider>().startAutoRefresh(plcAddresses);

      // range: refresh mỗi 2s + cập nhật cửa sổ trượt (3h gần nhất)
      final rangeProvider = context.read<FacilityRangeProvider>();

      // update range lần đầu
      final now = DateTime.now();
      rangeProvider.setRange(now.subtract(const Duration(hours: 3)), now);

      rangeProvider.startAutoRefresh(
        plcAddresses,
        interval: const Duration(seconds: 60),
        runImmediately: true,
      );
    });
  }

  @override
  void dispose() {
    context.read<FacilityRealtimeProvider>().stopAutoRefresh();
    context.read<FacilityRangeProvider>().stopAutoRefresh();
    super.dispose();
  }


  final List<String> plcAddresses = [
    'D24', 'D1113', 'D1114', 'D1115', 'D1116', 'D1117', 'D62' // ví dụ
  ];

  void _printRealtimeFacilities(List<FacilityFiltered> list) {
    debugPrint('========== REALTIME FACILITIES (${list.length}) ==========');
    for (final f in list) {
      debugPrint('FAC=${f.fac} | name=${f.facName}');
      for (final s in f.signals) {
        debugPrint(
          '  PLC=${s.plcAddress} | ${s.description} = ${s.value} ${s.unit}',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final realtime = context.watch<FacilityRealtimeProvider>();
    final range = context.watch<FacilityRangeProvider>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _printRealtimeFacilities(realtime.facilities);
    });
    if (realtime.facilities.isEmpty && realtime.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final mapFacilities = realtime.facilities;
    final chartFacilities = range.facilities;

    if (mapFacilities.isEmpty) {
      return const Center(child: Text('No realtime data'));
    }

    final chartFacility = chartFacilities.isNotEmpty
        ? chartFacilities.first
        : mapFacilities.first; // fallback
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0a0e27), // - Deep space black-blue
              Color(0xFF1a1a2e), // - Dark navy
              Color(0xFF16213e), // - Midnight blue
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              HeaderOverview(),
              // _buildTimeNow(context),
              const SizedBox(height: 10),
              // Expanded(child: _buildFactoryMap(context, facilities)),
              FactoryMapDashboard(
                facilities: realtime.facilities,
                prevFacilities: realtime.prevFacilities,
                mainImageUrl: mainImageUrl,
              ),
              // _buildFactoryMap(context, provider.facilities),
              const SizedBox(height: 20),
              // Expanded(child: _buildBottomChartsSection()),
              Expanded(
                child: Row(
                  children: [
                    // Expanded(
                    //   child: FacilityChart(
                    //     facility: provider.facilities[0],
                    //     title: 'Electricity',
                    //     color: Colors.orange,
                    //   ),
                    // ),
                    // Expanded(
                    //   child: FacilityChart(
                    //     facility: chartFacility,
                    //     title: 'Electricity',
                    //     color: Colors.red,
                    //   ),
                    // ),
                    // Expanded(
                    //   child: FacilityChart(
                    //     facility: provider.facilities[2],
                    //     title: 'Electricity',
                    //     color: Colors.blue,
                    //   ),
                    // ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // child: Padding(
        //   padding: const EdgeInsets.all(16),
        //   child: StreamBuilder<List<FacilityData>>(
        //     stream: facilityStream,
        //     builder: (context, snapshot) {
        //       if (!snapshot.hasData) {
        //         return const Center(child: CircularProgressIndicator());
        //       }
        //
        //       final facilities = snapshot.data!;
        //       print("🟢 UI rebuild: Fac A = ${facilities[0].electricPower}");
        //
        //       return Column(
        //         crossAxisAlignment: CrossAxisAlignment.center,
        //         children: [
        //           HeaderOverview(),
        //           // _buildTimeNow(context),
        //           const SizedBox(height: 10),
        //           // Expanded(child: _buildFactoryMap(context, facilities)),
        //           _buildFactoryMap(context, facilities),
        //           const SizedBox(height: 20),
        //           Expanded(child: _buildBottomChartsSection()),
        //         ],
        //       );
        //     },
        //   ),
        // ),
      ),
    );
  }

  Widget _buildFactoryMapWithAdvancedRain() {
    // final WeatherApiService weatherService = WeatherApiService(); // Dùng mock
    final WeatherApiService weatherService = MockWeatherService();
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
              fit: BoxFit.cover,
            ),
            // ... overlay và facility boxes ...
          ],
        ),
      ),
    );
  }

  Widget _buildFactoryMap(
    BuildContext context,
    List<FacilityFiltered> facilities,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
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
                  _buildFactoryMapWithAdvancedRain(),
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

                  // 🔹 Fac A
                  Positioned(
                    top: screenHeight * 0.0,
                    right: screenWidth * 0.05,
                    child: FacilityInfoBox(facility: facilities[0]),
                  ),

                  // 🔹 Fac B
                  Positioned(
                    top: screenHeight * 0.4,
                    right: screenWidth * 0.05,
                    child: FacilityInfoBox(facility: facilities[1]),
                  ),

                  // 🔹 Fac C
                  Positioned(
                    top: screenHeight * 0.0,
                    left: screenWidth * 0.03,
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
                _buildSummaryColumn(
                  // Tính tổng công suất của tất cả các facility
                  facilities,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget _buildFactoryMap1(BuildContext context, List<FacilityData> facilities) {
  //   final screenWidth = MediaQuery.of(context).size.width;
  //   final screenHeight = MediaQuery.of(context).size.height;
  //   final totalPower = facilities.fold(0.0, (sum, f) => sum + f.electricPower);
  //   final totalVolume = facilities.fold(0.0, (sum, f) => sum + f.waterFlow);
  //   final avgPressure =
  //       facilities.fold(0.0, (sum, f) => sum + f.compressedAirPressure) /
  //       facilities.length;
  //   return Container(
  //     width: screenWidth,
  //     height: screenHeight / 1.5,
  //     decoration: BoxDecoration(
  //       borderRadius: BorderRadius.circular(16),
  //       boxShadow: [
  //         BoxShadow(
  //           color: Colors.black.withOpacity(0.35),
  //           spreadRadius: 2,
  //           blurRadius: 10,
  //           offset: const Offset(0, 5),
  //         ),
  //       ],
  //     ),
  //     child: Row(
  //       children: [
  //         Expanded(
  //           child: Padding(
  //             padding: const EdgeInsets.all(8.0),
  //             child: _buildSummaryCharts(facilities),
  //           ),
  //         ),
  //         Expanded(
  //           flex: 3,
  //           child: ClipRRect(
  //             borderRadius: BorderRadius.circular(16),
  //             child: Stack(
  //               alignment: AlignmentDirectional.center,
  //               children: [
  //                 // Image.asset(
  //                 //   mainImageUrl,
  //                 //   fit: BoxFit.fill,
  //                 //   // width: screenWidth / 2,
  //                 // ),
  //                 _buildFactoryMapWithAdvancedRain(),
  //                 // ModelViewer(
  //                 //   src: 'assets/images/AnyConv.glb',
  //                 //   alt: "A 3D model",
  //                 //   autoRotate: true,
  //                 //   cameraControls: true,
  //                 //   ar: true,
  //                 // ),
  //                 Container(
  //                   decoration: BoxDecoration(
  //                     gradient: LinearGradient(
  //                       begin: Alignment.topCenter,
  //                       end: Alignment.bottomCenter,
  //                       colors: [
  //                         Colors.black.withOpacity(0.1),
  //                         Colors.transparent,
  //                         Colors.black.withOpacity(0.15),
  //                       ],
  //                     ),
  //                   ),
  //                 ),
  //
  //                 //Fac A
  //                 Positioned(
  //                   top: screenHeight * 0,
  //                   right: screenWidth * 0.05,
  //                   child: FacilityInfoBox(facility: facilities[0]),
  //                 ),
  //                 // Fac B
  //                 Positioned(
  //                   top: screenHeight * 0.4,
  //                   right: screenWidth * 0.05,
  //                   child: FacilityInfoBox(facility: facilities[1]),
  //                 ),
  //                 //Fac C
  //                 Positioned(
  //                   top: screenHeight * 0,
  //                   left: screenWidth * 0.03,
  //                   child: FacilityInfoBox(facility: facilities[2]),
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ),
  //         Expanded(
  //           flex: 1,
  //           child: Column(
  //             children: [
  //               _buildSummaryColumn(totalPower, totalVolume, avgPressure),
  //               Flexible(
  //                 child: FactorySummaryWidget(
  //                   totalPower,
  //                   totalVolume,
  //                   avgPressure,
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildSummaryCharts(List<FacilityFiltered> facilities) {
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
                  facilities[index].fac,
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
            // SizedBox(
            //   height: 120,
            //   child: CustomWaterWaveGauge(
            //     facility: facilities[index],
            //     maxVolume: 6000,
            //   ),
            // ),
            // SizedBox(height: 10),
            // SizedBox(
            //   height: 150,
            //   child: AirTankIndicator(facility: facilities[index]),
            // ),
            // SizedBox(height: 10),
            // SizedBox(
            //   height: 150,
            //   child: TemperatureThermometer(facility: facilities[index]),
            // ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryColumn(List<FacilityFiltered> facilities) {
    if (facilities.isEmpty) return const SizedBox();

    // Tính tổng công suất, tổng lưu lượng, trung bình áp suất
    double totalPower = facilities
        .map(
          (f) => f.signals.firstWhere(
            (s) => s.description.toLowerCase().contains('power'),
            orElse: () => f.signals.first,
          ),
        )
        .map((s) => s.value)
        .reduce((a, b) => a + b);

    String powerUnit = facilities.first.signals
        .firstWhere(
          (s) => s.description.toLowerCase().contains('power'),
          orElse: () => facilities.first.signals.first,
        )
        .unit;

    double totalVolume = facilities
        .map(
          (f) => f.signals.firstWhere(
            (s) => s.description.toLowerCase().contains('flow'),
            orElse: () => f.signals.first,
          ),
        )
        .map((s) => s.value)
        .reduce((a, b) => a + b);

    String volumeUnit = facilities.first.signals
        .firstWhere(
          (s) => s.description.toLowerCase().contains('flow'),
          orElse: () => facilities.first.signals.first,
        )
        .unit;

    double avgPressure =
        facilities
            .map(
              (f) => f.signals.firstWhere(
                (s) => s.description.toLowerCase().contains('pressure'),
                orElse: () => f.signals.first,
              ),
            )
            .map((s) => s.value)
            .reduce((a, b) => a + b) /
        facilities.length;

    String pressureUnit = facilities.first.signals
        .firstWhere(
          (s) => s.description.toLowerCase().contains('pressure'),
          orElse: () => facilities.first.signals.first,
        )
        .unit;

    return Column(
      children: [
        Text(
          "Factory Summary",
          style: TextStyle(
            fontSize: 18,
            color: Colors.grey[400],
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        SummaryCard(
          title: 'Total electricPower',
          value: '${(totalPower).toStringAsFixed(0)} $powerUnit',
          icon: Icons.flash_on,
          color: Colors.orange,
        ),
        const SizedBox(height: 8),
        SummaryCard(
          title: 'Total Volume',
          value: '${totalVolume.toStringAsFixed(0)} $volumeUnit',
          icon: Icons.water_drop,
          color: Colors.blue,
        ),
        const SizedBox(height: 8),
        SummaryCard(
          title: 'Avg Pressure',
          value: '${avgPressure.toStringAsFixed(2)} $pressureUnit',
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

import 'package:flutter/material.dart';
import '../rain_effect_image_realtime.dart';
import '../weather/api/weather_api_service.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

class FactoryMapWithRain extends StatelessWidget {
  final String mainImageUrl;

  const FactoryMapWithRain({super.key, required this.mainImageUrl});

  @override
  Widget build(BuildContext context) {
    final WeatherApiService weatherService = WeatherApiService();
    // final WeatherApiService weatherApiService = MockWeatherService();
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
        child: ApiControlledRainImage(
          imageUrl: mainImageUrl,
          weatherService: weatherService,
          fit: BoxFit.cover,
        ),
      ),
      // child:ViewerPage(),
    );
  }
}

class ViewerPage extends StatefulWidget {
  const ViewerPage({super.key});
  @override
  State<ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends State<ViewerPage> {
  static const _viewType = 'three-viewer';

  @override
  void initState() {
    super.initState();

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      return html.IFrameElement()
        ..src = 'viewer/index.html'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('STL Viewer'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: const SizedBox.expand(child: HtmlElementView(viewType: _viewType)),
    );
  }
}

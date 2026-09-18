import 'package:flutter/material.dart';

import '../../../weather_widgets/rain_effect_image_realtime.dart';
import '../../../weather_widgets/weather/api/weather_api_service.dart';

class FactoryMapWithRain extends StatelessWidget {
  final bool isActive;
  final String mainImageUrl;
  final String nightImageUrl;

  const FactoryMapWithRain({
    super.key,
    required this.isActive,
    required this.mainImageUrl,
    required this.nightImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final weatherService = WeatherApiService();

    return SizedBox.expand(
      child: DecoratedBox(
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
            isActive: isActive,
            imageUrl: mainImageUrl,
            nightImageUrl: nightImageUrl,
            weatherService: weatherService,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

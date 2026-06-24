// Weather API Service
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../model/weather_data.dart';

class WeatherApiService {
  final String apiKey = 'f0481fa18fbc9c353fa3b3530208e8f1';

  Future<WeatherData?> fetchWeatherData() async {
    try {
      final url =
          'https://api.openweathermap.org/data/2.5/weather?lat=10.889414655521932&lon=106.72094061256969&appid=$apiKey&units=metric';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return WeatherData.fromJson(data);
      } else {
        print('Error response: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('Error fetching weather: $e');
    }
    return null;
  }

  // Stream realtime weather (update mỗi 60 phút)
  Stream<WeatherData> weatherStream() async* {
    while (true) {
      final data = await fetchWeatherData();
      if (data != null) yield data;
      await Future.delayed(const Duration(minutes: 5));
    }
  }
}

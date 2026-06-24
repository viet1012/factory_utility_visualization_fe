// Weather Data Model
class WeatherData {
  final String condition; // "rain", "clear", "cloudy", "storm"
  final double rainIntensity; // 0.0 - 1.0
  final double temperature;
  final double humidity;
  final double windSpeed;
  final bool isDaytime; // true = ban ngày, false = ban đêm

  WeatherData({
    required this.condition,
    required this.rainIntensity,
    required this.temperature,
    required this.humidity,
    required this.windSpeed,
    this.isDaytime = true, // default là ban ngày
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final weatherMain = json['weather'][0]['main'].toString().toLowerCase();

    // lấy lượng mưa (mm/h)
    final rain = (json['rain'] != null)
        ? (json['rain']['1h'] ?? json['rain']['3h'] ?? 0.0)
        : 0.0;

    // intensity = tỷ lệ 0.0 - 1.0
    double intensity;
    if (rain > 0) {
      intensity = (rain / 10.0).clamp(0.0, 1.0);
    } else if (weatherMain.contains('rain') ||
        weatherMain.contains('drizzle') ||
        weatherMain.contains('thunderstorm')) {
      intensity = 0.5; // mặc định có mưa vừa
    } else {
      intensity = 0.0;
    }

    final sunrise = json['sys']['sunrise']; // timestamp UTC
    final sunset = json['sys']['sunset']; // timestamp UTC
    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

    bool isDay = now >= sunrise && now <= sunset;

    print("DEBUG: condition=$weatherMain, rain=$rain, intensity=$intensity");

    return WeatherData(
      condition: weatherMain,
      rainIntensity: intensity,
      temperature: (json['main']['temp'] ?? 0.0).toDouble(),
      humidity: (json['main']['humidity'] ?? 0.0).toDouble(),
      windSpeed: (json['wind']['speed'] ?? 0.0).toDouble(),
      isDaytime: isDay,
    );
  }

  // Custom API format
  factory WeatherData.fromCustomJson(Map<String, dynamic> json) {
    return WeatherData(
      condition: json['condition'] ?? 'clear',
      rainIntensity: (json['rain_intensity'] ?? 0.0).toDouble(),
      temperature: (json['temperature'] ?? 25.0).toDouble(),
      humidity: (json['humidity'] ?? 60.0).toDouble(),
      windSpeed: (json['wind_speed'] ?? 0.0).toDouble(),
    );
  }
}

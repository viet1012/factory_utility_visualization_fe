import 'package:flutter/material.dart';

class HeaderOverview extends StatelessWidget {
  const HeaderOverview({super.key});

  String _getCurrentTime() {
    final now = DateTime.now();
    return "${now.hour.toString().padLeft(2, '0')}:"
        "${now.minute.toString().padLeft(2, '0')}:"
        "${now.second.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final timeString = _getCurrentTime();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0A192F), // xanh navy rất tối
            Color(0xFF071625), // xanh đậm
            Color(0xFF072757), // xanh đậm
            Color(0xFF100F0F), // xanh sáng hơn chút
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.factory_rounded,
                color: Colors.lightBlueAccent,
                size: 32,
              ),
              SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF00F5FF).withOpacity(0.1),
                      Color(0xFFFF006E).withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Color(0xFF00F5FF).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  "Factory Control System",
                  style: TextStyle(
                    fontSize: 20,
                    color: Color(0xFF00F5FF),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    shadows: [Shadow(color: Color(0xFF00F5FF), blurRadius: 10)],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Icon(
                Icons.access_time,
                color: Colors.lightBlueAccent,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                timeString,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

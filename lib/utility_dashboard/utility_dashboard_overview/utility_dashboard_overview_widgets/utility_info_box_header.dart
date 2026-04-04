import 'package:flutter/material.dart';

import '../../utility_dashboard_common/data_health.dart';
import 'health_indicator.dart';

class UtilityInfoBoxHeader {
  static Widget header({
    required Color facilityColor,
    required String facTitle,
    required DataHealthResult healthResult,
    String? boxDeviceId,
    String? plcAddress,
    String? unit,
  }) {
    // 👇 Override màu khi OK để theo theme
    final DataHealthResult result = healthResult;

    final DataHealthResult themedResult = result.health == DataHealth.ok
        ? DataHealthResult(DataHealth.ok)
        : result;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            facilityColor.withOpacity(0.82),
            facilityColor.withOpacity(0.32),
          ],
        ),
        border: Border(
          bottom: BorderSide(color: facilityColor.withOpacity(0.55), width: 2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.factory, color: Colors.white.withOpacity(0.95), size: 20),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  facTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // ✅ DÙNG HealthIndicator
          HealthIndicator(
            result: themedResult,
            size: 11,
            showLabel: false,
            enableTooltip: true,
          ),
        ],
      ),
    );
  }

  static Widget emptyState({required bool hasError, required Object? err}) {
    return Center(
      child: Text(
        hasError ? 'Error: $err' : 'No data',
        style: TextStyle(color: Colors.white.withOpacity(0.7)),
        textAlign: TextAlign.center,
      ),
    );
  }
}

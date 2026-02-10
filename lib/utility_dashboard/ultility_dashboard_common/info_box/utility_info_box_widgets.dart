import 'package:flutter/material.dart';

import '../../../utility_models/response/latest_record.dart';

class UtilityInfoBoxWidgets {
  static Widget header({
    required Color facilityColor,
    required String facTitle,
    required bool isLoading,
    required bool hasError,
    required Object? err,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            facilityColor.withOpacity(0.8),
            facilityColor.withOpacity(0.4),
          ],
        ),
        border: Border(
          bottom: BorderSide(color: facilityColor.withOpacity(0.5), width: 2),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.factory, color: Colors.white.withOpacity(0.95), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              facTitle,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Tooltip(
            message: hasError
                ? 'API error: $err'
                : (isLoading ? 'Loading...' : 'Live'),
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: hasError
                    ? Colors.redAccent
                    : (isLoading ? Colors.amberAccent : Colors.greenAccent),
                shape: BoxShape.circle,
              ),
            ),
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

  static Widget latestRow(LatestRecordDto r) {
    IconData iconData = Icons.sensors;
    Color color = Colors.lightBlueAccent;

    final type = (r.cate ?? '').toLowerCase();

    // NOTE: type đang lowercase => so sánh lowercase
    if (type.contains('electricity')) {
      iconData = Icons.flash_on;
      color = Colors.orangeAccent;
    } else if (type.contains('volume') || type.contains('water')) {
      iconData = Icons.water_drop_outlined;
      color = Colors.blueAccent;
    }

    final valueText = r.value == null ? '--' : r.value!.toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Row(
        children: [
          Icon(iconData, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${r.plcAddress} • ${r.boxDeviceId}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  valueText,
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../utility_models/response/latest_record.dart';

class UtilityInfoBoxWidgets {
  static Widget header({
    required Color facilityColor,
    required String facTitle,
    required bool isLoading,
    required bool hasError,
    required Object? err,

    // ✅ thêm
    String? boxDeviceId,
    String? plcAddress,
  }) {
    final sub = [
      if ((boxDeviceId ?? '').trim().isNotEmpty) boxDeviceId!.trim(),
      if ((plcAddress ?? '').trim().isNotEmpty) plcAddress!.trim(),
    ].join(' • ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      // giảm vertical
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

          // ✅ title + sub trong cùng 1 khối
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min, // ✅ không bung cao
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  facTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    height: 1.05, // ✅ thấp
                  ),
                ),
                if (sub.isNotEmpty)
                  Row(
                    children: [
                      Icon(
                        Icons.memory,
                        size: 22,
                        color: Colors.white.withOpacity(0.75),
                      ),
                      const SizedBox(width: 12),

                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.0, // ✅ thấp
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          const SizedBox(width: 10),

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
                // Text(
                //   '${r.plcAddress} • ${r.boxDeviceId}',
                //   maxLines: 2,
                //   overflow: TextOverflow.ellipsis,
                //   style: TextStyle(
                //     color: Colors.white.withOpacity(0.75),
                //     fontSize: 13,
                //     fontWeight: FontWeight.w600,
                //   ),
                // ),
                // const SizedBox(height: 4),
                Text(
                  '${r.plcAddress} • ${valueText}',
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

  static Widget latestChip(LatestRecordDto r) {
    final type = (r.cate ?? '').toLowerCase();

    IconData icon = Icons.sensors;
    Color accent = Colors.lightBlueAccent;

    if (type.contains('electricity') || type.contains('power')) {
      icon = Icons.flash_on;
      accent = Colors.orangeAccent;
    } else if (type.contains('water') || type.contains('volume')) {
      icon = Icons.water_drop_outlined;
      accent = Colors.blueAccent;
    } else if (type.contains('air') || type.contains('compress')) {
      icon = Icons.air;
      accent = Colors.cyanAccent;
    }

    final v = r.value == null ? '--' : r.value!.toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔹 Dòng chính (plc + value)
                Text(
                  '${r.plcAddress} • $v',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accent,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                  ),
                ),

                const SizedBox(height: 4),

                // 🔹 Dòng dưới: boxDeviceId (plain text)
                Text(
                  r.boxDeviceId ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.0,
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

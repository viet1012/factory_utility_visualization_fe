import 'package:flutter/material.dart';

import '../../../utility_models/response/latest_record.dart';

class UtilityInfoBoxWidgets {
  static Widget header({
    required Color facilityColor,
    required String facTitle,
    required bool isLoading,
    required bool hasError,
    required Object? err,
    String? boxDeviceId,
    String? plcAddress,
    String? unit,
  }) {
    final sub = [
      if ((boxDeviceId ?? '').trim().isNotEmpty) boxDeviceId!.trim(),
      if ((plcAddress ?? '').trim().isNotEmpty) plcAddress!.trim(),
      if ((unit ?? '').trim().isNotEmpty) unit!.trim(),
    ].join(' • ');

    final statusColor = hasError
        ? Colors.redAccent
        : (isLoading ? Colors.amberAccent : Colors.greenAccent);

    final statusText = hasError
        ? 'API error: $err'
        : (isLoading ? 'Loading...' : 'Live');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),

        // ?? GLASS n?n nh?
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.06),
            Colors.white.withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),

        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.08),
            width: 1,
          ),
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          // ?? accent nh? theo cate
          BoxShadow(
            color: facilityColor.withOpacity(0.10),
            blurRadius: 14,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // ICON
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.12),
              ),
            ),
            child: Icon(
              Icons.factory,
              color: Colors.white.withOpacity(0.9),
              size: 16,
            ),
          ),

          const SizedBox(width: 10),

          // TEXT
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  facTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),

                if (sub.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.65),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 10),

          // STATUS DOT (x?n hon)
          Tooltip(
            message: statusText,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withOpacity(0.6),
                    blurRadius: 10,
                  ),
                ],
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
                  '${r.nameEn}',
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
                Row(
                  children: [
                    Text(
                      // r.boxDeviceId ?? '',
                      v,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

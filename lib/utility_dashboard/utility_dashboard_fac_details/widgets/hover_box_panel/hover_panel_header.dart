import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../utility_dashboard_common/chart_theme.dart';
import '../../models/group_frame_types.dart';
import 'hover_flow_painters.dart';
import 'hover_panel_style.dart';

class PanelHeader extends StatelessWidget {
  final String boxId;
  final int total;
  final String? category;
  final AnimationController flowController;

  const PanelHeader({
    super.key,
    required this.boxId,
    required this.total,
    this.category,
    required this.flowController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PanelStyle.headerBg,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // ✅ ANIMATED ICON WITH FLOW EFFECT
          _buildAnimatedIcon(),

          const SizedBox(width: 8),

          Expanded(
            child: Text(
              'Box $boxId',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: PanelStyle.accent.withOpacity(0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: PanelStyle.accent.withOpacity(0.38)),
            ),
            child: Text(
              '$total items',
              style: const TextStyle(
                color: PanelStyle.accent,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedIcon() {
    return AnimatedBuilder(
      animation: flowController,
      builder: (context, child) {
        final color = ChartThemeResolver.iconColor(category);
        final progress = flowController.value;
        final pulse = 1.0 + math.sin(progress * math.pi * 2) * 0.055;

        return Transform.scale(
          scale: pulse,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer soft glow
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.36),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),

                // Animated ring + particles
                Positioned.fill(
                  child: CustomPaint(
                    painter: PremiumIconEffectPainter(
                      progress: progress,
                      color: color,
                      category: category,
                    ),
                  ),
                ),

                // Main glass icon box
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.18),
                        color.withOpacity(0.18),
                        Colors.black.withOpacity(0.10),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.20),
                      width: 1,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: CustomPaint(
                            painter: _getFlowEffectPainter(progress),
                          ),
                        ),
                      ),

                      Transform.rotate(
                        angle: category?.toLowerCase() == 'air'
                            ? math.sin(progress * math.pi * 2) * 0.10
                            : 0,
                        child: Icon(
                          ChartThemeResolver.icon(category),
                          color: color,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  CustomPainter _getFlowEffectPainter(double progress) {
    switch (ChartThemeResolver.effect(category)) {
      case GroupFrameEffect.electric:
        return ElectricFlowPainter(progress);

      case GroupFrameEffect.water:
        return WaterFlowPainter(progress);

      case GroupFrameEffect.air:
        return AirFlowPainter(progress);

      default:
        return ParticleFlowPainter(progress);
    }
  }
}

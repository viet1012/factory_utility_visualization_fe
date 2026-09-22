import 'package:flutter/material.dart';

import '../../utility_dashboard_common/data_health.dart';
import 'health_indicator.dart';

class UtilityInfoBoxHeader {
  static Widget header({
    required Color facilityColor,
    required String facTitle,
    required DataHealthResult healthResult,
  }) {
    final themedResult = healthResult.health == DataHealth.ok
        ? DataHealthResult(DataHealth.ok)
        : healthResult;

    return _PremiumInfoBoxHeader(
      facilityColor: facilityColor,
      facTitle: facTitle,
      healthResult: themedResult,
    );
  }
}

class _PremiumInfoBoxHeader extends StatefulWidget {
  final Color facilityColor;
  final String facTitle;
  final DataHealthResult healthResult;

  const _PremiumInfoBoxHeader({
    required this.facilityColor,
    required this.facTitle,
    required this.healthResult,
  });

  @override
  State<_PremiumInfoBoxHeader> createState() => _PremiumInfoBoxHeaderState();
}

class _PremiumInfoBoxHeaderState extends State<_PremiumInfoBoxHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  bool get _isOk => widget.healthResult.health == DataHealth.ok;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.facilityColor;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final shimmerX = -1.4 + (_controller.value * 2.8);

        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.7),
                color.withValues(alpha: 0.4),
                color.withValues(alpha: 0.2),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: _isOk ? 0.26 : 0.14),
                blurRadius: _isOk ? 16 : 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
          ),
          child: ClipRect(
            child: Stack(
              children: [
                Positioned.fill(
                  child: FractionalTranslation(
                    translation: Offset(shimmerX, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 90,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.white.withValues(alpha: 0.14),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _HeaderIcon(color: color),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        widget.facTitle.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.96),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.45,
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    Container(
                      height: 22,
                      width: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: HealthIndicator(
                        result: widget.healthResult,
                        size: 9,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  final Color color;

  const _HeaderIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 27,
      height: 27,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.24),
            Colors.white.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(
        Icons.factory_rounded,
        size: 15.5,
        color: Colors.white.withValues(alpha: 0.96),
      ),
    );
  }
}

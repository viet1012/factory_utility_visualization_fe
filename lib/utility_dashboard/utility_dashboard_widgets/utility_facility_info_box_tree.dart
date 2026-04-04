import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utility_models/response/tree_series_response.dart';
import '../../utility_state/tree_latest_provider.dart';
import '../utility_dashboard_common/info_box/circuit_pattern_painter.dart';
import '../utility_dashboard_common/info_box/utility_info_box_fx.dart';
import '../utility_dashboard_common/info_box/utility_info_box_widgets.dart';
import '../utility_dashboard_common/utility_fac_style.dart';

class UtilityFacilityInfoBoxTree extends StatefulWidget {
  final double width;
  final double? height;

  final List<String> facIds;
  final List<String> plcAddresses;
  final String? boxDeviceId;

  /// title hiển thị trên header (vd: "Fac B")
  final String headerTitle;

  const UtilityFacilityInfoBoxTree({
    super.key,
    required this.facIds,
    required this.plcAddresses,
    required this.headerTitle,
    this.boxDeviceId,
    this.width = 300,
    this.height = 200,
  });

  @override
  State<UtilityFacilityInfoBoxTree> createState() =>
      _UtilityFacilityInfoBoxTreeState();
}

class _UtilityFacilityInfoBoxTreeState extends State<UtilityFacilityInfoBoxTree>
    with TickerProviderStateMixin {
  late final UtilityInfoBoxFx fx;
  late String _key;

  // auto scroll giống box cũ (optional)
  final ScrollController _scroll = ScrollController();
  Timer? _autoTimer;

  void _startAutoScroll() {
    _autoTimer?.cancel();
    if (!_scroll.hasClients) return;

    double dir = 1;
    _autoTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted || !_scroll.hasClients) return;

      final max = _scroll.position.maxScrollExtent;
      if (max <= 0) return;

      final next = (_scroll.offset + dir * 90).clamp(0.0, max);

      await _scroll.animateTo(
        next,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
      );

      if (next >= max - 1) dir = -1;
      if (next <= 1) dir = 1;
    });
  }

  void _setupKeyAndStart() {
    final p = context.read<TreeLatestProvider>();
    _key = p.buildKey(
      facIds: widget.facIds,
      plcAddresses: widget.plcAddresses,
      boxDeviceId: widget.boxDeviceId,
    );

    // start auto poll
    p.startAuto(
      key: _key,
      facIds: widget.facIds,
      plcAddresses: widget.plcAddresses,
      boxDeviceId: widget.boxDeviceId,
      interval: const Duration(seconds: 3),
    );
  }

  @override
  void initState() {
    super.initState();
    fx = UtilityInfoBoxFx(this)..init();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _setupKeyAndStart();

      // auto scroll sau khi build xong 1 chút
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _startAutoScroll();
      });
    });
  }

  @override
  void didUpdateWidget(covariant UtilityFacilityInfoBoxTree oldWidget) {
    super.didUpdateWidget(oldWidget);

    final changed =
        oldWidget.boxDeviceId != widget.boxDeviceId ||
        oldWidget.headerTitle != widget.headerTitle ||
        oldWidget.facIds.join(',') != widget.facIds.join(',') ||
        oldWidget.plcAddresses.join(',') != widget.plcAddresses.join(',');

    if (!changed) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _setupKeyAndStart();
      _startAutoScroll();
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _scroll.dispose();
    fx.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TreeLatestProvider>(
      builder: (_, p, __) {
        final loading = p.loadingOf(_key);
        final err = p.errorOf(_key);
        final data = p.dataOf(_key);

        final hasError = err != null;
        final isLoading = loading && data == null && !hasError;

        // màu theo fac giống box cũ
        final facilityColor = UtilityFacStyle.colorFromFac(widget.headerTitle);

        return SlideTransition(
          position: fx.slide,
          child: MouseRegion(
            onEnter: (_) => fx.onHover(true),
            onExit: (_) => fx.onHover(false),
            child: AnimatedBuilder(
              animation: fx.listenable,
              builder: (context, child) {
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(fx.rotate.value),
                  child: Transform.scale(
                    scale: fx.scale.value,
                    child: Container(
                      width: widget.width,
                      height: widget.height,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF1A237E).withOpacity(0.28),
                            const Color(0xFF0D47A1).withOpacity(0.26),
                          ],
                        ),
                        border: Border.all(
                          color: const Color(0xFF0D47A1).withOpacity(0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: facilityColor.withOpacity(0.25),
                            blurRadius: 20,
                            spreadRadius: 2,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.35),
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: AnimatedBuilder(
                                animation: fx.pulse,
                                builder: (context, _) => CustomPaint(
                                  painter: CircuitPatternPainter(
                                    color: facilityColor,
                                    animationValue: fx.pulse.value,
                                  ),
                                ),
                              ),
                            ),

                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                UtilityInfoBoxWidgets.header(
                                  facilityColor: facilityColor,
                                  facTitle: widget.headerTitle,
                                  isLoading: isLoading,
                                  hasError: hasError,
                                  err: err,
                                ),

                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(2),
                                    child:
                                        (data == null || (data.cates.isEmpty))
                                        ? _TreeEmptyState(
                                            hasError: hasError,
                                            err: err,
                                          )
                                        : ScrollConfiguration(
                                            behavior:
                                                const _NoGlowScrollBehavior(),
                                            child: ListView.separated(
                                              controller: _scroll,
                                              padding: EdgeInsets.zero,
                                              itemCount: data.cates.length,
                                              separatorBuilder: (_, __) =>
                                                  const SizedBox(height: 4),
                                              itemBuilder: (_, i) => _CateCard(
                                                cate: data.cates[i],
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _TreeEmptyState extends StatelessWidget {
  final bool hasError;
  final Object? err;

  const _TreeEmptyState({required this.hasError, required this.err});

  @override
  Widget build(BuildContext context) {
    if (hasError) {
      return Center(
        child: Text(
          'API error: $err',
          style: TextStyle(color: Colors.red.withOpacity(0.9), fontSize: 12),
        ),
      );
    }
    return Center(
      child: Text(
        'No data',
        style: TextStyle(color: Colors.white.withOpacity(0.78), fontSize: 12),
      ),
    );
  }
}

class _CateCard extends StatelessWidget {
  final CateGroup cate;

  const _CateCard({required this.cate});

  @override
  Widget build(BuildContext context) {
    IconData icon = Icons.sensors;
    Color color = Colors.lightBlueAccent;

    if (cate.cate.contains('Electricity')) {
      icon = Icons.flash_on;
      color = Colors.orangeAccent;
    } else if (cate.cate.contains('water') || cate.cate.contains('volume')) {
      icon = Icons.water_drop_outlined;
      color = Colors.blueAccent;
    } else if (cate.cate.contains('air') || cate.cate.contains('compress')) {
      icon = Icons.air;
      color = Colors.cyanAccent;
    }
    // flatten signals
    final signals = <SignalNode>[];
    for (final bd in cate.boxDevices) {
      signals.addAll(bd.signals);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.35)),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  cate.cate,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          ...signals.map((s) => _SignalRow(node: s)),
        ],
      ),
    );
  }
}

class _SignalRow extends StatelessWidget {
  final SignalNode node;

  const _SignalRow({required this.node});

  String _name() {
    final n = (node.nameVi?.trim().isNotEmpty == true)
        ? node.nameVi!.trim()
        : (node.nameEn?.trim().isNotEmpty == true)
        ? node.nameEn!.trim()
        : node.plcAddress;
    return n;
  }

  String _valueText() {
    if (node.points.isEmpty) return '--';
    final v = node.points.last.value;

    // gọn đẹp hơn
    final abs = v.abs();
    String numStr;
    if (abs >= 1000) {
      numStr = v.toStringAsFixed(1);
    } else if (abs >= 100) {
      numStr = v.toStringAsFixed(2);
    } else if (abs >= 10) {
      numStr = v.toStringAsFixed(2);
    } else {
      numStr = v.toStringAsFixed(3);
    }

    final u = (node.unit ?? '').trim();
    if (u.isEmpty) return numStr;
    return '$numStr $u'; // ✅ có khoảng trắng cho đẹp
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            _name(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.80),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.18),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: Text(
            _valueText(),
            style: TextStyle(
              color: Colors.white.withOpacity(0.95),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _NoGlowScrollBehavior extends ScrollBehavior {
  const _NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}

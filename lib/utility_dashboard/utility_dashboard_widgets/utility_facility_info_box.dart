import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utility_state/latest_provider.dart';
import '../../widgets/facility_info_box.dart';
import '../utility_dashboard_common/info_box/utility_info_box_fx.dart';
import '../utility_dashboard_common/info_box/utility_info_box_widgets.dart';
import '../utility_dashboard_common/utility_fac_style.dart';

class UtilityFacilityInfoBox extends StatefulWidget {
  final double width;
  final double? height;

  final String? facId;
  final String? scadaId;
  final String? cate;
  final String? boxDeviceId;
  final List<String>? cateIds;

  const UtilityFacilityInfoBox({
    super.key,
    this.facId,
    this.scadaId,
    this.cate,
    this.boxDeviceId,
    this.cateIds,
    this.width = 360,
    this.height = 300,
  });

  @override
  State<UtilityFacilityInfoBox> createState() => _UtilityFacilityInfoBoxState();
}

class _UtilityFacilityInfoBoxState extends State<UtilityFacilityInfoBox>
    with TickerProviderStateMixin {
  late final UtilityInfoBoxFx fx;

  // ✅ quan trọng: init ngay, không để late String _key; bị dùng trước
  late String _key;

  // ✅ thêm
  final ScrollController _scroll = ScrollController();
  Timer? _autoTimer;

  void _startAutoScroll() {
    _autoTimer?.cancel();
    if (!_scroll.hasClients) return;

    double dir = 1; // 1 = xuống, -1 = lên
    _autoTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted || !_scroll.hasClients) return;

      final max = _scroll.position.maxScrollExtent;
      if (max <= 0) return;

      final next = (_scroll.offset + dir * 80).clamp(0.0, max);

      await _scroll.animateTo(
        next,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
      );

      // chạm đáy thì đảo chiều
      if (next >= max - 1) dir = -1;
      if (next <= 1) dir = 1;
    });
  }

  String _buildKey() {
    // ✅ build key không cần context => gọi được trong initState
    // nếu bạn muốn normalize cateIds giống provider thì làm ở đây
    final ids =
        (widget.cateIds ?? [])
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList()
          ..sort();

    return 'fac=${(widget.facId ?? '').trim()}'
        '|scada=${(widget.scadaId ?? '').trim()}'
        '|cate=${(widget.cate ?? '').trim()}'
        '|dev=${(widget.boxDeviceId ?? '').trim()}'
        '|cateIds=${ids.join(",")}';
  }

  void _registerAndFetch() {
    if (!mounted) return;
    final p = context.read<LatestProvider>();

    p.upsertRequest(
      key: _key,
      facId: widget.facId,
      scadaId: widget.scadaId,
      cate: widget.cate,
      boxDeviceId: widget.boxDeviceId,
      cateIds: widget.cateIds,
    );

    p.fetchKey(
      key: _key,
      facId: widget.facId,
      scadaId: widget.scadaId,
      cate: widget.cate,
      boxDeviceId: widget.boxDeviceId,
      cateIds: widget.cateIds,
    );
  }

  @override
  void initState() {
    super.initState();
    fx = UtilityInfoBoxFx(this)..init();

    // ✅ set _key ngay lập tức => build() không crash
    _key = _buildKey();

    // ✅ register + fetch cần provider/context => để postFrame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _registerAndFetch();
    });
  }

  @override
  void didUpdateWidget(covariant UtilityFacilityInfoBox oldWidget) {
    super.didUpdateWidget(oldWidget);

    final filterChanged =
        oldWidget.facId != widget.facId ||
        oldWidget.scadaId != widget.scadaId ||
        oldWidget.cate != widget.cate ||
        oldWidget.boxDeviceId != widget.boxDeviceId ||
        (oldWidget.cateIds?.join(',') != widget.cateIds?.join(','));

    if (!filterChanged) return;

    // ✅ tạo key mới ngay
    _key = _buildKey();

    // ✅ gọi provider sau frame (tránh setState trong build phase)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _registerAndFetch();
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
    return Consumer<LatestProvider>(
      builder: (context, p, _) {
        // ✅ giờ _key luôn có giá trị
        final all = p.getRows(_key);
        final rows = all.take(4).toList();
        final err = p.getError(_key);

        final hasError = err != null;
        final isLoading = rows.isEmpty && !hasError;

        final facTitle = UtilityFacStyle.resolveFacTitle(
          rows: all,
          fallbackFacId: widget.facId,
        );

        final facilityColor = UtilityFacStyle.colorFromFac(facTitle);

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
                      height: widget.height ?? 270,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF1A237E).withOpacity(0.3),
                            const Color(0xFF0D47A1).withOpacity(0.3),
                          ],
                        ),
                        border: Border.all(
                          color: const Color(0xFF0D47A1).withOpacity(0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: facilityColor.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
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
                                  facTitle: facTitle,
                                  isLoading: isLoading,
                                  hasError: hasError,
                                  err: err,
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      4,
                                      6,
                                      4,
                                      4,
                                    ),
                                    child: rows.isEmpty
                                        ? UtilityInfoBoxWidgets.emptyState(
                                            hasError: hasError,
                                            err: err,
                                          )
                                        : ScrollConfiguration(
                                            behavior:
                                                const _NoGlowScrollBehavior(),
                                            child: GridView.builder(
                                              controller: _scroll,
                                              padding: EdgeInsets.zero,
                                              gridDelegate:
                                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                                    crossAxisCount: 2,
                                                    // ✅ 2 cột => show nhiều item
                                                    crossAxisSpacing: 8,
                                                    mainAxisSpacing: 8,
                                                    childAspectRatio:
                                                        3.2, // ✅ pill thấp
                                                  ),
                                              itemCount: rows.length,
                                              itemBuilder: (_, i) =>
                                                  UtilityInfoBoxWidgets.latestChip(
                                                    rows[i],
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

class _NoGlowScrollBehavior extends ScrollBehavior {
  const _NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}

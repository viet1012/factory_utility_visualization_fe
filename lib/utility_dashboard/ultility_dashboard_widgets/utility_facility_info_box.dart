import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utility_state/latest_provider.dart';
import '../../widgets/facility_info_box.dart';
import '../ultility_dashboard_common/info_box/utility_info_box_fx.dart';
import '../ultility_dashboard_common/info_box/utility_info_box_widgets.dart';
import '../ultility_dashboard_common/utility_fac_style.dart';

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
    this.width = 260,
    this.height = 270,
  });

  @override
  State<UtilityFacilityInfoBox> createState() => _UtilityFacilityInfoBoxState();
}

class _UtilityFacilityInfoBoxState extends State<UtilityFacilityInfoBox>
    with TickerProviderStateMixin {
  late final UtilityInfoBoxFx fx;
  late String _key;

  @override
  void initState() {
    super.initState();
    fx = UtilityInfoBoxFx(this)..init();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<LatestProvider>();

      _key = p.buildKey(
        facId: widget.facId,
        scadaId: widget.scadaId,
        cate: widget.cate,
        boxDeviceId: widget.boxDeviceId,
        cateIds: widget.cateIds,
      );

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

    final p = context.read<LatestProvider>();
    _key = p.buildKey(
      facId: widget.facId,
      scadaId: widget.scadaId,
      cate: widget.cate,
      boxDeviceId: widget.boxDeviceId,
      cateIds: widget.cateIds,
    );

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
  void dispose() {
    fx.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LatestProvider>(
      builder: (context, p, _) {
        final all = p.getRows(_key);
        final rows = all.take(3).toList();
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
                                    padding: const EdgeInsets.all(8.0),
                                    child: rows.isEmpty
                                        ? UtilityInfoBoxWidgets.emptyState(
                                            hasError: hasError,
                                            err: err,
                                          )
                                        : Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceEvenly,
                                            children: rows
                                                .map(
                                                  UtilityInfoBoxWidgets
                                                      .latestRow,
                                                )
                                                .toList(),
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

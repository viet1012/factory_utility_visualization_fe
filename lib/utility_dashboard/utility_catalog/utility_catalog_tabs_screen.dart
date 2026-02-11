import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utility_models/f2_utility_scada_box.dart';
import '../../utility_models/response/utility_catalog.dart';
import '../../utility_models/utility_facade_service.dart';
import '../../utility_state/latest_provider.dart';
import '../utility_dashboard_common/industrial_tab_bar.dart';
import 'utility_catalog_widget.dart';

class UtilityCatalogTabsScreen extends StatefulWidget {
  const UtilityCatalogTabsScreen({super.key});

  @override
  State<UtilityCatalogTabsScreen> createState() =>
      _UtilityCatalogTabsScreenState();
}

class _UtilityCatalogTabsScreenState extends State<UtilityCatalogTabsScreen> {
  late Future<UtilityCatalogDto> _future;

  UtilityFacadeService get _svc => context.read<UtilityFacadeService>();

  LatestProvider get _latest => context.read<LatestProvider>();

  @override
  void initState() {
    super.initState();
    // ⚠️ initState dùng context.read OK
    _future = _svc.getCatalogCached();
  }

  Future<void> _reload({bool force = false}) async {
    setState(() {
      _future = _svc.getCatalogCached(force: force);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UtilityCatalogDto>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Text(
              'API error: ${snap.error}',
              style: const TextStyle(color: Colors.redAccent),
            ),
          );
        }

        final catalog = snap.data!;
        final facTabs = _buildFacTabs(catalog.scadas);

        if (facTabs.isEmpty) {
          return const Center(child: Text('No SCADA data'));
        }

        return DefaultTabController(
          length: facTabs.length,
          child: Column(
            children: [
              // top actions
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: Row(
                  children: [
                    const Text(
                      'UTILITY CATALOG',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF9FB2D6),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      tooltip: 'Refresh (force)',
                      onPressed: () => _reload(force: true),
                      icon: const Icon(Icons.refresh),
                    ),
                    const Spacer(),
                    Text('Cache: 5s', style: TextStyle(color: Colors.white54)),
                  ],
                ),
              ),

              IndustrialTabBar(
                tabs: facTabs
                    .map((f) => IndustrialTabItem(text: f, icon: Icons.factory))
                    .toList(),
              ),

              Expanded(
                child: TabBarView(
                  children: facTabs.map((fac) {
                    final cateTabs = _buildCateTabsForFac(catalog, fac);

                    return DefaultTabController(
                      length: cateTabs.isEmpty ? 1 : cateTabs.length,
                      child: Column(
                        children: [
                          if (cateTabs.isNotEmpty)
                            TabBar(
                              isScrollable: true,
                              tabs: cateTabs.map((c) => Tab(text: c)).toList(),
                            )
                          else
                            const Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('No category for this FAC'),
                            ),

                          Expanded(
                            child: (cateTabs.isEmpty)
                                ? UtilityCatalogWidget(
                                    catalog: catalog,
                                    fac: fac,
                                    cate: null,
                                    latestProvider:
                                        _latest, // ✅ lấy từ Provider
                                  )
                                : TabBarView(
                                    children: cateTabs.map((cate) {
                                      return UtilityCatalogWidget(
                                        catalog: catalog,
                                        fac: fac,
                                        cate: cate,
                                        latestProvider: _latest, // ✅
                                      );
                                    }).toList(),
                                  ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<String> _buildFacTabs(List<ScadaDto> scadas) {
    final set = <String>{};
    for (final s in scadas) {
      final f = s.fac.trim();
      if (f.isNotEmpty) set.add(f);
    }
    final out = set.toList()..sort();
    return out;
  }

  List<String> _buildCateTabsForFac(UtilityCatalogDto catalog, String fac) {
    final scadaIds = catalog.scadas
        .where((s) => s.fac == fac)
        .map((s) => s.scadaId)
        .toSet();

    final set = <String>{};
    for (final ch in catalog.channels) {
      if (scadaIds.contains(ch.scadaId)) {
        final c = ch.cate.trim();
        if (c.isNotEmpty) set.add(c);
      }
    }
    final out = set.toList()..sort();
    return out;
  }
}

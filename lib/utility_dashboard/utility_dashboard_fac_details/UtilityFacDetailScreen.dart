import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utility_models/response/latest_record.dart';
import '../../utility_models/utility_facade_service.dart';
import '../../utility_state/FacLatestDetailProvider.dart';

class UtilityFacDetailScreen extends StatelessWidget {
  final String facId;
  final UtilityFacadeService svc;

  const UtilityFacDetailScreen({
    super.key,
    required this.facId,
    required this.svc,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final p = FacLatestDetailProvider(svc: svc, facId: facId);
        p.fetch();
        p.startPolling(const Duration(seconds: 10));
        return p;
      },
      child: _FacDetailBody(facId: facId),
    );
  }
}

class _FacDetailBody extends StatefulWidget {
  final String facId;

  const _FacDetailBody({required this.facId});

  @override
  State<_FacDetailBody> createState() => _FacDetailBodyState();
}

class _FacDetailBodyState extends State<_FacDetailBody> {
  String q = '';

  int _addrNum(String s) {
    final m = RegExp(r'\d+').firstMatch(s);
    return m == null ? 0 : int.parse(m.group(0)!);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<FacLatestDetailProvider>();

    final filtered = p.rows.where((e) {
      if (q.trim().isEmpty) return true;
      final s = q.toLowerCase().trim();
      return e.boxDeviceId.toLowerCase().contains(s) ||
          e.plcAddress.toLowerCase().contains(s) ||
          (e.boxId ?? '').toLowerCase().contains(s) ||
          (e.scadaId ?? '').toLowerCase().contains(s) ||
          (e.cateId ?? '').toLowerCase().contains(s) ||
          (e.cate ?? '').toLowerCase().contains(s) ||
          (e.fac ?? '').toLowerCase().contains(s);
    }).toList();

    // ✅ group by boxDeviceId (gom address chung 1 device)
    final devGroups = <String, List<LatestRecordDto>>{};
    for (final r in filtered) {
      devGroups.putIfAbsent(r.boxDeviceId, () => []).add(r);
    }
    final devIds = devGroups.keys.toList()..sort();

    final last = p.lastUpdated;
    final lastText = last == null
        ? '—'
        : '${last.hour.toString().padLeft(2, '0')}:${last.minute.toString().padLeft(2, '0')}:${last.second.toString().padLeft(2, '0')}';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0a0e27), Color(0xFF1a1a2e), Color(0xFF16213e)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(
                title: 'FAC ${widget.facId}',
                subtitle: 'Last update: $lastText',
                onBack: () => Navigator.pop(context),
                onRefresh: () =>
                    context.read<FacLatestDetailProvider>().fetch(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: _SearchField(
                  hint: 'Search device / address / box / scada / cateId...',
                  onChanged: (v) => setState(() => q = v),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () =>
                      context.read<FacLatestDetailProvider>().fetch(),
                  child: Builder(
                    builder: (context) {
                      if (p.loading && p.rows.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (p.error != null && p.rows.isEmpty) {
                        return ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 80),
                            _ErrorState(
                              err: p.error,
                              onRetry: () => context
                                  .read<FacLatestDetailProvider>()
                                  .fetch(),
                            ),
                          ],
                        );
                      }

                      if (devIds.isEmpty) {
                        return ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [SizedBox(height: 80), _EmptyState()],
                        );
                      }

                      return ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: devIds.length,
                        itemBuilder: (_, i) {
                          final devId = devIds[i];
                          final rows = devGroups[devId]!
                            ..sort(
                              (a, b) => _addrNum(
                                a.plcAddress,
                              ).compareTo(_addrNum(b.plcAddress)),
                            );
                          return _DeviceGroupCard(deviceId: devId, rows: rows);
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  const _TopBar({
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRefresh,
            icon: Icon(Icons.refresh, color: Colors.white.withOpacity(0.9)),
            tooltip: 'Refresh',
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.bolt,
                  size: 16,
                  color: Colors.white.withOpacity(0.85),
                ),
                const SizedBox(width: 6),
                Text(
                  'LATEST',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 0.5,
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

class _SearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;

  const _SearchField({required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: Colors.white.withOpacity(0.7)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.45)),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceGroupCard extends StatefulWidget {
  final String deviceId;
  final List<LatestRecordDto> rows;

  const _DeviceGroupCard({
    super.key,
    required this.deviceId,
    required this.rows,
  });

  @override
  State<_DeviceGroupCard> createState() => _DeviceGroupCardState();
}

class _DeviceGroupCardState extends State<_DeviceGroupCard>
    with SingleTickerProviderStateMixin {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final rows = widget.rows;
    final first = rows.first;

    final boxId = (first.boxId ?? '').trim();
    final scadaId = (first.scadaId ?? '').trim();
    final cateId = (first.cateId ?? '').trim();
    final cate = (first.cate ?? '').trim();

    final values = rows.map((e) => (e.value ?? 0).toDouble()).toList();
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final avgV = values.fold<double>(0, (s, v) => s + v) / values.length;

    final latestTime = rows
        .map((e) => e.recordedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);

    // preview 4 rows thôi để card thấp
    final preview = rows.take(4).toList();

    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.055),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.30),
            blurRadius: 12,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => expanded = !expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                children: [
                  // ===== TOP ROW (1 dòng) =====
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.deviceId,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      _BadgeDense(
                        text: cate.isEmpty ? 'Electricity' : cate,
                        icon: Icons.bolt,
                      ),
                      const SizedBox(width: 10),

                      Text(
                        _fmtTime(latestTime),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.65),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        expanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.white.withOpacity(0.75),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // ===== META (1 dòng, nhỏ) + KPI inline =====
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'BOX:$boxId  •  SCADA:$scadaId  •  CATE:$cateId',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.62),
                            fontWeight: FontWeight.w800,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _KpiInline(label: 'MIN', value: minV),
                      const SizedBox(width: 10),
                      _KpiInline(label: 'AVG', value: avgV),
                      const SizedBox(width: 10),
                      _KpiInline(label: 'MAX', value: maxV),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // ===== COLLAPSED: preview rows (rất thấp) =====
                  if (!expanded) ...[_AddrPreviewGrid(rows: preview)],

                  // ===== EXPANDED: full table =====
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    child: expanded
                        ? Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: _AddrTableDense(rows: rows),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _fmtTime(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    final s = d.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

// --- KPI row separated to avoid const issues above ---
class _KpiRow extends StatelessWidget {
  final double minV;
  final double avgV;
  final double maxV;

  const _KpiRow({required this.minV, required this.avgV, required this.maxV});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.black.withOpacity(0.18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _KpiCell(label: 'MIN', value: minV.toStringAsFixed(2)),
          ),
          _VLine(),
          Expanded(
            child: _KpiCell(label: 'AVG', value: avgV.toStringAsFixed(2)),
          ),
          _VLine(),
          Expanded(
            child: _KpiCell(label: 'MAX', value: maxV.toStringAsFixed(2)),
          ),
        ],
      ),
    );
  }
}

class _AddrPreviewGrid extends StatelessWidget {
  final List<LatestRecordDto> rows;

  const _AddrPreviewGrid({required this.rows});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rows.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8, // ✅ 4 cột để cực thấp
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 3.3,
      ),
      itemBuilder: (_, i) {
        final r = rows[i];
        final v = (r.value ?? 0).toDouble();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.black.withOpacity(0.18),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              Text(
                r.plcAddress,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  v.toStringAsFixed(2),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AddrTableDense extends StatelessWidget {
  final List<LatestRecordDto> rows;

  const _AddrTableDense({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withOpacity(0.04),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'ADDRESS',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.60),
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                Text(
                  'VALUE',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.60),
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.white.withOpacity(0.10)),
          ...rows.map((r) => _AddrRowDense(row: r)),
        ],
      ),
    );
  }
}

class _AddrRowDense extends StatelessWidget {
  final LatestRecordDto row;

  const _AddrRowDense({required this.row});

  @override
  Widget build(BuildContext context) {
    final v = (row.value ?? 0).toDouble();

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              row.plcAddress,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                v.toStringAsFixed(3),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                _fmtTime(row.recordedAt),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.50),
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmtTime(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    final s = d.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

class _BadgeDense extends StatelessWidget {
  final String text;
  final IconData icon;

  const _BadgeDense({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withOpacity(0.07),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white.withOpacity(0.85)),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontWeight: FontWeight.w900,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiInline extends StatelessWidget {
  final String label;
  final double value;

  const _KpiInline({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontFamily: null),
        children: [
          TextSpan(
            text: '$label ',
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontWeight: FontWeight.w900,
              fontSize: 10,
              letterSpacing: 0.8,
            ),
          ),
          TextSpan(
            text: value.toStringAsFixed(2),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiCell extends StatelessWidget {
  final String label;
  final String value;

  const _KpiCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.60),
            fontWeight: FontWeight.w900,
            fontSize: 10,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _VLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: Colors.white.withOpacity(0.10),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object? err;
  final VoidCallback onRetry;

  const _ErrorState({required this.err, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 44,
              color: Colors.white.withOpacity(0.85),
            ),
            const SizedBox(height: 10),
            const Text(
              'Load failed',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              err.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.65),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 44,
            color: Colors.white.withOpacity(0.85),
          ),
          const SizedBox(height: 10),
          const Text(
            'No data',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pull to refresh',
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

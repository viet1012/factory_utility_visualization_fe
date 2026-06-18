import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../utility_dashboard/utility_dashboard_overview/utility_dashboard_overview_api/utility_dashboard_overview_api.dart';
import '../utility_dashboard/utility_dashboard_overview/utility_dashboard_overview_widgets/chart_state_widgets.dart';

const kBg = Color(0xff0f172a);
const kCard = Color(0xff111827);
const kCard2 = Color(0xff1e293b);
const kBorder = Color(0xff334155);
const kText = Color(0xfff8fafc);
const kSubText = Color(0xffcbd5e1);
const kBlue = Color(0xff38bdf8);
const kGreen = Color(0xff22c55e);
const kOrange = Color(0xfff97316);
const kRed = Color(0xffef4444);

class SignalHealthMatrixScreen extends StatefulWidget {
  const SignalHealthMatrixScreen({super.key});

  @override
  State<SignalHealthMatrixScreen> createState() =>
      _SignalHealthMatrixScreenState();
}

class _SignalHealthMatrixScreenState extends State<SignalHealthMatrixScreen> {
  String facFilter = 'ALL';
  String cateFilter = 'ALL';
  String scadaFilter = 'ALL';
  String boxDeviceFilter = 'ALL';
  String keyword = '';

  static const Duration _pollInterval = Duration(minutes: 1);
  static const Duration _requestTimeout = Duration(seconds: 90);

  bool loading = true;
  bool refreshing = false;
  bool _isFetching = false;
  Object? error;

  Timer? _refreshTimer;

  List<Map<String, dynamic>> data = [];
  Map<String, dynamic>? selected;

  @override
  void initState() {
    super.initState();
    _load();
    _startPolling();
  }

  void _startPolling() {
    _refreshTimer?.cancel();

    _refreshTimer = Timer.periodic(_pollInterval, (_) {
      if (!_isFetching && mounted) {
        _load(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (_isFetching || !mounted) return;

    _isFetching = true;

    if (!silent && data.isEmpty) {
      setState(() {
        loading = true;
        error = null;
      });
    }

    if (silent) {
      setState(() => refreshing = true);
    }

    final oldBoxDeviceId = selected?['boxDeviceId'];

    try {
      final api = context.read<UtilityDashboardOverviewApi>();

      final newData = await api.getSignalHealthMatrix().timeout(
        _requestTimeout,
      );

      final newSelected = _findSelectedDevice(
        newData,
        oldBoxDeviceId?.toString(),
      );

      if (!mounted) return;

      setState(() {
        data = newData;
        selected = newSelected;
        loading = false;
        refreshing = false;
        error = null;
      });
    } on TimeoutException catch (e) {
      _handleLoadError(e, '[TIMEOUT]');
    } on DioException catch (e) {
      _handleLoadError(e, '[DIO] ${e.type}');
    } catch (e) {
      _handleLoadError(e, '[ERROR]');
    } finally {
      _isFetching = false;
    }
  }

  void _handleLoadError(Object e, String tag) {
    debugPrint('$tag $e');

    if (!mounted) return;

    setState(() {
      loading = false;
      refreshing = false;

      if (data.isEmpty) {
        error = e;
      }
    });
  }

  Map<String, dynamic>? _findSelectedDevice(
    List<Map<String, dynamic>> newData,
    String? oldBoxDeviceId,
  ) {
    if (newData.isEmpty) return null;

    if (oldBoxDeviceId != null) {
      for (final row in newData) {
        if ('${row['boxDeviceId']}' == oldBoxDeviceId) {
          return row;
        }
      }
    }

    return newData.first;
  }

  List<Map<String, dynamic>> get filteredData {
    return data.where((e) {
      final facOk = facFilter == 'ALL' || e['fac'] == facFilter;
      final cateOk = cateFilter == 'ALL' || e['cate'] == cateFilter;
      final scadaOk = scadaFilter == 'ALL' || e['scadaId'] == scadaFilter;
      final boxOk =
          boxDeviceFilter == 'ALL' || e['boxDeviceId'] == boxDeviceFilter;

      final text = keyword.toLowerCase();
      final searchOk =
          text.isEmpty ||
          '${e['fac']}'.toLowerCase().contains(text) ||
          '${e['cate']}'.toLowerCase().contains(text) ||
          '${e['scadaId']}'.toLowerCase().contains(text) ||
          '${e['boxDeviceId']}'.toLowerCase().contains(text);

      return facOk && cateOk && scadaOk && boxOk && searchOk;
    }).toList();
  }

  List<String> get facOptions => [
    'ALL',
    ...data.map((e) => '${e['fac']}').toSet(),
  ];

  List<String> get cateOptions => [
    'ALL',
    ...data.map((e) => '${e['cate']}').toSet(),
  ];

  List<String> get scadaOptions => [
    'ALL',
    ...data.map((e) => '${e['scadaId']}').toSet(),
  ];

  List<String> get boxDeviceOptions => [
    'ALL',
    ...data.map((e) => '${e['boxDeviceId']}').toSet(),
  ];

  int get totalFac => data.map((e) => e['fac']).toSet().length;

  int get totalBoxDevice => data.length;

  int get totalRegister => data.fold(
    0,
    (sum, e) => sum + ((e['totalRegisters'] ?? 0) as num).toInt(),
  );

  int get totalNgRegister =>
      data.fold(0, (sum, e) => sum + ((e['ngRegisters'] ?? 0) as num).toInt());

  String get lastUpdated {
    String latest = '-';

    for (final device in data) {
      for (final signal in device['signals'] ?? []) {
        final time = '${signal['recordedAt'] ?? ''}';
        if (time.isNotEmpty && (latest == '-' || time.compareTo(latest) > 0)) {
          latest = time;
        }
      }
    }

    return latest;
  }

  int get filteredTotalFac => filteredData.map((e) => e['fac']).toSet().length;

  int get filteredTotalBoxDevice => filteredData.length;

  int get filteredTotalRegister => filteredData.fold(
    0,
    (sum, e) => sum + ((e['totalRegisters'] ?? 0) as num).toInt(),
  );

  int get filteredTotalNgRegister => filteredData.fold(
    0,
    (sum, e) => sum + ((e['ngRegisters'] ?? 0) as num).toInt(),
  );

  Widget _body() {
    final rows = filteredData;

    if (loading && data.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (error != null && data.isEmpty) {
      return ChartApiErrorState(color: Colors.redAccent, onRetry: _load);
    }

    if (data.isEmpty) {
      return const EmptyChartState(
        title: 'No Signal Health Data',
        message: 'No signal health matrix data found.',
      );
    }

    return Padding(
      padding: const EdgeInsets.all(6),
      child: Column(
        children: [
          _Header(
            lastUpdated: refreshing ? 'Refreshing...' : lastUpdated,
            onRefresh: () => _load(silent: true),
          ),
          const SizedBox(height: 16),
          _KpiRow(
            totalFac: rows.map((e) => e['fac']).toSet().length,
            totalBoxDevice: rows.length,
            totalRegister: rows.fold(
              0,
              (sum, e) => sum + ((e['totalRegisters'] ?? 0) as num).toInt(),
            ),
            totalNgRegister: rows.fold(
              0,
              (sum, e) => sum + ((e['ngRegisters'] ?? 0) as num).toInt(),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 7,
                  child: Column(
                    children: [
                      _FilterRow(
                        facOptions: facOptions,
                        cateOptions: cateOptions,
                        scadaOptions: scadaOptions,
                        boxDeviceOptions: boxDeviceOptions,
                        facValue: facFilter,
                        cateValue: cateFilter,
                        scadaValue: scadaFilter,
                        boxDeviceValue: boxDeviceFilter,
                        onFacChanged: (v) => setState(() => facFilter = v!),
                        onCateChanged: (v) => setState(() => cateFilter = v!),
                        onScadaChanged: (v) => setState(() => scadaFilter = v!),
                        onBoxDeviceChanged: (v) =>
                            setState(() => boxDeviceFilter = v!),
                        onSearchChanged: (v) => setState(() => keyword = v),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _MatrixTable(
                          data: rows,
                          selected: selected,
                          onSelect: (item) {
                            setState(() => selected = item);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 4,
                  child: selected == null
                      ? const SizedBox()
                      : _DetailPanel(device: selected!),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: kBg, body: _body());
  }
}

class _Header extends StatelessWidget {
  final String lastUpdated;
  final VoidCallback onRefresh;

  const _Header({required this.lastUpdated, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            color: kBlue.withOpacity(.18),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBlue.withOpacity(.35)),
          ),
          child: const Icon(Icons.monitor_heart, color: kBlue),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Signal Health Matrix',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: kText,
                ),
              ),
              Text(
                'Tổng hợp tình trạng Device và Register',
                style: TextStyle(color: kSubText),
              ),
            ],
          ),
        ),
        Text(
          'Last updated: $lastUpdated',
          style: const TextStyle(color: kSubText),
        ),
        const SizedBox(width: 16),
        OutlinedButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
          style: OutlinedButton.styleFrom(
            foregroundColor: kBlue,
            side: BorderSide(color: kBlue.withOpacity(.45)),
          ),
        ),
      ],
    );
  }
}

class _KpiRow extends StatelessWidget {
  final int totalFac;
  final int totalBoxDevice;
  final int totalRegister;
  final int totalNgRegister;

  const _KpiRow({
    required this.totalFac,
    required this.totalBoxDevice,
    required this.totalRegister,
    required this.totalNgRegister,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _KpiCard(
          title: 'FACILITY',
          value: totalFac,
          subtitle: 'Tổng số FAC',
          icon: Icons.factory,
          color: const Color(0xff2563eb),
        ),
        const SizedBox(width: 16),
        _KpiCard(
          title: 'BOX DEVICE',
          value: totalBoxDevice,
          subtitle: 'Tổng số BoxDevice',
          icon: Icons.memory,
          color: const Color(0xff7c3aed),
        ),
        const SizedBox(width: 16),
        _KpiCard(
          title: 'REGISTER',
          value: totalRegister,
          subtitle: 'Tổng số Register',
          icon: Icons.menu_book,
          color: const Color(0xfff97316),
        ),
        const SizedBox(width: 16),
        _KpiCard(
          title: 'NG REGISTER',
          value: totalNgRegister,
          subtitle: 'Tổng số Register lỗi',
          icon: Icons.warning_amber_rounded,
          color: const Color(0xffdc2626),
          danger: true,
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final int value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool danger;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 108,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: danger ? kRed.withOpacity(.10) : kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: danger ? kRed.withOpacity(.45) : kBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(color: color, fontWeight: FontWeight.w900),
                ),
                Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: kText,
                    height: 1.1,
                  ),
                ),
                Text(subtitle, style: const TextStyle(color: kSubText)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final List<String> facOptions;
  final List<String> cateOptions;
  final List<String> scadaOptions;
  final List<String> boxDeviceOptions;

  final String facValue;
  final String cateValue;
  final String scadaValue;
  final String boxDeviceValue;

  final ValueChanged<String?> onFacChanged;
  final ValueChanged<String?> onCateChanged;
  final ValueChanged<String?> onScadaChanged;
  final ValueChanged<String?> onBoxDeviceChanged;
  final ValueChanged<String> onSearchChanged;

  const _FilterRow({
    required this.facOptions,
    required this.cateOptions,
    required this.scadaOptions,
    required this.boxDeviceOptions,
    required this.facValue,
    required this.cateValue,
    required this.scadaValue,
    required this.boxDeviceValue,
    required this.onFacChanged,
    required this.onCateChanged,
    required this.onScadaChanged,
    required this.onBoxDeviceChanged,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _FilterDropdown(
          value: facValue,
          items: facOptions,
          onChanged: onFacChanged,
        ),
        const SizedBox(width: 12),
        _FilterDropdown(
          value: cateValue,
          items: cateOptions,
          onChanged: onCateChanged,
        ),
        const SizedBox(width: 12),
        _FilterDropdown(
          value: scadaValue,
          items: scadaOptions,
          onChanged: onScadaChanged,
        ),
        const SizedBox(width: 12),
        _FilterDropdown(
          value: boxDeviceValue,
          items: boxDeviceOptions,
          onChanged: onBoxDeviceChanged,
          width: 260,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            onChanged: onSearchChanged,
            style: const TextStyle(color: kText),
            decoration: InputDecoration(
              hintText: 'Search device...',
              hintStyle: const TextStyle(color: kSubText),
              prefixIcon: const Icon(Icons.search, color: kSubText),
              filled: true,
              fillColor: kCard,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kBlue),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final double width;

  const _FilterDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    this.width = 180,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: kCard,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          dropdownColor: kCard,
          style: const TextStyle(
            color: kText,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          iconEnabledColor: kText,
          items: items.map((e) {
            return DropdownMenuItem<String>(
              value: e,
              child: Text(
                e,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: kText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _MatrixTable extends StatelessWidget {
  final List<dynamic> data;
  final Map<String, dynamic>? selected;
  final ValueChanged<Map<String, dynamic>> onSelect;

  const _MatrixTable({
    required this.data,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              color: kCard2,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: const Row(
              children: [
                _HeaderCell('Facility', flex: 1),
                _HeaderCell('Category', flex: 1),
                _HeaderCell('SCADA', flex: 1),
                _HeaderCell('Box Device ID', flex: 3),
                _HeaderCell('Total', flex: 1, center: true),
                _HeaderCell('NG', flex: 1, center: true),
                _HeaderCell('Status', flex: 1, center: true),
                SizedBox(width: 44),
              ],
            ),
          ),

          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(10),
              itemCount: data.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final row = data[index] as Map<String, dynamic>;
                final isSelected = identical(row, selected);
                final isNg = row['status'] == 'NG';

                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onSelect(row),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? kBlue.withOpacity(.14)
                          : isNg
                          ? kOrange.withOpacity(.10)
                          : kCard,
                      border: Border.all(
                        color: isSelected
                            ? kBlue
                            : isNg
                            ? kOrange.withOpacity(.45)
                            : kBorder,
                        width: isSelected ? 1.6 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        _BodyCell('${row['fac']}', flex: 1, bold: true),
                        _BodyCell(
                          '${row['cate']}',
                          flex: 1,
                          child: _CategoryBadge('${row['cate']}'),
                        ),
                        _BodyCell(
                          '${row['scadaId']}',
                          flex: 1,
                          child: _SoftBadge('${row['scadaId']}'),
                        ),
                        _BodyCell('${row['boxDeviceId']}', flex: 3, bold: true),
                        _BodyCell(
                          '${row['totalRegisters']}',
                          flex: 1,
                          center: true,
                          child: _RegisterNumber(
                            '${row['totalRegisters']}',
                            color: kText,
                          ),
                        ),
                        _BodyCell(
                          '${row['ngRegisters']}',
                          flex: 1,
                          center: true,
                          child: _RegisterNumber(
                            '${row['ngRegisters']}',
                            color: isNg
                                ? const Color(0xffdc2626)
                                : const Color(0xff16a34a),
                          ),
                        ),
                        _BodyCell(
                          '${row['status']}',
                          flex: 1,
                          center: true,
                          child: _StatusBadge('${row['status']}'),
                        ),
                        SizedBox(
                          width: 44,
                          child: Icon(
                            Icons.chevron_right,
                            color: isSelected
                                ? const Color(0xff2563eb)
                                : const Color(0xff94a3b8),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: kBorder)),
            ),
            child: Row(
              children: [
                Text(
                  'Hiển thị ${data.length} bản ghi',
                  style: const TextStyle(
                    color: Color(0xff64748b),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                const Text(
                  'Click vào dòng để xem chi tiết',
                  style: TextStyle(color: Color(0xff94a3b8), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final int flex;
  final bool center;

  const _HeaderCell(this.text, {required this.flex, this.center = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Align(
        alignment: center ? Alignment.center : Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(
            color: kSubText,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: .3,
          ),
        ),
      ),
    );
  }
}

class _BodyCell extends StatelessWidget {
  final String text;
  final int flex;
  final bool center;
  final bool bold;
  final Widget? child;

  const _BodyCell(
    this.text, {
    required this.flex,
    this.center = false,
    this.bold = false,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Align(
        alignment: center ? Alignment.center : Alignment.centerLeft,
        child:
            child ??
            Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: kText,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
      ),
    );
  }
}

class _RegisterNumber extends StatelessWidget {
  final String value;
  final Color color;

  const _RegisterNumber(this.value, {required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final String text;

  const _CategoryBadge(this.text);

  @override
  Widget build(BuildContext context) {
    final isElectric = text.toLowerCase().contains('electric');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isElectric ? const Color(0xfffff7ed) : const Color(0xffeff6ff),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isElectric ? const Color(0xffea580c) : const Color(0xff2563eb),
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _SoftBadge extends StatelessWidget {
  final String text;

  const _SoftBadge(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xfff1f5f9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xff334155),
          fontWeight: FontWeight.w900,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _DetailPanel extends StatelessWidget {
  final Map<String, dynamic> device;

  const _DetailPanel({required this.device});

  @override
  Widget build(BuildContext context) {
    final signals = device['signals'] as List? ?? [];

    return Container(
      height: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Register Details',
                style: TextStyle(
                  color: kText,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                '${signals.length} signals',
                style: const TextStyle(
                  color: kSubText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              itemCount: signals.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return _SignalMetricCard(signal: signals[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalMetricCard extends StatelessWidget {
  final dynamic signal;

  const _SignalMetricCard({required this.signal});

  @override
  Widget build(BuildContext context) {
    final status = '${signal['status']}';
    final isOk = status == 'OK';
    final borderColor = isOk
        ? kGreen.withOpacity(.25)
        : kOrange.withOpacity(.55);
    final bgColor = isOk ? kCard2 : kOrange.withOpacity(.10);

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isOk ? Icons.check_circle : Icons.warning_amber_rounded,
                color: isOk ? kGreen : kOrange,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${signal['signalName']}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: kText,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _StatusBadge(status),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _MetaChip('PLC', '${signal['plcAddress']}'),
              const Spacer(),
              Text(
                _formatTime('${signal['recordedAt']}'),
                style: const TextStyle(
                  color: kSubText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ValueBox(
                  label: 'PREV',
                  value: '${signal['prevValue']}',
                  color: kText,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ValueBox(
                  label: 'CURRENT',
                  value: '${signal['currentValue']}',
                  color: isOk ? kGreen : kRed,
                  highlight: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ValueBox(
                  label: 'JUMP',
                  value: '${signal['jumpSize']}',
                  color: _jumpColor(signal['jumpSize']),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(.18),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kBorder),
            ),
            child: Text(
              '${signal['description']}',
              style: TextStyle(
                color: isOk ? kSubText : const Color(0xffffd28a),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Color _jumpColor(dynamic value) {
    final number = num.tryParse('$value') ?? 0;
    if (number == 0) return kSubText;
    if (number > 1000) return kRed;
    return kOrange;
  }

  static String _formatTime(String value) {
    if (value.length >= 19) {
      return value.substring(0, 19).replaceFirst('T', ' ');
    }
    return value;
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final String value;

  const _MetaChip(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: kSubText,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ValueBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool highlight;

  const _ValueBox({
    required this.label,
    required this.value,
    required this.color,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(highlight ? .16 : .09),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: color.withOpacity(.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(.85),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: highlight ? 22 : 20,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final isOk = status == 'OK';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isOk ? kGreen.withOpacity(.14) : kRed.withOpacity(.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOk ? kGreen.withOpacity(.55) : kRed.withOpacity(.55),
        ),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: isOk ? kGreen : kRed,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: kCard,
    border: Border.all(color: kBorder),
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(.25),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

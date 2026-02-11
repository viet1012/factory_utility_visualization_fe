// import 'dart:async';
// import 'dart:math';
//
// import 'package:factory_utility_visualization/utility_models/f2_utility_parameter_history.dart';
// import 'package:factory_utility_visualization/utility_models/f2_utility_parameter_master.dart';
// import 'package:factory_utility_visualization/utility_models/f2_utility_scada_box.dart';
// import 'package:factory_utility_visualization/utility_models/f2_utility_scada_channel.dart';
// import 'package:factory_utility_visualization/utility_models/request/utility_series_request.dart';
// import 'package:factory_utility_visualization/utility_models/utility_facade_service.dart';
// import 'package:factory_utility_visualization/utility_models/utility_mock_repository.dart';
// import 'package:flutter/material.dart';
// import 'package:syncfusion_flutter_charts/charts.dart';
//
// import 'ScadaLineageHelper.dart';
// import 'utility_catalog_widget.dart';
//
// class MockTablesPage extends StatefulWidget {
//   const MockTablesPage({super.key});
//
//   @override
//   State<MockTablesPage> createState() => _MockTablesPageState();
// }
//
// class _MockTablesPageState extends State<MockTablesPage> {
//   late final UtilityMockRepository repo;
//   late final UtilityFacadeService service;
//
//   late final Future<_MockTablesVM> _future;
//
//   @override
//   void initState() {
//     super.initState();
//     repo = UtilityMockRepository();
//     service = UtilityFacadeService(repo);
//
//     _future = _load(seed: 1);
//   }
//
//   Future<_MockTablesVM> _load({required int seed}) async {
//     final facTrees = await service.fetchFacTrees(seed: seed);
//     final boxes = await repo.fetchBoxes();
//     final channels = await repo.fetchChannels();
//     final masters = await repo.fetchMasters();
//     final latest = await repo.fetchLatestHistories(seed: seed);
//
//     return _MockTablesVM(
//       facTrees: facTrees,
//       boxes: boxes,
//       channels: channels,
//       masters: masters,
//       latest: latest,
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return FutureBuilder<_MockTablesVM>(
//       future: _future,
//       builder: (context, snap) {
//         if (!snap.hasData) {
//           return const Scaffold(
//             backgroundColor: Color(0xFF0B1220),
//             body: Center(child: CircularProgressIndicator()),
//           );
//         }
//
//         final vm = snap.data!;
//
//         return DefaultTabController(
//           length: 7,
//           child: Scaffold(
//             backgroundColor: const Color(0xFF0B1220),
//             appBar: AppBar(
//               backgroundColor: const Color(0xFF0E1729),
//               title: const Text(
//                 'Mock Data Tables',
//                 style: TextStyle(
//                   color: Colors.white70,
//                   fontWeight: FontWeight.w900,
//                 ),
//               ),
//               bottom: const TabBar(
//                 isScrollable: true,
//                 tabs: [
//                   Tab(text: 'UTILITY DASH'),
//                   Tab(text: 'FAC VIEW'),
//                   Tab(text: 'FAC VIEW TABLE'),
//                   Tab(text: 'SCADA BOX'),
//                   Tab(text: 'SCADA CHANNEL'),
//                   Tab(text: 'PARAM MASTER'),
//                   Tab(text: 'PARAM HISTORY'),
//                 ],
//               ),
//             ),
//             body: TabBarView(
//               children: [
//                 UtilityDashTab(facs: vm.facTrees, repo: repo),
//                 _FacViewTab(facs: vm.facTrees),
//                 ScadaTableSection(facs: vm.facTrees),
//                 _BoxesTab(boxes: vm.boxes),
//                 _ChannelsTab(channels: vm.channels),
//                 _MastersTab(masters: vm.masters),
//                 _HistoryTab(histories: vm.latest),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
// }
//
// class _LineageStep {
//   final String table; // tên bảng / model
//   final String keyHint; // keys
//   final String join; // mô tả join
//
//   const _LineageStep({
//     required this.table,
//     required this.keyHint,
//     required this.join,
//   });
// }
//
// class _LineageCard extends StatelessWidget {
//   final String title;
//   final List<_LineageStep> steps;
//
//   const _LineageCard({required this.title, required this.steps});
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: const Color(0xFF0B1220),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: const Color(0xFF1B2A44)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             title,
//             style: const TextStyle(
//               color: Colors.white,
//               fontWeight: FontWeight.w900,
//             ),
//           ),
//           const SizedBox(height: 10),
//
//           // chips tables
//           Wrap(
//             spacing: 8,
//             runSpacing: 8,
//             children: steps.map((s) {
//               return Container(
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 10,
//                   vertical: 6,
//                 ),
//                 decoration: BoxDecoration(
//                   color: const Color(0xFF0E1729),
//                   borderRadius: BorderRadius.circular(999),
//                   border: Border.all(color: const Color(0xFF1B2A44)),
//                 ),
//                 child: Text(
//                   '${s.table} (${s.keyHint})',
//                   style: const TextStyle(
//                     color: Color(0xFF9FB2D6),
//                     fontSize: 12,
//                     fontWeight: FontWeight.w700,
//                   ),
//                 ),
//               );
//             }).toList(),
//           ),
//
//           const SizedBox(height: 10),
//
//           // join descriptions
//           ...steps.map((s) {
//             return Padding(
//               padding: const EdgeInsets.only(bottom: 6),
//               child: Text(
//                 '• ${s.join}',
//                 style: const TextStyle(
//                   color: Color(0xFF9FB2D6),
//                   fontSize: 12,
//                   height: 1.25,
//                 ),
//               ),
//             );
//           }),
//         ],
//       ),
//     );
//   }
// }
//
// class _MockTablesVM {
//   final List<FacTree> facTrees;
//   final List<UtilityScadaBox> boxes;
//   final List<UtilityScadaChannel> channels;
//   final List<UtilityParameterMaster> masters;
//   final List<UtilityParameterHistory> latest;
//
//   _MockTablesVM({
//     required this.facTrees,
//     required this.boxes,
//     required this.channels,
//     required this.masters,
//     required this.latest,
//   });
// }
//
// /// ===================== TABS =====================
// class _FacViewTab extends StatelessWidget {
//   final List<FacTree> facs;
//
//   const _FacViewTab({required this.facs});
//
//   String fmtTime(DateTime? dt) {
//     if (dt == null) return '--';
//     return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
//         '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return ListView(
//       padding: const EdgeInsets.all(12),
//       children: [
//         _CardHeader(title: 'FAC VIEW (${facs.length})'),
//         const SizedBox(height: 10),
//
//         // ===== GLOBAL GUIDE + COPY SQL =====
//         ScadaLineageHelper.lineageCard(
//           title: 'GLOBAL DATA FLOW (FAC → BOX → DEVICE → PARAM → HISTORY)',
//           steps: ScadaLineageHelper.facSteps(),
//           sqlToCopy: ScadaLineageHelper.sqlJoinByParameterId,
//         ),
//
//         ...facs.map((fac) {
//           final totalBoxes = fac.boxes.length;
//           final totalDevices = fac.boxes.fold<int>(
//             0,
//             (s, b) => s + b.devices.length,
//           );
//           final totalParams = fac.boxes.fold<int>(
//             0,
//             (s, b) =>
//                 s + b.devices.fold<int>(0, (s2, d) => s2 + d.params.length),
//           );
//
//           return Container(
//             margin: const EdgeInsets.only(bottom: 10),
//             decoration: BoxDecoration(
//               color: const Color(0xFF0E1729),
//               borderRadius: BorderRadius.circular(14),
//               border: Border.all(color: const Color(0xFF1B2A44)),
//             ),
//             child: Theme(
//               data: Theme.of(context).copyWith(
//                 dividerColor: Colors.transparent,
//                 splashColor: Colors.transparent,
//                 highlightColor: Colors.transparent,
//               ),
//               child: ExpansionTile(
//                 collapsedIconColor: const Color(0xFF9FB2D6),
//                 iconColor: const Color(0xFF9FB2D6),
//                 title: Text(
//                   '${fac.facId} • ${fac.facName}',
//                   style: const TextStyle(
//                     color: Colors.white,
//                     fontWeight: FontWeight.w900,
//                   ),
//                 ),
//                 subtitle: Text(
//                   'Boxes: $totalBoxes • Devices: $totalDevices • Params: $totalParams',
//                   style: const TextStyle(color: Color(0xFF9FB2D6)),
//                 ),
//                 children: [
//                   // ===== FAC LOCAL GUIDE + COPY SQL =====
//                   ScadaLineageHelper.lineageCard(
//                     title: 'FAC LINEAGE (${fac.facId})',
//                     steps: ScadaLineageHelper.facSteps(),
//                     sqlToCopy: ScadaLineageHelper.sqlJoinByParameterId,
//                   ),
//
//                   ...fac.boxes.map((bt) {
//                     final b = bt.box;
//
//                     // types theo BOX
//                     final types =
//                         bt.devices.map((d) => d.channel.cate).toSet().toList()
//                           ..sort();
//
//                     debugPrint(
//                       'BOX ${b.scadaId} -> ${types.join(", ")} | devices=${bt.devices.length}',
//                     );
//
//                     return Padding(
//                       padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
//                       child: Container(
//                         decoration: BoxDecoration(
//                           color: const Color(0xFF0B1220),
//                           borderRadius: BorderRadius.circular(12),
//                           border: Border.all(color: const Color(0xFF1B2A44)),
//                         ),
//                         child: ExpansionTile(
//                           collapsedIconColor: const Color(0xFF9FB2D6),
//                           iconColor: const Color(0xFF9FB2D6),
//                           title: Text(
//                             'BOX ${b.scadaId} • ${b.plcIp}:${b.plcPort}',
//                             style: const TextStyle(
//                               color: Colors.white,
//                               fontWeight: FontWeight.w800,
//                             ),
//                           ),
//                           subtitle: Text(
//                             'types: ${types.join(" • ")} • wlan: ${b.wlan ?? "-"} • devices: ${bt.devices.length}',
//                             style: const TextStyle(color: Color(0xFF9FB2D6)),
//                           ),
//                           children: [
//                             // ===== BOX LOCAL GUIDE + COPY SQL =====
//                             ScadaLineageHelper.lineageCard(
//                               title: 'BOX LINEAGE (${b.scadaId})',
//                               steps: ScadaLineageHelper.boxSteps(),
//                               // nếu history chưa có parameter_id thì copy fallback
//                               sqlToCopy:
//                                   ScadaLineageHelper.sqlJoinFallbackByAddress,
//                             ),
//
//                             ...bt.devices.map((dt) {
//                               final c = dt.channel;
//                               final imp = dt.params
//                                   .where((p) => p.master.isImportant == true)
//                                   .length;
//
//                               return Padding(
//                                 padding: const EdgeInsets.fromLTRB(
//                                   12,
//                                   0,
//                                   12,
//                                   12,
//                                 ),
//                                 child: Container(
//                                   decoration: BoxDecoration(
//                                     color: const Color(0xFF0E1729),
//                                     borderRadius: BorderRadius.circular(12),
//                                     border: Border.all(
//                                       color: const Color(0xFF1B2A44),
//                                     ),
//                                   ),
//                                   child: ExpansionTile(
//                                     collapsedIconColor: const Color(0xFF9FB2D6),
//                                     iconColor: const Color(0xFF9FB2D6),
//                                     title: Text(
//                                       'DEVICE ${c.boxDeviceId} • ${c.boxId}',
//                                       style: const TextStyle(
//                                         color: Colors.white,
//                                         fontWeight: FontWeight.w800,
//                                       ),
//                                     ),
//                                     subtitle: Text(
//                                       '${c.cate} • params: ${dt.params.length} (important: $imp)',
//                                       style: const TextStyle(
//                                         color: Color(0xFF9FB2D6),
//                                       ),
//                                     ),
//                                     children: [
//                                       // ===== DEVICE LOCAL GUIDE + COPY SQL =====
//                                       ScadaLineageHelper.lineageCard(
//                                         title:
//                                             'DEVICE LINEAGE (${c.boxDeviceId})',
//                                         steps: ScadaLineageHelper.deviceSteps(),
//                                         sqlToCopy: ScadaLineageHelper
//                                             .sqlJoinByParameterId,
//                                       ),
//
//                                       ...dt.params.map((p) {
//                                         final m = p.master;
//                                         final h = p.latest;
//
//                                         final breadcrumb =
//                                             'FAC(${fac.facId}) → BOX(${b.scadaId}) → '
//                                             'DEVICE(${c.boxDeviceId}|${c.cate}) → '
//                                             'MASTER(${m.nameEn}|${m.plcAddress}) → '
//                                             'HISTORY(latest@recorded_at)';
//
//                                         return Padding(
//                                           padding: const EdgeInsets.fromLTRB(
//                                             12,
//                                             0,
//                                             12,
//                                             10,
//                                           ),
//                                           child: Column(
//                                             crossAxisAlignment:
//                                                 CrossAxisAlignment.stretch,
//                                             children: [
//                                               // ✅ breadcrumb dùng helper (thay _BreadcrumbLine)
//                                               ScadaLineageHelper.breadcrumb(
//                                                 breadcrumb,
//                                               ),
//                                               const SizedBox(height: 8),
//
//                                               _RowCard(
//                                                 title:
//                                                     '${m.nameEn} ${m.isImportant == true ? '• IMPORTANT' : ''}',
//                                                 rows: {
//                                                   'nameVi': m.nameVi,
//                                                   'category': m.category,
//                                                   'plcAddress': m.plcAddress,
//                                                   'valueType': '${m.valueType}',
//                                                   'unit': m.unit,
//                                                   'latestValue': h == null
//                                                       ? '--'
//                                                       : '${h.value}',
//                                                   'recordedAt': h == null
//                                                       ? '--'
//                                                       : fmtTime(h.recordedAt),
//                                                 },
//                                               ),
//                                             ],
//                                           ),
//                                         );
//                                       }),
//                                     ],
//                                   ),
//                                 ),
//                               );
//                             }),
//                           ],
//                         ),
//                       ),
//                     );
//                   }),
//                 ],
//               ),
//             ),
//           );
//         }),
//       ],
//     );
//   }
// }
//
// class _BoxesTab extends StatefulWidget {
//   final List<UtilityScadaBox> boxes;
//
//   const _BoxesTab({required this.boxes});
//
//   @override
//   State<_BoxesTab> createState() => _BoxesTabState();
// }
//
// class _BoxesTabState extends State<_BoxesTab> {
//   String _fac = 'ALL';
//
//   @override
//   Widget build(BuildContext context) {
//     final facs = {'ALL', ...widget.boxes.map((e) => e.facName)}.toList();
//
//     final filtered = _fac == 'ALL'
//         ? widget.boxes
//         : widget.boxes.where((b) => b.facName == _fac).toList();
//
//     return ListView(
//       padding: const EdgeInsets.all(12),
//       children: [
//         _CardHeader(title: 'SCADA BOX (${filtered.length})'),
//         const SizedBox(height: 8),
//
//         /// FILTER
//         DropdownButton<String>(
//           value: _fac,
//           dropdownColor: const Color(0xFF0E1729),
//           items: facs
//               .map(
//                 (f) => DropdownMenuItem(
//                   value: f,
//                   child: Text(f, style: const TextStyle(color: Colors.white)),
//                 ),
//               )
//               .toList(),
//           onChanged: (v) => setState(() => _fac = v!),
//         ),
//
//         const SizedBox(height: 10),
//
//         ...filtered.map(
//           (b) => _RowCard(
//             title: '${b.scadaId} • ${b.facName}-${b.facName}',
//             rows: {
//               'id': '${b.id}',
//               'scadaId': b.scadaId,
//               'plcIp': b.plcIp,
//               'plcPort': '${b.plcPort}',
//               'wlan': b.wlan ?? '',
//             },
//           ),
//         ),
//       ],
//     );
//   }
// }
//
// class _ChannelsTab extends StatefulWidget {
//   final List<UtilityScadaChannel> channels;
//
//   const _ChannelsTab({required this.channels});
//
//   @override
//   State<_ChannelsTab> createState() => _ChannelsTabState();
// }
//
// class _ChannelsTabState extends State<_ChannelsTab> {
//   String _cate = 'ALL';
//
//   @override
//   Widget build(BuildContext context) {
//     final cates = {'ALL', ...widget.channels.map((e) => e.cate)}.toList();
//
//     final filtered = _cate == 'ALL'
//         ? widget.channels
//         : widget.channels.where((c) => c.cate == _cate).toList();
//
//     return ListView(
//       padding: const EdgeInsets.all(12),
//       children: [
//         _CardHeader(title: 'SCADA CHANNEL (${filtered.length})'),
//         const SizedBox(height: 8),
//
//         /// FILTER
//         Wrap(
//           spacing: 8,
//           children: cates.map((c) {
//             final selected = _cate == c;
//             return FilterChip(
//               label: Text(c),
//               selected: selected,
//               onSelected: (_) => setState(() => _cate = c),
//             );
//           }).toList(),
//         ),
//
//         const SizedBox(height: 10),
//
//         ...filtered.map(
//           (c) => _RowCard(
//             title: '${c.scadaId} • ${c.boxId}',
//             rows: {
//               'id': '${c.id}',
//               'utilityType': c.cate,
//               'boxDeviceId': c.boxDeviceId,
//               'boxId': c.boxId,
//             },
//           ),
//         ),
//       ],
//     );
//   }
// }
//
// class _MastersTab extends StatefulWidget {
//   final List<UtilityParameterMaster> masters;
//
//   const _MastersTab({required this.masters});
//
//   @override
//   State<_MastersTab> createState() => _MastersTabState();
// }
//
// class _MastersTabState extends State<_MastersTab> {
//   bool _importantOnly = false;
//   String _utility = 'ALL';
//
//   bool _byUtility(UtilityParameterMaster m) {
//     if (_utility == 'ALL') return true;
//     if (_utility == 'Electricity') return m.boxDeviceId.endsWith('_ELEC');
//     if (_utility == 'Water') return m.boxDeviceId.endsWith('_WTR');
//     // Compressed Air
//     return m.boxDeviceId.endsWith('_AIR');
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final filtered = widget.masters.where((m) {
//       if (_importantOnly && m.isImportant != true) return false;
//       if (!_byUtility(m)) return false;
//       return true;
//     }).toList();
//
//     debugPrint(
//       'MastersTab filtered=${filtered.length} total=${widget.masters.length}'
//       ' importantOnly=$_importantOnly utility=$_utility',
//     );
//
//     return ListView(
//       padding: const EdgeInsets.all(12),
//       children: [
//         _CardHeader(title: 'PARAMETER MASTER (${filtered.length})'),
//         const SizedBox(height: 10),
//
//         Wrap(
//           spacing: 8,
//           runSpacing: 8,
//           children: [
//             FilterChip(
//               label: const Text('ALL'),
//               selected: _utility == 'ALL',
//               onSelected: (_) => setState(() => _utility = 'ALL'),
//             ),
//             FilterChip(
//               label: const Text('Electricity'),
//               selected: _utility == 'Electricity',
//               onSelected: (_) => setState(() => _utility = 'Electricity'),
//             ),
//             FilterChip(
//               label: const Text('Water'),
//               selected: _utility == 'Water',
//               onSelected: (_) => setState(() => _utility = 'Water'),
//             ),
//             FilterChip(
//               label: const Text('Compressed Air'),
//               selected: _utility == 'Compressed Air',
//               onSelected: (_) => setState(() => _utility = 'Compressed Air'),
//             ),
//           ],
//         ),
//
//         const SizedBox(height: 6),
//
//         SwitchListTile(
//           value: _importantOnly,
//           onChanged: (v) => setState(() => _importantOnly = v),
//           title: const Text(
//             'Important only',
//             style: TextStyle(color: Colors.white),
//           ),
//         ),
//
//         const SizedBox(height: 12),
//
//         ...filtered.map(
//           (m) => _RowCard(
//             title: '${m.boxDeviceId} • ${m.nameEn}',
//             rows: {
//               'category': m.category,
//               'unit': m.unit,
//               'plcAddress': m.plcAddress,
//               'valueType': '${m.valueType}',
//               'important': '${m.isImportant}',
//             },
//           ),
//         ),
//       ],
//     );
//   }
// }
//
// class _HistoryTab extends StatefulWidget {
//   final List<UtilityParameterHistory> histories;
//
//   const _HistoryTab({required this.histories});
//
//   @override
//   State<_HistoryTab> createState() => _HistoryTabState();
// }
//
// class _HistoryTabState extends State<_HistoryTab> {
//   String _q = '';
//
//   @override
//   Widget build(BuildContext context) {
//     final filtered = _q.isEmpty
//         ? widget.histories
//         : widget.histories
//               .where(
//                 (h) => h.boxDeviceId.contains(_q) || h.plcAddress.contains(_q),
//               )
//               .toList();
//
//     return ListView(
//       padding: const EdgeInsets.all(12),
//       children: [
//         _CardHeader(title: 'PARAM HISTORY (${filtered.length})'),
//         const SizedBox(height: 8),
//
//         TextField(
//           decoration: const InputDecoration(
//             hintText: 'Search boxDeviceId / plcAddress',
//             filled: true,
//           ),
//           onChanged: (v) => setState(() => _q = v),
//         ),
//
//         const SizedBox(height: 10),
//
//         ...filtered.map(
//           (h) => _RowCard(
//             title: '${h.boxDeviceId} • ${h.plcAddress}',
//             rows: {'value': '${h.value}', 'time': '${h.recordedAt}'},
//           ),
//         ),
//       ],
//     );
//   }
// }
//
// /// ===================== SMALL UI =====================
//
// class _CardHeader extends StatelessWidget {
//   final String title;
//
//   const _CardHeader({required this.title});
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: const Color(0xFF0E1729),
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: const Color(0xFF1B2A44)),
//       ),
//       child: Text(
//         title,
//         style: const TextStyle(
//           color: Colors.white,
//           fontWeight: FontWeight.w900,
//           fontSize: 14,
//         ),
//       ),
//     );
//   }
// }
//
// class _RowCard extends StatelessWidget {
//   final String title;
//   final Map<String, String> rows;
//
//   const _RowCard({required this.title, required this.rows});
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       margin: const EdgeInsets.only(bottom: 10),
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: const Color(0xFF0E1729),
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: const Color(0xFF1B2A44)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             title,
//             style: const TextStyle(
//               color: Colors.white,
//               fontWeight: FontWeight.w900,
//             ),
//           ),
//           const SizedBox(height: 10),
//           ...rows.entries.map(
//             (e) => Padding(
//               padding: const EdgeInsets.only(bottom: 6),
//               child: Row(
//                 children: [
//                   SizedBox(
//                     width: 110,
//                     child: Text(
//                       e.key,
//                       style: const TextStyle(
//                         color: Color(0xFF9FB2D6),
//                         fontWeight: FontWeight.w700,
//                       ),
//                     ),
//                   ),
//                   Expanded(
//                     child: Text(
//                       e.value,
//                       style: const TextStyle(color: Colors.white),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// /// =========
//
// class UtilityDashTab extends StatefulWidget {
//   final List<FacTree> facs;
//   final UtilityMockRepository repo; // mock
//
//   const UtilityDashTab({super.key, required this.facs, required this.repo});
//
//   @override
//   State<UtilityDashTab> createState() => _UtilityDashTabState();
// }
//
// class _UtilityDashTabState extends State<UtilityDashTab> {
//   String _facId = 'A';
//   String _utility = 'Electricity';
//   String? _deviceId;
//   bool _onlyImportant = true;
//   TimeBucket _bucket = TimeBucket.hour;
//
//   // multi-select param (deviceId::plcAddress key)
//   final Set<String> _selectedParamKeys = {};
//
//   // chart selection
//   String? _chartParamKey;
//
//   // seed future (initial series)
//   Future<List<UtilityParameterHistory>>? _seriesFuture;
//
//   // ===== REALTIME =====
//   bool _realtime = true;
//   int _rtIntervalSec = 2;
//   Timer? _rtTimer;
//
//   // realtime buffer per key
//   final Map<String, List<UtilityParameterHistory>> _rtSeriesByKey = {};
//
//   List<String> get _facIds =>
//       widget.facs.map((e) => e.facId).toSet().toList()..sort();
//
//   List<String> get _utilities => const [
//     'Electricity',
//     'Water',
//     'Compressed Air',
//   ];
//
//   @override
//   void initState() {
//     super.initState();
//     _ensureDefaultDevice();
//     _reloadSeriesIfPossible();
//     _startRealtime(); // ✅ realtime start
//   }
//
//   @override
//   void didUpdateWidget(covariant UtilityDashTab oldWidget) {
//     super.didUpdateWidget(oldWidget);
//     _ensureDefaultDevice();
//     _reloadSeriesIfPossible();
//     if (_realtime) _startRealtime();
//   }
//
//   @override
//   void dispose() {
//     _rtTimer?.cancel();
//     super.dispose();
//   }
//
//   // =======================
//   // REALTIME CONTROL
//   // =======================
//
//   void _startRealtime() {
//     _rtTimer?.cancel();
//     if (!_realtime) return;
//
//     _rtTimer = Timer.periodic(
//       Duration(seconds: _rtIntervalSec),
//       (_) => _tickRealtime(),
//     );
//   }
//
//   void _stopRealtime() {
//     _rtTimer?.cancel();
//     _rtTimer = null;
//   }
//
//   DateTime _cutoffTime(DateTime now) {
//     switch (_bucket) {
//       case TimeBucket.hour:
//         return now.subtract(const Duration(hours: 23));
//       case TimeBucket.day:
//         return now.subtract(const Duration(days: 29));
//       case TimeBucket.month:
//         return DateTime(now.year, now.month - 11, 1);
//     }
//   }
//
//   Future<void> _tickRealtime() async {
//     if (!mounted) return;
//
//     final selectedParams = _paramsForSelectedDevice();
//     if (selectedParams.isEmpty) return;
//
//     final chartParam =
//         _findParamByKey(selectedParams, _chartParamKey) ?? selectedParams.first;
//
//     final key = _pKey(chartParam);
//     final deviceId = chartParam.master.boxDeviceId;
//     final plcAddress = chartParam.master.plcAddress;
//
//     // ✅ mock: lấy latest toàn bộ masters ở thời điểm now
//     final now = DateTime.now();
//     final latestAll = await widget.repo.fetchLatestHistories(
//       at: now,
//       // seed thay đổi theo thời gian để giá trị đổi thật
//       seed: now.millisecondsSinceEpoch,
//     );
//
//     // lọc đúng param đang xem chart
//     final pointList = latestAll
//         .where((h) => h.boxDeviceId == deviceId && h.plcAddress == plcAddress)
//         .toList();
//
//     if (pointList.isEmpty) return;
//     final point = pointList.first;
//
//     // append vào buffer
//     final buf = _rtSeriesByKey.putIfAbsent(key, () => []);
//
//     // tránh duplicate time
//     if (buf.isNotEmpty &&
//         buf.last.recordedAt.isAtSameMomentAs(point.recordedAt)) {
//       return;
//     }
//
//     buf.add(point);
//
//     // cắt theo window (23h/29d/12m)
//     final cutoff = _cutoffTime(now);
//     buf.removeWhere((e) => e.recordedAt.isBefore(cutoff));
//
//     // sort cho chắc
//     buf.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
//
//     setState(() {});
//   }
//
//   void _clearRtBuffers() {
//     _rtSeriesByKey.clear();
//   }
//
//   // =======================
//   // SELECTION
//   // =======================
//
//   void _ensureDefaultDevice() {
//     final devs = _devicesForSelection();
//     if (devs.isEmpty) return;
//
//     if (_deviceId == null ||
//         !devs.any((d) => d.channel.boxDeviceId == _deviceId)) {
//       _deviceId = devs.first.channel.boxDeviceId;
//       _selectedParamKeys.clear();
//       _chartParamKey = null;
//       _clearRtBuffers();
//     }
//   }
//
//   List<DeviceTree> _devicesForSelection() {
//     final fac = widget.facs.firstWhere((f) => f.facId == _facId);
//     final allDevices = fac.boxes.expand((b) => b.devices).toList();
//     return allDevices.where((d) => d.channel.cate == _utility).toList();
//   }
//
//   List<ParamNode> _paramsForSelectedDevice() {
//     final devs = _devicesForSelection();
//     if (devs.isEmpty) return [];
//
//     final did = _deviceId ?? devs.first.channel.boxDeviceId;
//     final d = devs.firstWhere(
//       (x) => x.channel.boxDeviceId == did,
//       orElse: () => devs.first,
//     );
//
//     final ps = _onlyImportant
//         ? d.params.where((p) => p.master.isImportant == true).toList()
//         : d.params;
//
//     if (_selectedParamKeys.isEmpty && ps.isNotEmpty) {
//       for (final p in ps.take(4)) {
//         _selectedParamKeys.add(_pKey(p));
//       }
//     }
//
//     return ps.where((p) => _selectedParamKeys.contains(_pKey(p))).toList();
//   }
//
//   String _pKey(ParamNode p) =>
//       '${p.master.boxDeviceId}::${p.master.plcAddress}';
//
//   ParamNode? _findParamByKey(List<ParamNode> list, String? key) {
//     if (key == null) return null;
//     for (final p in list) {
//       if (_pKey(p) == key) return p;
//     }
//     return null;
//   }
//
//   // =======================
//   // SERIES SEED (initial fetchSeries)
//   // =======================
//
//   void _reloadSeriesIfPossible() {
//     final selectedParams = _paramsForSelectedDevice();
//     if (selectedParams.isEmpty) {
//       setState(() => _seriesFuture = null);
//       return;
//     }
//
//     _chartParamKey ??= _pKey(selectedParams.first);
//
//     final chartParam = _findParamByKey(selectedParams, _chartParamKey);
//     if (chartParam == null) {
//       _chartParamKey = _pKey(selectedParams.first);
//     }
//
//     final p = _findParamByKey(selectedParams, _chartParamKey)!;
//     final req = _buildSeriesReq(p);
//     final key = _pKey(p);
//
//     setState(() {
//       _seriesFuture = widget.repo.fetchSeries(req).then((series) {
//         final sorted = [...series]
//           ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
//         _rtSeriesByKey[key] = sorted; // ✅ seed buffer để realtime nối tiếp
//         return sorted;
//       });
//     });
//   }
//
//   UtilitySeriesRequest _buildSeriesReq(ParamNode p) {
//     final now = DateTime.now();
//
//     DateTime from;
//     DateTime to = now;
//
//     switch (_bucket) {
//       case TimeBucket.hour:
//         from = now.subtract(const Duration(hours: 23));
//         break;
//       case TimeBucket.day:
//         from = now.subtract(const Duration(days: 29));
//         break;
//       case TimeBucket.month:
//         from = DateTime(now.year, now.month - 11, 1);
//         to = DateTime(now.year, now.month, 1);
//         break;
//     }
//
//     return UtilitySeriesRequest(
//       facId: _facId,
//       utility: _utility,
//       deviceId: p.master.boxDeviceId,
//       plcAddress: p.master.plcAddress,
//       from: from,
//       to: to,
//       bucket: _bucket,
//       seed: 1,
//     );
//   }
//
//   // =======================
//   // UI
//   // =======================
//
//   @override
//   Widget build(BuildContext context) {
//     final devices = _devicesForSelection();
//     if (devices.isNotEmpty && _deviceId == null) {
//       _deviceId = devices.first.channel.boxDeviceId;
//     }
//
//     final selectedParams = _paramsForSelectedDevice();
//
//     // ensure series loaded
//     if (selectedParams.isNotEmpty &&
//         (_seriesFuture == null ||
//             _findParamByKey(selectedParams, _chartParamKey) == null)) {
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         if (mounted) _reloadSeriesIfPossible();
//       });
//     }
//
//     return ListView(
//       padding: const EdgeInsets.all(12),
//       children: [
//         _CardHeader(title: 'UTILITY DASHBOARD'),
//         const SizedBox(height: 10),
//         _filtersCard(context, devices),
//         const SizedBox(height: 10),
//         _selectedSummaryCard(selectedParams),
//         const SizedBox(height: 10),
//         _chartCard(selectedParams),
//         const SizedBox(height: 10),
//         ...selectedParams.map((p) => _paramTile(p)),
//       ],
//     );
//   }
//
//   Widget _chartCard(List<ParamNode> selectedParams) {
//     if (selectedParams.isEmpty) {
//       return _RowCard(
//         title: 'Trend',
//         rows: const {'info': 'No selected params'},
//       );
//     }
//
//     final chartParam =
//         _findParamByKey(selectedParams, _chartParamKey) ?? selectedParams.first;
//     final chartKey = _pKey(chartParam);
//
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: const Color(0xFF0E1729),
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: const Color(0xFF1B2A44)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             'Trend (Realtime Series)',
//             style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
//           ),
//           const SizedBox(height: 10),
//
//           // param dropdown
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
//             decoration: BoxDecoration(
//               color: const Color(0xFF0B1220),
//               borderRadius: BorderRadius.circular(12),
//               border: Border.all(color: const Color(0xFF1B2A44)),
//             ),
//             child: DropdownButton<String>(
//               dropdownColor: const Color(0xFF0E1729),
//               value: chartKey,
//               underline: const SizedBox.shrink(),
//               iconEnabledColor: const Color(0xFF9FB2D6),
//               items: selectedParams.map((p) {
//                 return DropdownMenuItem(
//                   value: _pKey(p),
//                   child: Text(
//                     '${p.master.nameEn} • ${p.master.plcAddress}',
//                     style: const TextStyle(color: Colors.white),
//                   ),
//                 );
//               }).toList(),
//               onChanged: (v) {
//                 setState(() => _chartParamKey = v);
//                 _reloadSeriesIfPossible(); // seed buffer đúng param mới
//               },
//             ),
//           ),
//
//           const SizedBox(height: 10),
//
//           if (_seriesFuture == null)
//             const Text('No series', style: TextStyle(color: Color(0xFF9FB2D6)))
//           else
//             FutureBuilder<List<UtilityParameterHistory>>(
//               future: _seriesFuture,
//               builder: (context, snap) {
//                 if (!snap.hasData) {
//                   return const SizedBox(
//                     height: 220,
//                     child: Center(child: CircularProgressIndicator()),
//                   );
//                 }
//
//                 final seedSeries = snap.data!;
//                 if (seedSeries.isEmpty) {
//                   return const Text(
//                     'Empty series',
//                     style: TextStyle(color: Color(0xFF9FB2D6)),
//                   );
//                 }
//
//                 // ✅ ưu tiên realtime buffer (đã seed ở _reloadSeriesIfPossible)
//                 final buf = _rtSeriesByKey[chartKey];
//                 final showSeries = (buf != null && buf.isNotEmpty)
//                     ? buf
//                     : seedSeries;
//
//                 // summary
//                 final values = showSeries.map((e) {
//                   final v = e.value;
//                   if (v is num) return v.toDouble();
//                   return double.tryParse('$v') ?? 0.0;
//                 }).toList();
//
//                 final minV = values.reduce(min);
//                 final maxV = values.reduce(max);
//                 final lastV = values.last;
//
//                 debugPrint(
//                   'REALTIME series=${showSeries.length} '
//                   'from=${showSeries.first.recordedAt} to=${showSeries.last.recordedAt} '
//                   'device=${showSeries.first.boxDeviceId} plc=${showSeries.first.plcAddress}',
//                 );
//
//                 return Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     SizedBox(
//                       height: 220,
//                       child: UtilitySfLineChart(
//                         series: showSeries,
//                         bucket: _bucket,
//                       ),
//                     ),
//                     const SizedBox(height: 8),
//                     Text(
//                       'Realtime: ${_realtime ? "ON" : "OFF"} • ${_rtIntervalSec}s  '
//                       '• Points: ${values.length} • Min: ${minV.toStringAsFixed(2)} '
//                       '• Max: ${maxV.toStringAsFixed(2)} • Last: ${lastV.toStringAsFixed(2)}',
//                       style: const TextStyle(
//                         color: Color(0xFF9FB2D6),
//                         fontWeight: FontWeight.w700,
//                       ),
//                     ),
//                   ],
//                 );
//               },
//             ),
//         ],
//       ),
//     );
//   }
//
//   Widget _filtersCard(BuildContext context, List<DeviceTree> devices) {
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: const Color(0xFF0E1729),
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: const Color(0xFF1B2A44)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text(
//             'Filters',
//             style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
//           ),
//           const SizedBox(height: 10),
//
//           Wrap(
//             spacing: 10,
//             runSpacing: 10,
//             children: [
//               _drop<String>(
//                 label: 'Factory',
//                 value: _facId,
//                 items: _facIds,
//                 onChanged: (v) {
//                   setState(() {
//                     _facId = v!;
//                     _deviceId = null;
//                     _selectedParamKeys.clear();
//                     _chartParamKey = null;
//                     _clearRtBuffers();
//                   });
//                   _ensureDefaultDevice();
//                   _reloadSeriesIfPossible();
//                 },
//               ),
//               _drop<String>(
//                 label: 'Utility',
//                 value: _utility,
//                 items: _utilities,
//                 onChanged: (v) {
//                   setState(() {
//                     _utility = v!;
//                     _deviceId = null;
//                     _selectedParamKeys.clear();
//                     _chartParamKey = null;
//                     _clearRtBuffers();
//                   });
//                   _ensureDefaultDevice();
//                   _reloadSeriesIfPossible();
//                 },
//               ),
//             ],
//           ),
//
//           const SizedBox(height: 10),
//
//           Wrap(
//             spacing: 10,
//             runSpacing: 10,
//             children: [
//               _drop<String>(
//                 label: 'Device',
//                 value: _deviceId,
//                 items: devices.map((d) => d.channel.boxDeviceId).toList(),
//                 onChanged: (v) {
//                   setState(() {
//                     _deviceId = v;
//                     _selectedParamKeys.clear();
//                     _chartParamKey = null;
//                     _clearRtBuffers();
//                   });
//                   _reloadSeriesIfPossible();
//                 },
//                 allowNull: true,
//               ),
//               _drop<TimeBucket>(
//                 label: 'Time bucket',
//                 value: _bucket,
//                 items: TimeBucket.values,
//                 itemLabel: (t) => t.name.toUpperCase(),
//                 onChanged: (v) {
//                   setState(() {
//                     _bucket = v!;
//                     _clearRtBuffers();
//                   });
//                   _reloadSeriesIfPossible();
//                 },
//               ),
//             ],
//           ),
//
//           const SizedBox(height: 10),
//
//           Wrap(
//             spacing: 12,
//             runSpacing: 10,
//             crossAxisAlignment: WrapCrossAlignment.center,
//             children: [
//               // only important
//               Row(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Switch(
//                     value: _onlyImportant,
//                     onChanged: (v) {
//                       setState(() {
//                         _onlyImportant = v;
//                         _selectedParamKeys.clear();
//                         _chartParamKey = null;
//                         _clearRtBuffers();
//                       });
//                       _reloadSeriesIfPossible();
//                     },
//                   ),
//                   const SizedBox(width: 6),
//                   const Text(
//                     'Only important',
//                     style: TextStyle(color: Color(0xFF9FB2D6)),
//                   ),
//                 ],
//               ),
//
//               // realtime
//               Row(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Switch(
//                     value: _realtime,
//                     onChanged: (v) {
//                       setState(() => _realtime = v);
//                       if (v) {
//                         _startRealtime();
//                       } else {
//                         _stopRealtime();
//                       }
//                     },
//                   ),
//                   const SizedBox(width: 6),
//                   const Text(
//                     'Realtime',
//                     style: TextStyle(color: Color(0xFF9FB2D6)),
//                   ),
//                   const SizedBox(width: 8),
//                   _drop<int>(
//                     label: 'Interval',
//                     value: _rtIntervalSec,
//                     items: const [1, 2, 3, 5],
//                     itemLabel: (s) => '${s}s',
//                     onChanged: (v) {
//                       if (v == null) return;
//                       setState(() => _rtIntervalSec = v);
//                       if (_realtime) _startRealtime();
//                     },
//                   ),
//                 ],
//               ),
//
//               ElevatedButton(
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: const Color(0xFF1B2A44),
//                   foregroundColor: Colors.white,
//                 ),
//                 onPressed: devices.isEmpty
//                     ? null
//                     : () => _openParamPicker(context),
//                 child: const Text('Choose parameters'),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
//
//   Future<void> _openParamPicker(BuildContext context) async {
//     final devs = _devicesForSelection();
//     if (devs.isEmpty) return;
//
//     final did = _deviceId ?? devs.first.channel.boxDeviceId;
//     final dev = devs.firstWhere(
//       (d) => d.channel.boxDeviceId == did,
//       orElse: () => devs.first,
//     );
//
//     final params = _onlyImportant
//         ? dev.params.where((p) => p.master.isImportant == true).toList()
//         : dev.params;
//
//     final temp = Set<String>.from(_selectedParamKeys);
//
//     await showModalBottomSheet(
//       context: context,
//       backgroundColor: const Color(0xFF0E1729),
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
//       ),
//       builder: (_) {
//         return StatefulBuilder(
//           builder: (ctx, setModal) {
//             return Padding(
//               padding: const EdgeInsets.all(12),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const Text(
//                     'Select parameters',
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontWeight: FontWeight.w900,
//                       fontSize: 16,
//                     ),
//                   ),
//                   const SizedBox(height: 8),
//                   Expanded(
//                     child: ListView.builder(
//                       itemCount: params.length,
//                       itemBuilder: (_, i) {
//                         final p = params[i];
//                         final k = _pKey(p);
//                         final checked = temp.contains(k);
//                         return CheckboxListTile(
//                           value: checked,
//                           onChanged: (v) {
//                             setModal(() {
//                               if (v == true) {
//                                 temp.add(k);
//                               } else {
//                                 temp.remove(k);
//                               }
//                             });
//                           },
//                           title: Text(
//                             p.master.nameEn,
//                             style: const TextStyle(color: Colors.white),
//                           ),
//                           subtitle: Text(
//                             '${p.master.category} • ${p.master.plcAddress} • ${p.master.unit}',
//                             style: const TextStyle(color: Color(0xFF9FB2D6)),
//                           ),
//                           controlAffinity: ListTileControlAffinity.leading,
//                           activeColor: Colors.white,
//                           checkColor: Colors.black,
//                         );
//                       },
//                     ),
//                   ),
//                   Row(
//                     children: [
//                       Expanded(
//                         child: TextButton(
//                           onPressed: () => setModal(() => temp.clear()),
//                           child: const Text(
//                             'Clear',
//                             style: TextStyle(color: Color(0xFF9FB2D6)),
//                           ),
//                         ),
//                       ),
//                       Expanded(
//                         child: ElevatedButton(
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: const Color(0xFF1B2A44),
//                             foregroundColor: Colors.white,
//                           ),
//                           onPressed: () {
//                             setState(() {
//                               _selectedParamKeys
//                                 ..clear()
//                                 ..addAll(temp);
//                               _chartParamKey = null;
//                               _clearRtBuffers();
//                             });
//                             Navigator.pop(context);
//                             _reloadSeriesIfPossible();
//                           },
//                           child: const Text('Apply'),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             );
//           },
//         );
//       },
//     );
//   }
//
//   Widget _selectedSummaryCard(List<ParamNode> selectedParams) {
//     final dev = _deviceId ?? '-';
//     return Container(
//       padding: const EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: const Color(0xFF0E1729),
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: const Color(0xFF1B2A44)),
//       ),
//       child: Text(
//         'Selected: ${selectedParams.length} • Factory: $_facId • Utility: $_utility • Device: $dev • Bucket: ${_bucket.name.toUpperCase()}',
//         style: const TextStyle(
//           color: Color(0xFF9FB2D6),
//           fontWeight: FontWeight.w700,
//         ),
//       ),
//     );
//   }
//
//   Widget _paramTile(ParamNode p) {
//     final m = p.master;
//     final h = p.latest;
//     return _RowCard(
//       title: '${m.nameEn}${m.isImportant == true ? " • IMPORTANT" : ""}',
//       rows: {
//         'category': m.category,
//         'plcAddress': m.plcAddress,
//         'unit': m.unit,
//         'latest': h == null ? '--' : '${h.value}',
//         'time': h == null ? '--' : '${h.recordedAt}',
//       },
//     );
//   }
//
//   Widget _drop<T>({
//     required String label,
//     required T? value,
//     required List<T> items,
//     required ValueChanged<T?> onChanged,
//     String Function(T v)? itemLabel,
//     bool allowNull = false,
//   }) {
//     final menuItems = <DropdownMenuItem<T?>>[];
//
//     if (allowNull) {
//       menuItems.add(
//         DropdownMenuItem<T?>(
//           value: null,
//           child: Text(
//             '(Any) $label',
//             style: const TextStyle(color: Colors.white),
//           ),
//         ),
//       );
//     }
//
//     menuItems.addAll(
//       items.map(
//         (e) => DropdownMenuItem<T?>(
//           value: e,
//           child: Text(
//             itemLabel?.call(e) ?? e.toString(),
//             style: const TextStyle(color: Colors.white),
//           ),
//         ),
//       ),
//     );
//
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
//       decoration: BoxDecoration(
//         color: const Color(0xFF0B1220),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: const Color(0xFF1B2A44)),
//       ),
//       child: DropdownButton<T?>(
//         dropdownColor: const Color(0xFF0E1729),
//         value: value,
//         hint: Text(label, style: const TextStyle(color: Color(0xFF9FB2D6))),
//         underline: const SizedBox.shrink(),
//         iconEnabledColor: const Color(0xFF9FB2D6),
//         items: menuItems,
//         onChanged: onChanged,
//       ),
//     );
//   }
// }
//
// // ==============================
// // SYNCFUSION CHART WIDGET
// // ==============================
//
// class _TsPoint {
//   final DateTime t;
//   final double v;
//
//   const _TsPoint(this.t, this.v);
// }
//
// class UtilitySfLineChart extends StatelessWidget {
//   final List<UtilityParameterHistory> series;
//   final TimeBucket bucket;
//
//   const UtilitySfLineChart({
//     super.key,
//     required this.series,
//     required this.bucket,
//   });
//
//   double _toDouble(dynamic v) {
//     if (v == null) return 0.0;
//     if (v is num) return v.toDouble();
//     return double.tryParse('$v') ?? 0.0;
//   }
//
//   DateTimeIntervalType _intervalType(TimeBucket b) {
//     switch (b) {
//       case TimeBucket.hour:
//         return DateTimeIntervalType.hours;
//       case TimeBucket.day:
//         return DateTimeIntervalType.days;
//       case TimeBucket.month:
//         return DateTimeIntervalType.months;
//     }
//   }
//
//   String _xLabel(DateTime d, TimeBucket b) {
//     switch (b) {
//       case TimeBucket.hour:
//         return '${d.hour.toString().padLeft(2, "0")}:${d.minute.toString().padLeft(2, "0")}';
//       case TimeBucket.day:
//         return '${d.day.toString().padLeft(2, "0")}/${d.month.toString().padLeft(2, "0")}';
//       case TimeBucket.month:
//         return '${d.month.toString().padLeft(2, "0")}/${d.year}';
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final sorted = [...series]
//       ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
//
//     final data = sorted
//         .map((e) => _TsPoint(e.recordedAt, _toDouble(e.value)))
//         .toList();
//
//     final tooltip = TooltipBehavior(
//       enable: true,
//       activationMode: ActivationMode.singleTap,
//       format: 'point.x : point.y',
//     );
//
//     final zoomPan = ZoomPanBehavior(
//       enablePinching: true,
//       enablePanning: true,
//       zoomMode: ZoomMode.x,
//     );
//
//     return SfCartesianChart(
//       plotAreaBorderWidth: 0,
//       tooltipBehavior: tooltip,
//       zoomPanBehavior: zoomPan,
//       primaryXAxis: DateTimeAxis(
//         intervalType: _intervalType(bucket),
//         majorGridLines: const MajorGridLines(width: 0.6),
//         axisLine: const AxisLine(width: 0),
//         labelStyle: const TextStyle(color: Color(0xFF9FB2D6), fontSize: 11),
//         axisLabelFormatter: (AxisLabelRenderDetails args) {
//           final dt = DateTime.fromMillisecondsSinceEpoch(args.value.toInt());
//           return ChartAxisLabel(_xLabel(dt, bucket), args.textStyle);
//         },
//       ),
//       primaryYAxis: NumericAxis(
//         majorGridLines: const MajorGridLines(width: 0.6),
//         axisLine: const AxisLine(width: 0),
//         labelStyle: const TextStyle(color: Color(0xFF9FB2D6), fontSize: 11),
//       ),
//       series: <LineSeries<_TsPoint, DateTime>>[
//         LineSeries<_TsPoint, DateTime>(
//           dataSource: data,
//           xValueMapper: (p, _) => p.t,
//           yValueMapper: (p, _) => p.v,
//           width: 2,
//           markerSettings: const MarkerSettings(isVisible: false),
//         ),
//       ],
//     );
//   }
// }

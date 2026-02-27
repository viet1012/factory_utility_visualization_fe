// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
//
// import '../../../utility_models/response/latest_record.dart';
// import '../../../utility_models/utility_facade_service.dart';
// import '../../../utility_state/FacLatestDetailProvider.dart';
// import 'overlay_layout_store.dart';
//
// class UtilityFacDetailScreens extends StatelessWidget {
//   final String facId;
//   final UtilityFacadeService svc;
//
//   const UtilityFacDetailScreens({
//     super.key,
//     required this.facId,
//     required this.svc,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return MultiProvider(
//       providers: [
//         ChangeNotifierProvider<FacLatestDetailProvider>(
//           create: (_) {
//             final p = FacLatestDetailProvider(svc: svc, facId: facId);
//             p.fetch();
//             p.startPolling(const Duration(seconds: 10));
//             return p;
//           },
//         ),
//         ChangeNotifierProvider<OverlayLayoutStore>(
//           create: (_) {
//             final s = OverlayLayoutStore(svc);
//             s.load(facId); // ✅ load 1 lần ở đây đủ rồi
//             return s;
//           },
//         ),
//       ],
//       child: _FacDetailBody(facId: facId),
//     );
//   }
// }
//
// // ======================= BODY =======================
//
// class _FacDetailBody extends StatefulWidget {
//   final String facId;
//
//   const _FacDetailBody({required this.facId});
//
//   @override
//   State<_FacDetailBody> createState() => _FacDetailBodyState();
// }
//
// class _FacDetailBodyState extends State<_FacDetailBody>
//     with SingleTickerProviderStateMixin {
//   late final TabController _tab;
//
//   String q = '';
//   bool editMode = false;
//   String? editingAddress;
//
//   @override
//   void initState() {
//     super.initState();
//     _tab = TabController(length: 2, vsync: this);
//   }
//
//   @override
//   void dispose() {
//     _tab.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final latest = context.watch<FacLatestDetailProvider>();
//     final layoutStore = context.watch<OverlayLayoutStore>();
//
//     final vm = _FacDetailVm.build(
//       facId: widget.facId,
//       rows: latest.rows,
//       lastUpdated: latest.lastUpdated,
//       q: q,
//       currentEditingAddress: editingAddress,
//       editMode: editMode,
//     );
//
//     // đảm bảo edit mode có default editingAddress
//     if (editMode && editingAddress == null && vm.allAddresses.isNotEmpty) {
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         if (!mounted) return;
//         setState(() => editingAddress = vm.allAddresses.first);
//       });
//     }
//
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: const Color(0xFF0a0e27),
//         elevation: 0,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: Colors.white),
//           onPressed: () => Navigator.of(context).pop(),
//         ),
//       ),
//       body: _ScadaGradient(
//         child: SafeArea(
//           child: Column(
//             children: [
//               _TopHeader(
//                 facId: widget.facId,
//                 lastText: vm.lastText,
//                 editMode: editMode,
//                 onToggleEdit: () => setState(() => editMode = !editMode),
//               ),
//               _Tabs(controller: _tab),
//               const SizedBox(height: 8),
//               Expanded(
//                 child: TabBarView(
//                   controller: _tab,
//                   children: [
//                     _FacOverlayMap(
//                       facId: widget.facId,
//                       image: Image.asset(
//                         'assets/images/${widget.facId.toLowerCase()}.png',
//                         fit: BoxFit.cover,
//                       ),
//                       layout: layoutStore.layoutOf(widget.facId),
//                       latestByAddress: vm.byAddr,
//                       editMode: editMode,
//                       editingAddress: editingAddress,
//                       allAddresses: vm.allAddresses,
//                       onPickEditingAddress: (addr) =>
//                           setState(() => editingAddress = addr),
//                       onUpdatePos: (addr, pos01) async {
//                         final rec = vm.byAddr[addr];
//                         if (rec == null) {
//                           debugPrint(
//                             'No latest record for $addr => cannot determine boxDeviceId',
//                           );
//                           return;
//                         }
//
//                         await context.read<OverlayLayoutStore>().setPos(
//                           facId: widget.facId,
//                           boxDeviceId: rec.boxDeviceId,
//                           plcAddress: addr,
//                           pos01: pos01,
//                         );
//
//                         // reload to confirm
//                         await context.read<OverlayLayoutStore>().load(
//                           widget.facId,
//                         );
//                       },
//                     ),
//                     const Center(
//                       child: Text(
//                         'List tab (TODO)',
//                         style: TextStyle(color: Colors.white70),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// // ======================= VIEW MODEL =======================
//
// class _FacDetailVm {
//   final Map<String, LatestRecordDto> byAddr;
//   final List<String> allAddresses;
//   final String lastText;
//
//   const _FacDetailVm({
//     required this.byAddr,
//     required this.allAddresses,
//     required this.lastText,
//   });
//
//   static _FacDetailVm build({
//     required String facId,
//     required List<LatestRecordDto> rows,
//     required DateTime? lastUpdated,
//     required String q,
//     required bool editMode,
//     required String? currentEditingAddress,
//   }) {
//     // byAddr
//     final byAddr = <String, LatestRecordDto>{};
//     for (final r in rows) {
//       final key = r.plcAddress.trim();
//       if (key.isEmpty) continue;
//       byAddr[key] = r;
//     }
//
//     // all address sorted by number
//     final addrs =
//         rows
//             .map((e) => e.plcAddress.trim())
//             .where((e) => e.isNotEmpty)
//             .toSet()
//             .toList()
//           ..sort((a, b) => _addrNum(a).compareTo(_addrNum(b)));
//
//     // last text
//     final lastText = lastUpdated == null
//         ? '—'
//         : '${lastUpdated.hour.toString().padLeft(2, '0')}:'
//               '${lastUpdated.minute.toString().padLeft(2, '0')}:'
//               '${lastUpdated.second.toString().padLeft(2, '0')}';
//
//     return _FacDetailVm(
//       byAddr: byAddr,
//       allAddresses: addrs,
//       lastText: lastText,
//     );
//   }
//
//   static int _addrNum(String s) {
//     final m = RegExp(r'\d+').firstMatch(s);
//     return m == null ? 0 : int.parse(m.group(0)!);
//   }
// }
//
// // ======================= HEADER/TABS =======================
//
// class _TopHeader extends StatelessWidget {
//   final String facId;
//   final String lastText;
//   final bool editMode;
//   final VoidCallback onToggleEdit;
//
//   const _TopHeader({
//     required this.facId,
//     required this.lastText,
//     required this.editMode,
//     required this.onToggleEdit,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 8),
//       child: Row(
//         children: [
//           Expanded(
//             child: Text(
//               'FAC $facId   |   Last: $lastText',
//               style: const TextStyle(
//                 color: Colors.white,
//                 fontWeight: FontWeight.w700,
//               ),
//             ),
//           ),
//           IconButton(
//             tooltip: editMode ? 'Disable Edit' : 'Enable Edit',
//             onPressed: onToggleEdit,
//             icon: Icon(
//               editMode ? Icons.edit_off : Icons.edit,
//               color: editMode ? Colors.amber : Colors.white,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// class _Tabs extends StatelessWidget {
//   final TabController controller;
//
//   const _Tabs({required this.controller});
//
//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 8),
//       child: TabBar(
//         controller: controller,
//         indicatorColor: Colors.white,
//         labelColor: Colors.white,
//         unselectedLabelColor: Colors.white70,
//         tabs: const [
//           Tab(text: 'Map'),
//           Tab(text: 'List'),
//         ],
//       ),
//     );
//   }
// }
//
// class _ScadaGradient extends StatelessWidget {
//   final Widget child;
//
//   const _ScadaGradient({required this.child});
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       decoration: const BoxDecoration(
//         gradient: LinearGradient(
//           colors: [Color(0xFF0a0e27), Color(0xFF1a1a2e), Color(0xFF16213e)],
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//       ),
//       child: child,
//     );
//   }
// }
//
// // ========================= MAP =========================
//
// class _FacOverlayMap extends StatefulWidget {
//   final String facId;
//   final Widget image;
//
//   /// plcAddress -> pos 0..1
//   final Map<String, Offset> layout;
//
//   /// plcAddress -> latest record
//   final Map<String, LatestRecordDto> latestByAddress;
//
//   final bool editMode;
//   final String? editingAddress;
//   final ValueChanged<String?> onPickEditingAddress;
//   final void Function(String addr, Offset pos01) onUpdatePos;
//
//   final List<String> allAddresses;
//
//   const _FacOverlayMap({
//     required this.facId,
//     required this.image,
//     required this.layout,
//     required this.latestByAddress,
//     required this.editMode,
//     required this.editingAddress,
//     required this.onPickEditingAddress,
//     required this.onUpdatePos,
//     required this.allAddresses,
//   });
//
//   @override
//   State<_FacOverlayMap> createState() => _FacOverlayMapState();
// }
//
// class _FacOverlayMapState extends State<_FacOverlayMap> {
//   final TransformationController _tx = TransformationController();
//
//   @override
//   void dispose() {
//     _tx.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final entries = widget.layout.entries.toList()
//       ..sort((a, b) => _addrNum(a.key).compareTo(_addrNum(b.key)));
//
//     return Padding(
//       padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
//       child: Column(
//         children: [
//           if (widget.editMode) _editorBar(),
//           const SizedBox(height: 10),
//           Expanded(
//             child: ClipRRect(
//               borderRadius: BorderRadius.circular(16),
//               child: Container(
//                 color: Colors.black.withOpacity(0.25),
//                 child: LayoutBuilder(
//                   builder: (context, cs) {
//                     final w = cs.maxWidth;
//                     final h = cs.maxHeight;
//
//                     Offset toPos01FromTap(Offset localInViewer) {
//                       final scene = _tx.toScene(localInViewer);
//                       return Offset(
//                         (scene.dx / w).clamp(0.0, 1.0),
//                         (scene.dy / h).clamp(0.0, 1.0),
//                       );
//                     }
//
//                     return GestureDetector(
//                       behavior: HitTestBehavior.opaque,
//                       onTapDown: (d) {
//                         if (!widget.editMode) return;
//                         final addr = widget.editingAddress;
//                         if (addr == null) return;
//
//                         widget.onUpdatePos(
//                           addr,
//                           toPos01FromTap(d.localPosition),
//                         );
//                       },
//                       child: InteractiveViewer(
//                         transformationController: _tx,
//                         minScale: 0.8,
//                         maxScale: 6,
//                         child: SizedBox(
//                           width: w,
//                           height: h,
//                           child: Stack(
//                             children: [
//                               Positioned.fill(child: widget.image),
//                               for (final e in entries)
//                                 _OverlayMarker(
//                                   addr: e.key,
//                                   pos01: e.value,
//                                   parentSize: Size(w, h),
//                                   record: widget.latestByAddress[e.key.trim()],
//                                   editMode: widget.editMode,
//                                   isEditing: widget.editingAddress == e.key,
//                                   onTap: widget.editMode
//                                       ? () => widget.onPickEditingAddress(e.key)
//                                       : null,
//                                   onDragUpdate01: widget.editMode
//                                       ? (new01) =>
//                                             widget.onUpdatePos(e.key, new01)
//                                       : null,
//                                 ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     );
//                   },
//                 ),
//               ),
//             ),
//           ),
//           const SizedBox(height: 10),
//           _LegendHint(editMode: widget.editMode),
//         ],
//       ),
//     );
//   }
//
//   Widget _editorBar() {
//     return Row(
//       children: [
//         Expanded(
//           child: _Glass(
//             child: DropdownButtonHideUnderline(
//               child: DropdownButton<String>(
//                 isExpanded: true,
//                 dropdownColor: const Color(0xFF11183a),
//                 value: widget.editingAddress,
//                 hint: const Text(
//                   'Chọn plcAddress để đặt marker',
//                   style: TextStyle(color: Colors.white70),
//                 ),
//                 items: widget.allAddresses
//                     .map(
//                       (a) => DropdownMenuItem(
//                         value: a,
//                         child: Text(
//                           a,
//                           style: const TextStyle(color: Colors.white),
//                         ),
//                       ),
//                     )
//                     .toList(),
//                 onChanged: widget.onPickEditingAddress,
//               ),
//             ),
//           ),
//         ),
//         const SizedBox(width: 10),
//         _Glass(
//           child: IconButton(
//             tooltip: 'Reset zoom',
//             onPressed: () => _tx.value = Matrix4.identity(),
//             icon: const Icon(Icons.center_focus_strong, color: Colors.white),
//           ),
//         ),
//       ],
//     );
//   }
//
//   int _addrNum(String s) {
//     final m = RegExp(r'\d+').firstMatch(s);
//     return m == null ? 0 : int.parse(m.group(0)!);
//   }
// }
//
// // ========================= MARKER =========================
//
// class _OverlayMarker extends StatelessWidget {
//   final String addr;
//   final Offset pos01;
//   final Size parentSize;
//   final LatestRecordDto? record;
//
//   final bool editMode;
//   final bool isEditing;
//   final VoidCallback? onTap;
//   final ValueChanged<Offset>? onDragUpdate01;
//
//   const _OverlayMarker({
//     required this.addr,
//     required this.pos01,
//     required this.parentSize,
//     required this.record,
//     required this.editMode,
//     required this.isEditing,
//     required this.onTap,
//     required this.onDragUpdate01,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final left = pos01.dx * parentSize.width;
//     final top = pos01.dy * parentSize.height;
//
//     final valueText = record == null ? '—' : _fmtValue(record!.value ?? 0);
//
//     final chip = Container(
//       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
//       decoration: BoxDecoration(
//         color: isEditing
//             ? Colors.amber.withOpacity(0.25)
//             : Colors.black.withOpacity(0.35),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(
//           color: isEditing ? Colors.amber : Colors.white24,
//           width: 1,
//         ),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Container(
//             width: 8,
//             height: 8,
//             decoration: BoxDecoration(
//               color: record == null ? Colors.grey : Colors.greenAccent,
//               shape: BoxShape.circle,
//             ),
//           ),
//           const SizedBox(width: 8),
//           Text(
//             '$addr: $valueText',
//             style: const TextStyle(
//               color: Colors.white,
//               fontWeight: FontWeight.w700,
//               fontSize: 13,
//             ),
//           ),
//         ],
//       ),
//     );
//
//     Widget content = GestureDetector(onTap: onTap, child: chip);
//
//     if (editMode && onDragUpdate01 != null) {
//       content = _DraggableOverlay(
//         initialPos01: pos01,
//         parentSize: parentSize,
//         onDragUpdate01: onDragUpdate01!,
//         child: content,
//       );
//     }
//
//     return Positioned(
//       left: left,
//       top: top,
//       child: Transform.translate(
//         offset: const Offset(-10, -10),
//         child: content,
//       ),
//     );
//   }
//
//   String _fmtValue(num v) {
//     final d = v.toDouble();
//     if (d.abs() >= 100) return d.toStringAsFixed(1);
//     if (d.abs() >= 10) return d.toStringAsFixed(2);
//     return d.toStringAsFixed(3);
//   }
// }
//
// class _DraggableOverlay extends StatefulWidget {
//   final Offset initialPos01;
//   final Size parentSize;
//   final Widget child;
//   final ValueChanged<Offset> onDragUpdate01;
//
//   const _DraggableOverlay({
//     required this.initialPos01,
//     required this.parentSize,
//     required this.child,
//     required this.onDragUpdate01,
//   });
//
//   @override
//   State<_DraggableOverlay> createState() => _DraggableOverlayState();
// }
//
// class _DraggableOverlayState extends State<_DraggableOverlay> {
//   late Offset pos01;
//
//   @override
//   void initState() {
//     super.initState();
//     pos01 = widget.initialPos01;
//   }
//
//   @override
//   void didUpdateWidget(covariant _DraggableOverlay oldWidget) {
//     super.didUpdateWidget(oldWidget);
//     pos01 = widget.initialPos01;
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onPanUpdate: (d) {
//         final dx01 = d.delta.dx / widget.parentSize.width;
//         final dy01 = d.delta.dy / widget.parentSize.height;
//
//         final next = Offset(
//           (pos01.dx + dx01).clamp(0.0, 1.0),
//           (pos01.dy + dy01).clamp(0.0, 1.0),
//         );
//
//         setState(() => pos01 = next);
//         widget.onDragUpdate01(next);
//       },
//       child: widget.child,
//     );
//   }
// }
//
// // ========================= SMALL UI =========================
//
// class _LegendHint extends StatelessWidget {
//   final bool editMode;
//
//   const _LegendHint({required this.editMode});
//
//   @override
//   Widget build(BuildContext context) {
//     return _Glass(
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//         child: Text(
//           editMode
//               ? 'EDIT MODE: Chọn plcAddress → tap lên ảnh để đặt vị trí, hoặc drag marker để chỉnh.'
//               : 'Tip: Pinch/scroll để zoom. Overlay hiển thị plcAddress → latest value.',
//           style: const TextStyle(color: Colors.white70, fontSize: 12),
//         ),
//       ),
//     );
//   }
// }
//
// class _Glass extends StatelessWidget {
//   final Widget child;
//
//   const _Glass({required this.child});
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white.withOpacity(0.08),
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: Colors.white.withOpacity(0.12)),
//       ),
//       child: child,
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../utility_models/response/latest_record.dart';
import '../../../utility_models/utility_facade_service.dart';
import '../../../utility_state/FacLatestDetailProvider.dart';
import 'overlay_layout_store.dart';

class UtilityFacDetailScreens extends StatelessWidget {
  final String facId;
  final UtilityFacadeService svc;

  const UtilityFacDetailScreens({
    super.key,
    required this.facId,
    required this.svc,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<FacLatestDetailProvider>(
          create: (_) {
            final p = FacLatestDetailProvider(svc: svc, facId: facId);
            p.fetch();
            p.startPolling(const Duration(seconds: 10));
            return p;
          },
        ),
        ChangeNotifierProvider<OverlayGroupLayoutStore>(
          create: (_) {
            final s = OverlayGroupLayoutStore(svc);
            s.loadGroups(facId);
            return s;
          },
        ),
      ],
      child: _FacDetailBody(facId: facId),
    );
  }
}

// ======================= BODY =======================

class _FacDetailBody extends StatefulWidget {
  final String facId;

  const _FacDetailBody({required this.facId});

  @override
  State<_FacDetailBody> createState() => _FacDetailBodyState();
}

class _FacDetailBodyState extends State<_FacDetailBody>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  bool editMode = false;
  String? editingBox; // ✅ boxDeviceId đang edit

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final latest = context.watch<FacLatestDetailProvider>();
    final groupStore = context.watch<OverlayGroupLayoutStore>();

    final rows = latest.rows;

    // group by boxDeviceId
    final groups = <String, List<LatestRecordDto>>{};
    for (final r in rows) {
      groups.putIfAbsent(r.boxDeviceId, () => []).add(r);
    }

    // sort inside group by plc number
    int addrNum(String s) =>
        int.tryParse(RegExp(r'\d+').firstMatch(s)?.group(0) ?? '0') ?? 0;

    for (final list in groups.values) {
      list.sort(
        (a, b) => addrNum(a.plcAddress).compareTo(addrNum(b.plcAddress)),
      );
    }

    final boxIds = groups.keys.toList()..sort();

    // ensure editingBox default
    if (editMode && editingBox == null && boxIds.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => editingBox = boxIds.first);
      });
    }

    final last = latest.lastUpdated;
    final lastText = last == null
        ? '—'
        : '${last.hour.toString().padLeft(2, '0')}:'
              '${last.minute.toString().padLeft(2, '0')}:'
              '${last.second.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0a0e27),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _ScadaGradient(
        child: SafeArea(
          child: Column(
            children: [
              _TopHeader(
                facId: widget.facId,
                lastText: lastText,
                editMode: editMode,
                onToggleEdit: () => setState(() => editMode = !editMode),
              ),
              _Tabs(controller: _tab),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _FacOverlayMapGroup(
                      facId: widget.facId,
                      image: Image.asset(
                        'assets/images/${widget.facId.toLowerCase()}.png',
                        fit: BoxFit.cover,
                      ),
                      groups: groups,
                      boxIds: boxIds,
                      groupLayout: groupStore.groupLayoutOf(widget.facId),
                      editMode: editMode,
                      editingBox: editingBox,
                      onPickEditingBox: (b) => setState(() => editingBox = b),
                      onUpdateGroupPos: (box, pos01) async {
                        await context
                            .read<OverlayGroupLayoutStore>()
                            .setGroupPos(
                              facId: widget.facId,
                              boxDeviceId: box,
                              pos01: pos01,
                            );
                      },
                    ),
                    _ListTab(groups: groups),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ======================= LIST TAB =======================

class _ListTab extends StatelessWidget {
  final Map<String, List<LatestRecordDto>> groups;

  const _ListTab({required this.groups});

  @override
  Widget build(BuildContext context) {
    final boxIds = groups.keys.toList()..sort();
    if (boxIds.isEmpty) {
      return const Center(
        child: Text('No data', style: TextStyle(color: Colors.white70)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: boxIds.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final box = boxIds[i];
        final items = groups[box] ?? const [];
        return _Glass(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  box,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                ...items.map(
                  (r) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Text(
                          r.plcAddress,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _fmtValue(r.value ?? 0),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _fmtValue(num v) {
    final d = v.toDouble();
    if (d.abs() >= 100) return d.toStringAsFixed(1);
    if (d.abs() >= 10) return d.toStringAsFixed(2);
    return d.toStringAsFixed(3);
  }
}

// ======================= MAP GROUP =======================

class _FacOverlayMapGroup extends StatefulWidget {
  final String facId;
  final Widget image;

  final Map<String, List<LatestRecordDto>> groups;
  final List<String> boxIds;

  /// boxDeviceId -> pos01
  final Map<String, Offset> groupLayout;

  final bool editMode;
  final String? editingBox;
  final ValueChanged<String?> onPickEditingBox;

  final void Function(String boxDeviceId, Offset pos01) onUpdateGroupPos;

  const _FacOverlayMapGroup({
    required this.facId,
    required this.image,
    required this.groups,
    required this.boxIds,
    required this.groupLayout,
    required this.editMode,
    required this.editingBox,
    required this.onPickEditingBox,
    required this.onUpdateGroupPos,
  });

  @override
  State<_FacOverlayMapGroup> createState() => _FacOverlayMapGroupState();
}

class _FacOverlayMapGroupState extends State<_FacOverlayMapGroup> {
  final TransformationController _tx = TransformationController();

  @override
  void dispose() {
    _tx.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          if (widget.editMode) _editorBar(),
          const SizedBox(height: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: Colors.black.withOpacity(0.25),
                child: LayoutBuilder(
                  builder: (context, cs) {
                    final w = cs.maxWidth;
                    final h = cs.maxHeight;

                    Offset toPos01FromTap(Offset localInViewer) {
                      final scene = _tx.toScene(localInViewer);
                      return Offset(
                        (scene.dx / w).clamp(0.0, 1.0),
                        (scene.dy / h).clamp(0.0, 1.0),
                      );
                    }

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (d) {
                        if (!widget.editMode) return;
                        final box = widget.editingBox;
                        if (box == null) return;
                        widget.onUpdateGroupPos(
                          box,
                          toPos01FromTap(d.localPosition),
                        );
                      },
                      child: InteractiveViewer(
                        transformationController: _tx,
                        minScale: 0.8,
                        maxScale: 6,
                        child: SizedBox(
                          width: w,
                          height: h,
                          child: Stack(
                            children: [
                              Positioned.fill(child: widget.image),

                              for (final box in widget.boxIds)
                                _GroupFrame(
                                  boxDeviceId: box,
                                  parentSize: Size(w, h),
                                  groupPos01:
                                      widget.groupLayout[box] ??
                                      _autoPlace(
                                        box,
                                        widget.boxIds.indexOf(box),
                                      ),
                                  items: widget.groups[box] ?? const [],
                                  editMode: widget.editMode,
                                  isEditing: widget.editingBox == box,
                                  onTap: widget.editMode
                                      ? () => widget.onPickEditingBox(box)
                                      : null,
                                  onDragGroup01: widget.editMode
                                      ? (new01) =>
                                            widget.onUpdateGroupPos(box, new01)
                                      : null,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _LegendHint(editMode: widget.editMode),
        ],
      ),
    );
  }

  /// fallback auto place nếu chưa có layout group trong DB
  Offset _autoPlace(String box, int idx) {
    // grid 3 cột
    final col = idx % 3;
    final row = idx ~/ 3;
    final x = 0.18 + col * 0.28;
    final y = 0.18 + row * 0.22;
    return Offset(x.clamp(0.0, 1.0), y.clamp(0.0, 1.0));
  }

  Widget _editorBar() {
    return Row(
      children: [
        Expanded(
          child: _Glass(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                dropdownColor: const Color(0xFF11183a),
                value: widget.editingBox,
                hint: const Text(
                  'Chọn boxDeviceId để đặt/move khung',
                  style: TextStyle(color: Colors.white70),
                ),
                items: widget.boxIds
                    .map(
                      (b) => DropdownMenuItem(
                        value: b,
                        child: Text(
                          b,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: widget.onPickEditingBox,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _Glass(
          child: IconButton(
            tooltip: 'Reset zoom',
            onPressed: () => _tx.value = Matrix4.identity(),
            icon: const Icon(Icons.center_focus_strong, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

// ======================= GROUP FRAME =======================

class _GroupFrame extends StatefulWidget {
  final String boxDeviceId;
  final Offset groupPos01;
  final Size parentSize;

  final List<LatestRecordDto> items;

  final bool editMode;
  final bool isEditing;
  final VoidCallback? onTap;
  final ValueChanged<Offset>? onDragGroup01;

  const _GroupFrame({
    required this.boxDeviceId,
    required this.groupPos01,
    required this.parentSize,
    required this.items,
    required this.editMode,
    required this.isEditing,
    required this.onTap,
    required this.onDragGroup01,
  });

  @override
  State<_GroupFrame> createState() => _GroupFrameState();
}

class _GroupFrameState extends State<_GroupFrame> {
  late Offset pos01;

  @override
  void initState() {
    super.initState();
    pos01 = widget.groupPos01;
  }

  @override
  void didUpdateWidget(covariant _GroupFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    pos01 = widget.groupPos01;
  }

  @override
  Widget build(BuildContext context) {
    final left = pos01.dx * widget.parentSize.width;
    final top = pos01.dy * widget.parentSize.height;

    final borderColor = widget.isEditing ? Colors.amber : Colors.white24;
    final bg = widget.isEditing
        ? Colors.amber.withOpacity(0.10)
        : Colors.black.withOpacity(0.35);

    final frame = Container(
      width: 260,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.view_quilt_rounded,
                size: 16,
                color: Colors.white70,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.boxDeviceId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
              if (widget.editMode)
                Icon(
                  widget.isEditing ? Icons.edit : Icons.drag_indicator,
                  size: 16,
                  color: widget.isEditing ? Colors.amber : Colors.white54,
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (final r in widget.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Text(
                    r.plcAddress,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _fmtValue(r.value ?? 0),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    Widget content = GestureDetector(onTap: widget.onTap, child: frame);

    if (widget.editMode && widget.onDragGroup01 != null) {
      content = GestureDetector(
        onPanUpdate: (d) {
          final dx01 = d.delta.dx / widget.parentSize.width;
          final dy01 = d.delta.dy / widget.parentSize.height;
          final next = Offset(
            (pos01.dx + dx01).clamp(0.0, 1.0),
            (pos01.dy + dy01).clamp(0.0, 1.0),
          );
          setState(() => pos01 = next);
          widget.onDragGroup01!(next);
        },
        child: content,
      );
    }

    return Positioned(
      left: left,
      top: top,
      child: Transform.translate(
        offset: const Offset(-10, -10),
        child: content,
      ),
    );
  }

  static String _fmtValue(num v) {
    final d = v.toDouble();
    if (d.abs() >= 100) return d.toStringAsFixed(1);
    if (d.abs() >= 10) return d.toStringAsFixed(2);
    return d.toStringAsFixed(3);
  }
}

// ======================= HEADER/TABS/HELPERS =======================

class _TopHeader extends StatelessWidget {
  final String facId;
  final String lastText;
  final bool editMode;
  final VoidCallback onToggleEdit;

  const _TopHeader({
    required this.facId,
    required this.lastText,
    required this.editMode,
    required this.onToggleEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'FAC $facId   |   Last: $lastText',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: editMode ? 'Disable Edit' : 'Enable Edit',
            onPressed: onToggleEdit,
            icon: Icon(
              editMode ? Icons.edit_off : Icons.edit,
              color: editMode ? Colors.amber : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  final TabController controller;

  const _Tabs({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: TabBar(
        controller: controller,
        indicatorColor: Colors.white,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        tabs: const [
          Tab(text: 'Map'),
          Tab(text: 'List'),
        ],
      ),
    );
  }
}

class _ScadaGradient extends StatelessWidget {
  final Widget child;

  const _ScadaGradient({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0a0e27), Color(0xFF1a1a2e), Color(0xFF16213e)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: child,
    );
  }
}

class _LegendHint extends StatelessWidget {
  final bool editMode;

  const _LegendHint({required this.editMode});

  @override
  Widget build(BuildContext context) {
    return _Glass(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(
          editMode
              ? 'EDIT MODE: Chọn boxDeviceId → tap map để đặt vị trí khung, hoặc drag khung để di chuyển.'
              : 'Tip: Pinch/scroll để zoom. Overlay theo cụm boxDeviceId.',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ),
    );
  }
}

class _Glass extends StatelessWidget {
  final Widget child;

  const _Glass({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: child,
    );
  }
}

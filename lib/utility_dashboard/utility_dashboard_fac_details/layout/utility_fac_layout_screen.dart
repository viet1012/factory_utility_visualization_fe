import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../utility_models/response/latest_record.dart';
import '../../../utility_models/utility_facade_service.dart';
import '../../../utility_state/FacLatestDetailProvider.dart';
import 'overlay_layout_store.dart';

class UtilityFacDetailScreens extends StatelessWidget {
  final String facId; // "A"
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
        ChangeNotifierProvider(
          create: (_) {
            final p = FacLatestDetailProvider(svc: svc, facId: facId);
            p.fetch();
            p.startPolling(const Duration(seconds: 10));
            return p;
          },
        ),
        ChangeNotifierProvider(
          create: (_) => OverlayLayoutStore(svc)..load(facId),
        ),
      ],
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

class _FacDetailBodyState extends State<_FacDetailBody>
    with SingleTickerProviderStateMixin {
  String q = '';
  late final TabController _tab;

  bool editMode = false;
  String? editingAddress;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OverlayLayoutStore>().load(widget.facId);
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  int _addrNum(String s) {
    final m = RegExp(r'\d+').firstMatch(s);
    return m == null ? 0 : int.parse(m.group(0)!);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<FacLatestDetailProvider>();
    final layoutStore = context.watch<OverlayLayoutStore>();

    final rows = p.rows;

    // quick lookup: plcAddress -> record
    final byAddr = <String, LatestRecordDto>{};
    for (final r in rows) {
      byAddr[r.plcAddress.trim()] = r;
    }

    // all addresses
    final allAddresses =
        (rows.map((e) => e.plcAddress.trim()).toSet()
              ..removeWhere((e) => e.isEmpty))
            .toList()
          ..sort((a, b) => _addrNum(a).compareTo(_addrNum(b)));
    if (editMode && editingAddress == null && allAddresses.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => editingAddress = allAddresses.first);
      });
    }

    final last = p.lastUpdated;
    final lastText = last == null
        ? '—'
        : '${last.hour.toString().padLeft(2, '0')}:'
              '${last.minute.toString().padLeft(2, '0')}:'
              '${last.second.toString().padLeft(2, '0')}';

    // filter list tab
    final filtered = rows.where((e) {
      final s = q.trim().toLowerCase();
      if (s.isEmpty) return true;
      return e.boxDeviceId.toLowerCase().contains(s) ||
          e.plcAddress.toLowerCase().contains(s) ||
          (e.boxId ?? '').toLowerCase().contains(s) ||
          (e.scadaId ?? '').toLowerCase().contains(s) ||
          (e.cateId ?? '').toLowerCase().contains(s) ||
          (e.cate ?? '').toLowerCase().contains(s) ||
          (e.fac ?? '').toLowerCase().contains(s);
    }).toList();

    // group by device
    final devGroups = <String, List<LatestRecordDto>>{};
    for (final r in filtered) {
      devGroups.putIfAbsent(r.boxDeviceId, () => []).add(r);
    }
    final devIds = devGroups.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0a0e27),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),

                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'FAC ${widget.facId}   |   Last: $lastText',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: editMode ? 'Tắt Edit' : 'Bật Edit',
                      onPressed: () => setState(() => editMode = !editMode),
                      icon: Icon(
                        editMode ? Icons.edit_off : Icons.edit,
                        color: editMode ? Colors.amber : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: TabBar(
                  controller: _tab,
                  indicatorColor: Colors.white,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  tabs: const [
                    Tab(text: 'Map'),
                    Tab(text: 'List'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _FacOverlayMap(
                      facId: widget.facId,
                      image: Image.asset(
                        'assets/images/${widget.facId.toLowerCase()}.png',
                        fit: BoxFit.cover,
                      ),
                      layout: layoutStore.layoutOf(widget.facId),
                      latestByAddress: byAddr,
                      editMode: editMode,
                      editingAddress: editingAddress,
                      onPickEditingAddress: (addr) =>
                          setState(() => editingAddress = addr),
                      onUpdatePos: (addr, pos01) async {
                        final rec = byAddr[addr];

                        if (rec == null) {
                          debugPrint(
                            'No latest record for $addr => cannot determine boxDeviceId',
                          );
                          return;
                        }

                        await context.read<OverlayLayoutStore>().setPos(
                          facId: widget.facId,
                          // hoặc "Fac_${widget.facId}" tù hệ của bạn
                          boxDeviceId: rec.boxDeviceId,
                          plcAddress: addr,
                          pos01: pos01,
                        );

                        // optional: reload lại từ db để confirm
                        await context.read<OverlayLayoutStore>().load(
                          widget.facId,
                        );
                      },

                      allAddresses: allAddresses,
                    ),

                    // ? Child th? 2: placeholder
                    const Center(
                      child: Text(
                        'List tab (TODO)',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
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

// ========================= MAP WIDGET =========================

class _FacOverlayMap extends StatefulWidget {
  final String facId;
  final Widget image;

  /// plcAddress -> pos 0..1
  final Map<String, Offset> layout;

  /// plcAddress -> latest record
  final Map<String, LatestRecordDto> latestByAddress;

  final bool editMode;
  final String? editingAddress;
  final ValueChanged<String?> onPickEditingAddress;
  final void Function(String addr, Offset pos01) onUpdatePos;

  final List<String> allAddresses;

  const _FacOverlayMap({
    required this.facId,
    required this.image,
    required this.layout,
    required this.latestByAddress,
    required this.editMode,
    required this.editingAddress,
    required this.onPickEditingAddress,
    required this.onUpdatePos,
    required this.allAddresses,
  });

  @override
  State<_FacOverlayMap> createState() => _FacOverlayMapState();
}

class _FacOverlayMapState extends State<_FacOverlayMap> {
  final TransformationController _tx = TransformationController();

  @override
  void dispose() {
    _tx.dispose();
    super.dispose();
  }

  int _addrNum(String s) {
    final m = RegExp(r'\d+').firstMatch(s);
    return m == null ? 0 : int.parse(m.group(0)!);
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.layout.entries.toList()
      ..sort((a, b) => _addrNum(a.key).compareTo(_addrNum(b.key)));

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

                    Offset _toPos01FromTap(Offset localInViewer) {
                      // Convert tap position (viewer) => scene using matrix inverse
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
                        final addr = widget.editingAddress;
                        if (addr == null) return;

                        final pos01 = _toPos01FromTap(d.localPosition);
                        widget.onUpdatePos(addr, pos01);
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

                              for (final e in entries)
                                _OverlayMarker(
                                  addr: e.key,
                                  pos01: e.value,
                                  parentSize: Size(w, h),
                                  record: widget.latestByAddress[e.key.trim()],
                                  editMode: widget.editMode,
                                  isEditing: widget.editingAddress == e.key,
                                  onTap: widget.editMode
                                      ? () => widget.onPickEditingAddress(e.key)
                                      : null,
                                  onDragUpdate01: widget.editMode
                                      ? (new01) =>
                                            widget.onUpdatePos(e.key, new01)
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

  Widget _editorBar() {
    return Row(
      children: [
        Expanded(
          child: _Glass(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                dropdownColor: const Color(0xFF11183a),
                value: widget.editingAddress,
                hint: const Text(
                  'Ch?n plcAddress d? d?t marker',
                  style: TextStyle(color: Colors.white70),
                ),
                items: widget.allAddresses
                    .map(
                      (a) => DropdownMenuItem(
                        value: a,
                        child: Text(
                          a,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: widget.onPickEditingAddress,
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

// ========================= MARKERS =========================

class _OverlayMarker extends StatelessWidget {
  final String addr;
  final Offset pos01;
  final Size parentSize;
  final LatestRecordDto? record;

  final bool editMode;
  final bool isEditing;
  final VoidCallback? onTap;
  final ValueChanged<Offset>? onDragUpdate01;

  const _OverlayMarker({
    required this.addr,
    required this.pos01,
    required this.parentSize,
    required this.record,
    required this.editMode,
    required this.isEditing,
    required this.onTap,
    required this.onDragUpdate01,
  });

  @override
  Widget build(BuildContext context) {
    final left = pos01.dx * parentSize.width;
    final top = pos01.dy * parentSize.height;

    final valueText = record == null
        ? '—'
        : _fmtValue(record!.value ?? 0); // ✅ null -> 0

    final timeText = record == null
        ? ''
        : '${record!.recordedAt.hour.toString().padLeft(2, '0')}:'
              '${record!.recordedAt.minute.toString().padLeft(2, '0')}:'
              '${record!.recordedAt.second.toString().padLeft(2, '0')}';

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isEditing
            ? Colors.amber.withOpacity(0.25)
            : Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEditing ? Colors.amber : Colors.white24,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: record == null ? Colors.grey : Colors.greenAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$addr: $valueText',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );

    Widget content = GestureDetector(onTap: onTap, child: chip);

    // Drag ch?nh v? trí (scene coords) — vì marker n?m trong scene
    if (editMode && onDragUpdate01 != null) {
      content = _DraggableOverlay(
        initialPos01: pos01,
        parentSize: parentSize,
        child: content,
        onDragUpdate01: onDragUpdate01!,
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

  String _fmtValue(num v) {
    final d = v.toDouble();
    if (d.abs() >= 100) return d.toStringAsFixed(1);
    if (d.abs() >= 10) return d.toStringAsFixed(2);
    return d.toStringAsFixed(3);
  }
}

class _DraggableOverlay extends StatefulWidget {
  final Offset initialPos01;
  final Size parentSize;
  final Widget child;
  final ValueChanged<Offset> onDragUpdate01;

  const _DraggableOverlay({
    required this.initialPos01,
    required this.parentSize,
    required this.child,
    required this.onDragUpdate01,
  });

  @override
  State<_DraggableOverlay> createState() => _DraggableOverlayState();
}

class _DraggableOverlayState extends State<_DraggableOverlay> {
  late Offset pos01;

  @override
  void initState() {
    super.initState();
    pos01 = widget.initialPos01;
  }

  @override
  void didUpdateWidget(covariant _DraggableOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    pos01 = widget.initialPos01;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (d) {
        final dx01 = d.delta.dx / widget.parentSize.width;
        final dy01 = d.delta.dy / widget.parentSize.height;
        final next = Offset(
          (pos01.dx + dx01).clamp(0.0, 1.0),
          (pos01.dy + dy01).clamp(0.0, 1.0),
        );
        setState(() => pos01 = next);
        widget.onDragUpdate01(next);
      },
      child: widget.child,
    );
  }
}

// ========================= SMALL UI HELPERS =========================

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
              ? 'EDIT MODE: Ch?n plcAddress ? tap lên ?nh d? d?t v? trí, ho?c drag marker d? ch?nh.'
              : 'Tip: Pinch/scroll d? zoom. Overlay hi?n th? theo plcAddress ? value (latest).',
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

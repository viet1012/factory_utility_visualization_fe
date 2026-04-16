import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../utility_models/response/latest_record.dart';
import '../../../utility_models/utility_facade_service.dart';
import '../../../utility_state/FacLatestDetailProvider.dart';
import 'overlay_layout_store.dart';

enum ArrowDirection {
  right,
  left,
  up,
  down,
}

enum LabelOrientation {
  horizontal,
  vertical,
}

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
            final provider = FacLatestDetailProvider(svc: svc, facId: facId);
            provider.fetch();
            provider.startPolling(const Duration(seconds: 10));
            return provider;
          },
        ),
        ChangeNotifierProvider<OverlayGroupLayoutStore>(
          create: (_) {
            final store = OverlayGroupLayoutStore(svc);
            store.loadGroups(facId);
            return store;
          },
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
  late final TabController _tabController;

  bool editMode = false;
  String? editingBoxId;

  // luu hu?ng mui tên theo box
  final Map<String, ArrowDirection> _boxDirections = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final latestProvider = context.watch<FacLatestDetailProvider>();
    final layoutStore = context.watch<OverlayGroupLayoutStore>();

    final boxIds = _extractSortedBoxIds(latestProvider.rows);

    if (editMode && editingBoxId == null && boxIds.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => editingBoxId = boxIds.first);
      });
    }

    final lastText = _formatTime(latestProvider.lastUpdated);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0a0e27),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: _TopHeader(
          facId: widget.facId,
          lastText: lastText,
          editMode: editMode,
          onToggleEdit: () => setState(() => editMode = !editMode),
        ),
      ),
      body: _ScadaGradient(
        child: SafeArea(
          child: Column(
            children: [
              _Tabs(controller: _tabController),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _FacOverlayMapGroup(
                      facId: widget.facId,
                      image: Image.asset(
                        'assets/images/${widget.facId.toLowerCase()}.png',
                        fit: BoxFit.contain,
                      ),
                      boxIds: boxIds,
                      groupLayout: layoutStore.groupLayoutOf(widget.facId),
                      directions: _boxDirections,
                      editMode: editMode,
                      editingBoxId: editingBoxId,
                      onPickEditingBox: (boxId) {
                        setState(() => editingBoxId = boxId);
                      },
                      onUpdateDirection: (boxId, direction) {
                        setState(() {
                          _boxDirections[boxId] = direction;
                        });
                      },
                      onUpdateGroupPos: (boxId, pos01) async {
                        await context.read<OverlayGroupLayoutStore>().setGroupPos(
                          facId: widget.facId,
                          boxDeviceId: boxId,
                          pos01: pos01,
                        );
                      },
                    ),
                    _ListTab(boxIds: boxIds),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _extractSortedBoxIds(List<LatestRecordDto> rows) {
    final ids = rows
        .map((e) => e.boxDeviceId.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ids;
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '—';
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
  }
}

class _ListTab extends StatelessWidget {
  final List<String> boxIds;

  const _ListTab({required this.boxIds});

  @override
  Widget build(BuildContext context) {
    if (boxIds.isEmpty) {
      return const Center(
        child: Text('No data', style: TextStyle(color: Colors.white70)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: boxIds.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final boxId = boxIds[index];
        return _Glass(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              boxId,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FacOverlayMapGroup extends StatefulWidget {
  final String facId;
  final Widget image;
  final List<String> boxIds;
  final Map<String, Offset> groupLayout;
  final Map<String, ArrowDirection> directions;
  final bool editMode;
  final String? editingBoxId;
  final ValueChanged<String?> onPickEditingBox;
  final void Function(String boxDeviceId, Offset pos01) onUpdateGroupPos;
  final void Function(String boxDeviceId, ArrowDirection direction)
  onUpdateDirection;

  const _FacOverlayMapGroup({
    required this.facId,
    required this.image,
    required this.boxIds,
    required this.groupLayout,
    required this.directions,
    required this.editMode,
    required this.editingBoxId,
    required this.onPickEditingBox,
    required this.onUpdateGroupPos,
    required this.onUpdateDirection,
  });

  @override
  State<_FacOverlayMapGroup> createState() => _FacOverlayMapGroupState();
}

class _FacOverlayMapGroupState extends State<_FacOverlayMapGroup> {
  final TransformationController _transformController =
  TransformationController();

  @override
  void dispose() {
    _transformController.dispose();
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
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final height = constraints.maxHeight;

                    Offset toPos01FromTap(Offset localInViewer) {
                      final scene = _transformController.toScene(localInViewer);
                      return Offset(
                        (scene.dx / width).clamp(0.0, 1.0),
                        (scene.dy / height).clamp(0.0, 1.0),
                      );
                    }

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) {
                        if (!widget.editMode) return;
                        final boxId = widget.editingBoxId;
                        if (boxId == null) return;

                        widget.onUpdateGroupPos(
                          boxId,
                          toPos01FromTap(details.localPosition),
                        );
                      },
                      child: InteractiveViewer(
                        transformationController: _transformController,
                        minScale: 0.8,
                        maxScale: 6,
                        child: SizedBox(
                          width: width,
                          height: height,
                          child: Stack(
                            children: [
                              Positioned.fill(child: widget.image),
                              for (final boxId in widget.boxIds)
                                _GroupFrame(
                                  boxDeviceId: boxId,
                                  parentSize: Size(width, height),
                                  groupPos01: widget.groupLayout[boxId] ??
                                      _autoPlace(widget.boxIds.indexOf(boxId)),
                                  editMode: widget.editMode,
                                  isEditing: widget.editingBoxId == boxId,
                                  onTap: widget.editMode
                                      ? () => widget.onPickEditingBox(boxId)
                                      : null,
                                  onDragGroup01: widget.editMode
                                      ? (newPos) =>
                                      widget.onUpdateGroupPos(boxId, newPos)
                                      : null,
                                  direction: widget.directions[boxId] ??
                                      ArrowDirection.right,
                                  orientation: LabelOrientation.horizontal,
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
        ],
      ),
    );
  }

  Offset _autoPlace(int index) {
    final col = index % 3;
    final row = index ~/ 3;
    final x = 0.18 + col * 0.28;
    final y = 0.18 + row * 0.22;
    return Offset(x.clamp(0.0, 1.0), y.clamp(0.0, 1.0));
  }

  Widget _editorBar() {
    final selectedBox = widget.editingBoxId;
    final selectedDirection =
        widget.directions[selectedBox] ?? ArrowDirection.right;

    return _Glass(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _DirectionButton(
              icon: Icons.arrow_left,
              selected: selectedDirection == ArrowDirection.left,
              onTap: selectedBox == null
                  ? null
                  : () => widget.onUpdateDirection(
                selectedBox,
                ArrowDirection.left,
              ),
            ),
            _DirectionButton(
              icon: Icons.keyboard_arrow_up,
              selected: selectedDirection == ArrowDirection.up,
              onTap: selectedBox == null
                  ? null
                  : () =>
                  widget.onUpdateDirection(selectedBox, ArrowDirection.up),
            ),
            _DirectionButton(
              icon: Icons.keyboard_arrow_down,
              selected: selectedDirection == ArrowDirection.down,
              onTap: selectedBox == null
                  ? null
                  : () => widget.onUpdateDirection(
                selectedBox,
                ArrowDirection.down,
              ),
            ),
            _DirectionButton(
              icon: Icons.arrow_right,
              selected: selectedDirection == ArrowDirection.right,
              onTap: selectedBox == null
                  ? null
                  : () => widget.onUpdateDirection(
                selectedBox,
                ArrowDirection.right,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DirectionButton extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  const _DirectionButton({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withOpacity(0.15) // ? nh?
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? Colors.white.withOpacity(0.5) // ? vi?n sáng nh?
                  : Colors.white.withOpacity(0.12),
            ),
          ),
          child: Icon(
            icon,
            size: 20,
            color: selected
                ? Colors.white // ? b? amber
                : Colors.white70,
          ),
        ),
      ),
    );
  }
}

class _GroupFrame extends StatefulWidget {
  final String boxDeviceId;
  final Offset groupPos01;
  final Size parentSize;
  final bool editMode;
  final bool isEditing;
  final VoidCallback? onTap;
  final ValueChanged<Offset>? onDragGroup01;

  final ArrowDirection direction;
  final LabelOrientation orientation;

  const _GroupFrame({
    required this.boxDeviceId,
    required this.groupPos01,
    required this.parentSize,
    required this.editMode,
    required this.isEditing,
    required this.onTap,
    required this.onDragGroup01,
    this.direction = ArrowDirection.right,
    this.orientation = LabelOrientation.horizontal,
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

  EdgeInsets _padding() {
    switch (widget.direction) {
      case ArrowDirection.right:
        return const EdgeInsets.fromLTRB(10, 8, 20, 8);
      case ArrowDirection.left:
        return const EdgeInsets.fromLTRB(20, 8, 10, 8);
      case ArrowDirection.up:
        return const EdgeInsets.fromLTRB(10, 20, 10, 8);
      case ArrowDirection.down:
        return const EdgeInsets.fromLTRB(10, 8, 10, 20);
    }
  }

  Offset _offset() {
    switch (widget.direction) {
      case ArrowDirection.right:
        return const Offset(-10, -10);
      case ArrowDirection.left:
        return const Offset(-160, -10);
      case ArrowDirection.up:
        return const Offset(-70, -10);
      case ArrowDirection.down:
        return const Offset(-70, -70);
    }
  }

  Widget _buildLabel() {
    final text = Text(
      widget.boxDeviceId,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w900,
        fontSize: 12,
      ),
    );

    if (widget.orientation == LabelOrientation.vertical) {
      return RotatedBox(quarterTurns: 1, child: text);
    }

    return Flexible(child: text);
  }

  Widget _buildContent() {
    if (widget.orientation == LabelOrientation.vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.view_quilt_rounded, size: 16, color: Colors.white70),
          const SizedBox(height: 6),
          _buildLabel(),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.view_quilt_rounded, size: 16, color: Colors.white70),
        const SizedBox(width: 6),
        _buildLabel(),
      ],
    );
  }

  Alignment _alignment() {
    switch (widget.direction) {
      case ArrowDirection.right:
        return Alignment.centerRight;

      case ArrowDirection.left:
        return Alignment.centerLeft;

      case ArrowDirection.up:
        return Alignment.topCenter;

      case ArrowDirection.down:
        return Alignment.bottomCenter;
    }
  }

  @override
  Widget build(BuildContext context) {
    final left = pos01.dx * widget.parentSize.width;
    final top = pos01.dy * widget.parentSize.height;

    final borderColor = widget.isEditing
        ? Colors.white.withOpacity(0.6)
        : Colors.white24;

    final backgroundColor = widget.isEditing
        ? Colors.white.withOpacity(0.12)
        : Colors.black.withOpacity(0.6);

    final frame = CustomPaint(
      painter: _ArrowPainter(
        color: backgroundColor,
        borderColor: borderColor,
        direction: widget.direction,
      ),
      child: Container(
        padding: _padding(),
        constraints: widget.orientation == LabelOrientation.vertical
            ? const BoxConstraints(minWidth: 60, maxWidth: 80)
            : const BoxConstraints(minWidth: 120, maxWidth: 220),
        child: _buildContent(),
      ),
    );

    Widget content = GestureDetector(onTap: widget.onTap, child: frame);

    if (widget.editMode && widget.onDragGroup01 != null) {
      content = GestureDetector(
        onPanUpdate: (details) {
          final dx = details.delta.dx / widget.parentSize.width;
          final dy = details.delta.dy / widget.parentSize.height;

          final next = Offset(
            (pos01.dx + dx).clamp(0.0, 1.0),
            (pos01.dy + dy).clamp(0.0, 1.0),
          );

          setState(() => pos01 = next);
        },
        onPanEnd: (_) {
          debugPrint('SAVE: ${widget.boxDeviceId} -> $pos01');
          widget.onDragGroup01!(pos01);
        },
        child: content,
      );
    }

    return Positioned(
      left: left,
      top: top,
      child: Align(
        alignment: _alignment(), // ? m?i
        child: content,
      ),
    );
  }
}



class _ArrowPainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  final ArrowDirection direction;

  _ArrowPainter({
    required this.color,
    required this.borderColor,
    required this.direction,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const arrow = 12.0;
    final path = Path();

    switch (direction) {
      case ArrowDirection.right:
        path.moveTo(0, 0);
        path.lineTo(size.width - arrow, 0);
        path.lineTo(size.width, size.height / 2);
        path.lineTo(size.width - arrow, size.height);
        path.lineTo(0, size.height);
        break;

      case ArrowDirection.left:
        path.moveTo(arrow, 0);
        path.lineTo(size.width, 0);
        path.lineTo(size.width, size.height);
        path.lineTo(arrow, size.height);
        path.lineTo(0, size.height / 2);
        break;

      case ArrowDirection.up:
        path.moveTo(0, arrow);
        path.lineTo(size.width / 2, 0);
        path.lineTo(size.width, arrow);
        path.lineTo(size.width, size.height);
        path.lineTo(0, size.height);
        break;

      case ArrowDirection.down:
        path.moveTo(0, 0);
        path.lineTo(size.width, 0);
        path.lineTo(size.width, size.height - arrow);
        path.lineTo(size.width / 2, size.height);
        path.lineTo(0, size.height - arrow);
        break;
    }

    path.close();

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final border = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawPath(path, fill);
    canvas.drawPath(path, border);
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter oldDelegate) => true;
}

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
              '$facId   |   Last: $lastText',
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
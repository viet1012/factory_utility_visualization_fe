import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../utility_models/response/latest_record.dart';
import '../../../utility_models/utility_facade_service.dart';
import '../../../utility_state/FacLatestDetailProvider.dart';
import 'overlay_layout_store.dart';

enum ArrowDirection { right, left, up, down }

enum LabelOrientation { horizontal, vertical }

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

  // local cache de UI cap nhat ngay
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

  Future<void> _updateDirection(ArrowDirection direction) async {
    final boxId = editingBoxId;
    if (boxId == null) return;

    setState(() {
      _boxDirections[boxId] = direction;
    });

    final store = context.read<OverlayGroupLayoutStore>();
    final pos = store.groupLayoutOf(widget.facId)[boxId];

    if (pos != null) {
      await store.setGroupPos(
        facId: widget.facId,
        boxDeviceId: boxId,
        pos01: pos,
        direction: direction,
      );
    }
  }

  List<String> _extractSortedBoxIds(List<LatestRecordDto> rows) {
    final ids =
        rows
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

  @override
  Widget build(BuildContext context) {
    final latestProvider = context.watch<FacLatestDetailProvider>();
    final layoutStore = context.watch<OverlayGroupLayoutStore>();

    final boxIds = _extractSortedBoxIds(latestProvider.rows);
    final savedDirections = layoutStore.groupDirectionOf(widget.facId);
    final mergedDirections = {...savedDirections, ..._boxDirections};

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
        actions: [
          if (editMode && editingBoxId != null) ...[
            _AppBarDirectionButton(
              icon: Icons.arrow_left,
              selected:
                  (mergedDirections[editingBoxId] ?? ArrowDirection.right) ==
                  ArrowDirection.left,
              onTap: () => _updateDirection(ArrowDirection.left),
            ),
            _AppBarDirectionButton(
              icon: Icons.keyboard_arrow_up,
              selected:
                  (mergedDirections[editingBoxId] ?? ArrowDirection.right) ==
                  ArrowDirection.up,
              onTap: () => _updateDirection(ArrowDirection.up),
            ),
            _AppBarDirectionButton(
              icon: Icons.keyboard_arrow_down,
              selected:
                  (mergedDirections[editingBoxId] ?? ArrowDirection.right) ==
                  ArrowDirection.down,
              onTap: () => _updateDirection(ArrowDirection.down),
            ),
            _AppBarDirectionButton(
              icon: Icons.arrow_right,
              selected:
                  (mergedDirections[editingBoxId] ?? ArrowDirection.right) ==
                  ArrowDirection.right,
              onTap: () => _updateDirection(ArrowDirection.right),
            ),
            const SizedBox(width: 8),
          ],
        ],
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
                      directions: mergedDirections,
                      editMode: editMode,
                      editingBoxId: editingBoxId,
                      onPickEditingBox: (boxId) {
                        setState(() => editingBoxId = boxId);
                      },
                      onUpdateDirection: (boxId, direction) async {
                        setState(() {
                          _boxDirections[boxId] = direction;
                        });

                        final pos = layoutStore.groupLayoutOf(
                          widget.facId,
                        )[boxId];
                        if (pos != null) {
                          await layoutStore.setGroupPos(
                            facId: widget.facId,
                            boxDeviceId: boxId,
                            pos01: pos,
                            direction: direction,
                          );
                        }
                      },
                      onUpdateGroupPos: (boxId, pos01) async {
                        final direction =
                            mergedDirections[boxId] ?? ArrowDirection.right;

                        await layoutStore.setGroupPos(
                          facId: widget.facId,
                          boxDeviceId: boxId,
                          pos01: pos01,
                          direction: direction,
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

class _AppBarDirectionButton extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _AppBarDirectionButton({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: selected
                ? Colors.amber.withOpacity(0.18)
                : Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? Colors.amberAccent
                  : Colors.white.withOpacity(0.14),
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: selected ? Colors.amberAccent : Colors.white,
          ),
        ),
      ),
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
  final Future<void> Function(String boxDeviceId, Offset pos01)
  onUpdateGroupPos;
  final Future<void> Function(String boxDeviceId, ArrowDirection direction)
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
  final FocusNode _focusNode = FocusNode();

  static const Size _imageSize = Size(1920, 1080);

  @override
  void dispose() {
    _focusNode.dispose();
    _transformController.dispose();
    super.dispose();
  }

  Rect _getImageRect(Size containerSize) {
    final scaleX = containerSize.width / _imageSize.width;
    final scaleY = containerSize.height / _imageSize.height;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    final scaledWidth = _imageSize.width * scale;
    final scaledHeight = _imageSize.height * scale;

    final dx = (containerSize.width - scaledWidth) / 2;
    final dy = (containerSize.height - scaledHeight) / 2;

    return Rect.fromLTWH(dx, dy, scaledWidth, scaledHeight);
  }

  Offset _autoPlace(int index) {
    final col = index % 3;
    final row = index ~/ 3;
    return Offset(0.2 + col * 0.25, 0.2 + row * 0.2);
  }

  Future<void> _moveSelectedByKeyboard(KeyEvent event) async {
    if (event is! KeyDownEvent) return;
    if (!widget.editMode) return;

    final boxId = widget.editingBoxId;
    if (boxId == null) return;

    final current =
        widget.groupLayout[boxId] ?? _autoPlace(widget.boxIds.indexOf(boxId));

    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final isAlt = HardwareKeyboard.instance.isAltPressed;
    final double step = isAlt ? 0.002 : (isShift ? 0.02 : 0.008);

    Offset delta = Offset.zero;

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      delta = const Offset(0, -1);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      delta = const Offset(0, 1);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      delta = const Offset(-1, 0);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      delta = const Offset(1, 0);
    } else {
      return;
    }

    final next = Offset(
      (current.dx + delta.dx * step).clamp(0.0, 1.0),
      (current.dy + delta.dy * step).clamp(0.0, 1.0),
    );

    await widget.onUpdateGroupPos(boxId, next);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final containerSize = Size(
            constraints.maxWidth,
            constraints.maxHeight,
          );

          final imageRect = _getImageRect(containerSize);

          return Focus(
            focusNode: _focusNode,
            autofocus: true,
            onKeyEvent: (_, event) {
              _moveSelectedByKeyboard(event);
              return KeyEventResult.handled;
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) {
                _focusNode.requestFocus();
              },
              child: InteractiveViewer(
                transformationController: _transformController,
                minScale: 0.8,
                maxScale: 5,
                panEnabled: !widget.editMode,
                scaleEnabled: !widget.editMode,
                child: SizedBox(
                  width: containerSize.width,
                  height: containerSize.height,
                  child: Stack(
                    children: [
                      Positioned.fromRect(rect: imageRect, child: widget.image),
                      for (final boxId in widget.boxIds)
                        _buildBox(boxId, imageRect),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBox(String boxId, Rect imageRect) {
    final pos01 =
        widget.groupLayout[boxId] ?? _autoPlace(widget.boxIds.indexOf(boxId));

    final left = imageRect.left + pos01.dx * imageRect.width;
    final top = imageRect.top + pos01.dy * imageRect.height;

    return Positioned(
      left: left,
      top: top,
      child: _GroupFrame(
        boxDeviceId: boxId,
        groupPos01: pos01,
        parentSize: Size(imageRect.width, imageRect.height),
        editMode: widget.editMode,
        isEditing: widget.editingBoxId == boxId,
        onTap: widget.editMode
            ? () {
                _focusNode.requestFocus();
                widget.onPickEditingBox(boxId);
              }
            : null,
        onDragGroup01: widget.editMode
            ? (newPos) async {
                await widget.onUpdateGroupPos(boxId, newPos);
              }
            : null,
        direction: widget.directions[boxId] ?? ArrowDirection.right,
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
  final Future<void> Function(Offset)? onDragGroup01;
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
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    pos01 = widget.groupPos01;
  }

  @override
  void didUpdateWidget(covariant _GroupFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dragging) {
      pos01 = widget.groupPos01;
    }
  }

  EdgeInsets _padding() {
    switch (widget.direction) {
      case ArrowDirection.right:
        return const EdgeInsets.fromLTRB(8, 5, 14, 5);
      case ArrowDirection.left:
        return const EdgeInsets.fromLTRB(14, 5, 8, 5);
      case ArrowDirection.up:
        return const EdgeInsets.fromLTRB(8, 12, 8, 5);
      case ArrowDirection.down:
        return const EdgeInsets.fromLTRB(8, 5, 8, 12);
    }
  }

  Widget _buildLabel(Color textColor) {
    final text = Text(
      widget.boxDeviceId,
      style: TextStyle(
        color: textColor,
        fontWeight: FontWeight.w900,
        fontSize: 10,
        shadows: const [
          Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1)),
        ],
      ),
    );

    if (widget.orientation == LabelOrientation.vertical) {
      return RotatedBox(quarterTurns: 1, child: text);
    }

    return Flexible(child: text);
  }

  Widget _buildContent(Color textColor) {
    if (widget.orientation == LabelOrientation.vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.view_quilt_rounded,
            size: 16,
            color: textColor.withOpacity(0.9),
          ),
          const SizedBox(height: 6),
          _buildLabel(textColor),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [_buildLabel(textColor)],
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
    // ===== STYLE STATES =====
    // Normal: dùng style đẹp như edit cũ
    // Selected/Edit: đổi sang màu khác nổi bật hơn
    final bool selected = widget.isEditing;
    final bool dragging = _dragging;

    final Color borderColor = selected
        ? const Color(0xFF7C4DFF) // tím sáng khi được chọn
        : const Color(0xFF122FEA).withOpacity(0.85); // cyan nhẹ khi bình thường

    final Color backgroundColor = selected
        ? const Color(0xFF2A1B4D).withOpacity(0.92) // tím đậm khi chọn
        : Colors.black.withOpacity(
            0.82,
          ); // dùng style edit cũ cho trạng thái thường

    final Color textColor = selected
        ? const Color(0xFFFFD54F) // vàng sáng khi đang chọn
        : Colors.white; // bình thường vẫn trắng rõ

    final List<BoxShadow> shadows = [
      BoxShadow(
        color: selected
            ? const Color(0xFF7C4DFF).withOpacity(0.35)
            : const Color(0xFF122FEA).withOpacity(0.18),
        blurRadius: selected ? 14 : 8,
        spreadRadius: selected ? 1.5 : 0.5,
      ),
    ];

    final frame = RepaintBoundary(
      child: AnimatedScale(
        scale: dragging ? 1.04 : (selected ? 1.02 : 1.0),
        duration: const Duration(milliseconds: 70),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          // decoration: BoxDecoration(boxShadow: shadows),
          child: CustomPaint(
            painter: _ArrowPainter(
              color: backgroundColor,
              borderColor: borderColor,
              direction: widget.direction,
            ),
            child: Container(
              padding: _padding(),
              constraints: widget.orientation == LabelOrientation.vertical
                  ? const BoxConstraints(minWidth: 44, maxWidth: 60)
                  : const BoxConstraints(
                      minWidth: 78,
                      maxWidth: 160,
                      minHeight: 40,
                    ),
              child: _buildContent(textColor),
            ),
          ),
        ),
      ),
    );

    if (!(widget.editMode && widget.onDragGroup01 != null)) {
      return Align(
        alignment: _alignment(),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: frame,
          ),
        ),
      );
    }

    return Align(
      alignment: _alignment(),
      child: MouseRegion(
        cursor: dragging
            ? SystemMouseCursors.grabbing
            : SystemMouseCursors.grab,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onPanStart: (_) {
            setState(() {
              _dragging = true;
            });
          },
          onPanUpdate: (details) {
            final dx = details.delta.dx / widget.parentSize.width;
            final dy = details.delta.dy / widget.parentSize.height;

            final next = Offset(
              (pos01.dx + dx).clamp(0.0, 1.0),
              (pos01.dy + dy).clamp(0.0, 1.0),
            );

            if (next != pos01) {
              setState(() {
                pos01 = next;
              });
            }
          },
          onPanEnd: (_) async {
            setState(() {
              _dragging = false;
            });
            await widget.onDragGroup01!(pos01);
          },
          onPanCancel: () {
            setState(() {
              _dragging = false;
            });
          },
          child: frame,
        ),
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
    final path = Path();

    const tip = 10.0;
    const neck = 6.0;

    switch (direction) {
      case ArrowDirection.right:
        path.moveTo(0, neck);
        path.lineTo(size.width - tip, neck);
        path.lineTo(size.width - tip, 0);
        path.lineTo(size.width, size.height / 2);
        path.lineTo(size.width - tip, size.height);
        path.lineTo(size.width - tip, size.height - neck);
        path.lineTo(0, size.height - neck);
        break;

      case ArrowDirection.left:
        path.moveTo(tip, 0);
        path.lineTo(tip, neck);
        path.lineTo(size.width, neck);
        path.lineTo(size.width, size.height - neck);
        path.lineTo(tip, size.height - neck);
        path.lineTo(tip, size.height);
        path.lineTo(0, size.height / 2);
        break;

      case ArrowDirection.up:
        path.moveTo(neck, tip);
        path.lineTo(size.width / 2 - neck, tip);
        path.lineTo(size.width / 2, 0);
        path.lineTo(size.width / 2 + neck, tip);
        path.lineTo(size.width - neck, tip);
        path.lineTo(size.width - neck, size.height);
        path.lineTo(neck, size.height);
        break;

      case ArrowDirection.down:
        path.moveTo(neck, 0);
        path.lineTo(size.width - neck, 0);
        path.lineTo(size.width - neck, size.height - tip);
        path.lineTo(size.width / 2 + neck, size.height - tip);
        path.lineTo(size.width / 2, size.height);
        path.lineTo(size.width / 2 - neck, size.height - tip);
        path.lineTo(neck, size.height - tip);
        break;
    }

    path.close();

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final border = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawPath(path, fill);
    canvas.drawPath(path, border);
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.direction != direction;
  }
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
                fontSize: 18,
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../utility_state/latest_provider.dart';
import '../controllers/fac_detail_edit_controller.dart';
import '../helpers/fac_detail_formatters.dart';
import '../layout/fac_overlay_map.dart';
import '../layout/overlay_layout_store.dart';
import '../layout/scada_style.dart';
import '../mappers/latest_tree_device_mapper.dart';
import '../models/group_frame_types.dart';
import '../widgets/color_picker_dialog.dart';
import '../widgets/edit_actions.dart';
import '../widgets/scada_gradient.dart';
import '../widgets/top_header.dart';

class FacDetailBody extends StatefulWidget {
  final String facId;

  const FacDetailBody({super.key, required this.facId});

  @override
  State<FacDetailBody> createState() {
    return _FacDetailBodyState();
  }
}

class _FacDetailBodyState extends State<FacDetailBody> {
  OverlayGroupLayoutStore get _layoutStore {
    return context.read<OverlayGroupLayoutStore>();
  }

  FacDetailEditController get _editController {
    return context.read<FacDetailEditController>();
  }

  @override
  void initState() {
    super.initState();
    _refreshFacility();
  }

  @override
  void didUpdateWidget(covariant FacDetailBody oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.facId != widget.facId) {
      _editController.reset();
      _refreshFacility();
    }
  }

  void _refreshFacility() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      context.read<LatestProvider>().refreshFacility(
        widget.facId,
        silent: false,
      );
    });
  }

  Future<void> _pickColor() async {
    final boxDeviceId = _editController.editingBoxDeviceId;

    if (boxDeviceId == null) return;

    final color = await showDialog<Color>(
      context: context,
      builder: (_) => const ColorPickerDialog(),
    );

    if (!mounted || color == null) return;

    await _layoutStore.setGroupColor(
      facId: widget.facId,
      boxDeviceId: boxDeviceId,
      color: color,
    );
  }

  Future<void> _saveDirection({
    required String boxDeviceId,
    required ArrowDirection direction,
  }) async {
    _editController.setLocalDirection(boxDeviceId, direction);

    final position = _layoutStore.groupLayoutOf(widget.facId)[boxDeviceId];

    if (position == null) return;

    await _savePosition(
      boxDeviceId: boxDeviceId,
      position: position,
      direction: direction,
    );
  }

  Future<void> _savePosition({
    required String boxDeviceId,
    required Offset position,
    required ArrowDirection direction,
  }) {
    return _layoutStore.setGroupPos(
      facId: widget.facId,
      boxDeviceId: boxDeviceId,
      pos01: position,
      direction: direction,

      // Không truyền color.
      // Store sẽ giữ màu hiện tại của box.
    );
  }

  @override
  Widget build(BuildContext context) {
    final latestProvider = context.watch<LatestProvider>();

    final layoutStore = context.watch<OverlayGroupLayoutStore>();

    final editController = context.watch<FacDetailEditController>();

    final facility = latestProvider.facilityOf(widget.facId);

    final devicesById = LatestTreeDeviceMapper.mapFacility(facility);

    final boxDeviceIds = LatestTreeDeviceMapper.sortedDeviceIds(devicesById);

    final lastUpdated = LatestTreeDeviceMapper.latestRecordedAt(
      devicesById.values,
    );

    final directions = <String, ArrowDirection>{
      ...layoutStore.groupDirectionOf(widget.facId),
      ...editController.localDirections,
    };

    _ensureEditingDevice(editController, boxDeviceIds);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: ScadaStyle.dark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: Navigator.of(context).pop,
        ),
        title: TopHeader(
          facId: widget.facId,
          lastText: FacDetailFormatters.time(lastUpdated),
          editMode: editController.editMode,
          onToggleEdit: editController.toggleEditMode,
        ),
        actions: [
          if (editController.editMode &&
              editController.editingBoxDeviceId != null)
            EditActions(
              selectedDirection:
                  directions[editController.editingBoxDeviceId] ??
                  ArrowDirection.right,
              onPickColor: _pickColor,
              onChangeDirection: (direction) {
                final boxDeviceId = editController.editingBoxDeviceId;

                if (boxDeviceId == null) return;

                _saveDirection(boxDeviceId: boxDeviceId, direction: direction);
              },
            ),
        ],
      ),
      body: ScadaGradient(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FacOverlayMap(
              facId: widget.facId,
              boxDeviceIds: boxDeviceIds,
              devicesById: devicesById,
              groupLayout: layoutStore.groupLayoutOf(widget.facId),
              directions: directions,
              colors: layoutStore.groupColorOf(widget.facId),
              editMode: editController.editMode,
              editingBoxDeviceId: editController.editingBoxDeviceId,
              onPickEditingDevice: editController.selectDevice,
              onUpdateDirection: _saveDirection,
              onUpdateGroupPosition:
                  ({required boxDeviceId, required position}) {
                    return _savePosition(
                      boxDeviceId: boxDeviceId,
                      position: position,
                      direction:
                          directions[boxDeviceId] ?? ArrowDirection.right,
                    );
                  },
            ),
          ),
        ),
      ),
    );
  }

  void _ensureEditingDevice(
    FacDetailEditController controller,
    List<String> boxDeviceIds,
  ) {
    if (!controller.editMode ||
        controller.editingBoxDeviceId != null ||
        boxDeviceIds.isEmpty) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      controller.ensureSelected(boxDeviceIds);
    });
  }
}

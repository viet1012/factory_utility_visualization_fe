import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../utility_state/latest_provider.dart';
import '../controllers/fac_detail_edit_controller.dart';
import '../helpers/fac_detail_formatters.dart';
import '../layout/fac_overlay_map.dart';
import '../layout/overlay_layout_store.dart';
import '../layout/scada_style.dart';
import '../mappers/fac_box_group_mapper.dart';
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

    if (oldWidget.facId == widget.facId) {
      return;
    }

    _editController.reset();
    _refreshFacility();
  }

  // ============================================================
  // REFRESH
  // ============================================================

  void _refreshFacility() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      context.read<LatestProvider>().refreshFacility(
        widget.facId,
        silent: false,
      );
    });
  }

  // ============================================================
  // COLOR
  //
  // Controller và store vẫn đang dùng tên boxDeviceId,
  // nhưng giá trị truyền vào thực tế bây giờ là boxId.
  // ============================================================

  Future<void> _pickColor() async {
    final boxId = _editController.editingBoxDeviceId;

    if (boxId == null || boxId.trim().isEmpty) {
      return;
    }

    final color = await showDialog<Color>(
      context: context,
      builder: (_) {
        return const ColorPickerDialog();
      },
    );

    if (!mounted || color == null) {
      return;
    }

    await _layoutStore.setGroupColor(
      facId: widget.facId,
      boxDeviceId: boxId,
      color: color,
    );
  }

  // ============================================================
  // DIRECTION
  // ============================================================

  Future<void> _saveDirection({
    required String boxId,
    required ArrowDirection direction,
  }) async {
    final normalizedBoxId = boxId.trim();

    if (normalizedBoxId.isEmpty) {
      return;
    }

    _editController.setLocalDirection(normalizedBoxId, direction);

    final position = _layoutStore.groupLayoutOf(widget.facId)[normalizedBoxId];

    /*
     * Box chưa từng được kéo/lưu vị trí.
     * Không ghi direction xuống store vì chưa có position.
     *
     * Direction vẫn được giữ tạm trong editController.
     */
    if (position == null) {
      return;
    }

    await _savePosition(
      boxId: normalizedBoxId,
      position: position,
      direction: direction,
    );
  }

  // ============================================================
  // POSITION
  // ============================================================

  Future<void> _savePosition({
    required String boxId,
    required Offset position,
    required ArrowDirection direction,
  }) {
    final normalizedBoxId = boxId.trim();

    if (normalizedBoxId.isEmpty) {
      return Future<void>.value();
    }

    return _layoutStore.setGroupPos(
      facId: widget.facId,

      /*
       * Store vẫn dùng property boxDeviceId.
       * Key thực tế được lưu là boxId.
       */
      boxDeviceId: normalizedBoxId,

      pos01: position,
      direction: direction,
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final latestProvider = context.watch<LatestProvider>();

    final layoutStore = context.watch<OverlayGroupLayoutStore>();

    final editController = context.watch<FacDetailEditController>();

    final facility = latestProvider.facilityOf(widget.facId);

    // ==========================================================
    // 1. MAP TREE THÀNH DEVICE
    // ==========================================================

    final devicesById = LatestTreeDeviceMapper.mapFacility(facility);

    // ==========================================================
    // 2. GOM NHIỀU BOX DEVICE THEO BOX ID
    //
    // Ví dụ:
    // DB-01_ES35-SW
    // DB-01_TEMP
    // DB-01_POWER
    //
    // đều thuộc boxId DB-01 và chỉ hiển thị một frame DB-01.
    // ==========================================================

    final boxesById = FacBoxGroupMapper.groupDevices(devicesById);

    final boxIds = FacBoxGroupMapper.sortedKeys(boxesById);

    // ==========================================================
    // LAST UPDATED
    // ==========================================================

    final lastUpdated = LatestTreeDeviceMapper.latestRecordedAt(
      devicesById.values,
    );

    // ==========================================================
    // LAYOUT DATA
    //
    // Tất cả key bên dưới bây giờ đều là boxId.
    // ==========================================================

    final savedDirections = layoutStore.groupDirectionOf(widget.facId);

    final directions = <String, ArrowDirection>{
      ...savedDirections,
      ...editController.localDirections,
    };

    final groupLayout = layoutStore.groupLayoutOf(widget.facId);

    final groupColors = layoutStore.groupColorOf(widget.facId);

    _ensureEditingBox(controller: editController, boxIds: boxIds);

    final editingBoxId = editController.editingBoxDeviceId;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: ScadaStyle.dark,
        elevation: 0,

        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),

        title: TopHeader(
          facId: widget.facId,
          lastText: FacDetailFormatters.time(lastUpdated),
          editMode: editController.editMode,
          onToggleEdit: editController.toggleEditMode,
        ),

        actions: [
          if (editController.editMode && editingBoxId != null)
            EditActions(
              selectedDirection:
                  directions[editingBoxId] ?? ArrowDirection.right,

              onPickColor: _pickColor,

              onChangeDirection: (direction) {
                final currentBoxId = editController.editingBoxDeviceId;

                if (currentBoxId == null) {
                  return;
                }

                _saveDirection(boxId: currentBoxId, direction: direction);
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

              /*
               * Danh sách Box ID.
               */
              boxIds: boxIds,

              /*
               * Mỗi phần tử chứa toàn bộ signal của
               * các boxDeviceId cùng Box ID.
               */
              boxesById: boxesById,

              /*
               * Layout, direction và color đều sử dụng
               * Box ID làm key.
               */
              groupLayout: groupLayout,
              directions: directions,
              colors: groupColors,

              editMode: editController.editMode,

              /*
               * Controller vẫn có tên editingBoxDeviceId,
               * nhưng giá trị bên trong là Box ID.
               */
              editingBoxId: editingBoxId,

              onPickEditingBox: (boxId) {
                editController.selectDevice(boxId);
              },

              onUpdateDirection: ({required boxDeviceId, required direction}) {
                /*
                 * Tên callback cũ là boxDeviceId.
                 * Giá trị thực tế là boxId.
                 */
                return _saveDirection(boxId: boxDeviceId, direction: direction);
              },

              onUpdateGroupPosition:
                  ({required boxDeviceId, required position}) {
                    final boxId = boxDeviceId.trim();

                    final direction = directions[boxId] ?? ArrowDirection.right;

                    return _savePosition(
                      boxId: boxId,
                      position: position,
                      direction: direction,
                    );
                  },
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // AUTO SELECT BOX KHI BẬT EDIT MODE
  // ============================================================

  void _ensureEditingBox({
    required FacDetailEditController controller,
    required List<String> boxIds,
  }) {
    if (!controller.editMode) {
      return;
    }

    if (controller.editingBoxDeviceId != null) {
      return;
    }

    if (boxIds.isEmpty) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      /*
       * Method vẫn tên ensureSelected,
       * nhưng danh sách truyền vào là Box ID.
       */
      controller.ensureSelected(boxIds);
    });
  }
}

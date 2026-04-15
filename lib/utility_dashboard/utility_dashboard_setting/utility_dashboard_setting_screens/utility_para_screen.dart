import 'package:factory_utility_visualization/utility_dashboard/utility_dashboard_setting/utility_dashboard_setting_dialog/para_form_dialog.dart';
import 'package:flutter/material.dart' hide SearchBar;

import '../../utility_dashboard_common/utility_fac_style.dart';
import '../setting_security.dart';
import '../utility_dashboard_setting_models/utility_para.dart';
import '../utility_dashboard_setting_widgets/protected_edit_button.dart';
import '../utility_dashboard_setting_widgets/setting_common_widgets.dart';
import '../utility_para_api.dart';
import '../utility_scada_channel_api.dart';
import 'base_setting_screen.dart';

class UtilityParaTreeScreen extends StatefulWidget {
  final UtilityParaApi api;
  final UtilityScadaChannelApi scadaChannelApi;

  const UtilityParaTreeScreen({
    super.key,
    required this.api,
    required this.scadaChannelApi,
  });

  @override
  State<UtilityParaTreeScreen> createState() => _UtilityParaTreeScreenState();
}

class _UtilityParaTreeScreenState extends State<UtilityParaTreeScreen> {
  late final TextEditingController _searchController;

  bool _loading = false;
  bool _submitting = false;
  String? _error;
  String _searchKeyword = '';
  bool _expandAll = false;

  List<UtilityParaTreeFac> _items = [];

  bool get _isSearching => _searchKeyword.trim().isNotEmpty;

  bool get _shouldExpandAll => _expandAll || _isSearching;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await widget.api.getGroupedByFacWithParas();
      if (!mounted) return;
      setState(() {
        _items = data;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  void _setSearchKeyword(String keyword) {
    setState(() {
      _searchKeyword = keyword.trim().toLowerCase();
    });
  }

  Future<List<String>> _getBoxDeviceIdOptions() async {
    final channels = await widget.scadaChannelApi.getAll();

    final values =
        channels
            .map((e) => e.boxDeviceId?.trim() ?? '')
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    return values;
  }

  Future<void> _openCreateDialog() async {
    try {
      final boxDeviceIdOptions = await _getBoxDeviceIdOptions();

      if (!mounted) return;

      if (boxDeviceIdOptions.isEmpty) {
        _showMessage('Không có Box Device ID để chọn', isError: true);
        return;
      }

      final result = await showDialog<UtilityPara>(
        context: context,
        builder: (_) => ParaFormDialog(
          initialValue: null,
          isEdit: false,
          boxDeviceIdOptions: boxDeviceIdOptions,
        ),
      );

      if (result == null) return;

      setState(() {
        _submitting = true;
      });

      await widget.api.create(result);

      if (!mounted) return;
      _showMessage('Created successfully');
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString(), isError: true);
    } finally {
      if (!mounted) return;
      setState(() {
        _submitting = false;
      });
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  List<UtilityParaTreeFac> get _filteredItems {
    if (_searchKeyword.isEmpty) return _items;

    return _items
        .map((facNode) {
          final facMatch = facNode.fac.toLowerCase().contains(_searchKeyword);
          final scadaMatch = facNode.scadaId.toLowerCase().contains(
            _searchKeyword,
          );

          final boxes = facNode.boxes
              .map((box) {
                final boxMatch = box.boxId.toLowerCase().contains(
                  _searchKeyword,
                );

                final devices = box.devices
                    .map((device) {
                      final deviceMatch =
                          device.boxDeviceId.toLowerCase().contains(
                            _searchKeyword,
                          ) ||
                          device.cate.toLowerCase().contains(_searchKeyword) ||
                          '${device.channelId ?? ''}'.contains(_searchKeyword);

                      final paras = device.paras.where((para) {
                        return para.plcAddress.toLowerCase().contains(
                              _searchKeyword,
                            ) ||
                            para.valueType.toLowerCase().contains(
                              _searchKeyword,
                            ) ||
                            para.unit.toLowerCase().contains(_searchKeyword) ||
                            para.cateId.toLowerCase().contains(
                              _searchKeyword,
                            ) ||
                            para.nameVi.toLowerCase().contains(
                              _searchKeyword,
                            ) ||
                            para.nameEn.toLowerCase().contains(_searchKeyword);
                      }).toList();

                      if (deviceMatch || paras.isNotEmpty) {
                        return UtilityParaTreeDevice(
                          channelId: device.channelId,
                          cate: device.cate,
                          boxDeviceId: device.boxDeviceId,
                          paras: paras.isEmpty ? device.paras : paras,
                        );
                      }
                      return null;
                    })
                    .whereType<UtilityParaTreeDevice>()
                    .toList();

                if (boxMatch || devices.isNotEmpty) {
                  return UtilityParaTreeBox(
                    boxId: box.boxId,
                    devices: devices.isEmpty ? box.devices : devices,
                  );
                }
                return null;
              })
              .whereType<UtilityParaTreeBox>()
              .toList();

          if (facMatch || scadaMatch || boxes.isNotEmpty) {
            return UtilityParaTreeFac(
              fac: facNode.fac,
              scadaId: facNode.scadaId,
              boxes: boxes.isEmpty ? facNode.boxes : boxes,
            );
          }
          return null;
        })
        .whereType<UtilityParaTreeFac>()
        .toList();
  }

  List<UtilityParaTreeFacGroup> get _groupedByFac {
    final map = <String, List<UtilityParaTreeFac>>{};

    for (final item in _filteredItems) {
      map.putIfAbsent(item.fac, () => []).add(item);
    }

    return map.entries.map((entry) {
      return UtilityParaTreeFacGroup(fac: entry.key, scadas: entry.value);
    }).toList();
  }

  int get _totalCount {
    var count = 0;
    for (final fac in _items) {
      for (final box in fac.boxes) {
        for (final device in box.devices) {
          count += device.paras.length;
        }
      }
    }
    return count;
  }

  int get _filteredCount {
    var count = 0;
    for (final fac in _filteredItems) {
      for (final box in fac.boxes) {
        for (final device in box.devices) {
          count += device.paras.length;
        }
      }
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return BaseSettingScreen(
      title: 'Utility Para',
      loading: _loading,
      submitting: _submitting,
      error: _error,
      totalCount: _totalCount,
      filteredCount: _filteredCount,
      searchController: _searchController,
      onSearchChanged: _setSearchKeyword,
      onRefresh: _loadData,
      onAdd: _openCreateDialog,
      searchHint:
          'Search by FAC, SCADA, box, device, PLC address, para name...',
      addButtonText: 'Add Para',
      requireAddPassword: true,
      addPassword: SettingSecurity.editPassword,
      topActions: [
        _TopActionChip(
          icon: Icons.unfold_more_rounded,
          label: 'Expand all',
          onTap: () {
            setState(() {
              _expandAll = true;
            });
          },
        ),
        _TopActionChip(
          icon: Icons.unfold_less_rounded,
          label: 'Collapse all',
          onTap: () {
            setState(() {
              _expandAll = false;
            });
          },
        ),
        _TopActionChip(
          icon: Icons.clear_rounded,
          label: 'Clear search',
          onTap: () {
            _searchController.clear();
            setState(() {
              _searchKeyword = '';
            });
          },
        ),
      ],
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _loadData);
    }

    if (_groupedByFac.isEmpty) {
      return const EmptyState(message: 'No data found');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      child: Column(
        children: _groupedByFac.map((group) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _ParaFacGroupNode(group: group, expandAll: _shouldExpandAll),
          );
        }).toList(),
      ),
    );
  }
}

/* =========================
   MODELS
========================= */

class UtilityParaTreeFacGroup {
  final String fac;
  final List<UtilityParaTreeFac> scadas;

  const UtilityParaTreeFacGroup({required this.fac, required this.scadas});
}

class UtilityParaTreeFac {
  final String fac;
  final String scadaId;
  final List<UtilityParaTreeBox> boxes;

  const UtilityParaTreeFac({
    required this.fac,
    required this.scadaId,
    required this.boxes,
  });

  factory UtilityParaTreeFac.fromJson(Map<String, dynamic> json) {
    return UtilityParaTreeFac(
      fac: json['fac']?.toString() ?? '',
      scadaId: json['scadaId']?.toString() ?? '',
      boxes: (json['boxes'] as List? ?? [])
          .map((e) => UtilityParaTreeBox.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class UtilityParaTreeBox {
  final String boxId;
  final List<UtilityParaTreeDevice> devices;

  const UtilityParaTreeBox({required this.boxId, required this.devices});

  factory UtilityParaTreeBox.fromJson(Map<String, dynamic> json) {
    return UtilityParaTreeBox(
      boxId: json['boxId']?.toString() ?? '',
      devices: (json['devices'] as List? ?? [])
          .map(
            (e) => UtilityParaTreeDevice.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(),
    );
  }
}

class UtilityParaTreeDevice {
  final int? channelId;
  final String cate;
  final String boxDeviceId;
  final List<UtilityParaItem> paras;

  const UtilityParaTreeDevice({
    required this.channelId,
    required this.cate,
    required this.boxDeviceId,
    required this.paras,
  });

  factory UtilityParaTreeDevice.fromJson(Map<String, dynamic> json) {
    return UtilityParaTreeDevice(
      channelId: json['channelId'] as int?,
      cate: json['cate']?.toString() ?? '',
      boxDeviceId: json['boxDeviceId']?.toString() ?? '',
      paras: (json['paras'] as List? ?? [])
          .map((e) => UtilityParaItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class UtilityParaItem {
  final int? id;
  final String plcAddress;
  final String valueType;
  final String unit;
  final String cateId;
  final String nameVi;
  final String nameEn;
  final int? isImportant;
  final int? isAlert;
  final int? minAlert;
  final int? maxAlert;

  const UtilityParaItem({
    required this.id,
    required this.plcAddress,
    required this.valueType,
    required this.unit,
    required this.cateId,
    required this.nameVi,
    required this.nameEn,
    required this.isImportant,
    required this.isAlert,
    required this.minAlert,
    required this.maxAlert,
  });

  factory UtilityParaItem.fromJson(Map<String, dynamic> json) {
    return UtilityParaItem(
      id: json['id'] as int?,
      plcAddress: json['plcAddress']?.toString() ?? '',
      valueType: json['valueType']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      cateId: json['cateId']?.toString() ?? '',
      nameVi: json['nameVi']?.toString() ?? '',
      nameEn: json['nameEn']?.toString() ?? '',
      isImportant: json['isImportant'] as int?,
      isAlert: json['isAlert'] as int?,
      minAlert: _toInt(json['minAlert']),
      maxAlert: _toInt(json['maxAlert']),
    );
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}

/* =========================
   TREE UI
========================= */

class _ParaFacGroupNode extends StatelessWidget {
  final UtilityParaTreeFacGroup group;
  final bool expandAll;

  const _ParaFacGroupNode({required this.group, required this.expandAll});

  @override
  Widget build(BuildContext context) {
    final facColor = UtilityFacStyle.colorFromFac(group.fac);

    final totalBoxes = group.scadas.fold<int>(
      0,
      (sum, scada) => sum + scada.boxes.length,
    );

    final totalDevices = group.scadas.fold<int>(
      0,
      (sum, scada) =>
          sum + scada.boxes.fold<int>(0, (s, box) => s + box.devices.length),
    );

    final totalParas = group.scadas.fold<int>(
      0,
      (sum, scada) =>
          sum +
          scada.boxes.fold<int>(
            0,
            (s1, box) =>
                s1 + box.devices.fold<int>(0, (s2, d) => s2 + d.paras.length),
          ),
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.035),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey('para_fac_group_${group.fac}_$expandAll'),
          initiallyExpanded: true,
          leading: _NodeIconBox(color: facColor, icon: Icons.factory),
          title: Text(
            group.fac,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            '${group.scadas.length} SCADA • $totalBoxes boxes • $totalDevices devices • $totalParas paras',
            style: TextStyle(
              color: Colors.white.withOpacity(0.62),
              fontSize: 14,
            ),
          ),
          children: group.scadas.map((scada) {
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _TreeIndent(
                color: facColor.withOpacity(0.35),
                child: _ParaFacNode(
                  fac: scada,
                  expandAll: expandAll,
                  showFacInTitle: false,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _ParaFacNode extends StatelessWidget {
  final UtilityParaTreeFac fac;
  final bool expandAll;
  final bool showFacInTitle;

  const _ParaFacNode({
    required this.fac,
    required this.expandAll,
    this.showFacInTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final facColor = UtilityFacStyle.colorFromFac(fac.fac);
    final totalDevices = fac.boxes.fold<int>(
      0,
      (sum, box) => sum + box.devices.length,
    );
    final totalParas = fac.boxes.fold<int>(
      0,
      (sum, box) =>
          sum + box.devices.fold<int>(0, (s, d) => s + d.paras.length),
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.035),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey('para_fac_${fac.fac}_${fac.scadaId}_$expandAll'),
          initiallyExpanded: true,
          leading: _NodeIconBox(color: facColor, icon: Icons.hub_outlined),
          title: Text(
            showFacInTitle ? '${fac.fac} • ${fac.scadaId}' : fac.scadaId,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            '${fac.boxes.length} boxes • $totalDevices devices • $totalParas paras',
            style: TextStyle(
              color: Colors.white.withOpacity(0.62),
              fontSize: 14,
            ),
          ),
          children: fac.boxes.map((box) {
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _TreeIndent(
                color: facColor.withOpacity(0.35),
                child: _ParaBoxNode(box: box, expandAll: expandAll),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _ParaBoxNode extends StatelessWidget {
  final UtilityParaTreeBox box;
  final bool expandAll;

  const _ParaBoxNode({required this.box, required this.expandAll});

  @override
  Widget build(BuildContext context) {
    final totalParas = box.devices.fold<int>(
      0,
      (sum, d) => sum + d.paras.length,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey('para_box_${box.boxId}_$expandAll'),
          initiallyExpanded: expandAll,
          leading: const _NodeIconBox(
            color: Colors.white70,
            icon: Icons.inventory_2_outlined,
          ),
          title: Text(
            box.boxId,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            '${box.devices.length} devices • $totalParas paras',
            style: TextStyle(
              color: Colors.white.withOpacity(0.60),
              fontSize: 14,
            ),
          ),
          children: box.devices.map((device) {
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _TreeIndent(
                color: Colors.white24,
                child: _ParaDeviceNode(device: device, expandAll: expandAll),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _ParaDeviceNode extends StatelessWidget {
  final UtilityParaTreeDevice device;
  final bool expandAll;

  const _ParaDeviceNode({required this.device, required this.expandAll});

  void _onEditPara(BuildContext context, UtilityParaItem para) async {
    final state = context
        .findAncestorStateOfType<_UtilityParaTreeScreenState>();
    if (state == null) return;

    final boxDeviceIdOptions = await state._getBoxDeviceIdOptions();

    if (!context.mounted) return;

    final result = await showDialog<UtilityPara>(
      context: context,
      builder: (_) => ParaFormDialog(
        isEdit: true,
        initialValue: UtilityPara(
          id: para.id,
          boxDeviceId: device.boxDeviceId,
          plcAddress: para.plcAddress,
          valueType: para.valueType,
          unit: para.unit,
          cateId: para.cateId,
          nameVi: para.nameVi,
          nameEn: para.nameEn,
          isImportant: para.isImportant,
          isAlert: para.isAlert,
          minAlert: para.minAlert,
          maxAlert: para.maxAlert,
        ),
        boxDeviceIdOptions: boxDeviceIdOptions,
      ),
    );

    if (result == null || para.id == null) return;

    await state.widget.api.update(para.id!, result);
    await state._loadData();

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Updated successfully')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = UtilityFacStyle.colorByCate(device.cate);
    final icon = UtilityFacStyle.iconByCate(device.cate);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.025),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey('para_device_${device.boxDeviceId}_$expandAll'),
          initiallyExpanded: expandAll,
          leading: _NodeIconBox(color: accent, icon: icon),
          title: Text(
            device.boxDeviceId,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Text(
            '${device.cate} • ${device.paras.length} paras',
            style: TextStyle(
              color: Colors.white.withOpacity(0.58),
              fontSize: 14,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _TreeIndent(
                color: Colors.white24,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 10.0;

                    int columns = 1;
                    if (constraints.maxWidth >= 1200) {
                      columns = 4;
                    } else if (constraints.maxWidth >= 900) {
                      columns = 3;
                    } else if (constraints.maxWidth >= 600) {
                      columns = 2;
                    }

                    final itemWidth =
                        (constraints.maxWidth - spacing * (columns - 1)) /
                        columns;

                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: device.paras.map((para) {
                        return SizedBox(
                          width: itemWidth,
                          child: _ParaLeafCard(
                            para: para,
                            onEdit: () => _onEditPara(context, para),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParaLeafCard extends StatelessWidget {
  final UtilityParaItem para;
  final VoidCallback onEdit;

  const _ParaLeafCard({required this.para, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final important = para.isImportant == 1;
    final alert = para.isAlert == 1;

    final title = para.nameEn.isNotEmpty
        ? para.nameEn
        : (para.nameVi.isNotEmpty ? para.nameEn : para.cateId);

    final subtitle =
        '${para.plcAddress} • ${para.valueType}${para.unit.isNotEmpty ? ' • ${para.unit}' : ''}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF11151C),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),

              ProtectedEditButton(
                password: SettingSecurity.editPassword,
                onVerified: onEdit,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniBadge(
                label: para.cateId.isEmpty ? 'No cate' : para.cateId,
                color: Colors.blueAccent,
              ),
              if (important)
                const _MiniBadge(label: 'Important', color: Colors.orange),
              if (alert)
                _MiniBadge(
                  label:
                      'Alert ${para.minAlert?.toString() ?? '-'} ~ ${para.maxAlert?.toString() ?? '-'}',
                  color: Colors.redAccent,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
/* =========================
   HELPERS
========================= */

class _TreeIndent extends StatelessWidget {
  final Widget child;
  final Color color;

  const _TreeIndent({required this.child, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 1.5,
            margin: const EdgeInsets.only(right: 12),
            constraints: const BoxConstraints(minHeight: 56),
            color: color,
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _NodeIconBox extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _NodeIconBox({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _TopActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _TopActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white.withOpacity(0.85)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.90),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

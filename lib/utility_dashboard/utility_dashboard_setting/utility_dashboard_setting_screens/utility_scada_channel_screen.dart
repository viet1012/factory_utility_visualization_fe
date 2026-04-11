import 'package:flutter/material.dart';

import '../../utility_dashboard_common/utility_fac_style.dart';
import '../utility_dashboard_setting_dialog/channel_form_dialog.dart';
import '../utility_dashboard_setting_models/utility_scada_channel.dart';
import '../utility_dashboard_setting_widgets/setting_common_widgets.dart';
import '../utility_scada_channel_api.dart';
import 'base_setting_screen.dart';

class UtilityScadaChannelScreen extends StatefulWidget {
  final UtilityScadaChannelApi api;

  const UtilityScadaChannelScreen({super.key, required this.api});

  @override
  State<UtilityScadaChannelScreen> createState() =>
      _UtilityScadaChannelScreenState();
}

class _UtilityScadaChannelScreenState extends State<UtilityScadaChannelScreen> {
  late final TextEditingController _searchController;

  bool _loading = false;
  bool _submitting = false;
  String? _error;
  String _searchKeyword = '';

  List<FacTreeNode> _groupedItems = [];

  bool _expandAll = false;

  bool get _isSearching => _searchKeyword.trim().isNotEmpty;

  bool get _shouldExpandAll => _expandAll || _isSearching;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _loadGroupedData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadGroupedData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final raw = await widget.api.getGroupedByFac();
      final grouped = regroupTree(raw);

      if (!mounted) return;
      setState(() {
        _groupedItems = grouped;
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
      _searchKeyword = keyword;
    });
  }

  Future<void> _openCreateDialog() async {
    final result = await showDialog<UtilityScadaChannel>(
      context: context,
      builder: (_) =>
          const ChannelFormDialog(initialValue: null, isEdit: false),
    );

    if (result == null) return;

    try {
      setState(() {
        _submitting = true;
      });

      await widget.api.create(result);

      if (!mounted) return;
      _showMessage('Created successfully');
      await _loadGroupedData();
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

  List<FacTreeNode> get _filteredGroupedItems {
    final q = _searchKeyword.trim().toLowerCase();
    if (q.isEmpty) return _groupedItems;

    return _groupedItems
        .map((fac) {
          final matchedFac = fac.fac.toLowerCase().contains(q);

          final scadas = fac.scadas
              .map((scada) {
                final matchedScada = scada.scadaId.toLowerCase().contains(q);

                final boxes = scada.boxes
                    .map((box) {
                      final matchedBox = box.boxId.toLowerCase().contains(q);

                      final devices = box.devices.where((device) {
                        return device.boxDeviceId.toLowerCase().contains(q) ||
                            device.cate.toLowerCase().contains(q) ||
                            '${device.channelId ?? ''}'.contains(q);
                      }).toList();

                      if (matchedBox || devices.isNotEmpty) {
                        return BoxTreeNode(
                          boxId: box.boxId,
                          devices: devices.isEmpty ? box.devices : devices,
                        );
                      }
                      return null;
                    })
                    .whereType<BoxTreeNode>()
                    .toList();

                if (matchedScada || boxes.isNotEmpty) {
                  return ScadaTreeNode(
                    scadaId: scada.scadaId,
                    boxes: boxes.isEmpty ? scada.boxes : boxes,
                  );
                }
                return null;
              })
              .whereType<ScadaTreeNode>()
              .toList();

          if (matchedFac || scadas.isNotEmpty) {
            return FacTreeNode(
              fac: fac.fac,
              scadas: scadas.isEmpty ? fac.scadas : scadas,
            );
          }
          return null;
        })
        .whereType<FacTreeNode>()
        .toList();
  }

  int get _totalCount => countDevices(_groupedItems);

  int get _filteredCount => countDevices(_filteredGroupedItems);

  @override
  Widget build(BuildContext context) {
    return BaseSettingScreen(
      title: 'Utility SCADA Channels',
      loading: _loading,
      submitting: _submitting,
      error: _error,
      totalCount: _totalCount,
      filteredCount: _filteredCount,
      searchController: _searchController,
      onSearchChanged: _setSearchKeyword,
      onRefresh: _loadGroupedData,
      onAdd: _openCreateDialog,
      searchHint: 'Search by facility, SCADA, box, device, category...',
      addButtonText: 'Add Channel',
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
      return ErrorState(message: _error!, onRetry: _loadGroupedData);
    }

    if (_filteredGroupedItems.isEmpty) {
      return const EmptyState(message: 'No data found');
    }

    return SingleChildScrollView(
      child: VerticalTreeBoard(
        data: _filteredGroupedItems,
        expandAll: _shouldExpandAll,
      ),
    );
  }
}

/* =========================
   API
========================= */

/* =========================
   RAW RESPONSE MODELS
========================= */

class UtilityScadaTreeFacRaw {
  final String fac;
  final String scadaId;
  final List<UtilityScadaTreeBoxRaw> boxes;

  const UtilityScadaTreeFacRaw({
    required this.fac,
    required this.scadaId,
    required this.boxes,
  });

  factory UtilityScadaTreeFacRaw.fromJson(Map<String, dynamic> json) {
    return UtilityScadaTreeFacRaw(
      fac: json['fac']?.toString() ?? '',
      scadaId: json['scadaId']?.toString() ?? '',
      boxes: (json['boxes'] as List? ?? [])
          .map(
            (e) =>
                UtilityScadaTreeBoxRaw.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(),
    );
  }
}

class UtilityScadaTreeBoxRaw {
  final String boxId;
  final List<UtilityScadaTreeDeviceRaw> devices;

  const UtilityScadaTreeBoxRaw({required this.boxId, required this.devices});

  factory UtilityScadaTreeBoxRaw.fromJson(Map<String, dynamic> json) {
    return UtilityScadaTreeBoxRaw(
      boxId: json['boxId']?.toString() ?? '',
      devices: (json['devices'] as List? ?? [])
          .map(
            (e) => UtilityScadaTreeDeviceRaw.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList(),
    );
  }
}

class UtilityScadaTreeDeviceRaw {
  final int? channelId;
  final String cate;
  final String boxDeviceId;

  const UtilityScadaTreeDeviceRaw({
    required this.channelId,
    required this.cate,
    required this.boxDeviceId,
  });

  factory UtilityScadaTreeDeviceRaw.fromJson(Map<String, dynamic> json) {
    return UtilityScadaTreeDeviceRaw(
      channelId: json['channelId'] as int?,
      cate: json['cate']?.toString() ?? '',
      boxDeviceId: json['boxDeviceId']?.toString() ?? '',
    );
  }
}

/* =========================
   TREE MODELS
========================= */

class FacTreeNode {
  final String fac;
  final List<ScadaTreeNode> scadas;

  const FacTreeNode({required this.fac, required this.scadas});
}

class ScadaTreeNode {
  final String scadaId;
  final List<BoxTreeNode> boxes;

  const ScadaTreeNode({required this.scadaId, required this.boxes});
}

class BoxTreeNode {
  final String boxId;
  final List<DeviceTreeNode> devices;

  const BoxTreeNode({required this.boxId, required this.devices});
}

class DeviceTreeNode {
  final int? channelId;
  final String cate;
  final String boxDeviceId;

  const DeviceTreeNode({
    required this.channelId,
    required this.cate,
    required this.boxDeviceId,
  });
}

List<FacTreeNode> regroupTree(List<UtilityScadaTreeFacRaw> raw) {
  final Map<String, List<UtilityScadaTreeFacRaw>> grouped = {};

  for (final item in raw) {
    grouped.putIfAbsent(item.fac, () => []).add(item);
  }

  return grouped.entries.map((entry) {
    return FacTreeNode(
      fac: entry.key,
      scadas: entry.value.map((scadaRaw) {
        return ScadaTreeNode(
          scadaId: scadaRaw.scadaId,
          boxes: scadaRaw.boxes.map((boxRaw) {
            return BoxTreeNode(
              boxId: boxRaw.boxId,
              devices: boxRaw.devices.map((d) {
                return DeviceTreeNode(
                  channelId: d.channelId,
                  cate: d.cate,
                  boxDeviceId: d.boxDeviceId,
                );
              }).toList(),
            );
          }).toList(),
        );
      }).toList(),
    );
  }).toList();
}

int countDevices(List<FacTreeNode> items) {
  var count = 0;
  for (final fac in items) {
    for (final scada in fac.scadas) {
      for (final box in scada.boxes) {
        count += box.devices.length;
      }
    }
  }
  return count;
}

/* =========================
   TREE UI
========================= */

class VerticalTreeBoard extends StatelessWidget {
  final List<FacTreeNode> data;
  final bool expandAll;

  const VerticalTreeBoard({
    super.key,
    required this.data,
    required this.expandAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: data.map((fac) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: VerticalFacTree(node: fac, expandAll: expandAll),
        );
      }).toList(),
    );
  }
}

class VerticalFacTree extends StatelessWidget {
  final FacTreeNode node;
  final bool expandAll;

  const VerticalFacTree({
    super.key,
    required this.node,
    required this.expandAll,
  });

  @override
  Widget build(BuildContext context) {
    final facColor = UtilityFacStyle.colorFromFac(node.fac);
    final totalBoxes = node.scadas.fold<int>(
      0,
      (sum, s) => sum + s.boxes.length,
    );
    final totalDevices = node.scadas.fold<int>(
      0,
      (sum, s) =>
          sum + s.boxes.fold<int>(0, (bSum, b) => bSum + b.devices.length),
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
          key: PageStorageKey('fac_${node.fac}_$expandAll'),
          initiallyExpanded: true,
          leading: _NodeIconBox(color: facColor, icon: Icons.factory),
          title: Text(
            node.fac,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            '${node.scadas.length} SCADA • $totalBoxes boxes • $totalDevices devices',
            style: TextStyle(
              color: Colors.white.withOpacity(0.62),
              fontSize: 13,
            ),
          ),
          children: [
            ...node.scadas.map(
              (scada) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: VerticalScadaTree(
                  fac: node.fac,
                  scada: scada,
                  lineColor: facColor,
                  expandAll: expandAll,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VerticalScadaTree extends StatelessWidget {
  final String fac;
  final ScadaTreeNode scada;
  final Color lineColor;
  final bool expandAll;

  const VerticalScadaTree({
    super.key,
    required this.fac,
    required this.scada,
    required this.lineColor,
    required this.expandAll,
  });

  @override
  Widget build(BuildContext context) {
    final totalDevices = scada.boxes.fold<int>(
      0,
      (sum, box) => sum + box.devices.length,
    );

    return _TreeIndent(
      color: lineColor.withOpacity(0.40),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: PageStorageKey('scada_${fac}_${scada.scadaId}_$expandAll'),
            initiallyExpanded: expandAll,
            leading: _NodeIconBox(color: lineColor, icon: Icons.hub_outlined),
            title: Text(
              scada.scadaId,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              '${scada.boxes.length} boxes • $totalDevices devices',
              style: TextStyle(
                color: Colors.white.withOpacity(0.60),
                fontSize: 14,
              ),
            ),
            children: [
              if (scada.boxes.isEmpty)
                const _EmptyLeaf(label: 'No box')
              else
                ...scada.boxes.map(
                  (box) => Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: VerticalBoxTree(
                      fac: fac,
                      scadaId: scada.scadaId,
                      box: box,
                      expandAll: expandAll,
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

class VerticalBoxTree extends StatelessWidget {
  final String fac;
  final String scadaId;
  final BoxTreeNode box;
  final bool expandAll;

  const VerticalBoxTree({
    super.key,
    required this.fac,
    required this.scadaId,
    required this.box,
    required this.expandAll,
  });

  @override
  Widget build(BuildContext context) {
    return _TreeIndent(
      color: Colors.white24,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.025),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: PageStorageKey(
              'box_${fac}_${scadaId}_${box.boxId}_$expandAll',
            ),
            initiallyExpanded: expandAll,

            leading: const _NodeIconBox(
              color: Colors.white70,
              icon: Icons.inventory_2_outlined,
            ),
            title: Text(
              box.boxId,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              '${box.devices.length} devices',
              style: TextStyle(
                color: Colors.white.withOpacity(0.58),
                fontSize: 14,
              ),
            ),
            children: [
              if (box.devices.isEmpty)
                const _EmptyLeaf(label: 'No device')
              else
                ...box.devices.map(
                  (device) => Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _TreeIndent(
                      color: Colors.white24,
                      child: VerticalDeviceNode(device: device),
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

class VerticalDeviceNode extends StatelessWidget {
  final DeviceTreeNode device;

  const VerticalDeviceNode({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    final accent = UtilityFacStyle.colorByCate(device.cate);
    final icon = UtilityFacStyle.iconByCate(device.cate);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF11151C),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _NodeIconBox(color: accent, icon: icon),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              device.boxDeviceId,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                height: 1.25,
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              // TODO: nối edit action ở đây
            },
            icon: const Icon(Icons.edit_rounded, size: 18),
            color: Colors.white70,
            tooltip: 'Edit',
          ),
        ],
      ),
    );
  }
}

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

class _EmptyLeaf extends StatelessWidget {
  final String label;

  const _EmptyLeaf({required this.label});

  @override
  Widget build(BuildContext context) {
    return _TreeIndent(
      color: Colors.white24,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.025),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 15),
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

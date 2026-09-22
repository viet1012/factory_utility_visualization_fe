import 'package:flutter/material.dart';

import '../catalog_view_models.dart';

class CatalogScadaBoxTreePanel extends StatelessWidget {
  final List<CatalogTreeGroup> groups;
  final String? selectedKey;
  final ValueChanged<String> onSelected;

  const CatalogScadaBoxTreePanel({
    required this.groups,
    required this.selectedKey,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final scadaGroups = <String, List<CatalogTreeGroup>>{};

    for (final group in groups) {
      scadaGroups.putIfAbsent(group.scadaId, () => <CatalogTreeGroup>[]);

      scadaGroups[group.scadaId]!.add(group);
    }

    return Container(
      color: const Color(0xFF07111F),
      child: Column(
        children: [
          const _PanelHeader(
            icon: Icons.account_tree_rounded,
            title: 'SCADA / BOX TREE',
          ),
          Expanded(
            child: groups.isEmpty
                ? const _SmallEmptyState(message: 'No SCADA or box')
                : ListView(
                    padding: const EdgeInsets.all(8),
                    children: [
                      for (final entry in scadaGroups.entries)
                        Theme(
                          data: ThemeData.dark().copyWith(
                            dividerColor: Colors.transparent,
                          ),
                          child: ExpansionTile(
                            initiallyExpanded: true,
                            tilePadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                            childrenPadding: const EdgeInsets.only(
                              left: 8,
                              bottom: 6,
                            ),
                            leading: const Icon(
                              Icons.hub_rounded,
                              size: 18,
                              color: Color(0xFF60A5FA),
                            ),
                            title: Text(
                              entry.key,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            children: [
                              for (final group in entry.value)
                                _TreeBoxTile(
                                  group: group,
                                  selected: selectedKey == group.key,
                                  onTap: () {
                                    onSelected(group.key);
                                  },
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _TreeBoxTile extends StatelessWidget {
  final CatalogTreeGroup group;
  final bool selected;
  final VoidCallback onTap;

  const _TreeBoxTile({
    required this.group,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasWarning = group.staleDeviceCount > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Material(
        color: selected
            ? const Color(0xFF22D3EE).withValues(alpha: .11)
            : const Color(0xFF0B1828),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected
                    ? const Color(0xFF22D3EE).withValues(alpha: .38)
                    : Colors.white.withValues(alpha: .05),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.inventory_2_rounded,
                  size: 16,
                  color: selected
                      ? const Color(0xFF67E8F9)
                      : const Color(0xFF7C92AC),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.boxId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : const Color(0xFFBCCBDB),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${group.deviceCount} devices'
                        ' • ${group.signalCount} signals',
                        style: const TextStyle(
                          color: Color(0xFF687E98),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasWarning
                        ? Colors.orangeAccent
                        : const Color(0xFF4ADE80),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CatalogDeviceListPanel extends StatelessWidget {
  final List<CatalogDeviceGroup> devices;
  final String? selectedDeviceKey;

  final int totalDevices;
  final int currentPage;
  final int pageSize;

  final ValueChanged<String> onSelected;

  const CatalogDeviceListPanel({
    required this.devices,
    required this.selectedDeviceKey,
    required this.totalDevices,
    required this.currentPage,
    required this.pageSize,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final start = totalDevices == 0 ? 0 : currentPage * pageSize + 1;

    final end = totalDevices == 0
        ? 0
        : (currentPage * pageSize + devices.length).clamp(0, totalDevices);

    return Container(
      color: const Color(0xFF081321),
      child: Column(
        children: [
          _PanelHeader(
            icon: Icons.memory_rounded,
            title: 'DEVICE LIST',
            trailing: '$start–$end / $totalDevices',
          ),
          Expanded(
            child: devices.isEmpty
                ? const _SmallEmptyState(message: 'No devices')
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: devices.length,
                    itemBuilder: (context, index) {
                      final device = devices[index];

                      return _DeviceListTile(
                        device: device,
                        selected: selectedDeviceKey == device.key,
                        onTap: () {
                          onSelected(device.key);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _DeviceListTile extends StatelessWidget {
  final CatalogDeviceGroup device;
  final bool selected;
  final VoidCallback onTap;

  const _DeviceListTile({
    required this.device,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final healthColor = switch (device.health) {
      DeviceHealth.online => const Color(0xFF4ADE80),
      DeviceHealth.warning => Colors.orangeAccent,
      DeviceHealth.offline => Colors.redAccent,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected
            ? const Color(0xFF22D3EE).withValues(alpha: .10)
            : const Color(0xFF0B1828),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? const Color(0xFF22D3EE).withValues(alpha: .38)
                    : Colors.white.withValues(alpha: .055),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 35,
                  height: 35,
                  decoration: BoxDecoration(
                    color: healthColor.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    Icons.memory_rounded,
                    color: healthColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.boxDeviceId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : const Color(0xFFD0DCEC),
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${device.signalCount} signals'
                        ' • ${device.onlineCount} online'
                        ' • ${device.staleCount} stale',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF71869F),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Updated ${_formatDeviceTime(device.lastUpdated)}',
                        style: const TextStyle(
                          color: Color(0xFF60758D),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: healthColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _formatDeviceTime(DateTime? value) {
    if (value == null) return '--:--:--';

    final local = value.toLocal();

    String two(int value) {
      return value.toString().padLeft(2, '0');
    }

    return '${two(local.hour)}:'
        '${two(local.minute)}:'
        '${two(local.second)}';
  }
}

class _PanelHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailing;

  const _PanelHeader({required this.icon, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1B2B),
        border: Border(bottom: BorderSide(color: Color(0xFF20344D))),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: const Color(0xFF8FA5BF)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFFB7C8DE),
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: .55,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: const TextStyle(
                color: Color(0xFF67E8F9),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    );
  }
}

class _SmallEmptyState extends StatelessWidget {
  final String message;

  const _SmallEmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFF667C94),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

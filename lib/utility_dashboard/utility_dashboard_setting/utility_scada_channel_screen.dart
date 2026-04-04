import 'package:flutter/material.dart';

import 'utility_scada_channel_api.dart';

class UtilityScadaChannelScreen extends StatefulWidget {
  final UtilityScadaChannelApi api;

  const UtilityScadaChannelScreen({super.key, required this.api});

  @override
  State<UtilityScadaChannelScreen> createState() =>
      _UtilityScadaChannelScreenState();
}

class _UtilityScadaChannelScreenState extends State<UtilityScadaChannelScreen> {
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  bool _submitting = false;
  String? _error;

  List<UtilityScadaChannel> _items = [];
  List<UtilityScadaChannel> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applyFilter);
    _loadData();
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFilter);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await widget.api.getAll();
      if (!mounted) return;

      setState(() {
        _items = items;
        _filteredItems = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _applyFilter() {
    final keyword = _searchController.text.trim().toLowerCase();

    setState(() {
      if (keyword.isEmpty) {
        _filteredItems = _items;
        return;
      }

      _filteredItems = _items.where((item) {
        final values = [
          item.id?.toString() ?? '',
          item.scadaId ?? '',
          item.cate ?? '',
          item.boxDeviceId ?? '',
          item.boxId ?? '',
        ];

        return values.any((value) => value.toLowerCase().contains(keyword));
      }).toList();
    });
  }

  Future<void> _openCreateDialog() async {
    final result = await showDialog<UtilityScadaChannel>(
      context: context,
      builder: (_) => const _ChannelFormDialog(),
    );

    if (result == null) return;
    await _createItem(result);
  }

  Future<void> _openEditDialog(UtilityScadaChannel item) async {
    final result = await showDialog<UtilityScadaChannel>(
      context: context,
      builder: (_) => _ChannelFormDialog(initialValue: item),
    );

    if (result == null || item.id == null) return;
    await _updateItem(item.id!, result);
  }

  Future<void> _createItem(UtilityScadaChannel item) async {
    setState(() => _submitting = true);

    try {
      final created = await widget.api.create(item);
      if (!mounted) return;

      setState(() {
        _items = [created, ..._items];
        _submitting = false;
      });

      _applyFilter();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Created successfully')));
    } catch (e) {
      if (!mounted) return;

      setState(() => _submitting = false);
      _showError(e);
    }
  }

  Future<void> _updateItem(int id, UtilityScadaChannel item) async {
    setState(() => _submitting = true);

    try {
      final updated = await widget.api.update(id, item);
      if (!mounted) return;

      setState(() {
        _items = _items.map((e) => e.id == id ? updated : e).toList();
        _submitting = false;
      });

      _applyFilter();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Updated successfully')));
    } catch (e) {
      if (!mounted) return;

      setState(() => _submitting = false);
      _showError(e);
    }
  }

  Future<void> _deleteItem(UtilityScadaChannel item) async {
    final id = item.id;
    if (id == null) return;

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete channel'),
            content: Text(
              'Delete "${item.boxDeviceId ?? item.boxId ?? item.scadaId ?? 'this item'}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    setState(() => _submitting = true);

    try {
      await widget.api.delete(id);
      if (!mounted) return;

      setState(() {
        _items = _items.where((e) => e.id != id).toList();
        _submitting = false;
      });

      _applyFilter();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Deleted successfully')));
    } catch (e) {
      if (!mounted) return;

      setState(() => _submitting = false);
      _showError(e);
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.toString())));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Utility SCADA Channels'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _submitting ? null : _openCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search channel...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              Expanded(child: _buildBody()),
            ],
          ),
          if (_submitting)
            Container(
              color: Colors.black12,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: _loadData, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_filteredItems.isEmpty) {
      return const Center(child: Text('No data'));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        int crossAxisCount = 2;
        if (width > 1200) {
          crossAxisCount = 5;
        } else if (width > 900) {
          crossAxisCount = 4;
        } else if (width > 600) {
          crossAxisCount = 3;
        }

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.4,
          ),
          itemCount: _filteredItems.length,
          itemBuilder: (_, index) {
            final item = _filteredItems[index];

            return Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.boxDeviceId ?? '-',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text('SCADA: ${item.scadaId ?? '-'}'),
                    Text('Cate: ${item.cate ?? '-'}'),
                    Text('Box: ${item.boxId ?? '-'}'),

                    const Spacer(),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: _submitting
                              ? null
                              : () => _openEditDialog(item),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: _submitting
                              ? null
                              : () => _deleteItem(item),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ChannelFormDialog extends StatefulWidget {
  final UtilityScadaChannel? initialValue;

  const _ChannelFormDialog({this.initialValue});

  @override
  State<_ChannelFormDialog> createState() => _ChannelFormDialogState();
}

class _ChannelFormDialogState extends State<_ChannelFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _scadaIdController;
  late final TextEditingController _cateController;
  late final TextEditingController _boxDeviceIdController;
  late final TextEditingController _boxIdController;

  @override
  void initState() {
    super.initState();

    final item = widget.initialValue;

    _scadaIdController = TextEditingController(text: item?.scadaId ?? '');
    _cateController = TextEditingController(text: item?.cate ?? '');
    _boxDeviceIdController = TextEditingController(
      text: item?.boxDeviceId ?? '',
    );
    _boxIdController = TextEditingController(text: item?.boxId ?? '');
  }

  @override
  void dispose() {
    _scadaIdController.dispose();
    _cateController.dispose();
    _boxDeviceIdController.dispose();
    _boxIdController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final item = (widget.initialValue ?? const UtilityScadaChannel()).copyWith(
      scadaId: _scadaIdController.text.trim(),
      cate: _cateController.text.trim(),
      boxDeviceId: _boxDeviceIdController.text.trim(),
      boxId: _boxIdController.text.trim(),
    );

    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialValue != null;

    return AlertDialog(
      title: Text(isEdit ? 'Edit Channel' : 'Create Channel'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _scadaIdController,
                  decoration: const InputDecoration(labelText: 'SCADA ID'),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'SCADA ID is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cateController,
                  decoration: const InputDecoration(labelText: 'Category'),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Category is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _boxDeviceIdController,
                  decoration: const InputDecoration(labelText: 'Box Device ID'),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Box Device ID is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _boxIdController,
                  decoration: const InputDecoration(labelText: 'Box ID'),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Box ID is required';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(isEdit ? 'Update' : 'Create'),
        ),
      ],
    );
  }
}

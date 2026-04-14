import 'package:flutter/material.dart';

import '../utility_dashboard_setting_models/utility_scada_channel.dart';
import '../utility_dashboard_setting_widgets/form_field_config.dart';
import 'base_setting_form_dialog.dart';

class ChannelFormDialog extends StatefulWidget {
  final UtilityScadaChannel? initialValue;
  final bool isEdit;
  final List<String> scadaOptions;

  const ChannelFormDialog({
    super.key,
    this.initialValue,
    this.isEdit = false,
    required this.scadaOptions,
  });

  @override
  State<ChannelFormDialog> createState() => _ChannelFormDialogState();
}

class _ChannelFormDialogState extends State<ChannelFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  static const List<String> _cateOptions = [
    'Electricity',
    'Water',
    'CompressedAir',
  ];

  late final TextEditingController _boxDeviceIdCtrl;
  late final TextEditingController _boxIdCtrl;

  late String? _selectedScadaId;
  late String? _selectedCate;

  String _lastBoxPrefix = '';

  bool get _isEdit => widget.isEdit || widget.initialValue != null;

  @override
  void initState() {
    super.initState();
    final item = widget.initialValue;

    _boxDeviceIdCtrl = TextEditingController(text: item?.boxDeviceId ?? '');
    _boxIdCtrl = TextEditingController(text: item?.boxId ?? '');

    final scadaId = item?.scadaId?.trim();
    _selectedScadaId =
        (scadaId != null && widget.scadaOptions.contains(scadaId))
        ? scadaId
        : (widget.scadaOptions.isNotEmpty ? widget.scadaOptions.first : null);

    final cate = item?.cate?.trim();
    _selectedCate = _cateOptions.contains(cate) ? cate : _cateOptions.first;

    _lastBoxPrefix = _buildBoxPrefix(_boxIdCtrl.text);

    _boxIdCtrl.addListener(_handleBoxIdChanged);

    if ((_boxDeviceIdCtrl.text.trim().isEmpty) && _lastBoxPrefix.isNotEmpty) {
      _boxDeviceIdCtrl.text = _lastBoxPrefix;
      _boxDeviceIdCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: _boxDeviceIdCtrl.text.length),
      );
    }
  }

  @override
  void dispose() {
    _boxIdCtrl.removeListener(_handleBoxIdChanged);
    _boxDeviceIdCtrl.dispose();
    _boxIdCtrl.dispose();
    super.dispose();
  }

  String _buildBoxPrefix(String boxId) {
    final text = boxId.trim();
    if (text.isEmpty) return '';
    return '${text}_';
  }

  void _handleBoxIdChanged() {
    final newPrefix = _buildBoxPrefix(_boxIdCtrl.text);
    final current = _boxDeviceIdCtrl.text;

    if (newPrefix == _lastBoxPrefix) return;

    if (current.trim().isEmpty || current == _lastBoxPrefix) {
      _boxDeviceIdCtrl.text = newPrefix;
    } else if (_lastBoxPrefix.isNotEmpty &&
        current.startsWith(_lastBoxPrefix)) {
      final suffix = current.substring(_lastBoxPrefix.length);
      _boxDeviceIdCtrl.text = '$newPrefix$suffix';
    }

    _lastBoxPrefix = newPrefix;

    _boxDeviceIdCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: _boxDeviceIdCtrl.text.length),
    );

    if (mounted) {
      setState(() {});
    }
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final item = (widget.initialValue ?? const UtilityScadaChannel()).copyWith(
      scadaId: _selectedScadaId,
      cate: _selectedCate,
      boxDeviceId: _boxDeviceIdCtrl.text.trim(),
      boxId: _boxIdCtrl.text.trim(),
    );

    Navigator.of(context).pop(item);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: BaseSettingFormDialog(
        title: _isEdit ? 'Edit SCADA Channel' : 'Create SCADA Channel',
        submitText: _isEdit ? 'Update' : 'Create',
        onSubmit: _submit,
        fields: [
          FormFieldConfig.dropdown(
            label: 'SCADA ID',
            validatorText: 'SCADA ID is required',
            value: _selectedScadaId,
            items: widget.scadaOptions,
            onChanged: (value) {
              setState(() {
                _selectedScadaId = value;
              });
            },
          ),
          FormFieldConfig.dropdown(
            label: 'Category',
            validatorText: 'Category is required',
            value: _selectedCate,
            items: _cateOptions,
            onChanged: (value) {
              setState(() {
                _selectedCate = value;
              });
            },
          ),
          FormFieldConfig(
            label: 'Box ID',
            validatorText: 'Box ID is required',
            controller: _boxIdCtrl,
          ),
          FormFieldConfig(
            label: 'Box Device ID',
            controller: _boxDeviceIdCtrl,
            validator: (value) {
              final text = value?.trim() ?? '';
              final prefix = _buildBoxPrefix(_boxIdCtrl.text);

              if (text.isEmpty) {
                return 'Box Device ID is required';
              }

              if (prefix.isNotEmpty && text == prefix) {
                return 'Please enter suffix after $prefix';
              }

              return null;
            },
          ),
        ],
      ),
    );
  }
}

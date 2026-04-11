import 'package:flutter/material.dart';

import '../utility_dashboard_setting_models/utility_scada_channel.dart';
import '../utility_dashboard_setting_widgets/form_field_config.dart';
import 'base_setting_form_dialog.dart';

class ChannelFormDialog extends StatefulWidget {
  final UtilityScadaChannel? initialValue;
  final bool isEdit;

  const ChannelFormDialog({super.key, this.initialValue, this.isEdit = false});

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

  late final TextEditingController _scadaIdCtrl;
  late final TextEditingController _boxDeviceIdCtrl;
  late final TextEditingController _boxIdCtrl;

  late String? _selectedCate;

  bool get _isEdit => widget.isEdit || widget.initialValue != null;

  @override
  void initState() {
    super.initState();
    final item = widget.initialValue;
    _scadaIdCtrl = TextEditingController(text: item?.scadaId ?? '');
    _boxDeviceIdCtrl = TextEditingController(text: item?.boxDeviceId ?? '');
    _boxIdCtrl = TextEditingController(text: item?.boxId ?? '');

    final cate = item?.cate?.trim();

    _selectedCate = _cateOptions.contains(cate) ? cate : _cateOptions.first;
  }

  @override
  void dispose() {
    _scadaIdCtrl.dispose();
    _boxDeviceIdCtrl.dispose();
    _boxIdCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final item = (widget.initialValue ?? const UtilityScadaChannel()).copyWith(
      scadaId: _scadaIdCtrl.text.trim(),
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
          FormFieldConfig(
            label: 'SCADA ID',
            validatorText: 'SCADA ID is required',
            controller: _scadaIdCtrl,
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
            validatorText: 'Box Device ID is required',
            controller: _boxDeviceIdCtrl,
          ),
        ],
      ),
    );
  }
}

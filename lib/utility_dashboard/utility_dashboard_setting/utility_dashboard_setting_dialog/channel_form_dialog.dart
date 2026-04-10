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

  late final TextEditingController _scadaIdCtrl;
  late final TextEditingController _cateCtrl;
  late final TextEditingController _boxDeviceIdCtrl;
  late final TextEditingController _boxIdCtrl;

  bool get _isEdit => widget.isEdit || widget.initialValue != null;

  @override
  void initState() {
    super.initState();
    final item = widget.initialValue;
    _scadaIdCtrl = TextEditingController(text: item?.scadaId ?? '');
    _cateCtrl = TextEditingController(text: item?.cate ?? '');
    _boxDeviceIdCtrl = TextEditingController(text: item?.boxDeviceId ?? '');
    _boxIdCtrl = TextEditingController(text: item?.boxId ?? '');
  }

  @override
  void dispose() {
    _scadaIdCtrl.dispose();
    _cateCtrl.dispose();
    _boxDeviceIdCtrl.dispose();
    _boxIdCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final item = (widget.initialValue ?? const UtilityScadaChannel()).copyWith(
      scadaId: _scadaIdCtrl.text.trim(),
      cate: _cateCtrl.text.trim(),
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
          FormFieldConfig(
            label: 'Category',
            validatorText: 'Category is required',
            controller: _cateCtrl,
          ),
          FormFieldConfig(
            label: 'Box Device ID',
            validatorText: 'Box Device ID is required',
            controller: _boxDeviceIdCtrl,
          ),
          FormFieldConfig(
            label: 'Box ID',
            validatorText: 'Box ID is required',
            controller: _boxIdCtrl,
          ),
        ],
      ),
    );
  }
}

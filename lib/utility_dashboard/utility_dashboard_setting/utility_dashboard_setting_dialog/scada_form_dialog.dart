import 'package:flutter/material.dart';

import '../utility_dashboard_setting_models/utility_scada.dart';
import '../utility_dashboard_setting_widgets/form_field_config.dart';
import 'base_setting_form_dialog.dart';

class ScadaFormDialog extends StatefulWidget {
  final UtilityScada? initialValue;
  final bool isEdit;

  const ScadaFormDialog({super.key, this.initialValue, this.isEdit = false});

  @override
  State<ScadaFormDialog> createState() => _ScadaFormDialogState();
}

class _ScadaFormDialogState extends State<ScadaFormDialog> {
  static const List<String> _facOptions = ['Fac_A', 'Fac_B', 'Fac_C'];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _scadaIdCtrl;
  late final TextEditingController _plcIpCtrl;
  late final TextEditingController _plcPortCtrl;
  late final TextEditingController _pcNameCtrl;
  late final TextEditingController _wlanCtrl;

  late String? _selectedFac;

  bool get _isEdit => widget.isEdit || widget.initialValue != null;

  @override
  void initState() {
    super.initState();
    final item = widget.initialValue;

    _scadaIdCtrl = TextEditingController(text: item?.scadaId ?? '');
    _plcIpCtrl = TextEditingController(text: item?.plcIp ?? '');
    _plcPortCtrl = TextEditingController(text: item?.plcPort?.toString() ?? '');
    _pcNameCtrl = TextEditingController(text: item?.pcName ?? '');
    _wlanCtrl = TextEditingController(text: item?.wlan ?? '');

    final fac = item?.fac?.trim();
    _selectedFac = _facOptions.contains(fac) ? fac : _facOptions.first;
  }

  @override
  void dispose() {
    _scadaIdCtrl.dispose();
    _plcIpCtrl.dispose();
    _plcPortCtrl.dispose();
    _pcNameCtrl.dispose();
    _wlanCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final item = (widget.initialValue ?? const UtilityScada()).copyWith(
      scadaId: _scadaIdCtrl.text.trim(),
      fac: _selectedFac,
      plcIp: _plcIpCtrl.text.trim(),
      plcPort: int.tryParse(_plcPortCtrl.text.trim()),
      pcName: _pcNameCtrl.text.trim(),
      wlan: _wlanCtrl.text.trim(),
    );

    Navigator.of(context).pop(item);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: BaseSettingFormDialog(
        title: _isEdit ? 'Edit SCADA' : 'Create SCADA',
        submitText: _isEdit ? 'Update' : 'Create',
        onSubmit: _submit,
        fields: [
          FormFieldConfig(
            label: 'SCADA ID',
            validatorText: 'SCADA ID is required',
            controller: _scadaIdCtrl,
          ),
          FormFieldConfig.dropdown(
            label: 'FAC',
            validatorText: 'FAC is required',
            value: _selectedFac,
            items: _facOptions,
            onChanged: (value) {
              setState(() {
                _selectedFac = value;
              });
            },
          ),
          FormFieldConfig(
            label: 'PLC IP',
            validatorText: 'PLC IP is required',
            controller: _plcIpCtrl,
          ),
          FormFieldConfig(
            label: 'PLC Port',
            validatorText: 'PLC Port is required',
            controller: _plcPortCtrl,
            keyboardType: TextInputType.number,
          ),
          FormFieldConfig(label: 'PC Name', controller: _pcNameCtrl),
          FormFieldConfig(label: 'WLAN', controller: _wlanCtrl),
        ],
      ),
    );
  }
}

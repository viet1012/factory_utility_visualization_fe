import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utility_dashboard_setting_models/utility_para.dart';
import '../utility_dashboard_setting_widgets/form_field_config.dart';
import 'base_setting_form_dialog.dart';

class ParaFormDialog extends StatefulWidget {
  final UtilityPara? initialValue;
  final bool isEdit;
  final List<String> boxDeviceIdOptions;

  const ParaFormDialog({
    super.key,
    this.initialValue,
    this.isEdit = false,
    required this.boxDeviceIdOptions,
  });

  @override
  State<ParaFormDialog> createState() => _ParaFormDialogState();
}

class _ParaFormDialogState extends State<ParaFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  static const List<String> _valueTypeOptions = [
    'BOOL',
    'INT16',
    'LONG',
    'FLOAT',
    'DOUBLE',
    'STRING',
  ];

  static const List<String> _flagOptions = ['0', '1'];

  late final TextEditingController _plcAddressCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _cateIdCtrl;
  late final TextEditingController _nameViCtrl;
  late final TextEditingController _nameEnCtrl;
  late final TextEditingController _minAlertCtrl;
  late final TextEditingController _maxAlertCtrl;

  late String? _selectedBoxDeviceId;
  late String? _selectedValueType;
  late String? _selectedIsImportant;
  late String? _selectedIsAlert;

  bool _boxDeviceIdTouched = false;

  bool get _isEdit => widget.isEdit || widget.initialValue != null;

  bool get _isAlertEnabled => _selectedIsAlert == '1';

  bool get _boxDeviceIdInvalid =>
      _boxDeviceIdTouched &&
      (_selectedBoxDeviceId == null || _selectedBoxDeviceId!.trim().isEmpty);

  @override
  void initState() {
    super.initState();
    final item = widget.initialValue;

    _plcAddressCtrl = TextEditingController(text: item?.plcAddress ?? '');
    _unitCtrl = TextEditingController(text: item?.unit ?? '');
    _cateIdCtrl = TextEditingController(text: item?.cateId ?? '');
    _nameViCtrl = TextEditingController(text: item?.nameVi ?? '');
    _nameEnCtrl = TextEditingController(text: item?.nameEn ?? '');
    _minAlertCtrl = TextEditingController(
      text: item?.minAlert?.toString() ?? '',
    );
    _maxAlertCtrl = TextEditingController(
      text: item?.maxAlert?.toString() ?? '',
    );

    final initBoxDeviceId = item?.boxDeviceId?.trim();
    _selectedBoxDeviceId =
        (initBoxDeviceId != null &&
            widget.boxDeviceIdOptions.contains(initBoxDeviceId))
        ? initBoxDeviceId
        : null;

    final valueType = item?.valueType?.trim();

    _selectedValueType = _valueTypeOptions.firstWhere(
      (e) => e.toLowerCase() == valueType?.toLowerCase(),
      orElse: () => _valueTypeOptions.first,
    );

    _selectedIsImportant = (item?.isImportant ?? 0).toString();
    _selectedIsAlert = (item?.isAlert ?? 0).toString();
  }

  @override
  void dispose() {
    _plcAddressCtrl.dispose();
    _unitCtrl.dispose();
    _cateIdCtrl.dispose();
    _nameViCtrl.dispose();
    _nameEnCtrl.dispose();
    _minAlertCtrl.dispose();
    _maxAlertCtrl.dispose();
    super.dispose();
  }

  int? _parseNullableInt(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  Future<void> _openBoxDeviceIdPicker() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF11151C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final searchCtrl = TextEditingController();
        List<String> filtered = List<String>.from(widget.boxDeviceIdOptions);

        return StatefulBuilder(
          builder: (context, setSheetState) {
            void onSearchChanged(String value) {
              final keyword = value.trim().toLowerCase();
              setSheetState(() {
                filtered = widget.boxDeviceIdOptions.where((e) {
                  return e.toLowerCase().contains(keyword);
                }).toList();
              });
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: SizedBox(
                  height: 520,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Box Device ID',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: searchCtrl,
                        onChanged: onSearchChanged,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search Box Device ID...',
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.45),
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.white.withOpacity(0.7),
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.06),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.08),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.08),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.18),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Text(
                                  'No Box Device ID found',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  color: Colors.white.withOpacity(0.06),
                                ),
                                itemBuilder: (context, index) {
                                  final item = filtered[index];
                                  final selected = item == _selectedBoxDeviceId;

                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    title: Text(
                                      item,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    trailing: selected
                                        ? const Icon(
                                            Icons.check_circle,
                                            color: Colors.greenAccent,
                                          )
                                        : null,
                                    onTap: () {
                                      Navigator.of(context).pop(item);
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _selectedBoxDeviceId = result;
        _boxDeviceIdTouched = true;
      });
    }
  }

  Widget _buildBoxDeviceIdPickerField() {
    final hasValue =
        _selectedBoxDeviceId != null && _selectedBoxDeviceId!.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Box Device ID',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () {
            setState(() {
              _boxDeviceIdTouched = true;
            });
            _openBoxDeviceIdPicker();
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _boxDeviceIdInvalid
                    ? Colors.red.withOpacity(0.8)
                    : Colors.white.withOpacity(0.10),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    hasValue ? _selectedBoxDeviceId! : 'Select Box Device ID',
                    style: TextStyle(
                      color: hasValue
                          ? Colors.white
                          : Colors.white.withOpacity(0.45),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  color: Colors.white.withOpacity(0.8),
                ),
              ],
            ),
          ),
        ),
        if (_boxDeviceIdInvalid)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              'Box Device ID is required',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }

  void _submit() {
    setState(() {
      _boxDeviceIdTouched = true;
    });

    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    if ((_selectedBoxDeviceId ?? '').trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Box Device ID is required')),
      );
      return;
    }

    final minAlert = _parseNullableInt(_minAlertCtrl.text);
    final maxAlert = _parseNullableInt(_maxAlertCtrl.text);

    if (_isAlertEnabled) {
      if (minAlert == null || maxAlert == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Min Alert và Max Alert là bắt buộc khi bật Alert'),
          ),
        );
        return;
      }

      if (minAlert > maxAlert) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Min Alert không được lớn hơn Max Alert'),
          ),
        );
        return;
      }
    }

    final item = (widget.initialValue ?? const UtilityPara()).copyWith(
      boxDeviceId: _selectedBoxDeviceId,
      plcAddress: _plcAddressCtrl.text.trim(),
      valueType: _selectedValueType,
      unit: _unitCtrl.text.trim(),
      cateId: _cateIdCtrl.text.trim(),
      nameVi: _nameViCtrl.text.trim(),
      nameEn: _nameEnCtrl.text.trim(),
      isImportant: int.tryParse(_selectedIsImportant ?? '0') ?? 0,
      isAlert: int.tryParse(_selectedIsAlert ?? '0') ?? 0,
      minAlert: _isAlertEnabled ? minAlert : null,
      maxAlert: _isAlertEnabled ? maxAlert : null,
    );

    Navigator.of(context).pop(item);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: BaseSettingFormDialog(
        title: _isEdit ? 'Edit Utility Para' : 'Create Utility Para',
        submitText: _isEdit ? 'Update' : 'Create',
        onSubmit: _submit,
        customFields: [_buildBoxDeviceIdPickerField()],
        fields: [
          FormFieldConfig(
            label: 'PLC Address',
            validatorText: 'PLC Address is required',
            controller: _plcAddressCtrl,
          ),
          FormFieldConfig.dropdown(
            label: 'Value Type',
            validatorText: 'Value Type is required',
            value: _selectedValueType,
            items: _valueTypeOptions,
            onChanged: (value) {
              setState(() {
                _selectedValueType = value;
              });
            },
          ),
          FormFieldConfig(label: 'Unit', controller: _unitCtrl),
          FormFieldConfig(
            label: 'Cate ID',
            // validatorText: 'Cate ID is required',
            controller: _cateIdCtrl,
          ),
          FormFieldConfig(label: 'Name VI', controller: _nameViCtrl),
          FormFieldConfig(label: 'Name EN', controller: _nameEnCtrl),
          FormFieldConfig.dropdown(
            label: 'Important',
            validatorText: 'Important is required',
            value: _selectedIsImportant,
            items: _flagOptions,
            onChanged: (value) {
              setState(() {
                _selectedIsImportant = value;
              });
            },
          ),
          FormFieldConfig.dropdown(
            label: 'Alert',
            validatorText: 'Alert is required',
            value: _selectedIsAlert,
            items: _flagOptions,
            onChanged: (value) {
              setState(() {
                _selectedIsAlert = value;
                if (value != '1') {
                  _minAlertCtrl.clear();
                  _maxAlertCtrl.clear();
                }
              });
            },
          ),
          FormFieldConfig(
            label: 'Min Alert',
            controller: _minAlertCtrl,
            enabled: _isAlertEnabled,
            validator: (value) {
              if (!_isAlertEnabled) return null;
              final text = value?.trim() ?? '';
              if (text.isEmpty) return 'Min Alert is required';
              if (int.tryParse(text) == null) {
                return 'Min Alert must be a number';
              }
              return null;
            },
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[-0-9]')),
            ],
          ),
          FormFieldConfig(
            label: 'Max Alert',
            controller: _maxAlertCtrl,
            enabled: _isAlertEnabled,
            validator: (value) {
              if (!_isAlertEnabled) return null;
              final text = value?.trim() ?? '';
              if (text.isEmpty) return 'Max Alert is required';
              if (int.tryParse(text) == null) {
                return 'Max Alert must be a number';
              }
              return null;
            },
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[-0-9]')),
            ],
          ),
        ],
      ),
    );
  }
}

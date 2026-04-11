import 'package:flutter/material.dart';

import '../utility_dashboard_setting_widgets/form_field_config.dart';
import '../utility_dashboard_setting_widgets/setting_common_widgets.dart';

class BaseSettingFormDialog extends StatelessWidget {
  final String title;
  final List<FormFieldConfig> fields;
  final VoidCallback onSubmit;
  final String submitText;

  const BaseSettingFormDialog({
    super.key,
    required this.title,
    required this.fields,
    required this.onSubmit,
    required this.submitText,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF172033),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < fields.length; i++) ...[
                _buildField(fields[i]),
                if (i < fields.length - 1) const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        FilledButton(onPressed: onSubmit, child: Text(submitText)),
      ],
    );
  }

  Widget _buildField(FormFieldConfig field) {
    if (field.isDropdown) {
      return DropdownButtonFormField<String>(
        value: field.value,
        items: field.items
            .map(
              (item) =>
                  DropdownMenuItem<String>(value: item, child: Text(item)),
            )
            .toList(),
        onChanged: field.onChanged,
        dropdownColor: const Color(0xFF172033),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: field.label,
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: Colors.white.withOpacity(0.06),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.blueAccent),
          ),
        ),
        validator: (value) {
          if (field.validatorText != null && (value ?? '').trim().isEmpty) {
            return field.validatorText;
          }
          return null;
        },
        iconEnabledColor: Colors.white70,
      );
    }

    return DarkTextField(
      controller: field.controller!,
      label: field.label,
      validatorText: field.validatorText,
      keyboardType: field.keyboardType,
    );
  }
}

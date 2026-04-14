import 'package:flutter/material.dart';

import '../utility_dashboard_setting_widgets/form_field_config.dart';

class BaseSettingFormDialog extends StatelessWidget {
  final String title;
  final String submitText;
  final VoidCallback onSubmit;
  final List<FormFieldConfig> fields;
  final List<Widget> customFields;

  const BaseSettingFormDialog({
    super.key,
    required this.title,
    required this.submitText,
    required this.onSubmit,
    required this.fields,
    this.customFields = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF11151C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close,
                      color: Colors.white.withOpacity(0.75),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      ...customFields,
                      if (customFields.isNotEmpty && fields.isNotEmpty)
                        const SizedBox(height: 14),
                      ...fields.map(
                        (field) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _buildField(field),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withOpacity(0.12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        submitText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(FormFieldConfig config) {
    final defaultValidator = config.validatorText != null
        ? (String? value) {
            if (value == null || value.trim().isEmpty) {
              return config.validatorText;
            }
            return null;
          }
        : null;

    if (config.isDropdown) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            config.label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: config.items.contains(config.value) ? config.value : null,
            items: config.items
                .map(
                  (item) =>
                      DropdownMenuItem<String>(value: item, child: Text(item)),
                )
                .toList(),
            onChanged: config.onChanged,
            validator: config.validator ?? defaultValidator,
            dropdownColor: const Color(0xFF1A1F29),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.18)),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.red.withOpacity(0.7)),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.red.withOpacity(0.9)),
              ),
            ),
            iconEnabledColor: Colors.white.withOpacity(0.85),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          config.label,
          style: TextStyle(
            color: config.enabled
                ? Colors.white
                : Colors.white.withOpacity(0.45),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: config.controller,
          keyboardType: config.keyboardType,
          maxLines: config.maxLines,
          enabled: config.enabled,
          inputFormatters: config.inputFormatters,
          validator: config.validator ?? defaultValidator,
          style: TextStyle(
            color: config.enabled
                ? Colors.white
                : Colors.white.withOpacity(0.45),
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(config.enabled ? 0.06 : 0.03),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.10)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.18)),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.withOpacity(0.7)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.withOpacity(0.9)),
            ),
          ),
        ),
      ],
    );
  }
}

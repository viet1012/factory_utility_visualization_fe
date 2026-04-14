import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FormFieldConfig {
  final String label;
  final String? validatorText;
  final FormFieldValidator<String>? validator;

  final TextEditingController? controller;
  final TextInputType keyboardType;
  final int maxLines;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;

  final bool isDropdown;
  final String? value;
  final List<String> items;
  final ValueChanged<String?>? onChanged;

  const FormFieldConfig({
    required this.label,
    this.validatorText,
    this.validator,
    this.controller,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.inputFormatters,
    this.enabled = true,
    this.isDropdown = false,
    this.value,
    this.items = const [],
    this.onChanged,
  });

  const FormFieldConfig.dropdown({
    required this.label,
    this.validatorText,
    this.validator,
    required this.value,
    required this.items,
    required this.onChanged,
  }) : controller = null,
       keyboardType = TextInputType.text,
       maxLines = 1,
       inputFormatters = null,
       enabled = true,
       isDropdown = true;
}

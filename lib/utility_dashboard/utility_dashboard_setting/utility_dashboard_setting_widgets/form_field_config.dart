import 'package:flutter/material.dart';

class FormFieldConfig {
  final String label;
  final String? validatorText; // 👈 đổi thành nullable

  final TextEditingController? controller;
  final TextInputType keyboardType;
  final int maxLines;

  final bool isDropdown;
  final String? value;
  final List<String> items;
  final ValueChanged<String?>? onChanged;

  const FormFieldConfig({
    required this.label,
    this.validatorText, // 👈 không required nữa
    this.controller,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.isDropdown = false,
    this.value,
    this.items = const [],
    this.onChanged,
  });

  const FormFieldConfig.dropdown({
    required this.label,
    this.validatorText,
    required this.value,
    required this.items,
    required this.onChanged,
  }) : controller = null,
       keyboardType = TextInputType.text,
       maxLines = 1,
       isDropdown = true;
}

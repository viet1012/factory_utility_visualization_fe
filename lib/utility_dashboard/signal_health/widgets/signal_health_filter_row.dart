import 'package:flutter/material.dart';

import '../signal_health_style.dart';

class SignalHealthFilterRow extends StatelessWidget {
  final List<String> facOptions;
  final List<String> cateOptions;
  final List<String> scadaOptions;
  final List<String> boxDeviceOptions;

  final String? facValue;
  final String? cateValue;
  final String? scadaValue;
  final String? boxDeviceValue;

  final ValueChanged<String?> onFacChanged;
  final ValueChanged<String?> onCateChanged;
  final ValueChanged<String?> onScadaChanged;
  final ValueChanged<String?> onBoxDeviceChanged;
  final ValueChanged<String> onSearchChanged;

  const SignalHealthFilterRow({
    super.key,
    required this.facOptions,
    required this.cateOptions,
    required this.scadaOptions,
    required this.boxDeviceOptions,
    required this.facValue,
    required this.cateValue,
    required this.scadaValue,
    required this.boxDeviceValue,
    required this.onFacChanged,
    required this.onCateChanged,
    required this.onScadaChanged,
    required this.onBoxDeviceChanged,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _FilterDropdown(
          hint: 'Facility',
          value: facValue,
          items: facOptions,
          onChanged: onFacChanged,
        ),

        const SizedBox(width: 12),

        _FilterDropdown(
          hint: 'Category',
          value: cateValue,
          items: cateOptions,
          onChanged: onCateChanged,
        ),

        const SizedBox(width: 12),

        _FilterDropdown(
          hint: 'SCADA',
          value: scadaValue,
          items: scadaOptions,
          onChanged: onScadaChanged,
        ),

        const SizedBox(width: 12),

        _FilterDropdown(
          hint: 'Device',
          value: boxDeviceValue,
          items: boxDeviceOptions,
          width: 260,
          onChanged: onBoxDeviceChanged,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 38,
            child: TextField(
              onChanged: onSearchChanged,
              style: const TextStyle(color: kText, fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search device...',
                hintStyle: const TextStyle(color: kSubText, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: kSubText, size: 18),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 34,
                  minHeight: 34,
                ),
                filled: true,
                fillColor: kCard,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kBlue),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String? value;
  final String hint;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final double width;

  const _FilterDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
    this.width = 180,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: kCard,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,

          // ALL => hiện hint
          value: value == 'ALL' ? null : value,

          hint: Text(
            hint,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: kSubText,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),

          dropdownColor: kCard,
          iconEnabledColor: kText,

          items: items.map((e) {
            return DropdownMenuItem<String>(
              value: e,
              child: Text(
                e == 'ALL'
                    ? 'All ${hint.replaceAll(RegExp(r'[^\w\s]'), '').trim()}'
                    : e,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: kText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }).toList(),

          onChanged: (v) {
            if (v != null) {
              onChanged(v);
            }
          },
        ),
      ),
    );
  }
}

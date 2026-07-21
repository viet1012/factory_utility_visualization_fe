class FacDetailFormatters {
  const FacDetailFormatters._();

  static String time(DateTime? value) {
    if (value == null) {
      return '—';
    }

    String pad(int number) {
      return number.toString().padLeft(2, '0');
    }

    return '${pad(value.hour)}:'
        '${pad(value.minute)}:'
        '${pad(value.second)}';
  }

  static String clean(Object? value) {
    return value?.toString().trim() ?? '';
  }

  static int compareText(String first, String second) {
    return first.trim().toLowerCase().compareTo(second.trim().toLowerCase());
  }
}

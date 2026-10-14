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
}

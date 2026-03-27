class EcuadorDateUtils {
  /// Converts a UTC ISO 8601 string to Ecuador Timezone (UTC-5)
  static DateTime toEcuadorTime(String isoString) {
    if (isoString.isEmpty)
      return DateTime.now().toUtc().subtract(const Duration(hours: 5));

    // Parse to UTC
    DateTime utcDate = DateTime.parse(isoString);
    if (!utcDate.isUtc) {
      // If the string doesn't specify 'Z', force it to act as UTC
      utcDate = DateTime.utc(
        utcDate.year,
        utcDate.month,
        utcDate.day,
        utcDate.hour,
        utcDate.minute,
        utcDate.second,
        utcDate.millisecond,
        utcDate.microsecond,
      );
    }

    // Convert to Ecuador time (UTC -5)
    return utcDate.subtract(const Duration(hours: 5));
  }

  /// Formats date to display locally in UI (dd/MM/yyyy HH:mm)
  static String formatEcuadorTime(String isoString) {
    if (isoString.isEmpty) return 'Fecha inválida';
    try {
      final date = toEcuadorTime(isoString);
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$day/$month/$year $hour:$minute';
    } catch (e) {
      return 'Fecha inválida';
    }
  }

  /// Get current date and time in Ecuador timezone
  static DateTime nowEcuador() {
    return DateTime.now().toUtc().subtract(const Duration(hours: 5));
  }
}

import '../schedule/shift_repository.dart';

/// Match the work-service join and checkout windows in Vietnam time, including
/// shifts that cross midnight. Missing configuration never enables attendance.
ApiShiftModel? nextDoubleAttendanceShift({
  required List<ApiShiftModel> shifts,
  required String employeeId,
  required String currentShiftId,
  required Map<String, dynamic> config,
  required DateTime now,
}) {
  if (config['allowDoubleCheckin'] != true) return null;
  final current = shifts
      .where((s) => s.id == currentShiftId && s.employeeId == employeeId)
      .firstOrNull;
  if (current == null ||
      current.isCancelled ||
      current.checkIn == null ||
      current.checkOut != null ||
      !current.canCheckout) {
    return null;
  }
  DateTime? startOf(ApiShiftModel shift) => DateTime.tryParse(
      '${toIsoDate(shift.workDate)}T${shift.scheduledStart}:00+07:00');
  final start = startOf(current);
  var join = DateTime.tryParse(
      '${toIsoDate(current.workDate)}T${current.scheduledEnd}:00+07:00');
  if (start == null || join == null) return null;
  if (!join.isAfter(start)) join = join.add(const Duration(days: 1));
  int? minutes(String key) => int.tryParse('${config[key]}');
  final early = minutes('doubleCheckinEarlyMinutes');
  final late = minutes('doubleCheckinLateMinutes');
  final checkout = minutes('checkoutWindowMinutes');
  if (early == null ||
      late == null ||
      checkout == null ||
      early < 0 ||
      late < 0 ||
      checkout <= 0) {
    return null;
  }
  if (now.isBefore(join.subtract(Duration(minutes: early))) ||
      now.isAfter(join.add(Duration(minutes: late))) ||
      !now.isBefore(join.add(Duration(minutes: checkout)))) {
    return null;
  }
  return shifts
      .where((s) =>
          s.id != current.id &&
          s.employeeId == employeeId &&
          s.branchId == current.branchId &&
          !s.isCancelled &&
          s.checkIn == null &&
          s.checkOut == null &&
          startOf(s) == join)
      .firstOrNull;
}

import 'package:flutter/material.dart';
import '../models/branch.dart';

/// Giữ chi nhánh đang được chọn trên toàn app.
///
/// Giá trị:
/// - `Branch`: đang xem chi nhánh cụ thể.
/// - `null`: đang xem "Tổng (Tất cả chi nhánh)".
class BranchScope extends InheritedNotifier<ValueNotifier<Branch?>> {
  const BranchScope({
    super.key,
    required ValueNotifier<Branch?> notifier,
    required super.child,
  }) : super(notifier: notifier);

  static BranchScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BranchScope>();

  /// Đọc scope mà không tạo dependency (dùng trong event handler).
  static BranchScope? read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<BranchScope>();

  static ValueNotifier<Branch?>? notifierOf(BuildContext context) =>
      read(context)?.notifier;

  static Branch? selectedBranch(BuildContext context) =>
      maybeOf(context)?.notifier?.value;

  static String label(BuildContext context) {
    final branch = selectedBranch(context);
    return branch?.name ?? 'Tất cả chi nhánh';
  }

  static void select(BuildContext context, Branch? branch) {
    final notifier = notifierOf(context);
    if (notifier != null) {
      notifier.value = branch;
    }
  }
}
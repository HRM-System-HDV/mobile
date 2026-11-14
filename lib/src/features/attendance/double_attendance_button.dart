import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../schedule/shift_repository.dart';
import 'attendance_repository.dart';
import 'double_attendance.dart';

class DoubleAttendanceButton extends StatefulWidget {
  final String employeeId;
  final String currentShiftId;
  final Future<void> Function() onChanged;
  final AttendanceRepository? attendanceRepository;
  final ShiftRepository? shiftRepository;
  final DateTime Function()? now;

  const DoubleAttendanceButton(
      {super.key,
      required this.employeeId,
      required this.currentShiftId,
      required this.onChanged,
      this.attendanceRepository,
      this.shiftRepository,
      this.now});

  @override
  State<DoubleAttendanceButton> createState() => _DoubleAttendanceButtonState();
}

class _DoubleAttendanceButtonState extends State<DoubleAttendanceButton>
    with WidgetsBindingObserver {
  late final AttendanceRepository _attendance =
      widget.attendanceRepository ?? AttendanceRepository();
  late final ShiftRepository _shifts =
      widget.shiftRepository ?? ShiftRepository();
  List<ApiShiftModel> _rows = [];
  Map<String, dynamic> _config = {};
  String? _error;
  bool _busy = false;
  bool _refreshing = false;
  Timer? _clock;
  Timer? _refreshTimer;

  DateTime get _now => widget.now?.call() ?? DateTime.now();
  ApiShiftModel? get _next => nextDoubleAttendanceShift(
      shifts: _rows,
      employeeId: widget.employeeId,
      currentShiftId: widget.currentShiftId,
      config: _config,
      now: _now);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_busy) setState(() {});
    });
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_busy) _refresh();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final config = await _attendance.getConfig();
      final rows = await _shifts.getShifts(employeeId: widget.employeeId);
      if (mounted) {
        setState(() {
          _config = config;
          _rows = rows;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _config = {};
          _rows = [];
          _error = error is ApiException
              ? error.message
              : 'Không kiểm tra được ca liền kề';
        });
      }
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _submit() async {
    if (_busy || _next == null) return;
    setState(() => _busy = true);
    var attempted = false;
    final success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        var sending = false;
        String? errorMessage;
        return StatefulBuilder(
            builder: (context, setDialogState) => PopScope(
                  canPop: !sending,
                  child: AlertDialog(
                    title: const Text('Ra ca & vào ca tiếp'),
                    content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                              'Xác nhận kết thúc ca hiện tại và bắt đầu ca liền sau tại mốc nối ca?'),
                          if (sending)
                            const Padding(
                                padding: EdgeInsets.only(top: 16),
                                child: LinearProgressIndicator()),
                          if (errorMessage != null)
                            Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(errorMessage!,
                                    style: const TextStyle(
                                        color: AppColors.error))),
                        ]),
                    actions: [
                      TextButton(
                          onPressed: sending
                              ? null
                              : () => Navigator.pop(dialogContext, false),
                          child: const Text('Hủy')),
                      FilledButton(
                          onPressed: sending
                              ? null
                              : () async {
                                  setDialogState(() {
                                    sending = true;
                                    errorMessage = null;
                                  });
                                  try {
                                    final config =
                                        await _attendance.getConfig();
                                    final rows = await _shifts.getShifts(
                                        employeeId: widget.employeeId);
                                    final next = nextDoubleAttendanceShift(
                                        shifts: rows,
                                        employeeId: widget.employeeId,
                                        currentShiftId: widget.currentShiftId,
                                        config: config,
                                        now: _now);
                                    if (next == null) {
                                      throw const ApiException(
                                          'SHIFT_CHANGED',
                                          'Không còn đủ điều kiện chấm công kép. Vui lòng tải lại lịch ca.',
                                          409);
                                    }
                                    attempted = true;
                                    await _attendance
                                        .doubleAttendanceWithDeviceWifi(
                                            employeeId: widget.employeeId,
                                            shiftId: widget.currentShiftId,
                                            nextShiftId: next.id);
                                    if (dialogContext.mounted) {
                                      Navigator.pop(dialogContext, true);
                                    }
                                  } catch (error) {
                                    if (dialogContext.mounted) {
                                      setDialogState(() {
                                        sending = false;
                                        errorMessage = error is ApiException
                                            ? error.message
                                            : 'Chấm công kép thất bại. Vui lòng thử lại.';
                                      });
                                    }
                                  }
                                },
                          child:
                              Text(sending ? 'Đang chấm công...' : 'Xác nhận')),
                    ],
                  ),
                ));
      },
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (success == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Đã ra ca trước và vào ca tiếp thành công.')));
    }
    if (attempted) await widget.onChanged();
    if (mounted) await _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(children: [
            Expanded(
                child: Text(_error!,
                    style:
                        const TextStyle(color: AppColors.error, fontSize: 12))),
            TextButton(onPressed: _refresh, child: const Text('Thử lại'))
          ]));
    }
    if (_next == null) return const SizedBox.shrink();
    return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _submit,
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Ra ca & vào ca tiếp'),
            )));
  }
}

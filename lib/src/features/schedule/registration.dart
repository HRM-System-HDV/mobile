import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/constants/colors.dart';
import '../../core/state/user_scope.dart';
import 'shift_repository.dart';

class ShiftOption {
  final String id;
  final String name;
  final String timeRange;

  const ShiftOption({
    required this.id,
    required this.name,
    required this.timeRange,
  });

  String get displayName => id == 'off' ? name : '$name ($timeRange)';
}

// Danh sách ca mẫu chuẩn do Quản trị thiết lập (đồng bộ với hệ thống ca quản trị)
List<ShiftOption> adminShiftTemplates = [
  const ShiftOption(id: 'off', name: 'Nghỉ (Không làm ca)', timeRange: 'Nghỉ ca'),
  const ShiftOption(id: 't1', name: 'Ca Sáng', timeRange: '07:00 - 14:00'),
  const ShiftOption(id: 't2', name: 'Ca Chiều', timeRange: '14:00 - 22:00'),
  const ShiftOption(id: 't3', name: 'Ca Tối', timeRange: '18:00 - 23:00'),
  const ShiftOption(id: 't4', name: 'Ca Hành chính', timeRange: '08:00 - 17:00'),
];

class DayShiftRegistration {
  final String dayName;
  final String dateStr;
  final String shortKey;
  String selectedShiftId;

  DayShiftRegistration({
    required this.dayName,
    required this.dateStr,
    required this.shortKey,
    required this.selectedShiftId,
  });

  bool get isOff => selectedShiftId == 'off';

  ShiftOption get currentShift =>
      adminShiftTemplates.firstWhere((s) => s.id == selectedShiftId, orElse: () => adminShiftTemplates.first);
}

/// Model lưu dữ liệu đăng ký ca theo từng tuần
class WeekRegistrationData {
  final String weekLabel;         // VD: "Tuần 24/08 - 30/08"
  final List<DayShiftRegistration> days;
  String? note;                   // Note nguyện vọng
  bool noteSent;                  // Đã gửi note chưa

  WeekRegistrationData({
    required this.weekLabel,
    required this.days,
    this.note,
    this.noteSent = false,
  });
}

class ScheduleRegistrationScreen extends StatefulWidget {
  const ScheduleRegistrationScreen({super.key});

  @override
  State<ScheduleRegistrationScreen> createState() => _ScheduleRegistrationScreenState();
}

class _ScheduleRegistrationScreenState extends State<ScheduleRegistrationScreen> {
  // Offset tuần so với tuần tới (0 = tuần tới, -1 = tuần này, -2 = tuần trước...)
  // Người dùng có thể chuyển về xem lịch sử tuần trước
  int _weekOffset = 1; // Mặc định là tuần tới (để đăng ký)

  final TextEditingController _noteController = TextEditingController();
  bool _isEditingNote = false;

  // Cache dữ liệu tuần — khởi rỗng, điền từ API (getRegistrations), không dùng mẫu cứng
  final Map<int, WeekRegistrationData> _weekDataCache = {};

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _thisWeekMonday {
    return _today.subtract(Duration(days: _today.weekday - 1));
  }

  DateTime _getWeekMonday(int offset) {
    return _thisWeekMonday.add(Duration(days: offset * 7));
  }

  String _getWeekRange(int offset) {
    final monday = _getWeekMonday(offset);
    final sunday = monday.add(const Duration(days: 6));
    final monStr = '${monday.day.toString().padLeft(2, '0')}/${monday.month.toString().padLeft(2, '0')}';
    final sunStr = '${sunday.day.toString().padLeft(2, '0')}/${sunday.month.toString().padLeft(2, '0')}';
    return '$monStr - $sunStr';
  }

  String _getWeekTitle(int offset) {
    if (offset == 0) return 'Tuần này';
    if (offset == -1) return 'Tuần trước';
    if (offset == 1) return 'Tuần sau';
    if (offset < -1) return '${offset.abs()} tuần trước';
    return '$offset tuần sau';
  }

  WeekRegistrationData _getOrCreateWeekData(int offset) {
    if (_weekDataCache.containsKey(offset)) {
      return _weekDataCache[offset]!;
    }

    final monday = _getWeekMonday(offset);
    final dayNames = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'];
    final shortKeys = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

    // Khởi rỗng (chưa đăng ký = Nghỉ) — lịch sử đọc từ API, rỗng thì hiện empty state
    final defaultShifts = List.generate(7, (_) => 'off');

    final days = List.generate(7, (i) {
      final dayDate = monday.add(Duration(days: i));
      final dateStr = '${dayDate.day.toString().padLeft(2, '0')}/${dayDate.month.toString().padLeft(2, '0')}';
      return DayShiftRegistration(
        dayName: dayNames[i],
        dateStr: dateStr,
        shortKey: shortKeys[i],
        selectedShiftId: defaultShifts[i],
      );
    });

    // Không dùng note mẫu — note đọc từ API getRegistrations
    final weekData = WeekRegistrationData(
      weekLabel: _getWeekRange(offset),
      days: days,
      note: null,
      noteSent: false,
    );
    _weekDataCache[offset] = weekData;
    return weekData;
  }

  WeekRegistrationData get _currentWeekData => _getOrCreateWeekData(_weekOffset);
  bool get _isPastWeek => _weekOffset <= 0; // Tuần này hoặc tuần trước = chỉ xem, không cho sửa ca

  @override
  void initState() {
    super.initState();
    final weekData = _getOrCreateWeekData(_weekOffset);
    if (weekData.noteSent && weekData.note != null) {
      _noteController.text = weekData.note!;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRemoteRegistrations();
    });
  }

  Future<void> _loadRemoteRegistrations() async {
    try {
      final user = UserScope.currentUser(context);
      final empId = user?.id ?? '';
      final repo = ShiftRepository();
      try {
        final tpls = await repo.getTemplates();
        if (tpls.isNotEmpty) {
          final List<ShiftOption> loaded = [
            const ShiftOption(id: 'off', name: 'Nghỉ (Không làm ca)', timeRange: 'Nghỉ ca'),
          ];
          for (final t in tpls) {
            final id = t['id']?.toString() ?? '';
            final name = t['name']?.toString() ?? '';
            final start = t['startTime']?.toString() ?? '';
            final end = t['endTime']?.toString() ?? '';
            if (id.isNotEmpty && name.isNotEmpty) {
              loaded.add(ShiftOption(
                id: id,
                name: name,
                timeRange: start.isNotEmpty && end.isNotEmpty ? '$start - $end' : start,
              ));
            }
          }
          if (loaded.length > 1) {
            adminShiftTemplates = loaded;
          }
        }
      } catch (_) {}

      final regs = empId.isNotEmpty
          ? await repo.getRegistrations(employeeId: empId)
          : <Map<String, dynamic>>[];
      if (mounted) {
        final weekData = _getOrCreateWeekData(_weekOffset);
        // Reset về rỗng trước khi điền API để rỗng hiện empty state
        for (final day in weekData.days) {
          day.selectedShiftId = 'off';
        }
        weekData.note = null;
        weekData.noteSent = false;
        _noteController.text = '';
        for (final r in regs) {
          final pref = r['preference']?.toString() ?? '';
          final shiftId = r['shiftId']?.toString() ?? '';
          if (shiftId == 'preference_note' && pref.isNotEmpty) {
            weekData.note = pref;
            weekData.noteSent = true;
            _noteController.text = pref;
          } else {
            for (final day in weekData.days) {
              if (day.dateStr == pref || pref.contains(day.dateStr)) {
                day.selectedShiftId = shiftId;
              }
            }
          }
        }
        setState(() {});
      }
    } catch (_) {}
  }

  void _onWeekChanged(int newOffset) {
    setState(() {
      _weekOffset = newOffset;
      _isEditingNote = false;
      final weekData = _getOrCreateWeekData(newOffset);
      if (weekData.noteSent && weekData.note != null) {
        _noteController.text = weekData.note!;
      } else {
        _noteController.text = weekData.note ?? '';
      }
    });
    _loadRemoteRegistrations();
  }

  void _onSelectShift(DayShiftRegistration day, String shiftId) {
    final user = UserScope.currentUser(context);
    final empId = user?.id ?? '';
    if (empId.isNotEmpty) {
      ShiftRepository().registerShift(
        employeeId: empId,
        shiftId: shiftId,
        preference: day.dateStr,
      ).catchError((_) {});
    }
    setState(() {
      day.selectedShiftId = shiftId;
    });
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(milliseconds: 1000),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Row(
          children: [
            const FaIcon(FontAwesomeIcons.cloudArrowUp, color: Colors.greenAccent, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${day.dayName}: Đã lưu ${day.currentShift.displayName}',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendNote() {
    final note = _noteController.text.trim();
    if (note.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Vui lòng nhập nội dung ghi chú trước khi gửi'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    final user = UserScope.currentUser(context);
    final empId = user?.id ?? '';
    if (empId.isNotEmpty) {
      ShiftRepository().registerShift(
        employeeId: empId,
        shiftId: 'preference_note',
        preference: note,
      ).catchError((_) {});
    }
    setState(() {
      _currentWeekData.note = note;
      _currentWeekData.noteSent = true;
      _isEditingNote = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            FaIcon(FontAwesomeIcons.circleCheck, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Đã gửi ghi chú nguyện vọng thành công!'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _saveNote() {
    final note = _noteController.text.trim();
    setState(() {
      _currentWeekData.note = note.isEmpty ? null : note;
      _currentWeekData.noteSent = note.isNotEmpty;
      _isEditingNote = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            FaIcon(FontAwesomeIcons.floppyDisk, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Đã lưu ghi chú nguyện vọng'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _startEditNote() {
    setState(() {
      _noteController.text = _currentWeekData.note ?? '';
      _isEditingNote = true;
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final weekData = _currentWeekData;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Đăng ký ca làm việc',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const FaIcon(FontAwesomeIcons.chevronLeft, size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // ── THANH ĐIỀU HƯỚNG TUẦN (Xem lịch sử / tuần tới) ──
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () => _onWeekChanged(_weekOffset - 1),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: const FaIcon(FontAwesomeIcons.chevronLeft, size: 13, color: AppColors.primary),
                      ),
                    ),

                    Column(
                      children: [
                        Text(
                          _getWeekTitle(_weekOffset),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          _getWeekRange(_weekOffset),
                          style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                        ),
                      ],
                    ),

                    InkWell(
                      onTap: () => _onWeekChanged(_weekOffset + 1),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: const FaIcon(FontAwesomeIcons.chevronRight, size: 13, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),

                // Badge trạng thái tuần
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: _isPastWeek ? Colors.grey.shade100 : AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isPastWeek ? Colors.grey.shade300 : AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        _isPastWeek ? 'Chỉ xem — Đã qua' : 'Đang mở đăng ký',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _isPastWeek ? Colors.grey.shade600 : AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── DANH SÁCH CÁC NGÀY TRONG TUẦN ──
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              itemCount: weekData.days.length + 1, // +1 cho khối Note cuối
              separatorBuilder: (_, index) => SizedBox(height: index < weekData.days.length - 1 ? 10 : 14),
              itemBuilder: (context, index) {
                // Phần cuối: Khối Note Ghi chú
                if (index == weekData.days.length) {
                  return _buildNoteSection(weekData);
                }

                final day = weekData.days[index];
                final isOff = day.isOff;
                final isLocked = _isPastWeek; // Không cho sửa nếu tuần đã qua

                return Card(
                  margin: EdgeInsets.zero,
                  elevation: 0.5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isLocked
                          ? Colors.grey.shade200
                          : (isOff ? Colors.grey.shade200 : AppColors.primary.withValues(alpha: 0.25)),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        // Cột Thứ & Ngày bên trái
                        SizedBox(
                          width: 82,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                day.dayName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isLocked ? Colors.grey.shade600 : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                day.dateStr,
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Cột Dropdown sổ xuống chọn ca bên phải
                        Expanded(
                          child: isLocked
                              // Khóa: Chỉ hiển thị badge ca đã đăng ký (không cho sửa)
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isOff ? Colors.grey.shade100 : AppColors.primary.withValues(alpha: 0.07),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isOff ? Colors.grey.shade300 : AppColors.primary.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      FaIcon(
                                        isOff ? FontAwesomeIcons.umbrellaBeach : FontAwesomeIcons.clock,
                                        size: 16,
                                        color: isOff ? Colors.grey.shade500 : AppColors.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          day.currentShift.displayName,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isOff ? Colors.grey.shade600 : AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      FaIcon(FontAwesomeIcons.lock, size: 14, color: Colors.grey.shade400),
                                    ],
                                  ),
                                )
                              : DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  initialValue: day.selectedShiftId,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(color: Colors.grey.shade300),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(color: Colors.grey.shade300),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                                    ),
                                    filled: true,
                                    fillColor: isOff ? Colors.grey.shade50 : AppColors.primary.withValues(alpha: 0.04),
                                  ),
                                  icon: const FaIcon(FontAwesomeIcons.caretDown, color: AppColors.textSecondary),
                                  items: adminShiftTemplates.map((shift) {
                                    final isShiftOff = shift.id == 'off';
                                    return DropdownMenuItem<String>(
                                      value: shift.id,
                                      child: Text(
                                        shift.displayName,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: isShiftOff ? FontWeight.normal : FontWeight.w600,
                                          color: isShiftOff ? Colors.grey.shade600 : AppColors.textPrimary,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) _onSelectShift(day, val);
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteSection(WeekRegistrationData weekData) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Note
          Row(
            children: [
              FaIcon(FontAwesomeIcons.penToSquare, size: 18, color: Colors.amber.shade700),
              const SizedBox(width: 6),
              const Text(
                'Ghi chú nguyện vọng',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const Spacer(),
              if (_isPastWeek)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Chỉ xem', style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // STATE 1: CHƯA GỬI - Hiển thị ô nhập + nút Gửi
          if (!weekData.noteSent && !_isEditingNote) ...[
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _noteController,
                    maxLines: 3,
                    readOnly: _isPastWeek,
                    decoration: InputDecoration(
                      hintText: _isPastWeek
                          ? 'Không có ghi chú nào được gửi'
                          : 'Nhập nguyện vọng của bạn (ưu tiên ca, xin nghỉ đặc biệt, v.v.)',
                      hintStyle: TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(14),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                  if (!_isPastWeek)
                    Container(
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: Colors.grey.shade200)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _sendNote,
                            icon: const FaIcon(FontAwesomeIcons.paperPlane, size: 15),
                            label: const Text('Gửi'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],

          // STATE 2: ĐÃ GỬI & KHÔNG ĐANG SỬA - Hiển thị note + nút Sửa
          if (weekData.noteSent && !_isEditingNote) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    weekData.note ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.brown.shade800,
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      FaIcon(FontAwesomeIcons.circleCheck, size: 13, color: Colors.green.shade600),
                      const SizedBox(width: 4),
                      Text(
                        'Đã gửi cho quản lý',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                      ),
                      const Spacer(),
                      if (!_isPastWeek)
                        InkWell(
                          onTap: _startEditNote,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FaIcon(FontAwesomeIcons.penToSquare, size: 14, color: Colors.amber.shade800),
                                const SizedBox(width: 4),
                                Text(
                                  'Sửa',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // STATE 3: ĐANG SỬA - Hiển thị ô nhập + nút Lưu & Hủy
          if (_isEditingNote) ...[
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 1.5),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _noteController,
                    maxLines: 3,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Chỉnh sửa nguyện vọng của bạn...',
                      hintStyle: TextStyle(fontSize: 12.5, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(14),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.grey.shade200)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Nút Hủy
                        OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _noteController.text = weekData.note ?? '';
                              _isEditingNote = false;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Hủy'),
                        ),
                        const SizedBox(width: 8),
                        // Nút Lưu
                        ElevatedButton.icon(
                          onPressed: _saveNote,
                          icon: const FaIcon(FontAwesomeIcons.floppyDisk, size: 15),
                          label: const Text('Lưu'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../constants/colors.dart';

/// Widget thanh 7 ngày trong tuần với mũi tên chuyển tuần overlay 2 đầu + hiệu ứng fade.
/// Tái sử dụng ở nhiều màn hình: Lịch làm việc chung, Xếp ca, v.v.
class WeekDayStrip extends StatelessWidget {
  /// Dải 7 ngày - mỗi phần tử là một Map với các key:
  ///   'label'     : String - nhãn ngắn (T2, T3, ..., CN)
  ///   'day'       : int    - số ngày trong tháng
  ///   'isToday'   : bool
  ///   'dotColor'  : Color? - màu chấm tròn dưới ngày (nếu null = xám)
  final List<Map<String, dynamic>> days;

  /// Index ngày đang được chọn (0–6)
  final int selectedIndex;

  /// Gọi khi người dùng chạm vào một ngày
  final ValueChanged<int> onDaySelected;

  /// Gọi khi bấm mũi tên trái (về tuần trước)
  final VoidCallback onPrevWeek;

  /// Gọi khi bấm mũi tên phải (sang tuần sau)
  final VoidCallback onNextWeek;

  /// Tiêu đề tuần hiển thị (VD: "Tuần này • 07/09 - 13/09")
  final String weekLabel;

  const WeekDayStrip({
    super.key,
    required this.days,
    required this.selectedIndex,
    required this.onDaySelected,
    required this.onPrevWeek,
    required this.onNextWeek,
    required this.weekLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Nhãn tuần hiện tại (ở giữa trên cùng)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Center(
              child: Text(
                weekLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Dải 7 ngày + mũi tên overlay hai đầu
          SizedBox(
            height: 72, // Chiều cao cố định của dải ngày
            child: Stack(
              alignment: Alignment.center,
              children: [
                // ── Hàng 7 ngày (có padding nhỏ ở 2 đầu để tránh bị mũi tên che) ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(days.length, (index) {
                      final d = days[index];
                      final isSelected = index == selectedIndex;
                      final isToday = d['isToday'] as bool? ?? false;
                      final dotColor = d['dotColor'] as Color?;

                      return GestureDetector(
                        onTap: () => onDaySelected(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          width: 38,
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : (isToday
                                    ? AppColors.primary.withValues(alpha: 0.11)
                                    : Colors.transparent),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : (isToday
                                      ? AppColors.primary.withValues(alpha: 0.5)
                                      : Colors.grey.shade200),
                              width: isSelected ? 1.8 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Nhãn ngày (T2, T3...)
                              Text(
                                d['label'] as String,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : (isToday ? AppColors.primary : AppColors.textSecondary),
                                ),
                              ),
                              const SizedBox(height: 3),
                              // Số ngày
                              Text(
                                '${d['day'] as int}',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              // Chấm tròn indicator
                              Container(
                                width: 4.5,
                                height: 4.5,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? Colors.white.withValues(alpha: 0.85)
                                      : (dotColor ?? Colors.grey.shade300),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                // ── Gradient fade BÊN TRÁI + mũi tên trái ──
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: onPrevWeek,
                    child: SizedBox(
                      width: 44,
                      child: Stack(
                        children: [
                          // Hiệu ứng fade trắng mờ dần sang phải
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    Colors.white,
                                    Colors.white.withValues(alpha: 0.92),
                                    Colors.white.withValues(alpha: 0.0),
                                  ],
                                  stops: const [0.0, 0.55, 1.0],
                                ),
                              ),
                            ),
                          ),
                          // Mũi tên trái
                          Center(
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.10),
                                    blurRadius: 6,
                                    offset: const Offset(1, 0),
                                  ),
                                ],
                              ),
                              child: const FaIcon(
                                FontAwesomeIcons.chevronLeft,
                                size: 20,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Gradient fade BÊN PHẢI + mũi tên phải ──
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: onNextWeek,
                    child: SizedBox(
                      width: 44,
                      child: Stack(
                        children: [
                          // Hiệu ứng fade trắng mờ dần sang trái
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerRight,
                                  end: Alignment.centerLeft,
                                  colors: [
                                    Colors.white,
                                    Colors.white.withValues(alpha: 0.92),
                                    Colors.white.withValues(alpha: 0.0),
                                  ],
                                  stops: const [0.0, 0.55, 1.0],
                                ),
                              ),
                            ),
                          ),
                          // Mũi tên phải
                          Center(
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.10),
                                    blurRadius: 6,
                                    offset: const Offset(-1, 0),
                                  ),
                                ],
                              ),
                              child: const FaIcon(
                                FontAwesomeIcons.chevronRight,
                                size: 20,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

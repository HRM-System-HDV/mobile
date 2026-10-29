import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/constants/colors.dart';

class FaqItem {
  final String question;
  final String answer;

  const FaqItem({required this.question, required this.answer});
}

class FaqHelpScreen extends StatelessWidget {
  const FaqHelpScreen({super.key});

  final List<FaqItem> _faqs = const [
    FaqItem(
      question: 'Làm thế nào để chấm công Wi-Fi hợp lệ?',
      answer:
          'Bạn cần kết nối điện thoại vào đúng mạng Wi-Fi của chi nhánh (VD: HRM_HN1_OFFICE). Khi vào tab Trang chủ, nút Chấm công sẽ chuyển sang trạng thái sẵn sàng. Chạm vào nút và chọn ca làm việc hôm nay để xác thực.',
    ),
    FaqItem(
      question: 'Tôi quên bấm check-in hoặc check-out thì phải làm sao?',
      answer:
          'Bạn vào tab "Tác vụ" > Chọn mục "Bổ sung / sửa chấm công" > Chọn ca làm việc và nhập thời gian vào/ra thực tế cùng lý do giải trình. Đơn sẽ được chuyển đến Quản lý chi nhánh để duyệt và bù công.',
    ),
    FaqItem(
      question: 'Quy trình đổi ca hoặc nhờ người khác làm thay?',
      answer:
          'Vào tab "Trang chủ" hoặc "Lịch làm việc" > Bấm vào ca muốn đổi > Chọn "Yêu cầu đổi ca" hoặc "Nhờ làm thay" > Chọn đồng nghiệp nhận ca và gửi yêu cầu. Khi đồng nghiệp xác nhận "Đồng ý", lịch ca sẽ tự động cập nhật ngay mà không qua admin. Trường hợp đồng nghiệp bận hoặc có việc gấp, Quản lý chi nhánh có thể vào duyệt đồng ý hộ.',
    ),
    FaqItem(
      question: 'Quản trị viên và Quản lý có cần chấm công không?',
      answer:
          'Có! Trong hệ thống HRM, Quản trị viên (Admin) và Quản lý (Manager) cũng là một nhân sự của công ty. Họ vẫn có lịch ca, thực hiện chấm công Wi-Fi và nhận phiếu lương hàng tháng như mọi nhân viên.',
    ),
    FaqItem(
      question: 'Khi nào có phiếu lương và tiền lương được thanh toán?',
      answer:
          'Phiếu lương được phòng Nhân sự tổng hợp vào cuối tháng. Quản lý chi nhánh kiểm tra và Quản trị viên chốt lương trước ngày 03. Tiền lương sẽ được chuyển khoản vào tài khoản ngân hàng của bạn vào ngày 05 hằng tháng.',
    ),
    FaqItem(
      question: 'Điều kiện để được tạm ứng lương là gì?',
      answer:
          'Nhân viên làm việc từ 10 ngày công trở lên trong tháng và đã tích lũy giờ công hợp lệ có thể xin tạm ứng tối đa 50% số tiền lương tạm tính. Vào "Tác vụ" > "Tạm ứng lương" để nộp yêu cầu.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Câu hỏi thường gặp & Trợ giúp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Color(0xFFEFF6FF),
                  child: FaIcon(FontAwesomeIcons.headset, color: Color(0xFF2563EB), size: 24),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Trung tâm trợ giúp HRM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      SizedBox(height: 2),
                      Text('Tổng hợp các giải đáp nhanh về vận hành, chấm công và quyền lợi nhân sự.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Các câu hỏi phổ biến', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 10),

          ..._faqs.map((faq) => _buildFaqCard(faq)),
        ],
      ),
    );
  }

  Widget _buildFaqCard(FaqItem faq) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Theme(
        data: ThemeData().copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          title: Text(
            faq.question,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(
                faq.answer,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/colors.dart';
import '../../core/models/user.dart';
import '../../core/services/upload_service.dart';
import '../../core/state/branch_scope.dart';
import '../../core/state/user_scope.dart';
import '../auth/auth_repository.dart';
import 'employee_repository.dart';

class PersonalInfoScreen extends StatefulWidget {
  final String name;
  final String email;
  final String phone;
  final bool isManager;
  final UserModel? user;

  const PersonalInfoScreen({
    super.key,
    required this.name,
    required this.email,
    required this.phone,
    required this.isManager,
    this.user,
  });

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _cccdCtrl;
  bool _isEditing = false;

  late String _birthDate;
  late String _gender;
  late String _province;
  late String _ward;
  late String _street;
  late String _bankAcc;
  late String _bankName;
  late String _cccd;
  late String _issueDate;
  late String _issuePlace;
  String? _avatarUrl;
  String? _cccdFrontUrl;
  String? _cccdBackUrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.name);
    _phoneCtrl = TextEditingController(text: widget.phone);
    // Không tự điền mẫu — thiếu dữ liệu thì để '' và hiện hint 'Chưa cập nhật'.
    _birthDate = widget.user?.birthDate ?? '';
    _gender = widget.user?.gender ?? '';
    _province = widget.user?.province ?? '';
    _ward = widget.user?.ward ?? '';
    _street = widget.user?.street ?? '';
    _bankAcc = widget.user?.bankAccountNumber ?? '';
    _bankName = widget.user?.bankName ?? '';
    _cccd = widget.user?.cccd ?? '';
    _issueDate = widget.user?.issueDate ?? '';
    _issuePlace = widget.user?.issuePlace ?? '';
    _avatarUrl = widget.user?.avatarUrl;
    _cccdFrontUrl = widget.user?.cccdFrontUrl;
    _cccdBackUrl = widget.user?.cccdBackUrl;
    _cccdCtrl = TextEditingController(text: _cccd);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _cccdCtrl.dispose();
    super.dispose();
  }

  void _handleAutoLeave() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [FaIcon(FontAwesomeIcons.rightFromBracket, color: AppColors.error), SizedBox(width: 8), Text('Tự động nghỉ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
        content: const Text('Bạn có chắc muốn gửi yêu cầu thôi việc khỏi hệ thống? Hành động này sẽ đăng xuất tài khoản của bạn.', style: TextStyle(fontSize: 13, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              Navigator.pop(ctx);
              final current = UserScope.currentUser(context);
              if (current != null) {
                await EmployeeRepository().leaveJob(current.id).catchError((_) {});
                if (!mounted) return;
                UserScope.setUser(context, null);
              }
              await AuthRepository().logout().catchError((_) {});
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: AppColors.error, content: Text('✅ Đã xác nhận — bạn đã đăng xuất khỏi hệ thống.')));
              Navigator.pop(context);
            },
            child: const Text('Xác nhận nghỉ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleEdit() async {
    if (_isEditing) {
      // Lưu qua API thật với await/try-catch đàng hoàng.
      final current = UserScope.currentUser(context);
      final newPhone = _phoneCtrl.text.trim();
      final newName = _nameCtrl.text.trim();
      setState(() {
        _cccd = _cccdCtrl.text.trim();
        _isEditing = false;
      });
      if (current != null) {
        try {
          await EmployeeRepository().updateEmployee(current.id, {
            if (newName.isNotEmpty) 'name': newName,
            if (newPhone.isNotEmpty) 'phone': newPhone,
            'cccd': _cccd,
            if (_avatarUrl != null) 'avatarUrl': _avatarUrl,
            if (_cccdFrontUrl != null) 'cccdFrontUrl': _cccdFrontUrl,
            if (_cccdBackUrl != null) 'cccdBackUrl': _cccdBackUrl,
          });
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: AppColors.success, content: Text('✅ Đã lưu thông tin cá nhân')));
        } catch (_) {
          if (!mounted) return;
          setState(() => _isEditing = true);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: AppColors.error, content: Text('❌ Lưu thất bại, vui lòng thử lại')));
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: AppColors.error, content: Text('❌ Không xác định được người dùng')));
      }
    } else {
      setState(() => _isEditing = true);
    }
  }

  Future<void> _pickAndUploadPhoto({
    required String title,
    required String folder,
    required ValueChanged<String> onUploaded,
  }) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
                title: const Text('Chụp ảnh từ máy ảnh (Camera)'),
                onTap: () => Navigator.pop(modalCtx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
                title: const Text('Chọn ảnh từ thư viện (Gallery)'),
                onTap: () => Navigator.pop(modalCtx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                SizedBox(width: 12),
                Text('Đang tải ảnh lên Cloudinary...'),
              ],
            ),
            duration: Duration(seconds: 4),
          ),
        );
      }
      final url = await UploadService().pickAndUploadImage(source: source, folder: folder);
      if (url != null && mounted) {
        onUploaded(url);
        final current = UserScope.currentUser(context);
        if (current != null) {
          await EmployeeRepository().updateEmployee(current.id, {
            if (_avatarUrl != null) 'avatarUrl': _avatarUrl,
            if (_cccdFrontUrl != null) 'cccdFrontUrl': _cccdFrontUrl,
            if (_cccdBackUrl != null) 'cccdBackUrl': _cccdBackUrl,
          }).catchError((_) => <String, dynamic>{});
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.success,
            content: Text('✓ Tải ảnh lên Cloudinary thành công!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải ảnh: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Thông tin cá nhân'),
        actions: [
          PopupMenuButton<String>(
            icon: const FaIcon(FontAwesomeIcons.ellipsisVertical, color: AppColors.textPrimary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (v) {
              if (v == 'edit') _toggleEdit();
              if (v == 'leave') _handleAutoLeave();
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'edit', child: Row(children: [FaIcon(_isEditing ? FontAwesomeIcons.floppyDisk : FontAwesomeIcons.penToSquare, size: 18, color: AppColors.primary), const SizedBox(width: 10), Text(_isEditing ? 'Lưu' : 'Sửa')])),
              const PopupMenuItem(value: 'leave', child: Row(children: [FaIcon(FontAwesomeIcons.rightFromBracket, size: 18, color: AppColors.error), SizedBox(width: 10), Text('Tự động nghỉ', style: TextStyle(color: AppColors.error))])),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
            child: Row(children: [
              GestureDetector(
                onTap: () => _pickAndUploadPhoto(
                  title: 'Cập nhật ảnh đại diện',
                  folder: 'hrm/avatars',
                  onUploaded: (url) => setState(() => _avatarUrl = url),
                ),
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                      backgroundImage: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                          ? NetworkImage(_avatarUrl!)
                          : null,
                      child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                          ? FaIcon(widget.isManager ? FontAwesomeIcons.userShield : FontAwesomeIcons.person, color: AppColors.primary, size: 32)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_nameCtrl.text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(widget.email, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20)), child: Text(BranchScope.label(context), style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold))),
              ])),
            ]),
          ),
          const SizedBox(height: 16),
          _groupTitle('Hồ sơ cá nhân', FontAwesomeIcons.user),
          _card(children: [
            _editableRow('Họ và tên', _nameCtrl, FontAwesomeIcons.user, enabled: _isEditing),
            _divider(),
            _row('Ngày sinh', _birthDate, FontAwesomeIcons.cakeCandles, onTap: _isEditing ? () async { final d = await showDatePicker(context: context, initialDate: DateTime(1998, 3, 15), firstDate: DateTime(1950), lastDate: DateTime.now()); if (d != null) setState(() => _birthDate = '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}'); } : null),
            _divider(),
            _row('Giới tính', _gender, FontAwesomeIcons.restroom),
            _divider(),
            _editableRow('Số điện thoại', _phoneCtrl, FontAwesomeIcons.phone, enabled: _isEditing),
            _divider(),
            _row('Email', widget.email, FontAwesomeIcons.envelope),
          ]),
          const SizedBox(height: 14),
          _groupTitle('Địa chỉ hiện tại', FontAwesomeIcons.house),
          _card(children: [
            _row('Tỉnh/ Thành phố', _province, FontAwesomeIcons.city),
            _divider(),
            _row('Xã/ Phường', _ward, FontAwesomeIcons.locationDot),
            _divider(),
            _row('Số nhà/ Tên đường', _street, FontAwesomeIcons.signsPost),
          ]),
          const SizedBox(height: 14),
          _groupTitle('Thông tin ngân hàng', FontAwesomeIcons.buildingColumns),
          _card(children: [
            _row('Số tài khoản', _bankAcc, FontAwesomeIcons.creditCard),
            _divider(),
            _row('Tên ngân hàng', _bankName, FontAwesomeIcons.wallet),
          ]),
          const SizedBox(height: 14),
          _groupTitle('Thông tin CCCD', FontAwesomeIcons.idCard),
          _card(children: [
            _editableRow('Số CCCD', _cccdCtrl, FontAwesomeIcons.idCard, enabled: _isEditing),
            _divider(),
            _row('Ngày cấp', _issueDate, FontAwesomeIcons.calendarDays, onTap: _isEditing ? () async { final d = await showDatePicker(context: context, initialDate: DateTime(2021, 5, 20), firstDate: DateTime(2000), lastDate: DateTime.now()); if (d != null) setState(() => _issueDate = '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}'); } : null),
            _divider(),
            _row('Nơi cấp', _issuePlace, FontAwesomeIcons.locationDot),
            _divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                const FaIcon(FontAwesomeIcons.image, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 10),
                const Expanded(child: Text('Ảnh CCCD', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
                const SizedBox(width: 10),
                _cccdThumb('Mặt trước', _cccdFrontUrl, () {
                  _pickAndUploadPhoto(
                    title: 'Tải ảnh CCCD mặt trước',
                    folder: 'hrm/cccd',
                    onUploaded: (url) => setState(() => _cccdFrontUrl = url),
                  );
                }),
                const SizedBox(width: 8),
                _cccdThumb('Mặt sau', _cccdBackUrl, () {
                  _pickAndUploadPhoto(
                    title: 'Tải ảnh CCCD mặt sau',
                    folder: 'hrm/cccd',
                    onUploaded: (url) => setState(() => _cccdBackUrl = url),
                  );
                }),
              ]),
            ),
          ]),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _groupTitle(String title, FaIconData icon) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Row(children: [Container(width: 3, height: 14, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))), const SizedBox(width: 8), FaIcon(icon, size: 14, color: AppColors.primary), const SizedBox(width: 6), Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary))]),
      );

  Widget _card({required List<Widget> children}) => Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)), child: Column(children: children));

  Widget _row(String label, String value, FaIconData icon, {VoidCallback? onTap}) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            FaIcon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
            Expanded(
                child: Text(value.isEmpty ? 'Chưa cập nhật' : value,
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontStyle: value.isEmpty ? FontStyle.italic : FontStyle.normal, color: value.isEmpty ? Colors.grey.shade500 : AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis)),
            if (onTap != null) const Padding(padding: EdgeInsets.only(left: 6), child: FaIcon(FontAwesomeIcons.chevronRight, size: 16, color: AppColors.textSecondary)),
          ]),
        ),
      );

  Widget _editableRow(String label, TextEditingController ctrl, FaIconData icon, {bool enabled = false}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          FaIcon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
          Expanded(child: enabled ? TextField(controller: ctrl, textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero)) : Text(ctrl.text, textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
        ]),
      );

  Widget _divider() => Divider(height: 1, indent: 46, color: Colors.grey.shade200);

  Widget _cccdThumb(String label, String? url, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 70,
          height: 48,
          decoration: BoxDecoration(
            color: (url != null && url.isNotEmpty) ? Colors.transparent : Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: (url != null && url.isNotEmpty) ? AppColors.primary : Colors.green.shade200),
          ),
          clipBehavior: Clip.antiAlias,
          child: (url != null && url.isNotEmpty)
              ? Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 18, color: Colors.grey)),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const FaIcon(FontAwesomeIcons.camera, size: 14, color: Colors.green),
                    const SizedBox(height: 2),
                    Text(label, style: const TextStyle(fontSize: 9, color: Colors.green, fontWeight: FontWeight.w600)),
                  ],
                ),
        ),
      );
}

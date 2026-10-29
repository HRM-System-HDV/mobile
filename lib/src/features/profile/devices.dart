import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/constants/colors.dart';
import '../../core/models/device_session.dart';
import '../auth/auth_repository.dart';

class LoggedInDevicesScreen extends StatefulWidget {
  const LoggedInDevicesScreen({super.key});

  @override
  State<LoggedInDevicesScreen> createState() => _LoggedInDevicesScreenState();
}

class _LoggedInDevicesScreenState extends State<LoggedInDevicesScreen> {
  final AuthRepository _authRepo = AuthRepository();
  List<DeviceSession> _devices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() => _isLoading = true);
    try {
      final items = await _authRepo.getDevices();
      if (mounted) setState(() => _devices = items);
    } catch (_) {
      // Giữ danh sách hiện có khi API bận
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  FaIconData _getDeviceIcon(String type) {
    switch (type) {
      case 'tablet':
        return FontAwesomeIcons.tabletScreenButton;
      case 'desktop':
        return FontAwesomeIcons.laptop;
      case 'phone':
      default:
        return FontAwesomeIcons.mobileScreen;
    }
  }

  Future<void> _logoutDevice(DeviceSession device) async {
    try {
      await _authRepo.revokeDevice(device.id);
      if (!mounted) return;
      setState(() {
        _devices.removeWhere((d) => d.id == device.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          content: Text('✅ Đã đăng xuất tài khoản khỏi "${device.deviceName}"'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Không thể đăng xuất thiết bị. Vui lòng thử lại sau.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _logoutAllOtherDevices() async {
    final otherDevices = _devices.where((d) => !d.isCurrent).toList();
    if (otherDevices.isEmpty) return;

    try {
      for (final d in otherDevices) {
        await _authRepo.revokeDevice(d.id);
      }
      if (!mounted) return;
      setState(() {
        _devices.removeWhere((d) => !d.isCurrent);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          content: Text('✅ Đã đăng xuất khỏi ${otherDevices.length} thiết bị khác thành công!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Có lỗi xảy ra khi gỡ các thiết bị.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentDevice = _devices.where((d) => d.isCurrent).toList();
    final otherDevices = _devices.where((d) => !d.isCurrent).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Thiết bị đã đăng nhập'),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const FaIcon(FontAwesomeIcons.chevronLeft, size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadDevices,
              color: AppColors.primary,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Mục: Thiết bị hiện tại
                  if (currentDevice.isNotEmpty) ...[
                    const Text(
                      'Thiết bị này',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    _buildDeviceCard(currentDevice.first),
                    const SizedBox(height: 20),
                  ],

                  // Mục: Các thiết bị khác
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Thiết bị khác (${otherDevices.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                      ),
                      if (otherDevices.isNotEmpty)
                        TextButton.icon(
                          onPressed: _logoutAllOtherDevices,
                          icon: const FaIcon(FontAwesomeIcons.rightFromBracket, size: 16, color: Colors.red),
                          label: const Text(
                            'Đăng xuất tất cả',
                            style: TextStyle(color: Colors.red, fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (otherDevices.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          FaIcon(FontAwesomeIcons.userShield, size: 48, color: AppColors.success.withValues(alpha: 0.8)),
                          const SizedBox(height: 12),
                          const Text(
                            'Không có thiết bị lạ nào khác',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Tài khoản của bạn chỉ đang đăng nhập trên thiết bị này.',
                            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    ...otherDevices.map((dev) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildDeviceCard(dev),
                        )),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildDeviceCard(DeviceSession device) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: device.isCurrent ? AppColors.primary.withValues(alpha: 0.3) : Colors.grey.shade200,
          width: device.isCurrent ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: device.isCurrent
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: FaIcon(
                  _getDeviceIcon(device.deviceType),
                  color: device.isCurrent ? AppColors.primary : Colors.grey.shade700,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            device.deviceName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (device.isCurrent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Thiết bị này',
                              style: TextStyle(
                                color: AppColors.success,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      device.osInfo,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (!device.isCurrent)
                IconButton(
                  icon: const FaIcon(FontAwesomeIcons.rightFromBracket, color: Colors.red, size: 22),
                  tooltip: 'Đăng xuất thiết bị này',
                  onPressed: () => _logoutDevice(device),
                ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              const FaIcon(FontAwesomeIcons.locationDot, size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  device.location,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              const FaIcon(FontAwesomeIcons.clock, size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                device.lastActive,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: device.isCurrent ? FontWeight.bold : FontWeight.normal,
                  color: device.isCurrent ? AppColors.success : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

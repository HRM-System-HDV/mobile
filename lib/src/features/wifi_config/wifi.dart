import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/constants/colors.dart';
import '../../core/models/branch.dart';
import '../../core/models/user.dart';
import '../../core/network/api_client.dart';
import '../../core/state/branch_scope.dart';
import '../../core/state/user_scope.dart';
import '../../core/widgets/branch_selector.dart';
import '../profile/employee_repository.dart';
import 'wifi_config_repository.dart';

class WifiConfigScreen extends StatefulWidget {
  const WifiConfigScreen({super.key});

  @override
  State<WifiConfigScreen> createState() => _WifiConfigScreenState();
}

class _WifiEntry {
  // Gán lại sau khi tạo để lần lưu kế tiếp là UPDATE, không nhân bản bản ghi.
  String? apiId;
  final TextEditingController ssidController;
  final TextEditingController bssidController;
  bool enforceCheckIn;

  _WifiEntry({
    this.apiId,
    required this.ssidController,
    required this.bssidController,
    required this.enforceCheckIn,
  });
}

class _WifiConfigScreenState extends State<WifiConfigScreen> {
  final WifiConfigRepository _repo = WifiConfigRepository();
  final List<_WifiEntry> _entries = [];
  bool _isSaving = false;
  bool _isScanning = false;
  List<Map<String, dynamic>> _scannedNetworks = [];

  String? _loadedBranchId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Branch? branch = _targetBranch();
    if (branch == null) return;
    if (_loadedBranchId != branch.id) {
      _loadBranch(branch);
    }
  }

  /// Chi nhánh mà màn hình này thao tác trên đó.
  ///
  /// - Admin: theo scope đang chọn (đổi được, kể cả "Tất cả chi nhánh").
  /// - Manager/Staff: bị ghim cứng vào chi nhánh mà admin đã gán nên luôn dùng
  ///   `assignedBranchId`/`branchSlug` của chính họ, không phụ thuộc scope.
  Branch? _targetBranch() {
    final Branch? scope = BranchScope.selectedBranch(context);
    if (UserScope.isAdmin(context)) return scope;
    final UserModel? me = UserScope.currentUser(context);
    final String pinned = me?.assignedBranchId ?? me?.branchSlug ?? '';
    if (pinned.isNotEmpty) return branchById(pinned);
    return scope;
  }

  Future<void> _loadBranch(Branch branch) async {
    _loadedBranchId = branch.id;
    _disposeEntries();
    // Chỉ dùng config từ API thật; khởi rỗng để hiện empty state khi API rỗng.
    setState(() {});

    // Gọi API thật từ gateway/integration-service (4005)
    try {
      final remoteList = await _repo.getWifiConfigs(branch: branch.code);
      if (mounted && _loadedBranchId == branch.id) {
        _disposeEntries();
        for (final item in remoteList) {
          _entries.add(_WifiEntry(
            apiId: item.id,
            ssidController: TextEditingController(text: item.ssid),
            bssidController: TextEditingController(text: item.bssid),
            enforceCheckIn: item.status == 'hoạt động',
          ));
        }
        setState(() {});
      }
    } catch (e) {
      _showError(_errorText(e));
    }
  }

  String _errorText(Object e) =>
      e is ApiException ? e.message : 'Không kết nối được máy chủ, vui lòng thử lại.';

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ $message'),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _disposeEntries() {
    for (final entry in _entries) {
      entry.ssidController.dispose();
      entry.bssidController.dispose();
    }
    _entries.clear();
  }

  Future<void> _scanNearbyWifi() async {
    setState(() => _isScanning = true);
    try {
      final list = await _repo.scanNearbyWifi();
      if (!mounted) return;
      setState(() {
        _scannedNetworks = list;
        _isScanning = false;
      });
      _showScannedWifiModal();
    } catch (e) {
      if (mounted) setState(() => _isScanning = false);
      _showError(_errorText(e));
    }
  }

  void _showScannedWifiModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const FaIcon(FontAwesomeIcons.wifi, color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mạng Wi-Fi máy chủ đã lưu',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Chạm vào mạng để tự động điền SSID',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const FaIcon(FontAwesomeIcons.xmark, size: 18, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _scannedNetworks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FaIcon(FontAwesomeIcons.wifi, size: 40, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          const Text('Máy chủ chưa lưu mạng Wi-Fi nào',
                              style: TextStyle(color: AppColors.textSecondary)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: _scannedNetworks.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final net = _scannedNetworks[index];
                        final ssid = net['ssid']?.toString() ?? '';

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.wifi_rounded,
                                color: AppColors.primary,
                                size: 22,
                              ),
                            ),
                          ),
                          title: Text(
                            ssid,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                          ),
                          subtitle: const Text(
                            'SSID máy chủ đã lưu • chưa đo cường độ sóng',
                            style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Chọn',
                              style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            _applyScannedWifi(ssid);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _applyScannedWifi(String ssid) {
    if (_entries.isNotEmpty && _entries.first.ssidController.text.trim().isEmpty) {
      _entries.first.ssidController.text = ssid;
    } else {
      _entries.add(_WifiEntry(
        ssidController: TextEditingController(text: ssid),
        bssidController: TextEditingController(),
        enforceCheckIn: true,
      ));
    }
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã chọn mạng "$ssid"'),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _addNetwork() {
    setState(() {
      _entries.add(_WifiEntry(
        ssidController: TextEditingController(),
        bssidController: TextEditingController(),
        enforceCheckIn: true,
      ));
    });
  }

  Future<void> _removeNetwork(int index) async {
    final entry = _entries[index];
    if (entry.apiId != null) {
      try {
        await _repo.deleteWifiConfig(entry.apiId!);
      } catch (e) {
        _showError(_errorText(e));
        return;
      }
    }
    if (!mounted) return;
    entry.ssidController.dispose();
    entry.bssidController.dispose();
    setState(() => _entries.remove(entry));
  }

  Future<void> _saveConfig(Branch branch) async {
    // Chốt an toàn giống _showBranchPicker: gateway chỉ nhận lượt ghi từ admin.
    if (!UserScope.isAdmin(context)) return;
    final pending =
        _entries.where((e) => e.ssidController.text.trim().isNotEmpty).toList();
    if (pending.isEmpty) {
      _showError('Chưa có mạng Wi-Fi nào để lưu.');
      return;
    }
    for (final entry in pending) {
      if (entry.bssidController.text.trim().isEmpty) {
        _showError('Nhập BSSID cho mạng "${entry.ssidController.text.trim()}" trước khi lưu.');
        return;
      }
    }

    setState(() => _isSaving = true);
    var saved = 0;
    Object? firstError;
    for (final entry in pending) {
      final ssid = entry.ssidController.text.trim();
      final bssid = entry.bssidController.text.trim();
      // Backend chỉ chấp nhận "hoạt động" | "vô hiệu hóa".
      final status = entry.enforceCheckIn ? 'hoạt động' : 'vô hiệu hóa';
      try {
        if (entry.apiId != null) {
          await _repo.updateWifiConfig(entry.apiId!, {
            'ssid': ssid,
            'bssid': bssid,
            'branch': branch.code,
            'status': status,
          });
        } else {
          final created = await _repo.createWifiConfig(
            ssid: ssid,
            bssid: bssid,
            branch: branch.code,
            status: status,
          );
          entry.apiId = created.id;
        }
        saved++;
      } catch (e) {
        firstError ??= e;
      }
    }
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (firstError != null) {
      _showError('Chỉ lưu được $saved/${pending.length} mạng. ${_errorText(firstError)}');
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã lưu cấu hình Wi-Fi cho ${branch.name}!'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showBranchPicker() {
    // Chỉ Admin được đổi scope chi nhánh; Manager bị ghim vào chi nhánh được gán.
    if (!UserScope.isAdmin(context)) return;
    final current = BranchScope.selectedBranch(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: FutureBuilder<List<Branch>>(
          future: EmployeeRepository().getBranches(),
          initialData: branches.isNotEmpty ? branches : null,
          builder: (ctx, snap) {
            final branchList = snap.data ?? branches;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Text(
                    'Chọn chi nhánh để cấu hình Wi-Fi',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ),
                if (snap.connectionState == ConnectionState.waiting && branchList.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  )
                else if (branchList.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(
                      child: Text(
                        'Chưa có chi nhánh nào',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                else
                  for (final branch in branchList)
                    InkWell(
                      onTap: () {
                        BranchScope.select(context, branch);
                        Navigator.pop(sheetContext);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        child: Row(
                          children: [
                            FaIcon(
                              FontAwesomeIcons.store,
                              color: current?.id == branch.id ? AppColors.primary : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    branch.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: current?.id == branch.id ? AppColors.primary : AppColors.textPrimary,
                                    ),
                                  ),
                                  if (branch.address.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(branch.address, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                  ],
                                ],
                              ),
                            ),
                            if (current?.id == branch.id) const FaIcon(FontAwesomeIcons.check, color: AppColors.primary),
                          ],
                        ),
                      ),
                    ),
                const SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _disposeEntries();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = UserScope.isAdmin(context);
    final String pageTitle = isAdmin ? 'Cấu hình Wi-Fi' : 'Wi-Fi chi nhánh';
    final Branch? branch = _targetBranch();
    final bool isAll = branch == null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          pageTitle,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const FaIcon(FontAwesomeIcons.chevronLeft, size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: const [
          BranchSelector(includeAll: false),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isAll)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  const FaIcon(FontAwesomeIcons.wifi, size: 40, color: AppColors.textSecondary),
                  const SizedBox(height: 10),
                  const Text(
                    'Cấu hình Wi-Fi là theo từng chi nhánh',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    // Manager/Staff không có quyền đổi scope nên không hiện nút chọn.
                    isAdmin
                        ? 'Vui lòng dùng nút cửa hàng trên góc phải để chọn một chi nhánh cụ thể trước khi chỉnh sửa.'
                        : 'Tài khoản của bạn chưa được gán chi nhánh nào, liên hệ Quản trị viên để được gán chi nhánh.',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                  if (isAdmin) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _showBranchPicker,
                      icon: const FaIcon(FontAwesomeIcons.store, size: 18),
                      label: const Text('Chọn chi nhánh'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                      ),
                    ),
                  ],
                ],
              ),
            )
          else ...[
            // Luật 12/11: ẩn hẳn thanh "Chi nhánh của bạn" với vai trò bị ghim
            // (tên chi nhánh chỉ hiển thị ở tab "Cá nhân"). Việc đọc/ghi vẫn
            // dùng `_targetBranch()` (ghim theo assignedBranchId), payload không đổi.
            // Gateway chỉ mở quyền ghi (POST/PUT/DELETE /api/wifi-configs) cho
            // admin, nên Manager/Staff xem ở chế độ đọc để không bấm rồi nhận 403.
            _buildConfigForm(branch, canEdit: isAdmin),
          ],
        ],
      ),
    );
  }

  Widget _buildConfigForm(Branch branch, {required bool canEdit}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < _entries.length; i++)
          _buildNetworkCard(_entries[i], i, canEdit: canEdit),
        const SizedBox(height: 12),

        if (canEdit) ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _addNetwork,
                  icon: const FaIcon(FontAwesomeIcons.plus, size: 15),
                  label: const Text(
                    'Thêm thủ công',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isScanning ? null : _scanNearbyWifi,
                  icon: _isScanning
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const FaIcon(FontAwesomeIcons.wifi, size: 15),
                  label: const Text(
                    'Quét mạng quanh đây',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSaving ? null : () => _saveConfig(branch),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text(
                      'Lưu cấu hình Wi-Fi',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ] else
          _buildReadonlyHint(),
      ],
    );
  }

  /// Dòng nhắc quyền cho Manager/Staff: chỉ được xem, việc đổi cấu hình Wi-Fi
  /// do Quản trị viên thực hiện (gateway chặn mọi lượt ghi ngoài admin).
  Widget _buildReadonlyHint() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          FaIcon(FontAwesomeIcons.lock, size: 16, color: Colors.amber.shade800),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Chỉ Quản trị viên mới được thay đổi cấu hình Wi-Fi. '
              'Bạn chỉ có thể xem cấu hình hiện tại của chi nhánh.',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkCard(_WifiEntry entry, int index, {required bool canEdit}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Mạng ${index + 1}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const Spacer(),
              // Nút xóa gọi DELETE /api/wifi-configs/:id nên chỉ admin thấy được.
              if (_entries.length > 1 && canEdit)
                IconButton(
                  icon: const FaIcon(FontAwesomeIcons.trashCan, color: AppColors.error, size: 20),
                  tooltip: 'Xóa mạng',
                  onPressed: () => _removeNetwork(index),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: entry.ssidController,
            readOnly: !canEdit,
            decoration: InputDecoration(
              labelText: 'Tên mạng (SSID)',
              prefixIcon: const Icon(Icons.wifi_rounded, color: AppColors.primary, size: 22),
              hintText: 'Ví dụ: HRM_OFFICE_01',
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: entry.bssidController,
            keyboardType: TextInputType.text,
            autocorrect: false,
            readOnly: !canEdit,
            decoration: InputDecoration(
              labelText: 'Địa chỉ BSSID (MAC của điểm phát)',
              prefixIcon: const Icon(Icons.router_outlined, color: AppColors.primary, size: 22),
              hintText: 'Ví dụ: AC:84:C6:12:34:56',
              helperText: 'Dùng để xác thực đúng router của chi nhánh khi chấm công',
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bắt buộc dùng mạng này để chấm công',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Nhân viên chỉ chấm công được khi kết nối đúng Wi-Fi chi nhánh',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: entry.enforceCheckIn,
                activeTrackColor: AppColors.primary,
                // onChanged = null: switch chỉ bật/tắt được với admin.
                onChanged: canEdit
                    ? (value) => setState(() => entry.enforceCheckIn = value)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
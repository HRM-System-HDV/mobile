/// Model phiên thiết bị đăng nhập của người dùng.
class DeviceSession {
  final String id;
  final String deviceName;
  final String deviceType; // 'phone', 'tablet', 'desktop'
  final String osInfo;
  final String location;
  final String ipAddress;
  final String lastActive;
  final bool isCurrent;

  const DeviceSession({
    required this.id,
    required this.deviceName,
    required this.deviceType,
    required this.osInfo,
    required this.location,
    required this.ipAddress,
    required this.lastActive,
    this.isCurrent = false,
  });

  factory DeviceSession.fromJson(Map<String, dynamic> j) {
    return DeviceSession(
      id: j['id']?.toString() ?? '',
      deviceName: j['deviceName']?.toString() ?? 'Thiết bị',
      deviceType: j['deviceType']?.toString() ?? 'phone',
      osInfo: j['osInfo']?.toString() ?? '',
      location: j['location']?.toString() ?? 'Việt Nam',
      ipAddress: j['ipAddress']?.toString() ?? '',
      lastActive: j['lastActive']?.toString() ?? 'Vừa xong',
      isCurrent: j['isCurrent'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'deviceName': deviceName,
        'deviceType': deviceType,
        'osInfo': osInfo,
        'location': location,
        'ipAddress': ipAddress,
        'lastActive': lastActive,
        'isCurrent': isCurrent,
      };
}

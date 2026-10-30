/// Presentation-only personalization. Never contains identity, role or tokens.
class LocalProfile {
  const LocalProfile({
    required this.fullName,
    this.phone = '',
    this.address = '',
    this.avatarFileName,
  });
  final String fullName;
  final String phone;
  final String address;
  final String? avatarFileName;
  Map<String, dynamic> toJson() => {
    'fullName': fullName,
    'phone': phone,
    'address': address,
    'avatarFileName': avatarFileName,
  };
  factory LocalProfile.fromJson(Map<String, dynamic> json) {
    if (json['fullName'] is! String ||
        (json['fullName'] as String).trim().isEmpty ||
        json['phone'] is! String ||
        json['address'] is! String ||
        (json['avatarFileName'] != null && json['avatarFileName'] is! String)) {
      throw const FormatException('Invalid local profile');
    }
    return LocalProfile(
      fullName: json['fullName'] as String,
      phone: json['phone'] as String,
      address: json['address'] as String,
      avatarFileName: json['avatarFileName'] as String?,
    );
  }
}

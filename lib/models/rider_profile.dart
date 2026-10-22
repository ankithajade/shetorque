/// Rider profile model encapsulating rider identity, contact, emergency contacts
/// and medical information.
class RiderProfile {
  String name;
  String email;
  String phone;
  String emergencyContactName;
  String emergencyContactPhone;
  String bloodGroup;
  String address;

  RiderProfile({
    this.name = 'Ananya Sharma',
    this.email = 'ananya.rider@shetorque.io',
    this.phone = '+91 98765 43210',
    this.emergencyContactName = 'Sneha Sharma (Sister)',
    this.emergencyContactPhone = '+91 63608 26795',
    this.bloodGroup = 'O+',
    this.address = '42, Lavender Bough, Indiranagar, Bengaluru, KA',
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'phone': phone,
        'emergencyContactName': emergencyContactName,
        'emergencyContactPhone': emergencyContactPhone,
        'bloodGroup': bloodGroup,
        'address': address,
      };

  factory RiderProfile.fromJson(Map<String, dynamic> json) => RiderProfile(
        name: json['name'] as String? ?? 'Ananya Sharma',
        email: json['email'] as String? ?? 'ananya.rider@shetorque.io',
        phone: json['phone'] as String? ?? '+91 98765 43210',
        emergencyContactName:
            json['emergencyContactName'] as String? ?? 'Sneha Sharma (Sister)',
        emergencyContactPhone:
            json['emergencyContactPhone'] as String? ?? '+91 63608 26795',
        bloodGroup: json['bloodGroup'] as String? ?? 'O+',
        address: json['address'] as String? ??
            '42, Lavender Bough, Indiranagar, Bengaluru, KA',
      );

  RiderProfile copyWith({
    String? name,
    String? email,
    String? phone,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? bloodGroup,
    String? address,
  }) {
    return RiderProfile(
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      emergencyContactName:
          emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone:
          emergencyContactPhone ?? this.emergencyContactPhone,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      address: address ?? this.address,
    );
  }
}

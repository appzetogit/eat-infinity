class DeliveryPartner {
  const DeliveryPartner({
    required this.id,
    required this.name,
    required this.phone,
    required this.status,
    this.email,
    this.countryCode,
    this.address,
    this.city,
    this.state,
    this.vehicleType,
    this.vehicleName,
    this.vehicleNumber,
    this.panNumber,
    this.aadharNumber,
    this.drivingLicenseNumber,
    this.profilePhoto,
    this.aadharPhoto,
    this.panPhoto,
    this.drivingLicensePhoto,
    this.rejectionReason,
    this.bankAccountHolderName,
    this.bankAccountNumber,
    this.bankIfscCode,
    this.bankName,
    this.upiId,
    this.upiQrCode,
    this.availabilityStatus,
    this.lastLat,
    this.lastLng,
    this.referralCode,
    this.referralCount,
    this.rating,
    this.totalRatings,
  });

  final String id;
  final String name;
  final String phone;
  final String status; // pending | approved | rejected | deactivated
  final String? email;
  final String? countryCode;
  final String? address;
  final String? city;
  final String? state;
  final String? vehicleType;
  final String? vehicleName;
  final String? vehicleNumber;
  final String? panNumber;
  final String? aadharNumber;
  final String? drivingLicenseNumber;
  final String? profilePhoto;
  final String? aadharPhoto;
  final String? panPhoto;
  final String? drivingLicensePhoto;
  final String? rejectionReason;
  final String? bankAccountHolderName;
  final String? bankAccountNumber;
  final String? bankIfscCode;
  final String? bankName;
  final String? upiId;
  final String? upiQrCode;
  final String? availabilityStatus;
  final double? lastLat;
  final double? lastLng;
  final String? referralCode;
  final int? referralCount;
  final double? rating;
  final int? totalRatings;

  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isPending => status == 'pending';
  bool get isDeactivated => status == 'deactivated';
  bool get isOnline => availabilityStatus == 'online';

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim());
    return null;
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }

  static String? _str(dynamic v) {
    if (v == null) return null;
    return v.toString();
  }

  factory DeliveryPartner.fromJson(Map<String, dynamic> json) {
    return DeliveryPartner(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: _str(json['name']) ?? '',
      phone: _str(json['phone']) ?? '',
      status: _str(json['status']) ?? 'pending',
      email: _str(json['email']),
      countryCode: _str(json['countryCode']),
      address: _str(json['address']),
      city: _str(json['city']),
      state: _str(json['state']),
      vehicleType: _str(json['vehicleType']),
      vehicleName: _str(json['vehicleName']),
      vehicleNumber: _str(json['vehicleNumber']),
      panNumber: _str(json['panNumber']),
      aadharNumber: _str(json['aadharNumber']),
      drivingLicenseNumber: _str(json['drivingLicenseNumber']),
      profilePhoto: _str(json['profilePhoto']),
      aadharPhoto: _str(json['aadharPhoto']),
      panPhoto: _str(json['panPhoto']),
      drivingLicensePhoto: _str(json['drivingLicensePhoto']),
      rejectionReason: _str(json['rejectionReason']),
      bankAccountHolderName: _str(json['bankAccountHolderName']),
      bankAccountNumber: _str(json['bankAccountNumber']),
      bankIfscCode: _str(json['bankIfscCode']),
      bankName: _str(json['bankName']),
      upiId: _str(json['upiId']),
      upiQrCode: _str(json['upiQrCode']),
      availabilityStatus: _str(json['availabilityStatus']),
      lastLat: _toDouble(json['lastLat']),
      lastLng: _toDouble(json['lastLng']),
      referralCode: _str(json['referralCode']),
      referralCount: _toInt(json['referralCount']),
      rating: _toDouble(json['rating']),
      totalRatings: _toInt(json['totalRatings']),
    );
  }

  DeliveryPartner copyWith({String? availabilityStatus}) {
    return DeliveryPartner(
      id: id,
      name: name,
      phone: phone,
      status: status,
      email: email,
      countryCode: countryCode,
      address: address,
      city: city,
      state: state,
      vehicleType: vehicleType,
      vehicleName: vehicleName,
      vehicleNumber: vehicleNumber,
      panNumber: panNumber,
      aadharNumber: aadharNumber,
      drivingLicenseNumber: drivingLicenseNumber,
      profilePhoto: profilePhoto,
      aadharPhoto: aadharPhoto,
      panPhoto: panPhoto,
      drivingLicensePhoto: drivingLicensePhoto,
      rejectionReason: rejectionReason,
      bankAccountHolderName: bankAccountHolderName,
      bankAccountNumber: bankAccountNumber,
      bankIfscCode: bankIfscCode,
      bankName: bankName,
      upiId: upiId,
      upiQrCode: upiQrCode,
      availabilityStatus: availabilityStatus ?? this.availabilityStatus,
      lastLat: lastLat,
      lastLng: lastLng,
      referralCode: referralCode,
      referralCount: referralCount,
      rating: rating,
      totalRatings: totalRatings,
    );
  }
}

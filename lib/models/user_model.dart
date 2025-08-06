class User {
  final String id;
  final String name;
  final String email;
  final String phone;
  final DateTime dateOfBirth;
  final String gender;
  final Address? address;
  final EmergencyContact? emergencyContact;
  final List<MedicalHistory> medicalHistory;
  final String? currentIllness;
  final DateTime? lastVisit;
  final List<Note> notes;
  final String? fcmToken;
  final String username;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.dateOfBirth,
    required this.gender,
    this.address,
    this.emergencyContact,
    this.medicalHistory = const [],
    this.currentIllness,
    this.lastVisit,
    this.notes = const [],
    this.fcmToken,
    required this.username,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      dateOfBirth: DateTime.parse(json['dateOfBirth']),
      gender: json['gender'] ?? '',
      address:
          json['address'] != null ? Address.fromJson(json['address']) : null,
      emergencyContact:
          json['emergencyContact'] != null
              ? EmergencyContact.fromJson(json['emergencyContact'])
              : null,
      medicalHistory:
          (json['medicalHistory'] as List<dynamic>?)
              ?.map((item) => MedicalHistory.fromJson(item))
              .toList() ??
          [],
      currentIllness: json['currentIllness'],
      lastVisit:
          json['lastVisit'] != null ? DateTime.parse(json['lastVisit']) : null,
      notes:
          (json['notes'] as List<dynamic>?)
              ?.map((item) => Note.fromJson(item))
              .toList() ??
          [],
      fcmToken: json['fcmToken'],
      username: json['username'] ?? '',
    );
  }
}

class Address {
  final String? street;
  final String? city;
  final String? state;
  final String? zipCode;

  Address({this.street, this.city, this.state, this.zipCode});

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      street: json['street'],
      city: json['city'],
      state: json['state'],
      zipCode: json['zipCode'],
    );
  }
}

class EmergencyContact {
  final String? name;
  final String? phone;
  final String? relationship;

  EmergencyContact({this.name, this.phone, this.relationship});

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      name: json['name'],
      phone: json['phone'],
      relationship: json['relationship'],
    );
  }
}

class MedicalHistory {
  final String? condition;
  final DateTime? diagnosedDate;
  final String status;

  MedicalHistory({this.condition, this.diagnosedDate, this.status = 'Active'});

  factory MedicalHistory.fromJson(Map<String, dynamic> json) {
    return MedicalHistory(
      condition: json['condition'],
      diagnosedDate:
          json['diagnosedDate'] != null
              ? DateTime.parse(json['diagnosedDate'])
              : null,
      status: json['status'] ?? 'Active',
    );
  }
}

class Note {
  final String? content;
  final DateTime date;
  final String? doctor;

  Note({this.content, required this.date, this.doctor});

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      content: json['content'],
      date: DateTime.parse(json['date']),
      doctor: json['doctor'],
    );
  }
}

class LoginResponse {
  final bool success;
  final String message;
  final User? user;
  final String? token;

  LoginResponse({
    required this.success,
    required this.message,
    this.user,
    this.token,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      token: json['token'],
    );
  }
}

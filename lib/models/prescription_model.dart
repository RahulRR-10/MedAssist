import 'dart:convert';

class PrescriptionData {
  final String patientId;
  final String diagnosis;
  final String symptom;
  final List<Medication> medications;
  final DateTime followUpDate;
  final String notes;
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;

  PrescriptionData({
    required this.patientId,
    required this.diagnosis,
    required this.symptom,
    required this.medications,
    required this.followUpDate,
    required this.notes,
    required this.id,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PrescriptionData.fromJson(Map<String, dynamic> json) {
    try {
      print('📋 Parsing prescription from JSON...');
      print('JSON keys: ${json.keys}');

      final patientId = json['patientId'] as String?;
      final diagnosis = json['diagnosis'] as String?;
      final symptom = json['symptom'] as String?;
      final notes = json['notes'] as String?;
      final id = json['_id'] as String?;

      print('📋 Field values:');
      print('   patientId: $patientId');
      print('   diagnosis: $diagnosis');
      print('   symptom: $symptom');
      print('   notes: $notes');
      print('   id: $id');

      if (patientId == null) throw Exception('patientId is null');
      if (diagnosis == null) throw Exception('diagnosis is null');
      if (symptom == null) throw Exception('symptom is null');
      if (notes == null) throw Exception('notes is null');
      if (id == null) throw Exception('id is null');

      return PrescriptionData(
        patientId: patientId,
        diagnosis: diagnosis,
        symptom: symptom,
        medications:
            (json['medications'] as List)
                .map((e) => Medication.fromJson(e as Map<String, dynamic>))
                .toList(),
        followUpDate: DateTime.parse(json['followUpDate'] as String),
        notes: notes,
        id: id,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
    } catch (e, stackTrace) {
      print('❌ Error in fromJson: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  factory PrescriptionData.fromFCM(Map<String, dynamic> data) {
    try {
      print('📋 Parsing FCM prescription data...');
      print('FCM data keys: ${data.keys}');

      final prescriptionDataString = data['prescriptionData'];
      if (prescriptionDataString == null) {
        throw Exception('prescriptionData is null in FCM message');
      }

      print('📋 Prescription data string: $prescriptionDataString');
      final prescriptionJson = jsonDecode(prescriptionDataString);
      print('📋 Parsed JSON: $prescriptionJson');

      return PrescriptionData.fromJson(prescriptionJson);
    } catch (e, stackTrace) {
      print('❌ Error in fromFCM: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }
}

class Medication {
  final String name;
  final String beforeAfterFood;
  final List<Schedule> schedules;
  final String id;

  Medication({
    required this.name,
    required this.beforeAfterFood,
    required this.schedules,
    required this.id,
  });

  factory Medication.fromJson(Map<String, dynamic> json) {
    return Medication(
      name: json['name'] as String,
      beforeAfterFood: json['beforeAfterFood'] as String,
      schedules:
          (json['schedules'] as List)
              .map((e) => Schedule.fromJson(e as Map<String, dynamic>))
              .toList(),
      id: json['_id'] as String,
    );
  }
}

class Schedule {
  final DateTime startDate;
  final DateTime endDate;
  final String dosage;
  final List<String> times;
  final String id;

  Schedule({
    required this.startDate,
    required this.endDate,
    required this.dosage,
    required this.times,
    required this.id,
  });

  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      dosage: json['dosage'] as String,
      times: (json['times'] as List).map((e) => e as String).toList(),
      id: json['_id'] as String,
    );
  }
}

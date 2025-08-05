import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prescription_model.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String _prescriptionsKey = 'prescriptions';

  Future<void> savePrescription(PrescriptionData prescription) async {
    final prescriptions = await getPrescriptions();

    // Always add as new prescription (for stacking on main screen)
    // Each prescription from web app should be treated as unique
    prescriptions.add(prescription);
    
    print('📋 Added new prescription: ${prescription.id}');
    print('📋 Total prescriptions now: ${prescriptions.length}');

    // Save to shared preferences
    await _savePrescriptionList(prescriptions);
  }

  Future<void> deletePrescription(String prescriptionId) async {
    final prescriptions = await getPrescriptions();
    
    // Remove prescription with matching ID
    prescriptions.removeWhere((prescription) => prescription.id == prescriptionId);
    
    print('📋 Deleted prescription: $prescriptionId');
    print('📋 Total prescriptions now: ${prescriptions.length}');

    // Save updated list to shared preferences
    await _savePrescriptionList(prescriptions);
  }  Future<List<PrescriptionData>> getPrescriptions() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw Exception('SharedPreferences timeout');
        },
      );

      final prescriptionsJson = prefs.getStringList(_prescriptionsKey) ?? [];

      return prescriptionsJson
          .map((json) {
            try {
              final Map<String, dynamic> data = jsonDecode(json);
              return PrescriptionData.fromJson(data);
            } catch (e) {
              // Skip invalid prescription data
              return null;
            }
          })
          .where((prescription) => prescription != null)
          .cast<PrescriptionData>()
          .toList();
    } catch (e) {
      // Return empty list if storage fails
      return [];
    }
  }

  Future<void> deletePrescription(String prescriptionId) async {
    final prescriptions = await getPrescriptions();
    final updatedPrescriptions =
        prescriptions.where((p) => p.id != prescriptionId).toList();
    await _savePrescriptionList(updatedPrescriptions);
  }

  Future<void> _savePrescriptionList(
    List<PrescriptionData> prescriptions,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    // Convert prescriptions to JSON strings
    final prescriptionsJson =
        prescriptions.map((prescription) {
          final Map<String, dynamic> data = {
            'patientId': prescription.patientId,
            'diagnosis': prescription.diagnosis,
            'symptom': prescription.symptom,
            'medications':
                prescription.medications
                    .map(
                      (medication) => {
                        'name': medication.name,
                        'beforeAfterFood': medication.beforeAfterFood,
                        'schedules':
                            medication.schedules
                                .map(
                                  (schedule) => {
                                    'startDate':
                                        schedule.startDate.toIso8601String(),
                                    'endDate':
                                        schedule.endDate.toIso8601String(),
                                    'dosage': schedule.dosage,
                                    'times': schedule.times,
                                    '_id': schedule.id,
                                  },
                                )
                                .toList(),
                        '_id': medication.id,
                      },
                    )
                    .toList(),
            'followUpDate': prescription.followUpDate.toIso8601String(),
            'notes': prescription.notes,
            '_id': prescription.id,
            'createdAt': prescription.createdAt.toIso8601String(),
            'updatedAt': prescription.updatedAt.toIso8601String(),
          };

          return jsonEncode(data);
        }).toList();

    await prefs.setStringList(_prescriptionsKey, prescriptionsJson);
  }
}

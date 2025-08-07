import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prescription_model.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String _prescriptionsKey = 'prescriptions';

  Future<void> savePrescription(PrescriptionData prescription) async {
    print(
      '💾 Storage: Saving prescription ${prescription.id} - ${prescription.diagnosis}',
    );
    final prescriptions = await getPrescriptions();
    print('💾 Storage: Current prescriptions count: ${prescriptions.length}');

    // Check if prescription already exists to prevent duplicates
    final existingIndex = prescriptions.indexWhere(
      (p) => p.id == prescription.id,
    );

    if (existingIndex != -1) {
      // Update existing prescription
      prescriptions[existingIndex] = prescription;
      print('📋 Updated existing prescription: ${prescription.id}');
    } else {
      // Add new prescription
      prescriptions.add(prescription);
      print('📋 Added new prescription: ${prescription.id}');
    }

    print('📋 Total prescriptions now: ${prescriptions.length}');

    // Save to shared preferences
    await _savePrescriptionList(prescriptions);
    print('💾 Storage: Saved successfully');
  }

  Future<List<PrescriptionData>> getPrescriptions() async {
    try {
      print('💾 Storage: Getting prescriptions from SharedPreferences...');
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw Exception('SharedPreferences timeout');
        },
      );

      final prescriptionsJson = prefs.getStringList(_prescriptionsKey) ?? [];
      print(
        '💾 Storage: Found ${prescriptionsJson.length} JSON strings in storage',
      );

      final prescriptions =
          prescriptionsJson
              .map((json) {
                try {
                  final Map<String, dynamic> data = jsonDecode(json);
                  return PrescriptionData.fromJson(data);
                } catch (e) {
                  print('💾 Storage: Error parsing JSON: $e');
                  print('💾 Storage: Invalid JSON: $json');
                  // Skip invalid prescription data
                  return null;
                }
              })
              .where((prescription) => prescription != null)
              .cast<PrescriptionData>()
              .toList();

      print(
        '💾 Storage: Successfully parsed ${prescriptions.length} prescriptions',
      );
      return prescriptions;
    } catch (e) {
      print('💾 Storage: Error getting prescriptions: $e');
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

  // Remove duplicate prescriptions based on ID
  Future<void> removeDuplicates() async {
    print('🧹 Storage: Removing duplicate prescriptions...');
    final prescriptions = await getPrescriptions();
    final seenIds = <String>{};
    final uniquePrescriptions = <PrescriptionData>[];

    for (final prescription in prescriptions) {
      if (!seenIds.contains(prescription.id)) {
        seenIds.add(prescription.id);
        uniquePrescriptions.add(prescription);
      } else {
        print(
          '🧹 Storage: Removing duplicate prescription: ${prescription.id} - ${prescription.diagnosis}',
        );
      }
    }

    if (uniquePrescriptions.length != prescriptions.length) {
      await _savePrescriptionList(uniquePrescriptions);
      print(
        '🧹 Storage: Removed ${prescriptions.length - uniquePrescriptions.length} duplicates',
      );
      print(
        '🧹 Storage: ${uniquePrescriptions.length} unique prescriptions remaining',
      );
    } else {
      print('🧹 Storage: No duplicates found');
    }
  }

  // Clear all prescriptions (for testing/debugging)
  Future<void> clearAllPrescriptions() async {
    print('🗑️ Storage: Clearing all prescriptions...');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prescriptionsKey);
    print('🗑️ Storage: All prescriptions cleared');
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

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../utils/logger.dart';

class PrescriptionSyncService {
  static final PrescriptionSyncService _instance =
      PrescriptionSyncService._internal();
  factory PrescriptionSyncService() => _instance;
  PrescriptionSyncService._internal();

  // Sync prescriptions from server
  Future<Map<String, dynamic>> syncPrescriptions(String token) async {
    try {
      AppLogger.info('Syncing prescriptions from server...');

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/prescriptions/sync'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        AppLogger.info('Prescriptions synced successfully');
        return {'success': true, 'data': data};
      } else {
        final errorData = json.decode(response.body);
        AppLogger.error('Failed to sync prescriptions: ${errorData['error']}');
        return {
          'success': false,
          'error': errorData['error'] ?? 'Unknown error',
        };
      }
    } catch (e) {
      AppLogger.error('Network error during prescription sync', e);
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // Get prescriptions from server
  Future<Map<String, dynamic>> getPrescriptions(String token) async {
    try {
      AppLogger.info('Getting prescriptions from server...');

      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/prescriptions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        AppLogger.info('Prescriptions retrieved successfully');
        return {
          'success': true,
          'prescriptions': data['prescriptions'] ?? [],
          'lastUpdated': data['lastUpdated'],
        };
      } else {
        final errorData = json.decode(response.body);
        AppLogger.error('Failed to get prescriptions: ${errorData['error']}');
        return {
          'success': false,
          'error': errorData['error'] ?? 'Unknown error',
        };
      }
    } catch (e) {
      AppLogger.error('Network error during prescription retrieval', e);
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // Convert server prescription format to local prescription format
  List<Map<String, dynamic>> convertServerPrescriptions(
    List<dynamic> serverPrescriptions, {
    String? patientId,
  }) {
    try {
      print(
        '🔄 Converting ${serverPrescriptions.length} server prescriptions...',
      );

      final converted =
          serverPrescriptions.map((prescription) {
            print('🔄 Converting prescription: $prescription');

            // Convert from server format to local PrescriptionData format
            final convertedPrescription = {
              '_id':
                  prescription['_id'] ??
                  DateTime.now().millisecondsSinceEpoch.toString(),
              'patientId':
                  patientId ??
                  'unknown_patient', // Use provided patientId or default
              'diagnosis': prescription['name'] ?? 'Unknown Medication',
              'symptom':
                  'As prescribed by doctor', // Default symptom since server doesn't provide
              'medications': [
                {
                  '_id':
                      prescription['_id'] ??
                      DateTime.now().millisecondsSinceEpoch.toString(),
                  'name': prescription['name'] ?? 'Unknown Medication',
                  'beforeAfterFood':
                      prescription['beforeAfterFood'] ?? 'Before',
                  'schedules':
                      (prescription['schedules'] as List? ?? []).map((
                        schedule,
                      ) {
                        return {
                          '_id':
                              schedule['_id'] ??
                              DateTime.now().millisecondsSinceEpoch.toString(),
                          'startDate':
                              schedule['startDate'] ??
                              DateTime.now().toIso8601String(),
                          'endDate':
                              schedule['endDate'] ??
                              DateTime.now()
                                  .add(Duration(days: 7))
                                  .toIso8601String(),
                          'dosage': schedule['dosage'] ?? '1 tablet',
                          'times': List<String>.from(
                            schedule['times'] ?? ['8:00 AM'],
                          ),
                        };
                      }).toList(),
                },
              ],
              'followUpDate':
                  DateTime.now().add(Duration(days: 7)).toIso8601String(),
              'notes': 'Synced from server',
              'createdAt': DateTime.now().toIso8601String(),
              'updatedAt': DateTime.now().toIso8601String(),
            };

            print('🔄 Converted prescription: $convertedPrescription');
            return convertedPrescription;
          }).toList();

      print('🔄 Successfully converted ${converted.length} prescriptions');
      return converted;
    } catch (e) {
      AppLogger.error('Error converting server prescriptions', e);
      print('🔄 Error converting server prescriptions: $e');
      return [];
    }
  }
}

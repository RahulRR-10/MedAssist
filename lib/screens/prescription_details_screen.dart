import 'package:flutter/material.dart';
import '../models/prescription_model.dart';

class PrescriptionDetailsScreen extends StatelessWidget {
  final PrescriptionData prescription;

  const PrescriptionDetailsScreen({super.key, required this.prescription});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prescription Details'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(
              context,
              title: 'Diagnosis',
              content: prescription.diagnosis,
              icon: Icons.medical_information,
            ),
            const SizedBox(height: 16),
            _buildInfoCard(
              context,
              title: 'Symptoms',
              content: prescription.symptom,
              icon: Icons.sick,
            ),
            const SizedBox(height: 16),
            _buildFollowUpCard(context),
            const SizedBox(height: 16),
            _buildMedicationsSection(context),
            if (prescription.notes.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildInfoCard(
                context,
                title: 'Notes',
                content: prescription.notes,
                icon: Icons.note,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required String title,
    required String content,
    required IconData icon,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(content, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowUpCard(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.event, color: Colors.red),
                SizedBox(width: 8),
                Text(
                  'Follow-up Date',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${prescription.followUpDate.day}/${prescription.followUpDate.month}/${prescription.followUpDate.year}',
                  style: const TextStyle(fontSize: 16),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () {
                    // Add to calendar functionality
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: const Text('Add to Calendar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicationsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Text(
            'Medications',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: prescription.medications.length,
          itemBuilder: (context, index) {
            final medication = prescription.medications[index];
            return _buildMedicationCard(context, medication);
          },
        ),
      ],
    );
  }

  Widget _buildMedicationCard(BuildContext context, Medication medication) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.medication, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    medication.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Chip(
                  label: Text(medication.beforeAfterFood),
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                ),
              ],
            ),
            const Divider(),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: medication.schedules.length,
              itemBuilder: (context, index) {
                final schedule = medication.schedules[index];
                return _buildScheduleItem(context, schedule);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleItem(BuildContext context, Schedule schedule) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Dosage: ${schedule.dosage}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              Text(
                '${schedule.startDate.day}/${schedule.startDate.month} - ${schedule.endDate.day}/${schedule.endDate.month}',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children:
                schedule.times.map((time) {
                  return Chip(
                    label: Text(time),
                    avatar: const Icon(Icons.access_time, size: 16),
                    backgroundColor:
                        Theme.of(context).colorScheme.secondaryContainer,
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }
}

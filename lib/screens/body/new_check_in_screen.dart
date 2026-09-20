import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app_theme.dart';
import '../../data/database.dart';
import '../../providers.dart';

/// New check-in (Winter Arc reference, adapted): weight, body fat, and a
/// block of optional measurements. Every field is optional except the date —
/// a check-in can log just weight, just measurements, or both.
class NewCheckInScreen extends ConsumerStatefulWidget {
  const NewCheckInScreen({super.key});

  @override
  ConsumerState<NewCheckInScreen> createState() => _NewCheckInScreenState();
}

class _NewCheckInScreenState extends ConsumerState<NewCheckInScreen> {
  final _weight = TextEditingController();
  final _bodyFat = TextEditingController();
  final _neck = TextEditingController();
  final _chest = TextEditingController();
  final _waist = TextEditingController();
  final _hips = TextEditingController();
  final _leftArm = TextEditingController();
  final _rightArm = TextEditingController();
  final _forearm = TextEditingController();
  final _thigh = TextEditingController();
  final _calf = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [
      _weight,
      _bodyFat,
      _neck,
      _chest,
      _waist,
      _hips,
      _leftArm,
      _rightArm,
      _forearm,
      _thigh,
      _calf,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _parse(TextEditingController c) => double.tryParse(c.text.trim());

  bool get _hasAnyValue => [
        _weight,
        _bodyFat,
        _neck,
        _chest,
        _waist,
        _hips,
        _leftArm,
        _rightArm,
        _forearm,
        _thigh,
        _calf,
      ].any((c) => _parse(c) != null);

  Future<void> _save() async {
    if (!_hasAnyValue || _saving) return;
    setState(() => _saving = true);
    await ref.read(bodyCheckInDaoProvider).addCheckIn(
          BodyCheckInsCompanion.insert(
            date: DateTime.now(),
            weightKg: Value(_parse(_weight)),
            bodyFatPercent: Value(_parse(_bodyFat)),
            neckCm: Value(_parse(_neck)),
            chestCm: Value(_parse(_chest)),
            waistCm: Value(_parse(_waist)),
            hipsCm: Value(_parse(_hips)),
            leftArmCm: Value(_parse(_leftArm)),
            rightArmCm: Value(_parse(_rightArm)),
            forearmCm: Value(_parse(_forearm)),
            thighCm: Value(_parse(_thigh)),
            calfCm: Value(_parse(_calf)),
          ),
        );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('New check-in'),
        actions: [
          TextButton(
            onPressed: _hasAnyValue && !_saving ? _save : null,
            child: const Text('SAVE'),
          ),
        ],
      ),
      body: SafeArea(
        minimum: const EdgeInsets.only(bottom: 12),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(
              DateFormat('d MMMM yyyy').format(DateTime.now()),
              style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13.5),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _NumberField(controller: _weight, label: 'Weight (kg)')),
                const SizedBox(width: 12),
                Expanded(child: _NumberField(controller: _bodyFat, label: 'Body fat (%)')),
              ],
            ),
            const SizedBox(height: 24),
            const _SectionLabel('Measurements — centimetres'),
            const SizedBox(height: 10),
            _MeasurementGrid(
              fields: [
                (_neck, 'Neck'),
                (_chest, 'Chest'),
                (_waist, 'Waist'),
                (_hips, 'Hips'),
                (_leftArm, 'Left arm'),
                (_rightArm, 'Right arm'),
                (_forearm, 'Forearm'),
                (_thigh, 'Thigh'),
                (_calf, 'Calf'),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _hasAnyValue && !_saving ? _save : null,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Color(0xFF241B00),
                        ),
                      )
                    : const Text('SAVE CHECK-IN', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MeasurementGrid extends StatelessWidget {
  const _MeasurementGrid({required this.fields});
  final List<(TextEditingController, String)> fields;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: fields
          .map(
            (f) => SizedBox(
              width: (MediaQuery.of(context).size.width - 40 - 12) / 2,
              child: _NumberField(controller: f.$1, label: f.$2),
            ),
          )
          .toList(),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: AppColors.onBackground),
      decoration: InputDecoration(
        hintText: label,
        filled: true,
        fillColor: AppColors.surface,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.onSurfaceMuted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      );
}

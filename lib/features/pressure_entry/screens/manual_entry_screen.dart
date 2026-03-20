import 'package:flutter/material.dart';
import '../widgets/pressure_input_field.dart';
import '../widgets/reference_values_card.dart';
import '../../dashboard/widgets/primary_button.dart';
import '../../../models/pressure_reading.dart';
import '../../../data/repositories/pressure_repository.dart';

class ManualEntryScreen extends StatefulWidget {
  const ManualEntryScreen({super.key});

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final _sysController = TextEditingController(text: '120');
  final _diaController = TextEditingController(text: '80');
  final _pulseController = TextEditingController(text: '72');
  bool _isSaving = false;

  @override
  void dispose() {
    _sysController.dispose();
    _diaController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Confirmar datos',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A2E),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            PressureInputField(
              label: 'Presión Sistólica (SYS)',
              unit: 'mmHg',
              controller: _sysController,
              maxValue: 300,
            ),
            const SizedBox(height: 20),
            PressureInputField(
              label: 'Presión Diastólica (DIA)',
              unit: 'mmHg',
              controller: _diaController,
              maxValue: 200,
            ),
            const SizedBox(height: 20),
            PressureInputField(
              label: 'Pulso',
              unit: 'bpm',
              controller: _pulseController,
              maxValue: 250,
            ),
            const SizedBox(height: 32),
            PrimaryButton(
              label: _isSaving ? 'Guardando...' : 'Guardar medición',
              icon: Icons.check,
              onPressed: _isSaving ? null : _saveMeasurement,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancelar',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
            ),
            const SizedBox(height: 24),
            const ReferenceValuesCard(),
          ],
        ),
      ),
    );
  }

  Future<void> _saveMeasurement() async {
    final sys = int.tryParse(_sysController.text);
    final dia = int.tryParse(_diaController.text);
    final pulse = int.tryParse(_pulseController.text);

    if (sys == null || dia == null || pulse == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa todos los campos')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final reading = PressureReading(
      systolic: sys,
      diastolic: dia,
      pulse: pulse,
      date: DateTime.now(),
    );

    try {
      await PressureRepository.instance.saveReading(reading);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Medición guardada correctamente'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );

      // Navigate back - StreamBuilder will auto-update all screens!
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;

      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

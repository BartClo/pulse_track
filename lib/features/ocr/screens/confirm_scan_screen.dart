import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/pressure_reading.dart';
import '../../../data/repositories/pressure_repository.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../utils/ocr_parser.dart';

/// Confirmation screen for OCR scan results.
///
/// Displays the detected values with the ability to edit them manually
/// before saving to the database. Shows confidence indicators for each value.
class ConfirmScanScreen extends StatefulWidget {
  final int? systolic;
  final int? diastolic;
  final int? pulse;
  final String? imagePath;
  final ParseConfidence? systolicConfidence;
  final ParseConfidence? diastolicConfidence;
  final ParseConfidence? pulseConfidence;
  final List<String> warnings;
  final bool requiresManualInput;
  final bool allowRetake;

  const ConfirmScanScreen({
    super.key,
    this.systolic,
    this.diastolic,
    this.pulse,
    this.imagePath,
    this.systolicConfidence,
    this.diastolicConfidence,
    this.pulseConfidence,
    this.warnings = const [],
    this.requiresManualInput = false,
    this.allowRetake = false,
  });

  @override
  State<ConfirmScanScreen> createState() => _ConfirmScanScreenState();
}

class _ConfirmScanScreenState extends State<ConfirmScanScreen> {
  late TextEditingController _systolicController;
  late TextEditingController _diastolicController;
  late TextEditingController _pulseController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _systolicController = TextEditingController(
      text: widget.systolic?.toString() ?? '',
    );
    _diastolicController = TextEditingController(
      text: widget.diastolic?.toString() ?? '',
    );
    _pulseController = TextEditingController(
      text: widget.pulse?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _systolicController.dispose();
    _diastolicController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  bool get _isValid {
    final sys = int.tryParse(_systolicController.text);
    final dia = int.tryParse(_diastolicController.text);
    final pulse = int.tryParse(_pulseController.text);

    return sys != null &&
        sys >= 70 &&
        sys <= 250 &&
        dia != null &&
        dia >= 40 &&
        dia <= 150 &&
        pulse != null &&
        pulse >= 40 &&
        pulse <= 200;
  }

  String get _status {
    final sys = int.tryParse(_systolicController.text) ?? 0;
    final dia = int.tryParse(_diastolicController.text) ?? 0;

    if (sys >= 140 || dia >= 90) return 'Alta';
    if (sys >= 130 || dia >= 85) return 'Elevada';
    return 'Normal';
  }

  Color get _statusColor {
    switch (_status) {
      case 'Alta':
        return const Color(0xFFF44336);
      case 'Elevada':
        return const Color(0xFFFFA000);
      default:
        return const Color(0xFF4CAF50);
    }
  }

  String get _statusMessage {
    switch (_status) {
      case 'Alta':
        return 'Tu presión está alta. Consulta a un médico.';
      case 'Elevada':
        return 'Tu presión está ligeramente elevada. Monitorea regularmente.';
      default:
        return 'Tu presión está dentro del rango normal. ¡Sigue así!';
    }
  }

  Future<void> _saveReading() async {
    if (!_isValid || _isSaving) return;

    setState(() => _isSaving = true);

    try {
      final reading = PressureReading(
        systolic: int.parse(_systolicController.text),
        diastolic: int.parse(_diastolicController.text),
        pulse: int.parse(_pulseController.text),
        date: DateTime.now(),
      );

      await PressureRepository.instance.saveReading(reading);

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Medición guardada correctamente'),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );

        // Navigate back to dashboard
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetectionBanner(),
            if (widget.warnings.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildWarningsCard(widget.warnings),
            ],
            const SizedBox(height: 24),
            _buildValueField(
              label: 'Presión Sistólica (SYS)',
              controller: _systolicController,
              unit: 'mmHg',
              hintText: 'Ej: 120',
              confidence: widget.systolicConfidence,
            ),
            const SizedBox(height: 16),
            _buildValueField(
              label: 'Presión Diastólica (DIA)',
              controller: _diastolicController,
              unit: 'mmHg',
              hintText: 'Ej: 80',
              confidence: widget.diastolicConfidence,
            ),
            const SizedBox(height: 16),
            _buildValueField(
              label: 'Pulso',
              controller: _pulseController,
              unit: 'bpm',
              hintText: 'Ej: 75',
              confidence: widget.pulseConfidence,
            ),
            const SizedBox(height: 24),
            if (_isValid)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _status == 'Normal'
                            ? Icons.check_circle_outline
                            : Icons.warning_amber_outlined,
                        color: _statusColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _status == 'Normal'
                                ? 'Valores normales'
                                : 'Valores ${_status.toLowerCase()}s',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _statusColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _statusMessage,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _status,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: _statusColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.allowRetake) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1E88E5),
                      side: const BorderSide(color: Color(0xFF1E88E5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Repetir escaneo'),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                height: 56,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isValid && !_isSaving ? _saveReading : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E88E5),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Guardar medición',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildValueField({
    required String label,
    required TextEditingController controller,
    required String unit,
    required String hintText,
    ParseConfidence? confidence,
  }) {
    final isLowConfidence = confidence == ParseConfidence.low;
    final isEmpty = controller.text.isEmpty;
    final isManualMissing = widget.requiresManualInput && isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
            if (isLowConfidence && !isEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Verificar',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade800,
                  ),
                ),
              ),
            ],
            if (confidence == ParseConfidence.high && !isEmpty) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.check_circle,
                size: 16,
                color: Colors.green.shade600,
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isLowConfidence && !isEmpty
                  ? Colors.orange.shade300
                  : isManualMissing
                      ? Colors.red.shade300
                      : Colors.grey.shade200,
              width: (isLowConfidence && !isEmpty) || isManualMissing ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    hintText: hintText,
                    hintStyle: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade300,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Text(
                  unit,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildDetectionBanner() {
    final hasLowConfidence =
        widget.systolicConfidence == ParseConfidence.low ||
            widget.diastolicConfidence == ParseConfidence.low ||
            widget.pulseConfidence == ParseConfidence.low;

    final hasMissingValues = widget.requiresManualInput;
    final hasWarnings = widget.warnings.isNotEmpty;

    Color bannerColor;
    Color borderColor;
    String emoji;
    String message;

    if (hasMissingValues) {
      bannerColor = const Color(0xFFFFF3E0);
      borderColor = Colors.orange.withValues(alpha: 0.4);
      emoji = '⚠️';
      message =
          'No se pudieron detectar todos los valores. Por favor completa los campos antes de guardar.';
    } else if (hasWarnings || hasLowConfidence) {
      bannerColor = const Color(0xFFFFF8E1);
      borderColor = Colors.orange.withValues(alpha: 0.3);
      emoji = '🔍';
      message =
          'Detectamos lecturas poco confiables. Revisa los valores y ajusta cualquier número incorrecto.';
    } else {
      bannerColor = const Color(0xFFE3F2FD);
      borderColor = const Color(0xFF1E88E5).withValues(alpha: 0.2);
      emoji = '✨';
      message =
          'Datos detectados automáticamente. Confirma o edita si ves discrepancias.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bannerColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: borderColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningsCard(List<String> warnings) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_outlined, color: Colors.orange.shade800),
              const SizedBox(width: 8),
              Text(
                'Revisión recomendada',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...warnings.map(
            (warning) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontSize: 13)),
                  Expanded(
                    child: Text(
                      warning,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade800,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!widget.allowRetake)
            Text(
              'Confirma los valores manualmente antes de guardar.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange.shade900,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}

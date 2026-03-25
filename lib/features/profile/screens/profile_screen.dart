import 'package:flutter/material.dart';
import '../../../data/repositories/user_profile_repository.dart';
import '../../../data/repositories/pressure_repository.dart';
import '../../../models/user_profile.dart';
import '../../../services/export_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final Stream<UserProfile?> _profileStream;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _profileStream = UserProfileRepository.instance.watchProfile();
  }

  Future<ExportFormat?> _selectExportFormat() {
    return showModalBottomSheet<ExportFormat>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.table_chart_outlined),
                title: const Text('CSV'),
                onTap: () => Navigator.of(context).pop(ExportFormat.csv),
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: const Text('PDF'),
                onTap: () => Navigator.of(context).pop(ExportFormat.pdf),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportData(UserProfile? profile) async {
    if (_isExporting) return;

    final format = await _selectExportFormat();
    if (format == null) return;

    setState(() => _isExporting = true);

    try {
      final readings = await PressureRepository.instance.getAllReadings();

      if (readings.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No hay datos para exportar'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        return;
      }

      final ensuredProfile =
          profile ?? await UserProfileRepository.instance.ensureProfile();
      final exportService = ExportService.instance;
      final filePath = format == ExportFormat.pdf
          ? await exportService.exportToPdf(readings, ensuredProfile)
          : await exportService.exportToCsv(readings, ensuredProfile);
      await exportService.shareFile(filePath);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Archivo exportado correctamente'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al exportar: $e'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      body: StreamBuilder<UserProfile?>(
        stream: _profileStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final profile = snapshot.data;

          return SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(context),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  child: Column(
                    children: [
                      _buildPersonalInfoCard(profile),
                      const SizedBox(height: 16),
                      _buildExportCard(profile),
                      const SizedBox(height: 16),
                      _buildSettingsCard(),
                      const SizedBox(height: 16),
                      _buildPrivacyNote(),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2979FF), Color(0xFF448AFF)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mi Perfil',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Gestiona tu información y preferencias',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalInfoCard(UserProfile? profile) {
    final isEmpty = profile == null;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Datos personales',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 16),
            _infoRow('Nombre', profile?.name ?? 'Completar'),
            _infoRow('Edad', profile?.formattedAge ?? '—'),
            _infoRow('Peso', profile?.formattedWeight ?? '—'),
            _infoRow('Altura', profile?.formattedHeight ?? '—'),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _openEditProfileSheet(profile),
                icon: const Icon(Icons.edit_outlined),
                label: Text(
                  isEmpty ? 'Agregar información' : 'Editar información',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportCard(UserProfile? profile) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Exportar datos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Descarga todas tus mediciones en formato CSV o PDF.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _isExporting ? null : () => _exportData(profile),
              icon: _isExporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.download_outlined),
              label: Text(_isExporting ? 'Exportando...' : 'Exportar historial'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Configuración',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 16),
            _settingsRow(Icons.lock_outline, 'Privacidad y seguridad'),
            _settingsRow(Icons.help_outline, 'Ayuda y soporte'),
            _settingsRow(Icons.share_outlined, 'Compartir la app'),
          ],
        ),
      ),
    );
  }

  Widget _settingsRow(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF2979FF)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildPrivacyNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F1FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, color: Color(0xFF2979FF)),
              SizedBox(width: 8),
              Text(
                'Tu privacidad es importante',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Todos tus datos de salud se almacenan de forma segura en tu dispositivo. No compartimos información personal con terceros.',
            style: TextStyle(fontSize: 14, color: Color(0xFF1A1A2E)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            const Text(
              'Error al cargar el perfil',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditProfileSheet(UserProfile? profile) async {
    final nameController = TextEditingController(text: profile?.name ?? '');
    final ageController = TextEditingController(
      text: profile != null ? profile.age.toString() : '',
    );
    final weightController = TextEditingController(
      text: profile != null ? profile.weight.toString() : '',
    );
    final heightController = TextEditingController(
      text: profile != null ? profile.height.toString() : '',
    );
    final formKey = GlobalKey<FormState>();

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        bool isSaving = false;

        Future<void> handleSubmit() async {
          if (isSaving) return;
          if (!formKey.currentState!.validate()) return;

          final age = int.parse(ageController.text.trim());
          final weight = double.parse(weightController.text.trim());
          final height = double.parse(heightController.text.trim());

          final newProfile =
              (profile ??
                      UserProfile(
                        name: nameController.text.trim(),
                        age: age,
                        weight: weight,
                        height: height,
                      ))
                  .copyWith(
                    name: nameController.text.trim(),
                    age: age,
                    weight: weight,
                    height: height,
                  );

          isSaving = true;
          try {
            if (profile == null) {
              await UserProfileRepository.instance.saveProfile(newProfile);
            } else {
              await UserProfileRepository.instance.updateProfile(newProfile);
            }
            if (context.mounted) Navigator.of(context).pop(true);
          } catch (e) {
            isSaving = false;
            if (!context.mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
          }
        }

        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    profile == null ? 'Crear perfil' : 'Editar perfil',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _textField(
                    label: 'Nombre',
                    controller: nameController,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Ingresa tu nombre'
                        : null,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _textField(
                          label: 'Edad',
                          controller: ageController,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            final number = int.tryParse(value ?? '');
                            if (number == null || number <= 0) {
                              return 'Edad inválida';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _textField(
                          label: 'Peso (kg)',
                          controller: weightController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (value) {
                            final number = double.tryParse(value ?? '');
                            if (number == null || number <= 0) {
                              return 'Peso inválido';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  _textField(
                    label: 'Altura (cm)',
                    controller: heightController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      final number = double.tryParse(value ?? '');
                      if (number == null || number <= 0) {
                        return 'Altura inválida';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: handleSubmit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Guardar cambios'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancelar'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Perfil actualizado')));
    }
  }

  Widget _textField({
    required String label,
    required TextEditingController controller,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}

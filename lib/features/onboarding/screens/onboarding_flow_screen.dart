import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/repositories/user_profile_repository.dart';
import '../../../models/user_profile.dart';
import '../../dashboard/screens/dashboard_screen.dart';

class AppEntryScreen extends StatefulWidget {
  const AppEntryScreen({super.key});

  @override
  State<AppEntryScreen> createState() => _AppEntryScreenState();
}

class _AppEntryScreenState extends State<AppEntryScreen> {
  bool _loading = true;
  bool _onboardingCompleted = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool('onboarding_completed') ?? false;
    if (!mounted) return;
    setState(() {
      _onboardingCompleted = completed;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_onboardingCompleted) {
      return const DashboardScreen();
    }
    return const OnboardingFlowScreen();
  }
}

class OnboardingFlowScreen extends StatefulWidget {
  const OnboardingFlowScreen({super.key});

  @override
  State<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends State<OnboardingFlowScreen> {
  final PageController _pageController = PageController();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();

  int _currentIndex = 0;
  bool _isSaving = false;
  bool _isGoogleLoading = false;

  static const _introPages = [
    (
      icon: Icons.monitor_heart_outlined,
      title: 'Registra tu presión fácilmente',
      subtitle:
          'Ingresa tus mediciones de forma rápida y sencilla, o toma una foto de tu tensiómetro.',
    ),
    (
      icon: Icons.notifications_active_outlined,
      title: 'Recibe recordatorios diarios',
      subtitle: 'Configura notificaciones para nunca olvidar tus mediciones.',
    ),
    (
      icon: Icons.trending_up_outlined,
      title: 'Controla tu salud',
      subtitle:
          'Visualiza tus datos con gráficos claros y recibe recomendaciones personalizadas.',
    ),
  ];

  int get _lastIntroIndex => _introPages.length - 1;
  int get _loginPageIndex => _introPages.length;
  int get _totalPages => _introPages.length + 2;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _nextPage() async {
    if (_currentIndex < _totalPages - 1) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _mockGoogleSignIn() async {
    if (_isGoogleLoading) return;
    setState(() => _isGoogleLoading = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _isGoogleLoading = false);
    await _nextPage();
  }

  Future<void> _finishOnboarding() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final profile = UserProfile(
        name: _nameController.text.trim(),
        age: int.parse(_ageController.text.trim()),
        weight: double.parse(_weightController.text.trim()),
        height: double.parse(_heightController.text.trim()),
      );
      await UserProfileRepository.instance.updateProfile(profile);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', true);

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
        (_) => false,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF2F7),
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (index) => setState(() => _currentIndex = index),
          children: [
            ..._introPages.map((item) => _buildIntroPage(item)),
            _buildLoginPage(),
            _buildProfileCreationPage(),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroPage(
    ({IconData icon, String title, String subtitle}) pageData,
  ) {
    final isLastIntro = _currentIndex == _lastIntroIndex;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
      child: Column(
        children: [
          const SizedBox(height: 52),
          _brandHeader(),
          const SizedBox(height: 36),
          _featureIcon(pageData.icon),
          const SizedBox(height: 42),
          Text(
            pageData.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F2748),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            pageData.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              height: 1.45,
              color: Color(0xFF365072),
            ),
          ),
          const Spacer(),
          _introDots(),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton.icon(
              onPressed: _nextPage,
              icon: Icon(isLastIntro ? Icons.play_arrow_rounded : Icons.chevron_right),
              label: Text(isLastIntro ? 'Comenzar' : 'Siguiente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3479F5),
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          if (!isLastIntro) ...[
            const SizedBox(height: 14),
            TextButton(
              onPressed: () async {
                await _pageController.animateToPage(
                  _loginPageIndex,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                );
              },
              child: const Text('Saltar'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoginPage() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
      child: Column(
        children: [
          const SizedBox(height: 52),
          _brandHeader(),
          const SizedBox(height: 54),
          _featureIcon(Icons.login_rounded),
          const SizedBox(height: 36),
          const Text(
            'Inicia sesión',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F2748),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Conecta con Google para sincronizar tu progreso en futuras versiones con Supabase.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.4,
              color: Color(0xFF365072),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton.icon(
              onPressed: _isGoogleLoading ? null : _mockGoogleSignIn,
              icon: _isGoogleLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.g_mobiledata_rounded, size: 28),
              label: Text(_isGoogleLoading ? 'Conectando...' : 'Continuar con Google'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3479F5),
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _nextPage,
            child: const Text('Continuar sin cuenta'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCreationPage() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
      child: Column(
        children: [
          const SizedBox(height: 34),
          _brandHeader(),
          const SizedBox(height: 24),
          const Text(
            'Completa tu perfil',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F2748),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  _inputField(
                    controller: _nameController,
                    label: 'Nombre',
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Ingresa tu nombre'
                        : null,
                  ),
                  _inputField(
                    controller: _ageController,
                    label: 'Edad',
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      final number = int.tryParse(value ?? '');
                      return (number == null || number <= 0) ? 'Edad inválida' : null;
                    },
                  ),
                  _inputField(
                    controller: _weightController,
                    label: 'Peso (kg)',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      final number = double.tryParse(value ?? '');
                      return (number == null || number <= 0) ? 'Peso inválido' : null;
                    },
                  ),
                  _inputField(
                    controller: _heightController,
                    label: 'Altura (cm)',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      final number = double.tryParse(value ?? '');
                      return (number == null || number <= 0) ? 'Altura inválida' : null;
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _finishOnboarding,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3479F5),
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                    )
                  : const Text('Finalizar'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _brandHeader() {
    return const Column(
      children: [
        CircleAvatar(
          radius: 42,
          backgroundColor: Color(0xFF3479F5),
          child: Icon(Icons.monitor_heart_outlined, color: Colors.white, size: 38),
        ),
        SizedBox(height: 12),
        Text(
          'PulseTrack',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w800,
            color: Color(0xFF102748),
          ),
        ),
      ],
    );
  }

  Widget _featureIcon(IconData icon) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      width: 132,
      height: 132,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, size: 60, color: const Color(0xFF3479F5)),
    );
  }

  Widget _introDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_introPages.length, (index) {
        final selected = _currentIndex == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: selected ? 30 : 11,
          height: 11,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF3479F5) : const Color(0xFFD3D8E2),
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

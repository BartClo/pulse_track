import 'package:flutter/material.dart';
import '../widgets/entry_header.dart';
import '../widgets/camera_button.dart';
import '../widgets/manual_entry_button.dart';
import '../widgets/tips_card.dart';
import 'manual_entry_screen.dart';
import '../../ocr/screens/scan_screen.dart';

class PressureEntryScreen extends StatelessWidget {
  const PressureEntryScreen({super.key});

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
          'Nueva medición',
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
            const EntryHeader(
              title: '¿Cómo quieres registrar?',
              subtitle: 'Elige el método que prefieras',
            ),
            const SizedBox(height: 24),
            CameraButton(
              onTap: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const ScanScreen()));
              },
            ),
            const SizedBox(height: 12),
            ManualEntryButton(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ManualEntryScreen()),
                );
              },
            ),
            const SizedBox(height: 28),
            const TipsCard(),
          ],
        ),
      ),
    );
  }
}

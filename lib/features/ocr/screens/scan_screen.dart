import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../services/smart_ocr_service.dart';
import '../utils/ocr_parser.dart';
import 'confirm_scan_screen.dart';

/// Camera screen for scanning blood pressure monitor displays.
///
/// Provides a camera preview with a scan frame overlay.
/// Uses ML Kit OCR to extract values from captured images.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _flashEnabled = false;
  String _statusText = 'Alinea el tensiómetro';
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        _showError('No se encontró ninguna cámara');
        return;
      }

      _cameraController = CameraController(
        _cameras!.first,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      _showError('Error al inicializar la cámara: $e');
    }
  }

  Future<void> _captureAndProcess() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _statusText = 'Capturando...';
    });

    try {
      final XFile imageFile = await _cameraController!.takePicture();

      // For camera capture: use region-based OCR directly (no cropping needed)
      // The overlay guide helps the user align the monitor correctly
      setState(() => _statusText = 'Detectando valores...');
      await _processImageWithRegions(File(imageFile.path));
    } catch (e) {
      _showError('Error al capturar la imagen: $e');
      setState(() {
        _isProcessing = false;
        _statusText = 'Alinea el tensiómetro';
      });
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? imageFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (imageFile != null) {
        setState(() {
          _isProcessing = true;
          _statusText = 'Recortando...';
        });

        // For gallery: allow cropping first, then use region-based OCR
        final croppedFile = await _cropImage(imageFile.path);

        if (croppedFile != null) {
          setState(() => _statusText = 'Detectando valores...');
          await _processImageWithRegions(File(croppedFile.path));
        } else {
          // User cancelled cropping
          setState(() {
            _isProcessing = false;
            _statusText = 'Alinea el tensiómetro';
          });
        }
      }
    } catch (e) {
      _showError('Error al seleccionar imagen: $e');
      setState(() {
        _isProcessing = false;
        _statusText = 'Alinea el tensiómetro';
      });
    }
  }

  /// Process image using smart OCR (combines full image + region-based)
  Future<void> _processImageWithRegions(File imageFile) async {
    try {
      // Use smart OCR service for device-independent detection
      final result = await SmartOcrService.instance.processImage(imageFile);

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusText = 'Alinea el tensiómetro';
        });

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ConfirmScanScreen(
              systolic: result.systolic,
              diastolic: result.diastolic,
              pulse: result.pulse,
              imagePath: imageFile.path,
              systolicConfidence: _mapConfidence(result.systolicConfidence),
              diastolicConfidence: _mapConfidence(result.diastolicConfidence),
              pulseConfidence: _mapConfidence(result.pulseConfidence),
              warnings: result.warnings,
              requiresManualInput: result.requiresManualInput,
              allowRetake: result.allowRetake,
            ),
          ),
        );
      }
    } catch (e) {
      _showError('Error al procesar la imagen: $e');
      setState(() {
        _isProcessing = false;
        _statusText = 'Alinea el tensiómetro';
      });
    }
  }

  /// Map SmartOcrService confidence to ParseConfidence for UI compatibility
  ParseConfidence _mapConfidence(OcrConfidence conf) {
    switch (conf) {
      case OcrConfidence.high:
        return ParseConfidence.high;
      case OcrConfidence.medium:
        return ParseConfidence.medium;
      case OcrConfidence.low:
        return ParseConfidence.low;
    }
  }

  /// Open image cropper to let user select the blood pressure display area
  Future<CroppedFile?> _cropImage(String sourcePath) async {
    return ImageCropper().cropImage(
      sourcePath: sourcePath,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Recortar pantalla',
          toolbarColor: const Color(0xFF1E88E5),
          toolbarWidgetColor: Colors.white,
          backgroundColor: const Color(0xFF0A1929),
          activeControlsWidgetColor: const Color(0xFF1E88E5),
          cropFrameColor: const Color(0xFF1E88E5),
          cropGridColor: Colors.white54,
          dimmedLayerColor: Colors.black54,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
          aspectRatioPresets: [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio3x2,
          ],
          hideBottomControls: false,
          showCropGrid: true,
          cropFrameStrokeWidth: 3,
          cropGridStrokeWidth: 1,
          cropGridRowCount: 2,
          cropGridColumnCount: 2,
        ),
        IOSUiSettings(
          title: 'Recortar pantalla',
          doneButtonTitle: 'Listo',
          cancelButtonTitle: 'Cancelar',
          aspectRatioPresets: [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio3x2,
          ],
          aspectRatioLockEnabled: false,
          rotateButtonsHidden: false,
          resetButtonHidden: false,
          rectX: 0,
          rectY: 0,
          minimumAspectRatio: 0.5,
        ),
      ],
    );
  }

  /// Toggle camera flash
  Future<void> _toggleFlash() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      if (_flashEnabled) {
        await _cameraController!.setFlashMode(FlashMode.off);
      } else {
        await _cameraController!.setFlashMode(FlashMode.torch);
      }
      setState(() {
        _flashEnabled = !_flashEnabled;
      });
    } catch (e) {
      debugPrint('Error toggling flash: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1929),
      body: SafeArea(
        child: Stack(
          children: [
            // Camera preview
            if (_isInitialized && _cameraController != null)
              Positioned.fill(child: CameraPreview(_cameraController!))
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),

            // Scan frame overlay with region guides
            Positioned.fill(child: CustomPaint(painter: ScanFramePainter())),

            // Status indicator at top
            Positioned(
              top: MediaQuery.of(context).size.height * 0.12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Text(
                    _statusText,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                ),
              ),
            ),

            // Instruction text below frame
            Positioned(
              top: MediaQuery.of(context).size.height * 0.70,
              left: 20,
              right: 20,
              child: Text(
                'Alinea la pantalla del tensiómetro dentro del marco',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ),

            // Bottom controls
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Processing indicator or capture button
                    if (_isProcessing)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E88E5),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Detectando valores...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Gallery button
                          GestureDetector(
                            onTap: _pickFromGallery,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.photo_library_outlined,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                          const SizedBox(width: 32),
                          // Capture button
                          GestureDetector(
                            onTap: _captureAndProcess,
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E88E5),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF1E88E5,
                                    ).withValues(alpha: 0.4),
                                    blurRadius: 16,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          ),
                          const SizedBox(width: 32),
                          // Flash toggle
                          GestureDetector(
                            onTap: _toggleFlash,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _flashEnabled
                                    ? const Color(0xFF1E88E5)
                                    : Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _flashEnabled
                                    ? Icons.flash_on
                                    : Icons.flash_off,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 24),

                    // Cancel button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for the scan frame overlay with region guides
class ScanFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    // Calculate frame dimensions - taller frame for vertical monitor layout
    final frameWidth = size.width * 0.75;
    final frameHeight = size.height * 0.45;
    final frameLeft = (size.width - frameWidth) / 2;
    final frameTop = size.height * 0.22;

    final frameRect = Rect.fromLTWH(
      frameLeft,
      frameTop,
      frameWidth,
      frameHeight,
    );

    // Draw dark overlay with cutout
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(frameRect, const Radius.circular(16)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    // Draw frame border
    final borderPaint = Paint()
      ..color = const Color(0xFF1E88E5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawRRect(
      RRect.fromRectAndRadius(frameRect, const Radius.circular(16)),
      borderPaint,
    );

    // Draw corner accents
    final cornerLength = 30.0;
    final cornerPaint = Paint()
      ..color = const Color(0xFF1E88E5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    // Top-left corner
    canvas.drawLine(
      Offset(frameLeft, frameTop + cornerLength),
      Offset(frameLeft, frameTop + 8),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(frameLeft + 8, frameTop),
      Offset(frameLeft + cornerLength, frameTop),
      cornerPaint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(frameLeft + frameWidth, frameTop + cornerLength),
      Offset(frameLeft + frameWidth, frameTop + 8),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(frameLeft + frameWidth - 8, frameTop),
      Offset(frameLeft + frameWidth - cornerLength, frameTop),
      cornerPaint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(frameLeft, frameTop + frameHeight - cornerLength),
      Offset(frameLeft, frameTop + frameHeight - 8),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(frameLeft + 8, frameTop + frameHeight),
      Offset(frameLeft + cornerLength, frameTop + frameHeight),
      cornerPaint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(frameLeft + frameWidth, frameTop + frameHeight - cornerLength),
      Offset(frameLeft + frameWidth, frameTop + frameHeight - 8),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(frameLeft + frameWidth - 8, frameTop + frameHeight),
      Offset(frameLeft + frameWidth - cornerLength, frameTop + frameHeight),
      cornerPaint,
    );

    // Draw region dividers (3 horizontal regions)
    final regionHeight = frameHeight / 3;
    final dividerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;

    // Dashed line helper
    const dashWidth = 8.0;
    const dashSpace = 6.0;

    // First divider (between SYS and DIA)
    final y1 = frameTop + regionHeight;
    double startX = frameLeft + 20;
    while (startX < frameLeft + frameWidth - 20) {
      canvas.drawLine(
        Offset(startX, y1),
        Offset((startX + dashWidth).clamp(0, frameLeft + frameWidth - 20), y1),
        dividerPaint,
      );
      startX += dashWidth + dashSpace;
    }

    // Second divider (between DIA and PULSE)
    final y2 = frameTop + regionHeight * 2;
    startX = frameLeft + 20;
    while (startX < frameLeft + frameWidth - 20) {
      canvas.drawLine(
        Offset(startX, y2),
        Offset((startX + dashWidth).clamp(0, frameLeft + frameWidth - 20), y2),
        dividerPaint,
      );
      startX += dashWidth + dashSpace;
    }

    // Draw region labels
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
    );

    final labelStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.7),
      fontSize: 11,
      fontWeight: FontWeight.w500,
    );

    // SYS label
    textPainter.text = TextSpan(text: 'SYS', style: labelStyle);
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        frameLeft + frameWidth - textPainter.width - 12,
        frameTop + regionHeight / 2 - textPainter.height / 2,
      ),
    );

    // DIA label
    textPainter.text = TextSpan(text: 'DIA', style: labelStyle);
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        frameLeft + frameWidth - textPainter.width - 12,
        frameTop + regionHeight * 1.5 - textPainter.height / 2,
      ),
    );

    // PUL label
    textPainter.text = TextSpan(text: 'PUL', style: labelStyle);
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        frameLeft + frameWidth - textPainter.width - 12,
        frameTop + regionHeight * 2.5 - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

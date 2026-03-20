import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../utils/ocr_parser.dart';

/// Result of region-based OCR processing.
class RegionOcrResult {
  final int? systolic;
  final int? diastolic;
  final int? pulse;
  final String topRegionText;
  final String middleRegionText;
  final String bottomRegionText;
  final bool isValid;

  RegionOcrResult({
    this.systolic,
    this.diastolic,
    this.pulse,
    required this.topRegionText,
    required this.middleRegionText,
    required this.bottomRegionText,
  }) : isValid = systolic != null && diastolic != null;

  @override
  String toString() {
    return 'RegionOcrResult(sys: $systolic, dia: $diastolic, pulse: $pulse, valid: $isValid)';
  }
}

/// Service for performing region-based OCR on blood pressure monitor images.
///
/// Splits the image into 3 horizontal regions:
/// - Top: Systolic
/// - Middle: Diastolic
/// - Bottom: Pulse
class RegionOcrService {
  RegionOcrService._();

  static final RegionOcrService _instance = RegionOcrService._();
  static RegionOcrService get instance => _instance;

  final TextRecognizer _textRecognizer = TextRecognizer();

  /// Process an image using region-based detection.
  ///
  /// Splits the image into 3 horizontal regions and extracts
  /// numeric values from each region.
  Future<RegionOcrResult> processImageByRegions(File imageFile) async {
    debugPrint('═══════════════════════════════════');
    debugPrint('Region-based OCR Processing');
    debugPrint('═══════════════════════════════════');

    // Read and decode the image
    final bytes = await imageFile.readAsBytes();
    final originalImage = img.decodeImage(bytes);

    if (originalImage == null) {
      debugPrint('ERROR: Could not decode image');
      return RegionOcrResult(
        topRegionText: '',
        middleRegionText: '',
        bottomRegionText: '',
      );
    }

    final width = originalImage.width;
    final height = originalImage.height;
    debugPrint('Image dimensions: ${width}x$height');

    // Define region heights (divide into 3 equal parts)
    final regionHeight = height ~/ 3;

    // Create temp directory for region images
    final tempDir = await getTemporaryDirectory();

    // Process each region
    final topText = await _processRegion(
      originalImage,
      0,
      regionHeight,
      '${tempDir.path}/region_top.jpg',
      'TOP (Systolic)',
    );

    final middleText = await _processRegion(
      originalImage,
      regionHeight,
      regionHeight,
      '${tempDir.path}/region_middle.jpg',
      'MIDDLE (Diastolic)',
    );

    final bottomText = await _processRegion(
      originalImage,
      regionHeight * 2,
      height - (regionHeight * 2),
      '${tempDir.path}/region_bottom.jpg',
      'BOTTOM (Pulse)',
    );

    // Extract numeric values from each region
    final systolic = _extractNumber(topText, minValue: 80, maxValue: 200);
    final diastolic = _extractNumber(middleText, minValue: 50, maxValue: 130);
    final pulse = _extractNumber(bottomText, minValue: 40, maxValue: 150);

    // Validate: systolic should be greater than diastolic
    int? validSystolic = systolic;
    int? validDiastolic = diastolic;

    if (systolic != null && diastolic != null && systolic <= diastolic) {
      // Swap if they appear to be reversed
      debugPrint('⚠️ Values appear reversed, swapping...');
      validSystolic = diastolic;
      validDiastolic = systolic;
    }

    final result = RegionOcrResult(
      systolic: validSystolic,
      diastolic: validDiastolic,
      pulse: pulse,
      topRegionText: topText,
      middleRegionText: middleText,
      bottomRegionText: bottomText,
    );

    debugPrint('═══════════════════════════════════');
    debugPrint('Final Result: $result');
    debugPrint('═══════════════════════════════════');

    return result;
  }

  /// Process a single region of the image
  Future<String> _processRegion(
    img.Image originalImage,
    int yOffset,
    int regionHeight,
    String tempPath,
    String regionName,
  ) async {
    debugPrint('───────────────────────────────────');
    debugPrint('Processing $regionName');
    debugPrint('Y offset: $yOffset, Height: $regionHeight');

    // Crop the region
    final croppedRegion = img.copyCrop(
      originalImage,
      x: 0,
      y: yOffset,
      width: originalImage.width,
      height: regionHeight,
    );

    // Save to temp file
    final regionFile = File(tempPath);
    await regionFile.writeAsBytes(img.encodeJpg(croppedRegion, quality: 95));

    // Run OCR on the region
    final inputImage = InputImage.fromFile(regionFile);
    final recognizedText = await _textRecognizer.processImage(inputImage);

    final text = recognizedText.text.trim();
    debugPrint('Detected text: "$text"');

    // Clean up temp file
    try {
      await regionFile.delete();
    } catch (_) {}

    return text;
  }

  /// Extract the most likely numeric value from text within a valid range
  int? _extractNumber(
    String text, {
    required int minValue,
    required int maxValue,
  }) {
    if (text.isEmpty) return null;

    // Clean the text - replace common OCR errors
    String cleaned = text
        .toUpperCase()
        .replaceAll(RegExp(r'[OQ]'), '0')
        .replaceAll(RegExp(r'[Il|]'), '1')
        .replaceAll('S', '5')
        .replaceAll('B', '8')
        .replaceAll('Z', '2')
        .replaceAll('G', '6');

    // Extract all 2-3 digit numbers
    final pattern = RegExp(r'\d{2,3}');
    final matches = pattern.allMatches(cleaned);

    final validNumbers = <int>[];
    for (final match in matches) {
      final num = int.tryParse(match.group(0)!);
      if (num != null && num >= minValue && num <= maxValue) {
        validNumbers.add(num);
      }
    }

    if (validNumbers.isEmpty) {
      debugPrint('  No valid numbers found in range $minValue-$maxValue');
      return null;
    }

    // Return the first valid number (most likely the main reading)
    debugPrint(
      '  Valid numbers: $validNumbers, selected: ${validNumbers.first}',
    );
    return validNumbers.first;
  }

  /// Convert RegionOcrResult to OcrParser for compatibility
  OcrParser toOcrParser(RegionOcrResult result) {
    return OcrParser.fromValues(
      systolic: result.systolic,
      diastolic: result.diastolic,
      pulse: result.pulse,
      rawText:
          '${result.topRegionText}\n${result.middleRegionText}\n${result.bottomRegionText}',
      confidence: result.isValid ? ParseConfidence.high : ParseConfidence.low,
    );
  }

  void dispose() {
    _textRecognizer.close();
  }
}

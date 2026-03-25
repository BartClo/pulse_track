import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../utils/ocr_parser.dart';
import '../utils/image_preprocessor.dart';

/// Service for performing OCR on blood pressure monitor images.
///
/// Uses Google ML Kit for text recognition with preprocessing
/// to improve accuracy on blood pressure monitor displays.
class OcrService {
  OcrService._();

  static final OcrService _instance = OcrService._();
  static OcrService get instance => _instance;

  final TextRecognizer _textRecognizer = TextRecognizer();
  final ImagePreprocessor _preprocessor = ImagePreprocessor.instance;

  /// Process an image file and extract blood pressure values.
  ///
  /// Returns an [OcrParser] with the extracted values and confidence levels.
  Future<OcrParser> processImage(File imageFile) async {
    // Estimate image quality
    final quality = await _preprocessor.estimateQuality(imageFile);
    debugPrint(
      'OCR: Image quality estimate: ${(quality * 100).toStringAsFixed(0)}%',
    );

    // Preprocess the image
    final processedFile = await _preprocessor.preprocess(imageFile);

    // Perform OCR
    final inputImage = InputImage.fromFile(processedFile);
    final recognizedText = await _textRecognizer.processImage(inputImage);

    final fullText = recognizedText.text;

    // Debug: print all recognized text
    debugPrint('──────────────────────────────────');
    debugPrint('OCR Raw Text:');
    debugPrint(fullText);
    debugPrint('──────────────────────────────────');

    // Also extract text block by block for better analysis
    final blockTexts = <String>[];
    for (final block in recognizedText.blocks) {
      blockTexts.add(block.text);
      debugPrint('Block: ${block.text}');
    }

    // Parse the recognized text
    final result = OcrParser.parse(fullText);

    debugPrint('OCR Result: $result');
    debugPrint('──────────────────────────────────');

    return result;
  }

  /// Process an image from path and extract blood pressure values.
  Future<OcrParser> processImageFromPath(String path) async {
    return processImage(File(path));
  }

  /// Get raw text from image without parsing
  Future<String> getRawText(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognizedText = await _textRecognizer.processImage(inputImage);
    return recognizedText.text;
  }

  /// Get detailed text recognition results with block positions
  Future<RecognizedText> getDetailedRecognition(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    return _textRecognizer.processImage(inputImage);
  }

  /// Close the text recognizer when done
  void dispose() {
    _textRecognizer.close();
  }
}

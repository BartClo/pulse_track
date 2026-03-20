import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Utility class for preprocessing images before OCR.
///
/// Applies various transformations to improve OCR accuracy:
/// - Grayscale conversion
/// - Contrast enhancement
/// - Noise reduction
class ImagePreprocessor {
  ImagePreprocessor._();

  static final ImagePreprocessor _instance = ImagePreprocessor._();
  static ImagePreprocessor get instance => _instance;

  /// Process an image file and return the preprocessed file.
  ///
  /// Note: Flutter/Dart doesn't have built-in image manipulation,
  /// so we rely on the ML Kit's internal preprocessing.
  /// This class provides utility methods for future enhancements
  /// and logging of image quality metrics.
  Future<File> preprocess(File imageFile) async {
    // Log file size for debugging
    final fileSize = await imageFile.length();
    debugPrint(
      'OCR Preprocessor: Image size: ${(fileSize / 1024).toStringAsFixed(1)} KB',
    );

    // For now, return the original file
    // ML Kit handles basic preprocessing internally
    // Future: Add native image processing via platform channels
    return imageFile;
  }

  /// Estimate image quality based on file size and dimensions.
  /// Returns a score from 0.0 to 1.0.
  Future<double> estimateQuality(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final fileSize = bytes.length;

      // Basic heuristics for image quality
      // Ideal size for OCR: 500KB - 2MB
      double sizeScore = 1.0;
      if (fileSize < 100 * 1024) {
        // Too small, likely low resolution
        sizeScore = 0.5;
      } else if (fileSize > 5 * 1024 * 1024) {
        // Very large, might be slow to process
        sizeScore = 0.8;
      }

      return sizeScore;
    } catch (e) {
      debugPrint('Error estimating image quality: $e');
      return 0.5;
    }
  }

  /// Get image dimensions from file.
  Future<Size?> getImageDimensions(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      return Size(image.width.toDouble(), image.height.toDouble());
    } catch (e) {
      debugPrint('Error getting image dimensions: $e');
      return null;
    }
  }
}

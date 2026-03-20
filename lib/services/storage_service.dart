// ============================================================
// DEPRECATED - DO NOT USE
// ============================================================
// This file has been replaced by the reactive architecture.
// Use PressureRepository instead:
//
//   import '../data/repositories/pressure_repository.dart';
//   final repository = PressureRepository.instance;
//
// For reactive UI updates, use StreamBuilder:
//
//   StreamBuilder<List<PressureReading>>(
//     stream: repository.watchAllReadings(),
//     builder: (context, snapshot) { ... }
//   )
//
// ============================================================

@Deprecated('Use PressureRepository instead')
class StorageService {
  StorageService._();

  static Future<void> init() async {
    throw UnsupportedError(
      'StorageService is deprecated. Use PressureRepository instead.',
    );
  }
}

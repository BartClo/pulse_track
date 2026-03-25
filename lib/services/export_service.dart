import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../models/pressure_reading.dart';
import '../models/user_profile.dart';

enum ExportFormat { csv, pdf }

class ExportService {
  ExportService._();

  static final ExportService instance = ExportService._();

  Future<String> exportToCsv(
    List<PressureReading> readings,
    UserProfile profile,
  ) async {
    final buffer = StringBuffer();
    final dateTag = _dateTag(DateTime.now());

    buffer.writeln('Blood Pressure Report');
    buffer.writeln('Name,Age,Weight,Height');
    buffer.writeln(
      '${profile.name},${profile.age},${_formatNumber(profile.weight)} kg,${_formatNumber(profile.height)} cm',
    );
    buffer.writeln('');
    buffer.writeln('Date,Systolic,Diastolic,Pulse,Status');

    for (final reading in readings) {
      buffer.writeln(
        '${_humanDateTime(reading.date)},${reading.systolic},${reading.diastolic},${reading.pulse},${reading.status}',
      );
    }

    final directory = await _getExportDirectory();
    final file = File('${directory.path}\\blood_pressure_$dateTag.csv');
    await file.writeAsString(buffer.toString(), flush: true);
    return file.path;
  }

  Future<String> exportToPdf(
    List<PressureReading> readings,
    UserProfile profile,
  ) async {
    final document = pw.Document();
    final chartReadings = [...readings]..sort((a, b) => a.date.compareTo(b.date));
    final trendReadings = chartReadings.length > 14
        ? chartReadings.sublist(chartReadings.length - 14)
        : chartReadings;
    final generatedAt = DateTime.now();
    final avgSystolic = readings.isEmpty
        ? 0.0
        : readings.map((r) => r.systolic).reduce((a, b) => a + b) /
            readings.length;
    final avgDiastolic = readings.isEmpty
        ? 0.0
        : readings.map((r) => r.diastolic).reduce((a, b) => a + b) /
            readings.length;
    final avgPulse = readings.isEmpty
        ? 0.0
        : readings.map((r) => r.pulse).reduce((a, b) => a + b) /
            readings.length;
    final insights = _generateInsights(chartReadings);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 30),
        build: (context) => [
          pw.Center(
            child: pw.Text(
              'Reporte de Presión Arterial',
              style: pw.TextStyle(
                fontSize: 28,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.Text(
              'Fecha de generación: ${_humanDateTime(generatedAt)}',
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Información del paciente',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey800,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
              color: PdfColors.blue50,
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Name: ${profile.name}'),
                pw.Text('Age: ${profile.age}'),
                pw.Text('Weight: ${_formatNumber(profile.weight)} kg'),
                pw.Text('Height: ${_formatNumber(profile.height)} cm'),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Resumen',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey800,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _summaryCard('SYS Promedio', '${avgSystolic.toStringAsFixed(1)} mmHg'),
              _summaryCard('DIA Promedio', '${avgDiastolic.toStringAsFixed(1)} mmHg'),
              _summaryCard('Pulso Promedio', '${avgPulse.toStringAsFixed(1)} bpm'),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Análisis automático',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey800,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
              color: PdfColors.grey100,
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: insights.map(_insightBullet).toList(),
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Tendencia de presión arterial',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey800,
            ),
          ),
          pw.SizedBox(height: 10),
          _trendChart(trendReadings),
          pw.SizedBox(height: 20),
          pw.Text(
            'Registro de mediciones',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey800,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.6),
            columnWidths: {
              0: const pw.FlexColumnWidth(2.2),
              1: const pw.FlexColumnWidth(1.2),
              2: const pw.FlexColumnWidth(1.2),
              3: const pw.FlexColumnWidth(1.2),
              4: const pw.FlexColumnWidth(1.4),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blue100),
                children: [
                  _tableHeader('Fecha'),
                  _tableHeader('SYS\n(mmHg)'),
                  _tableHeader('DIA\n(mmHg)'),
                  _tableHeader('PUL\n(bpm)'),
                  _tableHeader('Estado'),
                ],
              ),
              ...readings.asMap().entries.map((entry) {
                final index = entry.key;
                final reading = entry.value;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: index.isEven ? PdfColors.white : PdfColors.grey100,
                  ),
                  children: [
                    _tableCell(_humanDateTime(reading.date)),
                    _tableCell('${reading.systolic}'),
                    _tableCell('${reading.diastolic}'),
                    _tableCell('${reading.pulse}'),
                    _tableCell(
                      reading.status,
                      textColor: _statusColor(reading.status),
                      bold: true,
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );

    final directory = await _getExportDirectory();
    final dateTag = _dateTag(DateTime.now());
    final file = File('${directory.path}\\blood_pressure_report_$dateTag.pdf');
    await file.writeAsBytes(await document.save(), flush: true);
    return file.path;
  }

  pw.Widget _trendChart(List<PressureReading> readings) {
    if (readings.isEmpty) {
      return pw.Container(
        height: 200,
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Text('Sin datos para graficar'),
      );
    }

    final labels = readings.map((e) => _shortDate(e.date)).toList();
    final systolicData = <pw.PointChartValue>[];
    final diastolicData = <pw.PointChartValue>[];

    for (var i = 0; i < readings.length; i++) {
      systolicData.add(
        pw.PointChartValue(i.toDouble(), readings[i].systolic.toDouble()),
      );
      diastolicData.add(
        pw.PointChartValue(i.toDouble(), readings[i].diastolic.toDouble()),
      );
    }

    final ySteps = <num>[60, 80, 100, 120, 140, 160, 180];

    return pw.Container(
      height: 200,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
        color: PdfColors.white,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Chart(
              grid: pw.CartesianGrid(
                xAxis: pw.FixedAxis.fromStrings(
                  labels,
                  marginStart: 10,
                  marginEnd: 10,
                  ticks: true,
                ),
                yAxis: pw.FixedAxis(
                  ySteps,
                  format: (v) => '$v',
                  divisions: true,
                ),
              ),
              datasets: [
                pw.LineDataSet(
                  legend: 'Sistólica',
                  data: systolicData,
                  color: PdfColors.blue900,
                ),
                pw.LineDataSet(
                  legend: 'Diastólica',
                  data: diastolicData,
                  color: PdfColors.lightBlue300,
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            children: [
              pw.Text('X: Fecha', style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(width: 16),
              pw.Text('Y: mmHg', style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _summaryCard(String label, String value) {
    return pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.symmetric(horizontal: 3),
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: pw.BoxDecoration(
          color: PdfColors.blue50,
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: PdfColors.blue100),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: const pw.TextStyle(
                fontSize: 9,
                color: PdfColors.blueGrey700,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _tableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blue900,
        ),
      ),
    );
  }

  pw.Widget _tableCell(
    String text, {
    PdfColor textColor = PdfColors.black,
    bool bold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 9.5,
          color: textColor,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  PdfColor _statusColor(String status) {
    final value = status.toLowerCase();
    if (value.contains('normal')) return PdfColors.green700;
    if (value.contains('alta') || value.contains('high') || value.contains('hta')) {
      return PdfColors.red700;
    }
    if (value.contains('baja') || value.contains('low') || value.contains('elevada')) {
      return PdfColors.orange700;
    }
    return PdfColors.blueGrey800;
  }

  List<String> _generateInsights(List<PressureReading> sortedReadings) {
    if (sortedReadings.isEmpty) {
      return [
        'No hay suficientes datos para generar análisis automático.',
        'Se recomienda registrar mediciones de forma continua.',
      ];
    }

    final avgSystolic = sortedReadings
            .map((r) => r.systolic)
            .reduce((a, b) => a + b) /
        sortedReadings.length;
    final avgDiastolic = sortedReadings
            .map((r) => r.diastolic)
            .reduce((a, b) => a + b) /
        sortedReadings.length;

    final highCount = sortedReadings
        .where((r) => r.systolic >= 130 || r.diastolic >= 80)
        .length;
    final lowCount = sortedReadings
        .where((r) => r.systolic < 90 || r.diastolic < 60)
        .length;

    final window = sortedReadings.length >= 3 ? 3 : 1;
    final firstSlice = sortedReadings.take(window).toList();
    final lastSlice = sortedReadings.sublist(sortedReadings.length - window);

    final firstSys =
        firstSlice.map((r) => r.systolic).reduce((a, b) => a + b) / window;
    final firstDia =
        firstSlice.map((r) => r.diastolic).reduce((a, b) => a + b) / window;
    final lastSys =
        lastSlice.map((r) => r.systolic).reduce((a, b) => a + b) / window;
    final lastDia =
        lastSlice.map((r) => r.diastolic).reduce((a, b) => a + b) / window;

    final isIncreasing = (lastSys - firstSys) > 2 || (lastDia - firstDia) > 2;
    final isDecreasing = (firstSys - lastSys) > 2 || (firstDia - lastDia) > 2;
    final trend = isIncreasing
        ? 'Tendencia en aumento.'
        : isDecreasing
            ? 'Tendencia en descenso.'
            : 'Tendencia estable.';

    final insights = <String>[
      'Promedio reciente: ${avgSystolic.toStringAsFixed(1)}/${avgDiastolic.toStringAsFixed(1)} mmHg.',
    ];

    if (highCount == 0 && lowCount == 0) {
      insights.add('Presión arterial dentro de rango normal en la mayoría de registros.');
    } else {
      if (highCount > 0) {
        insights.add('Se detectaron $highCount lecturas elevadas.');
      }
      if (lowCount > 0) {
        insights.add('Se detectaron $lowCount lecturas bajas.');
      }
    }

    insights.add(trend);
    insights.add('Se recomienda monitoreo continuo y seguimiento regular.');
    return insights;
  }

  pw.Widget _insightBullet(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '• ',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey800,
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              text,
              style: const pw.TextStyle(
                fontSize: 10.5,
                color: PdfColors.blueGrey900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> shareFile(String filePath) async {
    await Share.shareXFiles(
      [XFile(filePath)],
      subject: 'PulseTrack - Blood Pressure Report',
    );
  }

  Future<Directory> _getExportDirectory() async {
    final downloads = await getDownloadsDirectory();
    if (downloads != null) {
      return downloads;
    }
    return getApplicationDocumentsDirectory();
  }

  String _humanDateTime(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  String _shortDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month';
  }

  String _dateTag(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year$month$day';
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }
}

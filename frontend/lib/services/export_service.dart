import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'api_service.dart';
import '../models/task.dart';

import 'export_platform_io.dart'
    if (dart.library.html) 'export_platform_web.dart';

class ExportService {
  // Brand palette
  static const _primary      = PdfColor(0.310, 0.275, 0.898); // #4F46E5 Indigo
  static const _primaryLight = PdfColor(0.933, 0.945, 1.000); // #EEF2FF
  static const _success      = PdfColor(0.063, 0.725, 0.506); // #10B981 Emerald
  static const _successLight = PdfColor(0.820, 0.980, 0.898); // #D1FAE5
  static const _warning      = PdfColor(0.961, 0.620, 0.043); // #F59E0B Amber
  static const _warningLight = PdfColor(0.996, 0.953, 0.780); // #FEF3C7
  static const _danger       = PdfColor(0.937, 0.267, 0.267); // #EF4444 Red
  static const _dangerLight  = PdfColor(0.996, 0.886, 0.886); // #FEE2E2
  static const _rowAlt       = PdfColor(0.973, 0.976, 0.984); // #F8F9FA

  static Future<void> promptAndExport(BuildContext context) async {
    final format = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export Format'),
        content: const Text('Choose the format to export your tasks.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'csv'), child: const Text('CSV')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'pdf'), child: const Text('PDF')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    );

    if (format == null) return;

    final tasks = await ApiService.getTasks();
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());

    Uint8List bytes;
    String mime;
    String name;

    if (format == 'csv') {
      bytes = Uint8List.fromList(_buildCsv(tasks).codeUnits);
      mime = 'text/csv';
      name = 'tasks_$stamp.csv';
    } else {
      bytes = Uint8List.fromList(await _buildPdf(tasks));
      mime = 'application/pdf';
      name = 'tasks_$stamp.pdf';
    }

    if (kIsWeb) {
      await saveFile(bytes, name, mime);
    } else {
      final path = await saveFile(bytes, name, mime);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved: $path'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // CSV
  // ---------------------------------------------------------------------------

  static String _buildCsv(List<Task> tasks) {
    final fmt = DateFormat('yyyy-MM-dd HH:mm');
    final buf = StringBuffer();
    buf.writeln('ID,Title,Description,Category,Priority,Status,Due Date,Recurring,Est. (min),Actual (min),Created');
    for (final t in tasks) {
      buf.writeln([
        t.id, _esc(t.title), _esc(t.description), _esc(t.category),
        t.priority, t.status,
        t.dueDatetime != null ? fmt.format(t.dueDatetime!) : '',
        t.isRecurring, t.estimatedMinutes, t.actualMinutes,
        fmt.format(t.createdAt),
      ].join(','));
    }
    return buf.toString();
  }

  static String _esc(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  // ---------------------------------------------------------------------------
  // PDF
  // ---------------------------------------------------------------------------

  static Future<List<int>> _buildPdf(List<Task> tasks) async {
    final doc = pw.Document();
    final dateFmt = DateFormat('MMM d, yyyy');
    final now = DateTime.now();
    final nowStr = DateFormat('MMMM d, yyyy  |  HH:mm').format(now);

    final total = tasks.length;
    final done = tasks.where((t) => t.isCompleted).length;
    final inProgress = tasks.where((t) => t.status == 'in_progress').length;
    final overdue = tasks.where((t) =>
        !t.isCompleted && t.dueDatetime != null && t.dueDatetime!.isBefore(now)).length;

    final categoryMap = <String, int>{};
    for (final t in tasks) {
      categoryMap[t.category] = (categoryMap[t.category] ?? 0) + 1;
    }

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(0, 0, 0, 0),
      header: (ctx) => _pageHeader(nowStr, ctx.pageNumber > 1),
      footer: (ctx) => _pageFooter(ctx),
      build: (ctx) => [
        pw.SizedBox(height: 24),
        // ── Stat cards ──────────────────────────────────────────────────────
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 32),
          child: pw.Row(children: [
            _statCard('Total',       '$total',      _primary,  _primaryLight),
            pw.SizedBox(width: 10),
            _statCard('Completed',   '$done',       _success,  _successLight),
            pw.SizedBox(width: 10),
            _statCard('In Progress', '$inProgress', _warning,  _warningLight),
            pw.SizedBox(width: 10),
            _statCard('Overdue',     '$overdue',    _danger,   _dangerLight),
          ]),
        ),
        pw.SizedBox(height: 16),
        // ── Completion progress ──────────────────────────────────────────────
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 32),
          child: _progressSection(done, total),
        ),
        pw.SizedBox(height: 16),
        // ── Category breakdown ───────────────────────────────────────────────
        if (categoryMap.isNotEmpty) ...[
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 32),
            child: _categorySection(categoryMap),
          ),
          pw.SizedBox(height: 16),
        ],
        // ── Section label ────────────────────────────────────────────────────
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 32),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('All Tasks',
                  style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: _primary)),
              pw.Text('${tasks.length} task${tasks.length == 1 ? '' : 's'}',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            ],
          ),
        ),
        pw.SizedBox(height: 8),
        // ── Task table ───────────────────────────────────────────────────────
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 32),
          child: _taskTable(tasks, dateFmt, now),
        ),
        pw.SizedBox(height: 24),
      ],
    ));

    return doc.save();
  }

  // ── Page header ─────────────────────────────────────────────────────────────

  static pw.Widget _pageHeader(String dateStr, bool isContinuation) {
    if (isContinuation) {
      return pw.Container(
        height: 38,
        color: _primary,
        padding: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 10),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('MY TASKS REPORT',
                style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                    letterSpacing: 1.5)),
            pw.Text(dateStr,
                style: const pw.TextStyle(
                    fontSize: 8, color: PdfColor(1, 1, 1, 0.75))),
          ],
        ),
      );
    }

    return pw.Container(
      color: _primary,
      padding: const pw.EdgeInsets.fromLTRB(32, 28, 32, 22),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('MY TASKS REPORT',
                  style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                      letterSpacing: 1.0)),
              pw.SizedBox(height: 4),
              pw.Text('Personal productivity overview',
                  style: const pw.TextStyle(
                      fontSize: 10, color: PdfColor(1, 1, 1, 0.75))),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('Generated on',
                  style: const pw.TextStyle(
                      fontSize: 8, color: PdfColor(1, 1, 1, 0.65))),
              pw.SizedBox(height: 2),
              pw.Text(dateStr,
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white)),
            ]),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Container(height: 1, color: const PdfColor(1, 1, 1, 0.25)),
      ]),
    );
  }

  // ── Page footer ─────────────────────────────────────────────────────────────

  static pw.Widget _pageFooter(pw.Context ctx) {
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(32, 8, 32, 12),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('My Journal App',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey400)),
          pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey400)),
        ],
      ),
    );
  }

  // ── Stat card ───────────────────────────────────────────────────────────────

  static pw.Widget _statCard(
      String label, String value, PdfColor accent, PdfColor bg) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: pw.BoxDecoration(
          color: bg,
          border: pw.Border(left: pw.BorderSide(color: accent, width: 4)),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 20, fontWeight: pw.FontWeight.bold, color: accent)),
          pw.SizedBox(height: 2),
          pw.Text(label,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        ]),
      ),
    );
  }

  // ── Progress bar ────────────────────────────────────────────────────────────

  static pw.Widget _progressSection(int done, int total) {
    final pct = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    final pctStr = '${(pct * 100).round()}%';

    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Completion Progress',
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700)),
          pw.Text(pctStr,
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: _success)),
        ],
      ),
      pw.SizedBox(height: 5),
      pw.LayoutBuilder(
        builder: (pw.Context context, pw.BoxConstraints? constraints) {
          final totalW = constraints?.maxWidth ?? 400;
          final filledW = totalW * pct;
          return pw.Stack(children: [
            pw.Container(
              width: totalW,
              height: 8,
              decoration: pw.BoxDecoration(
                color: PdfColors.grey200,
                borderRadius: pw.BorderRadius.circular(4),
              ),
            ),
            if (filledW > 0)
              pw.Container(
                width: filledW,
                height: 8,
                decoration: pw.BoxDecoration(
                  color: _success,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
              ),
          ]);
        },
      ),
    ]);
  }

  // ── Category chips ──────────────────────────────────────────────────────────

  static pw.Widget _categorySection(Map<String, int> map) {
    final entries = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text('By Category',
          style: pw.TextStyle(
              fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
      pw.SizedBox(height: 6),
      pw.Wrap(
        spacing: 6,
        runSpacing: 4,
        children: entries.map((e) {
          final name = e.key.isNotEmpty
              ? e.key[0].toUpperCase() + e.key.substring(1)
              : e.key;
          return pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: pw.BoxDecoration(
              color: _primaryLight,
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Text('$name  ${e.value}',
                style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: _primary)),
          );
        }).toList(),
      ),
    ]);
  }

  // ── Task table ──────────────────────────────────────────────────────────────

  static pw.Widget _taskTable(List<Task> tasks, DateFormat dateFmt, DateTime now) {
    final headerStyle = pw.TextStyle(
        fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white);

    return pw.Table(
      border: pw.TableBorder(
        horizontalInside: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.8),
        1: pw.FlexColumnWidth(1.0),
        2: pw.FlexColumnWidth(0.9),
        3: pw.FlexColumnWidth(1.1),
        4: pw.FlexColumnWidth(1.3),
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _primary),
          children: ['Title', 'Category', 'Priority', 'Status', 'Due Date']
              .map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8, vertical: 7),
                    child: pw.Text(h, style: headerStyle),
                  ))
              .toList(),
        ),
        // Data rows
        ...tasks.asMap().entries.map((entry) {
          final i = entry.key;
          final t = entry.value;
          final bg = i.isEven ? PdfColors.white : _rowAlt;

          // Priority
          PdfColor priColor, priBg;
          String priLabel;
          if (t.priority == 'high') {
            priColor = _danger; priBg = _dangerLight; priLabel = 'High';
          } else if (t.priority == 'low') {
            priColor = _success; priBg = _successLight; priLabel = 'Low';
          } else {
            priColor = _warning; priBg = _warningLight; priLabel = 'Medium';
          }

          // Status
          PdfColor statusColor;
          String statusLabel;
          if (t.isCompleted) {
            statusColor = _success; statusLabel = 'Done';
          } else if (t.status == 'in_progress') {
            statusColor = _primary; statusLabel = 'In Progress';
          } else {
            statusColor = PdfColors.grey600; statusLabel = 'To Do';
          }

          final isOverdue = !t.isCompleted &&
              t.dueDatetime != null &&
              t.dueDatetime!.isBefore(now);

          final categoryStr = t.category.isNotEmpty
              ? t.category[0].toUpperCase() + t.category.substring(1)
              : t.category;

          return pw.TableRow(
            decoration: pw.BoxDecoration(color: bg),
            children: [
              // Title
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: pw.Text(t.title,
                    style: pw.TextStyle(
                        fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
              ),
              // Category
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: pw.Text(categoryStr,
                    style: const pw.TextStyle(fontSize: 7.5)),
              ),
              // Priority badge
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: pw.BoxDecoration(
                    color: priBg,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(priLabel,
                      style: pw.TextStyle(
                          fontSize: 7,
                          fontWeight: pw.FontWeight.bold,
                          color: priColor)),
                ),
              ),
              // Status
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: pw.Text(statusLabel,
                    style: pw.TextStyle(
                        fontSize: 7.5,
                        fontWeight: pw.FontWeight.bold,
                        color: statusColor)),
              ),
              // Due date (red if overdue)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: pw.Text(
                  t.dueDatetime != null ? dateFmt.format(t.dueDatetime!) : '—',
                  style: pw.TextStyle(
                    fontSize: 7.5,
                    color: isOverdue ? _danger : PdfColors.black,
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }
}

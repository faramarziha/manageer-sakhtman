
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/models.dart';
import '../utils/persian.dart';
import 'billing_service.dart';

/// خروجی تولیدشده گزارش
class ReportFile {
  final Uint8List bytes;
  final String fileName;
  final String mimeType;

  const ReportFile({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

  int get sizeKb => (bytes.lengthInBytes / 1024).ceil();
}

/// ---------------------------------------------------------------------------
/// سرویس تولید بیلان مالی ساختمان (خروجی PDF و اکسل)
///
/// معادل اندپوینت: GET /api/v1/manager/reports/balance
///
/// خروجی PDF ممهور به مهر هیئت‌مدیره جهت ارائه در جلسات مجمع عمومی
/// ساختمان تولید می‌شود و ترازنامه به تفکیک صندوق جاری و عمرانی
/// ارائه می‌گردد.
/// ---------------------------------------------------------------------------
class ReportService {
  const ReportService._();

  /// مسیر فونت فارسی برای رندر صحیح متن راست‌چین در PDF
  static const String _fontRegular = 'assets/fonts/Vazirmatn-Regular.ttf';
  static const String _fontBold = 'assets/fonts/Vazirmatn-Bold.ttf';

  // =========================================================================
  // بخش ۱ - خروجی PDF ترازنامه
  // =========================================================================

  /// تولید بیلان مالی PDF ممهور به مهر هیئت‌مدیره
  static Future<ReportFile> buildBalancePdf({
    required Building building,
    required String period,
    required FundBalance balance,
    required List<Expense> expenses,
    required List<Invoice> invoices,
    required List<Unit> units,
    String? managerName,
  }) async {
    final regular = pw.Font.ttf(await rootBundle.load(_fontRegular));
    final bold = pw.Font.ttf(await rootBundle.load(_fontBold));

    final theme = pw.ThemeData.withFont(base: regular, bold: bold);
    final doc = pw.Document(
      title: 'بیلان مالی ${building.name} - $period',
      author: 'سامانه مدیریت ساختمان',
    );

    doc.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(28),
        header: (ctx) => _pdfHeader(building, period),
        footer: (ctx) => _pdfFooter(ctx),
        build: (ctx) => [
          // ---------- خلاصه ترازنامه ----------
          _pdfSectionTitle('خلاصه ترازنامه مالی'),
          pw.SizedBox(height: 8),
          _pdfBalanceTable(balance),
          pw.SizedBox(height: 18),

          // ---------- تفکیک صندوق‌ها ----------
          _pdfSectionTitle('تفکیک قانونی صندوق جاری و عمرانی'),
          pw.SizedBox(height: 8),
          _pdfFundTable(balance),
          pw.SizedBox(height: 18),

          // ---------- ریز هزینه‌ها ----------
          _pdfSectionTitle('ریز هزینه‌های ثبت‌شده دوره'),
          pw.SizedBox(height: 8),
          _pdfExpenseTable(expenses),
          pw.SizedBox(height: 18),

          // ---------- وضعیت وصول واحدها ----------
          _pdfSectionTitle('وضعیت وصول مطالبات واحدها'),
          pw.SizedBox(height: 8),
          _pdfUnitTable(units: units, invoices: invoices),
          pw.SizedBox(height: 24),

          // ---------- مهر و امضا ----------
          _pdfSignature(building, managerName),
        ],
      ),
    );

    final bytes = await doc.save();
    return ReportFile(
      bytes: bytes,
      fileName: 'balance_${_slug(building.name)}_${_slug(period)}.pdf',
      mimeType: 'application/pdf',
    );
  }

  static pw.Widget _pdfHeader(Building building, String period) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(building.name,
                      style: pw.TextStyle(
                          fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 2),
                  pw.Text('${building.city} - ${building.address}',
                      style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('بیلان مالی ساختمان',
                      style: pw.TextStyle(
                          fontSize: 13, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 2),
                  pw.Text('دوره: $period',
                      style: const pw.TextStyle(fontSize: 9)),
                  pw.Text('تاریخ صدور: ${Persian.shortDate(DateTime.now())}',
                      style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Divider(thickness: 1.2, color: PdfColors.teal700),
          pw.SizedBox(height: 8),
        ],
      );

  static pw.Widget _pdfFooter(pw.Context ctx) => pw.Column(
        children: [
          pw.Divider(color: PdfColors.grey400),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'تهیه‌شده توسط سامانه مدیریت ساختمان',
                style:
                    const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
              pw.Text(
                'صفحه ${Persian.digits(ctx.pageNumber)} از ${Persian.digits(ctx.pagesCount)}',
                style:
                    const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
            ],
          ),
        ],
      );

  static pw.Widget _pdfSectionTitle(String title) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: const pw.BoxDecoration(color: PdfColors.teal50),
        child: pw.Text(title,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      );

  static pw.Widget _pdfBalanceTable(FundBalance b) => pw.TableHelper.fromTextArray(
        headerStyle:
            pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        cellStyle: const pw.TextStyle(fontSize: 9),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
        cellAlignment: pw.Alignment.center,
        columnWidths: {
          0: const pw.FlexColumnWidth(2),
          1: const pw.FlexColumnWidth(1.4),
        },
        headers: ['شرح', 'مبلغ (تومان)'],
        data: [
          ['مجموع وصولی تایید‌شده', Persian.money(b.totalCollected)],
          ['مجموع مطالبات وصول‌نشده', Persian.money(b.totalReceivable)],
          ['مجموع هزینه‌های دوره', Persian.money(b.totalExpense)],
          ['مانده کل صندوق', Persian.money(b.totalBalance)],
          [
            'درصد وصول مطالبات',
            '${Persian.digits((b.collectionRate * 100).round())}٪'
          ],
        ],
      );

  static pw.Widget _pdfFundTable(FundBalance b) => pw.TableHelper.fromTextArray(
        headerStyle:
            pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        cellStyle: const pw.TextStyle(fontSize: 9),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
        cellAlignment: pw.Alignment.center,
        headers: ['صندوق', 'درآمد', 'هزینه', 'مانده'],
        data: [
          [
            'جاری (مصرفی)',
            Persian.money(b.currentFundIncome),
            Persian.money(b.currentFundExpense),
            Persian.money(b.currentBalance),
          ],
          [
            'عمرانی (اساسی)',
            Persian.money(b.reserveFundIncome),
            Persian.money(b.reserveFundExpense),
            Persian.money(b.reserveBalance),
          ],
        ],
      );

  static pw.Widget _pdfExpenseTable(List<Expense> expenses) {
    if (expenses.isEmpty) {
      return pw.Text('هزینه‌ای در این دوره ثبت نشده است.',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700));
    }
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 8.5),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellAlignment: pw.Alignment.center,
      headers: ['ردیف', 'عنوان هزینه', 'سرفصل', 'دسته', 'تاریخ', 'مبلغ'],
      data: [
        for (var i = 0; i < expenses.length; i++)
          [
            Persian.digits(i + 1),
            expenses[i].title,
            expenses[i].expenseType.shortLabel,
            expenses[i].category.label,
            Persian.numericDate(expenses[i].date),
            Persian.money(expenses[i].amount),
          ],
      ],
    );
  }

  static pw.Widget _pdfUnitTable({
    required List<Unit> units,
    required List<Invoice> invoices,
  }) {
    if (units.isEmpty) {
      return pw.Text('واحدی ثبت نشده است.',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700));
    }
    final sorted = [...units]..sort((a, b) => a.number.compareTo(b.number));
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 8.5),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellAlignment: pw.Alignment.center,
      headers: [
        'واحد',
        'مالک',
        'متراژ',
        'نفرات',
        'وضعیت',
        'پرداختی',
        'بدهی'
      ],
      data: [
        for (final u in sorted)
          [
            Persian.digits(u.number),
            u.ownerName,
            Persian.digits(u.area.toStringAsFixed(0)),
            Persian.digits(u.residentCount),
            u.isVacant ? 'خالی' : 'ساکن',
            Persian.money(invoices
                .where((i) => i.unitId == u.id && i.status.isSettled)
                .fold(0, (s, i) => s + i.amount)),
            Persian.money(BillingEngine.outstandingDebt(u.id, invoices)),
          ],
      ],
    );
  }

  static pw.Widget _pdfSignature(Building building, String? managerName) =>
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('تایید و امضای هیئت‌مدیره',
                  style: pw.TextStyle(
                      fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.Text(
                'این سند جهت ارائه در جلسه مجمع عمومی ساختمان تنظیم شده است.',
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.SizedBox(height: 26),
              pw.Text('نام مدیر: ${managerName ?? building.managerName}',
                  style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 4),
              pw.Text('امضا: ....................................',
                  style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
          // مهر هیئت‌مدیره
          pw.Container(
            width: 108,
            height: 108,
            decoration: pw.BoxDecoration(
              shape: pw.BoxShape.circle,
              border: pw.Border.all(color: PdfColors.teal700, width: 2),
            ),
            child: pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text('مهر هیئت‌مدیره',
                      style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.teal700)),
                  pw.SizedBox(height: 4),
                  pw.Container(
                    width: 74,
                    child: pw.Text(
                      building.name,
                      textAlign: pw.TextAlign.center,
                      maxLines: 2,
                      style: pw.TextStyle(
                          fontSize: 7.5, color: PdfColors.teal800),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(Persian.numericDate(DateTime.now()),
                      style: const pw.TextStyle(
                          fontSize: 7, color: PdfColors.teal700)),
                ],
              ),
            ),
          ),
        ],
      );

  // =========================================================================
  // بخش ۲ - خروجی اکسل ترازنامه
  // =========================================================================

  /// تولید بیلان مالی در قالب فایل اکسل چند‌شیتی
  static ReportFile buildBalanceExcel({
    required Building building,
    required String period,
    required FundBalance balance,
    required List<Expense> expenses,
    required List<Invoice> invoices,
    required List<Unit> units,
  }) {
    final book = Excel.createExcel();

    // ---------- شیت ۱: خلاصه ترازنامه ----------
    final summary = book['خلاصه ترازنامه'];
    book.delete('Sheet1');

    _row(summary, ['بیلان مالی ساختمان']);
    _row(summary, ['نام ساختمان', building.name]);
    _row(summary, ['نشانی', '${building.city} - ${building.address}']);
    _row(summary, ['دوره گزارش', period]);
    _row(summary, ['تاریخ صدور', Persian.shortDate(DateTime.now())]);
    _row(summary, []);
    _row(summary, ['شرح', 'مبلغ (تومان)']);
    _row(summary, ['مجموع وصولی تاییدشده', balance.totalCollected]);
    _row(summary, ['مجموع مطالبات وصول‌نشده', balance.totalReceivable]);
    _row(summary, ['مجموع هزینه‌های دوره', balance.totalExpense]);
    _row(summary, ['مانده صندوق جاری', balance.currentBalance]);
    _row(summary, ['مانده صندوق عمرانی', balance.reserveBalance]);
    _row(summary, ['مانده کل صندوق', balance.totalBalance]);
    _row(summary,
        ['درصد وصول مطالبات', '${(balance.collectionRate * 100).round()}%']);

    // ---------- شیت ۲: تفکیک صندوق‌ها ----------
    final funds = book['تفکیک صندوق'];
    _row(funds, ['صندوق', 'درآمد', 'هزینه', 'مانده']);
    _row(funds, [
      'جاری (مصرفی)',
      balance.currentFundIncome,
      balance.currentFundExpense,
      balance.currentBalance,
    ]);
    _row(funds, [
      'عمرانی (اساسی)',
      balance.reserveFundIncome,
      balance.reserveFundExpense,
      balance.reserveBalance,
    ]);

    // ---------- شیت ۳: ریز هزینه‌ها ----------
    final exp = book['ریز هزینه‌ها'];
    _row(exp, ['ردیف', 'عنوان', 'سرفصل قانونی', 'دسته', 'تاریخ', 'مبلغ', 'فاکتور']);
    for (var i = 0; i < expenses.length; i++) {
      final e = expenses[i];
      _row(exp, [
        i + 1,
        e.title,
        e.expenseType.label,
        e.category.label,
        Persian.numericDate(e.date),
        e.amount,
        e.hasInvoiceImage ? 'دارد' : 'ندارد',
      ]);
    }

    // ---------- شیت ۴: وضعیت واحدها ----------
    final unitSheet = book['وضعیت واحدها'];
    _row(unitSheet, [
      'واحد',
      'طبقه',
      'مالک',
      'متراژ',
      'نفرات',
      'پارکینگ',
      'وضعیت سکونت',
      'پرداختی',
      'بدهی',
    ]);
    final sorted = [...units]..sort((a, b) => a.number.compareTo(b.number));
    for (final u in sorted) {
      _row(unitSheet, [
        u.number,
        u.floor,
        u.ownerName,
        u.area,
        u.residentCount,
        u.parkingCount,
        u.isVacant ? 'خالی' : 'ساکن',
        invoices
            .where((i) => i.unitId == u.id && i.status.isSettled)
            .fold<int>(0, (s, i) => s + i.amount),
        BillingEngine.outstandingDebt(u.id, invoices),
      ]);
    }

    // ---------- شیت ۵: ریز صورتحساب‌ها ----------
    final invSheet = book['صورتحساب‌ها'];
    _row(invSheet, [
      'شناسه قبض',
      'واحد',
      'عنوان',
      'دوره',
      'گیرنده',
      'مبلغ',
      'وضعیت',
      'روش پرداخت',
      'مهلت',
      'تاریخ پرداخت',
      'شماره مرجع',
    ]);
    for (final i in invoices) {
      final unit = units.where((u) => u.id == i.unitId).firstOrNull;
      _row(invSheet, [
        i.billId,
        unit?.number ?? '-',
        i.title,
        i.period,
        i.recipientRole.label,
        i.amount,
        i.status.label,
        i.method.shortLabel,
        Persian.numericDate(i.dueDate),
        i.paidAt != null ? Persian.numericDate(i.paidAt!) : '-',
        i.rrn ?? '-',
      ]);
    }

    final encoded = book.encode() ?? <int>[];
    return ReportFile(
      bytes: Uint8List.fromList(encoded),
      fileName: 'balance_${_slug(building.name)}_${_slug(period)}.xlsx',
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  /// افزودن یک ردیف به شیت اکسل
  static void _row(Sheet sheet, List<Object?> values) {
    sheet.appendRow(values.map(_cell).toList());
  }

  static CellValue? _cell(Object? v) {
    if (v == null) return null;
    if (v is int) return IntCellValue(v);
    if (v is double) return DoubleCellValue(v);
    return TextCellValue(v.toString());
  }

  // =========================================================================
  // بخش ۳ - رسید الکترونیکی پرداخت
  // =========================================================================

  /// تولید رسید الکترونیکی PDF برای تراکنش موفق
  static Future<ReportFile> buildPaymentReceiptPdf({
    required Building building,
    required Unit unit,
    required Invoice invoice,
  }) async {
    final regular = pw.Font.ttf(await rootBundle.load(_fontRegular));
    final bold = pw.Font.ttf(await rootBundle.load(_fontBold));
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        pageFormat: PdfPageFormat.a5,
        textDirection: pw.TextDirection.rtl,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Center(
              child: pw.Text('رسید الکترونیکی پرداخت',
                  style: pw.TextStyle(
                      fontSize: 15, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 4),
            pw.Center(
              child: pw.Text(building.name,
                  style: const pw.TextStyle(fontSize: 10)),
            ),
            pw.SizedBox(height: 12),
            pw.Divider(color: PdfColors.teal700, thickness: 1.2),
            pw.SizedBox(height: 10),
            _receiptRow('واحد', 'شماره ${Persian.digits(unit.number)}'),
            _receiptRow('نام مالک/ساکن', unit.ownerName),
            _receiptRow('عنوان صورتحساب', invoice.title),
            _receiptRow('دوره', invoice.period),
            _receiptRow('گیرنده صورتحساب', invoice.recipientRole.label),
            _receiptRow('شناسه قبض', Persian.digits(invoice.billId)),
            _receiptRow('شناسه پرداخت', Persian.digits(invoice.paymentId)),
            _receiptRow('روش پرداخت', invoice.method.label),
            if (invoice.rrn != null)
              _receiptRow('شماره مرجع بانکی (RRN)', Persian.digits(invoice.rrn!)),
            if (invoice.cardLast4 != null)
              _receiptRow('کارت پرداخت',
                  '**** **** **** ${Persian.digits(invoice.cardLast4!)}'),
            _receiptRow(
                'تاریخ پرداخت',
                invoice.paidAt != null
                    ? Persian.fullDate(invoice.paidAt!)
                    : '-'),
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: const pw.BoxDecoration(color: PdfColors.teal50),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('مبلغ پرداخت‌شده',
                      style: pw.TextStyle(
                          fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.Text(Persian.toman(invoice.amount),
                      style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.teal800)),
                ],
              ),
            ),
            pw.Spacer(),
            pw.Center(
              child: pw.Text(
                'این رسید به صورت الکترونیکی صادر شده و فاقد نیاز به مهر و امضا است.',
                style:
                    const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
              ),
            ),
          ],
        ),
      ),
    );

    final bytes = await doc.save();
    return ReportFile(
      bytes: bytes,
      fileName: 'receipt_${invoice.billId}.pdf',
      mimeType: 'application/pdf',
    );
  }

  static pw.Widget _receiptRow(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3.5),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label,
                style:
                    const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            pw.Text(value,
                style:
                    pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          ],
        ),
      );

  // =========================================================================
  // ابزارهای کمکی
  // =========================================================================

  /// تبدیل نام فارسی به شناسه لاتین امن برای نام فایل
  static String _slug(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isNotEmpty && digits.length >= 4) return digits;
    // در غیر این صورت از هش کوتاه استفاده می‌کنیم
    var hash = 0;
    for (final c in input.codeUnits) {
      hash = (hash * 31 + c) & 0xFFFFFF;
    }
    return hash.toRadixString(16);
  }
}

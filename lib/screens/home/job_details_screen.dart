import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../main.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/custom_card.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/widgets/invoice_receipt_card.dart';

class JobDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> job;
  final VoidCallback onJobUpdated;

  const JobDetailsScreen({
    super.key,
    required this.job,
    required this.onJobUpdated,
  });

  @override
  State<JobDetailsScreen> createState() => _ShopDetailsScreenState();
}

class _ShopDetailsScreenState extends State<JobDetailsScreen> {
  late String _status;
  late TextEditingController _workController;
  late TextEditingController _reviewController;
  double _currentAmountPaid = 0.0;
  List<Map<String, dynamic>> _billItems = [];
  bool _isLoadingBills = true;
  bool _isSavingJob = false;
  bool _isGeneratingPdf = false;
  bool _isSharing = false;
  String _paymentMode = 'Cash';
  String _shopName = 'Workshop';
  String _shopLocation = '';
  String _shopPhone = '';
  int _localJobCount = 0;

  @override
  void initState() {
    super.initState();
    _status = widget.job['status'] ?? 'Pending';
    _workController =
        TextEditingController(text: widget.job['work_description'] ?? '');
    _reviewController =
        TextEditingController(text: widget.job['review'] ?? '');
    _currentAmountPaid =
        double.tryParse(widget.job['amount_paid']?.toString() ?? '0') ?? 0.0;
    _paymentMode = widget.job['payment_mode'] ?? 'Cash';
    _fetchBillItems();
    _fetchShopData();
    _fetchLocalJobCount();
  }

  Future<void> _fetchLocalJobCount() async {
    try {
      final response = await supabase
          .from('jobs')
          .select('id')
          .eq('shop_id', widget.job['shop_id'])
          .lte('created_at', widget.job['created_at']);
      if (mounted) {
        setState(() {
          _localJobCount = response.length;
        });
      }
    } catch (_) {}
  }

  String _getBillNo({DateTime? date}) {
    final d = date ?? DateTime.now();
    final yearStr = d.year.toString();
    final jobId = _localJobCount > 0 ? _localJobCount.toString() : (widget.job['id'] ?? '').toString();

    final cleanName = _shopName.trim();
    String shortForm = 'MF';
    if (cleanName.isNotEmpty && cleanName.toLowerCase() != 'workshop') {
      final parts = cleanName.split(RegExp(r'\s+'));
      if (parts.length > 1) {
        shortForm = parts.map((p) => p.isNotEmpty ? p[0] : '').join('').toUpperCase();
      } else if (cleanName.length >= 2) {
        shortForm = cleanName.substring(0, cleanName.length >= 3 ? 3 : 2).toUpperCase();
      } else {
        shortForm = cleanName.toUpperCase();
      }
    }

    return '$jobId-$shortForm-$yearStr';
  }

  Future<void> _fetchShopData() async {
    try {
      final user = supabase.auth.currentUser;
      final shopData =
          await supabase.from('shops').select().eq('id', user?.id ?? '').maybeSingle();
      if (shopData != null && mounted) {
        setState(() {
          _shopName = shopData['shop_name'] ?? 'Workshop';
          _shopLocation = shopData['location'] ?? '';
          _shopPhone = shopData['phone'] ?? '';
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchBillItems() async {
    final jobId = widget.job['id'];
    if (jobId == null) {
      if (mounted) setState(() => _isLoadingBills = false);
      return;
    }

    try {
      final data = await supabase
          .from('bill_items')
          .select()
          .eq('job_id', jobId)
          .order('id', ascending: true);

      if (mounted) {
        setState(() {
          _billItems = List<Map<String, dynamic>>.from(data);
          _isLoadingBills = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingBills = false);
    }
  }



  Future<void> _updateWorkDescription() async {
    setState(() => _isSavingJob = true);
    try {
      await supabase.from('jobs').update({
        'work_description': _workController.text.trim(),
        'review': _reviewController.text.trim(),
      }).eq('id', widget.job['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Details saved successfully!'),
            backgroundColor: AppColors.statusCompleted,
          ),
        );
      }
      widget.onJobUpdated();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving work description: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingJob = false);
    }
  }

  Future<void> _saveFullBill({bool autoShare = false}) async {
    setState(() => _isSavingJob = true);
    try {
      final jobId = widget.job['id'];
      if (jobId != null) {
        await supabase.from('jobs').update({
          'work_description': _workController.text.trim(),
          'review': _reviewController.text.trim(),
          'status': _status,
          'amount_paid': _currentAmountPaid,
          'payment_mode': _paymentMode,
        }).eq('id', jobId);
      }

      if (autoShare) {
        await _sendWhatsAppUpdate();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bill & Invoice saved successfully!'),
            backgroundColor: AppColors.statusCompleted,
          ),
        );
        widget.onJobUpdated();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving bill: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingJob = false);
    }
  }

  Future<pw.Document> _buildPdf() async {
    final user = supabase.auth.currentUser;
    final shopData =
        await supabase.from('shops').select().eq('id', user?.id ?? '').maybeSingle();

    final shopName = ((shopData?['shop_name'] ?? _shopName) as String).toUpperCase();
    final place = (shopData?['location'] ?? _shopLocation) as String;
    final shopPhone = (shopData?['phone'] ?? _shopPhone) as String;

    final pdf = pw.Document();

    final customerName = widget.job['customer_name'] ?? 'Unknown Customer';
    final customerPhone = widget.job['customer_phone'] ?? '';
    final vehicleNo = widget.job['vehicle_no'] ?? '';
    final modelName = widget.job['model_name'] ?? '';
    final date = DateTime.now();
    final billNo = _getBillNo(date: date);
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

    final totalAmount = _totalSellingPrice;
    final isFullyPaid = _currentAmountPaid >= totalAmount && totalAmount > 0;
    final isPartiallyPaid = _currentAmountPaid > 0 && _currentAmountPaid < totalAmount;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(12),
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 1),
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                // 1. Header Section
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#0F172A'),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'AUTOMOTIVE SERVICE RECEIPT',
                        style: pw.TextStyle(
                          color: PdfColor.fromHex('#94A3B8'),
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        shopName,
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if (place.isNotEmpty || shopPhone.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(
                          [
                            if (place.isNotEmpty) place,
                            if (shopPhone.isNotEmpty) 'Phone: $shopPhone',
                          ].join('   -   '),
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            color: PdfColor.fromHex('#CBD5E1'),
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                pw.SizedBox(height: 10),

                // 2. Meta Info (Two-Column Grid)
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('BILL DETAILS',
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  color: PdfColor.fromHex('#64748B'),
                                  fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 2),
                          pw.Text(billNo,
                              style: pw.TextStyle(
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColor.fromHex('#0F172A'))),
                          pw.SizedBox(height: 2),
                          pw.Text('Date: $dateStr',
                              style: pw.TextStyle(
                                  fontSize: 9, color: PdfColor.fromHex('#64748B'))),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('CUSTOMER',
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  color: PdfColor.fromHex('#64748B'),
                                  fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 2),
                          pw.Text(customerName,
                              style: pw.TextStyle(
                                  fontSize: 11,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColor.fromHex('#0F172A')),
                              textAlign: pw.TextAlign.right),
                          if (customerPhone.isNotEmpty) ...[
                            pw.SizedBox(height: 2),
                            pw.Text(customerPhone,
                                style: pw.TextStyle(
                                    fontSize: 9, color: PdfColor.fromHex('#64748B')),
                                textAlign: pw.TextAlign.right),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),

                // Vehicle details badge/chip
                if (modelName.isNotEmpty || vehicleNo.isNotEmpty)
                  pw.Container(
                    width: double.infinity,
                    padding:
                        const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#EFF6FF'),
                      borderRadius: pw.BorderRadius.circular(6),
                      border:
                          pw.Border.all(color: PdfColor.fromHex('#BFDBFE'), width: 1),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        [
                          if (modelName.isNotEmpty) modelName,
                          if (vehicleNo.isNotEmpty) vehicleNo,
                        ].join('   -   '),
                        style: pw.TextStyle(
                          color: PdfColor.fromHex('#1E40AF'),
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                pw.SizedBox(height: 10),

                // 3. Itemized Table
                pw.Container(
                  decoration: pw.BoxDecoration(
                    border:
                        pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 1),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    children: [
                      // Header Row
                      pw.Container(
                        color: PdfColor.fromHex('#F1F5F9'),
                        padding:
                            const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        child: pw.Row(
                          children: [
                            pw.Expanded(
                              flex: 3,
                              child: pw.Text(
                                'SERVICE / DESCRIPTION',
                                style: pw.TextStyle(
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColor.fromHex('#475569')),
                              ),
                            ),
                            pw.Expanded(
                              flex: 1,
                              child: pw.Text(
                                'AMOUNT (Rs.)',
                                textAlign: pw.TextAlign.right,
                                style: pw.TextStyle(
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColor.fromHex('#475569')),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Rows
                      ..._billItems.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final desc = item['description'] ?? 'Service';
                        final selling =
                            double.tryParse(item['selling_price'].toString()) ?? 0.0;
                        final isEven = index % 2 == 0;

                        return pw.Container(
                          color:
                              isEven ? PdfColors.white : PdfColor.fromHex('#F8FAFC'),
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 8, vertical: 5),
                          child: pw.Row(
                            children: [
                              pw.Expanded(
                                flex: 3,
                                child: pw.Text(desc,
                                    style: const pw.TextStyle(fontSize: 9)),
                              ),
                              pw.Expanded(
                                flex: 1,
                                child: pw.Text(selling.toStringAsFixed(2),
                                    textAlign: pw.TextAlign.right,
                                    style: pw.TextStyle(
                                        fontSize: 9,
                                        fontWeight: pw.FontWeight.bold)),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                pw.SizedBox(height: 10),

                // 4. Total Amount & Payment Badge Bar
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#0F172A'),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'TOTAL AMOUNT',
                            style: pw.TextStyle(
                                color: PdfColor.fromHex('#94A3B8'),
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold),
                          ),
                          pw.SizedBox(height: 2),
                          // Payment Badge Pill
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: pw.BoxDecoration(
                              color: isFullyPaid
                                  ? PdfColor.fromHex('#DCFCE7')
                                  : (isPartiallyPaid
                                      ? PdfColor.fromHex('#FEF3C7')
                                      : PdfColor.fromHex('#FEE2E2')),
                              borderRadius: pw.BorderRadius.circular(10),
                            ),
                            child: pw.Text(
                              isFullyPaid
                                  ? 'Paid via $_paymentMode'
                                  : (isPartiallyPaid
                                      ? 'Paid Rs.${_currentAmountPaid.toStringAsFixed(0)} ($_paymentMode)'
                                      : 'Unpaid'),
                              style: pw.TextStyle(
                                color: isFullyPaid
                                    ? PdfColor.fromHex('#15803D')
                                    : (isPartiallyPaid
                                        ? PdfColor.fromHex('#B45309')
                                        : PdfColor.fromHex('#B91C1C')),
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      pw.Text(
                        'Rs. ${totalAmount.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 10),

                // 5. Footer Line
                pw.Center(
                  child: pw.Text(
                    'Thank you for choosing us!  -  Drive Safe',
                    style: pw.TextStyle(
                        fontSize: 8,
                        color: PdfColor.fromHex('#64748B'),
                        fontStyle: pw.FontStyle.italic),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    return pdf;
  }

  Future<void> _generateInvoicePdf() async {
    setState(() => _isGeneratingPdf = true);
    try {
      final pdf = await _buildPdf();
      final jobId = widget.job['id'];
      final billNo = '#$jobId${DateTime.now().year}';

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Invoice_$billNo.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating PDF: $e')));
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  Future<String> _shortenUrl(String longUrl) async {
    try {
      final uri = Uri.parse('https://tinyurl.com/api-create.php?url=${Uri.encodeComponent(longUrl)}');
      final request = await HttpClient().getUrl(uri);
      final response = await request.close();
      if (response.statusCode == 200) {
        return await response.transform(utf8.decoder).join();
      }
    } catch (_) {}
    return longUrl;
  }

  Future<void> _sendWhatsAppUpdate() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      final customerPhone = widget.job['customer_phone']?.toString() ?? '';
      if (customerPhone.isEmpty) throw 'No customer phone number available.';

      String cleanPhone = customerPhone.replaceAll(RegExp(r'\D'), '');
      if (!cleanPhone.startsWith('91') && cleanPhone.length == 10) {
        cleanPhone = '91$cleanPhone';
      }

      final pdf = await _buildPdf();
      final bytes = await pdf.save();

      final jobId = widget.job['id'];
      final fileName = 'Invoice_$jobId.pdf';

      await supabase.storage.from('invoices').uploadBinary(
        fileName,
        bytes,
        fileOptions: const FileOptions(upsert: true, contentType: 'application/pdf'),
      );

      final pdfUrl = supabase.storage.from('invoices').getPublicUrl(fileName);
      final shortPdfUrl = await _shortenUrl(pdfUrl);

      final user = supabase.auth.currentUser;
      final shopData = await supabase.from('shops').select().eq('id', user?.id ?? '').maybeSingle();
      final shopName = shopData?['shop_name'] ?? 'our workshop';
      final vehicleNo = widget.job['vehicle_no'] ?? '';
      final total = _totalSellingPrice.toStringAsFixed(0);
      final workDesc = _workController.text.trim();

      String extraDetails = '';
      if (workDesc.isNotEmpty) extraDetails += '\nWork Details: $workDesc\n';

      final message = 'Hello! Thank you for choosing $shopName.\nYour vehicle ($vehicleNo) work is completed.\n$extraDetails\nYour total bill amount is Rs. $total.\n\nYou can download your invoice securely here:\n$shortPdfUrl\n\nHave a great day!';

      final appUrl = Uri.parse('whatsapp://send?phone=$cleanPhone&text=${Uri.encodeComponent(message)}');
      final webUrl = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}');

      if (await canLaunchUrl(appUrl)) {
        await launchUrl(appUrl, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _addBillItem({
    required String description,
    required double actualPrice,
    required double sellingPrice,
  }) async {
    final jobId = widget.job['id'];
    if (jobId == null) return;

    try {
      await supabase.from('bill_items').insert({
        'job_id': jobId,
        'description': description,
        'actual_price': actualPrice,
        'selling_price': sellingPrice,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bill item added!'),
            backgroundColor: AppColors.statusCompleted,
          ),
        );
        _fetchBillItems();
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding bill item: ${error.message}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteBillItem(dynamic itemId) async {
    try {
      await supabase.from('bill_items').delete().eq('id', itemId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item deleted.')),
        );
        _fetchBillItems();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting item: $e')),
        );
      }
    }
  }

  Future<void> _showAddBillItemDialog() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedDescriptions = prefs.getStringList('bill_descriptions') ?? [];

    if (!mounted) return;

    final actualPriceController = TextEditingController();
    final sellingPriceController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    TextEditingController? autocompleteController;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Bill Item / Spare Part'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return savedDescriptions;
                      }
                      return savedDescriptions.where((String option) {
                        return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                      });
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4.0,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            constraints: const BoxConstraints(maxHeight: 200, maxWidth: 280),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (BuildContext context, int index) {
                                final option = options.elementAt(index);
                                return ListTile(
                                  title: Text(
                                    option,
                                    style: AppTypography.bodyMedium(Theme.of(context).brightness == Brightness.dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                                  ),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                    fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                      autocompleteController = controller;
                      return CustomTextField(
                        controller: controller,
                        focusNode: focusNode,
                        label: 'Description',
                        hint: 'e.g., Engine Oil 4L / Labor Charge',
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Enter item description';
                          }
                          return null;
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    controller: actualPriceController,
                    label: 'Cost Price (₹)',
                    hint: 'e.g., 1200',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    controller: sellingPriceController,
                    label: 'Selling Price (₹)',
                    hint: 'e.g., 1500',
                    keyboardType: TextInputType.number,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Enter selling price';
                      }
                      if (double.tryParse(val.trim()) == null) {
                        return 'Enter a valid number';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            CustomButton(
              label: 'Add Item',
              isFullWidth: false,
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final actual = double.tryParse(actualPriceController.text.trim()) ?? 0.0;
                  final selling = double.parse(sellingPriceController.text.trim());
                  final description = autocompleteController?.text.trim() ?? '';

                  if (description.isNotEmpty && !savedDescriptions.contains(description)) {
                    savedDescriptions.add(description);
                    await prefs.setStringList('bill_descriptions', savedDescriptions);
                  }

                  _addBillItem(
                    description: description,
                    actualPrice: actual,
                    sellingPrice: selling,
                  );
                  if (mounted) Navigator.pop(context);
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showAddPaymentDialog() {
    final paymentController = TextEditingController();
    final balance = _totalSellingPrice - _currentAmountPaid;
    paymentController.text = balance > 0 ? balance.toStringAsFixed(0) : '';
    final formKey = GlobalKey<FormState>();
    String selectedMode = _paymentMode.isNotEmpty ? _paymentMode : 'Cash';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Record Payment'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomTextField(
                      controller: paymentController,
                      label: 'Payment Amount (₹)',
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        final added = double.tryParse(val?.trim() ?? '') ?? 0.0;
                        if (added <= 0) return 'Enter a valid amount';
                        if (added > balance) {
                          return 'Cannot pay more than balance (₹${balance.toStringAsFixed(2)})';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedMode,
                      decoration: const InputDecoration(
                        labelText: 'Payment Mode',
                      ),
                      items: ['Cash', 'UPI', 'Card'].map((mode) {
                        return DropdownMenuItem(
                          value: mode,
                          child: Text(mode),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedMode = val);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                CustomButton(
                  label: 'Record Payment',
                  isFullWidth: false,
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      final added = double.tryParse(paymentController.text.trim()) ?? 0.0;
                      setState(() {
                        _currentAmountPaid += added;
                        _paymentMode = selectedMode;
                      });
                      Navigator.pop(context);
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  double get _totalSellingPrice {
    return _billItems.fold(0.0, (sum, item) {
      final price = double.tryParse(item['selling_price'].toString()) ?? 0.0;
      return sum + price;
    });
  }

  double get _totalActualPrice {
    return _billItems.fold(0.0, (sum, item) {
      final price = double.tryParse(item['actual_price'].toString()) ?? 0.0;
      return sum + price;
    });
  }

  @override
  void dispose() {
    _workController.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryText = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final customerName = widget.job['customer_name'] ?? 'Unknown Customer';
    final customerPhone = widget.job['customer_phone'] ?? '';
    final vehicleNo = widget.job['vehicle_no'] ?? '';
    final modelName = widget.job['model_name'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text('Job #${widget.job['id']}'),
        actions: [
          if (_status == 'Pending')
            TextButton.icon(
              icon: const Icon(Icons.play_circle_fill_rounded, color: AppColors.statusCompleted, size: 20),
              label: const Text('Start Work', style: TextStyle(color: AppColors.statusCompleted, fontWeight: FontWeight.bold)),
              onPressed: () async {
                setState(() => _status = 'In Progress');
                try {
                  await supabase.from('jobs').update({'status': 'In Progress'}).eq('id', widget.job['id']);
                  if (mounted) widget.onJobUpdated();
                } catch (e) {
                  setState(() => _status = 'Pending');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to start work: $e')));
                  }
                }
              },
            ),
          if (_status != 'Pending') CustomBadge(status: _status),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [


            // Vehicle & Customer Info Card
            CustomCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.directions_car_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              modelName,
                              style: AppTypography.titleMedium(primaryText),
                            ),
                            Text(
                              vehicleNo,
                              style: AppTypography.labelLarge(AppColors.primary),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.person_rounded, size: 14, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Text(customerName, style: AppTypography.bodySmall(secondaryText)),
                                if (customerPhone.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Text('($customerPhone)', style: AppTypography.bodySmall(secondaryText)),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (customerPhone.isNotEmpty && _status == 'Pending')
                        IconButton(
                          icon: const Icon(Icons.phone_rounded, color: AppColors.primary),
                          onPressed: () => launchUrl(Uri.parse('tel:$customerPhone')),
                          tooltip: 'Call Customer',
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Work & Review Card
            CustomCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Work Description',
                        style: AppTypography.titleMedium(primaryText),
                      ),
                      if (_status != 'Completed')
                        IconButton(
                          icon: _isSavingJob
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save_rounded, color: AppColors.primary),
                          onPressed: _isSavingJob ? null : _updateWorkDescription,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  CustomTextField(
                    controller: _workController,
                    label: '',
                    hint: 'Enter work description...',
                    maxLines: 3,
                    readOnly: _status == 'Completed',
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Mechanic Notes / Review',
                    style: AppTypography.titleMedium(primaryText),
                  ),
                  const SizedBox(height: 8),
                  CustomTextField(
                    controller: _reviewController,
                    label: '',
                    hint: 'Enter inspection findings or notes...',
                    maxLines: 2,
                    readOnly: _status == 'Completed',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Bill items section header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Bill Items & Parts (${_billItems.length})',
                  style: AppTypography.titleLarge(primaryText),
                ),
                if (_status != 'Completed')
                  CustomButton(
                    label: 'Add Item',
                    icon: Icons.add_rounded,
                    isFullWidth: false,
                    onPressed: _showAddBillItemDialog,
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Bill Items list
            if (_isLoadingBills)
              const CircularProgressIndicator()
            else if (_billItems.isEmpty)
              CustomCard(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Icon(Icons.receipt_long_outlined, size: 40, color: AppColors.primary),
                        const SizedBox(height: 8),
                        Text('No bill items added yet', style: AppTypography.bodyMedium(secondaryText)),
                      ],
                    ),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _billItems.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = _billItems[index];
                  final desc = item['description'] ?? '';
                  final actual = double.tryParse(item['actual_price'].toString()) ?? 0.0;
                  final selling = double.tryParse(item['selling_price'].toString()) ?? 0.0;
                  final itemId = item['id'];

                  return CustomCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(desc, style: AppTypography.titleSmall(primaryText)),
                              Text('Cost Price: ₹${actual.toStringAsFixed(2)}', style: AppTypography.bodySmall(secondaryText)),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              '₹${selling.toStringAsFixed(2)}',
                              style: AppTypography.titleMedium(AppColors.statusCompleted),
                            ),
                            if (_status != 'Completed')
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                                onPressed: () {
                                  if (itemId != null) _deleteBillItem(itemId);
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 24),

            // Financial Summary Card
            Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                gradient: isDark ? AppColors.darkCardGradient : null,
                color: isDark ? null : AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Actual Cost:', style: AppTypography.bodyMedium(secondaryText)),
                      Text('₹${_totalActualPrice.toStringAsFixed(2)}', style: AppTypography.labelLarge(primaryText)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('TOTAL BILL AMOUNT:', style: AppTypography.titleMedium(primaryText)),
                      Text(
                        '₹${_totalSellingPrice.toStringAsFixed(2)}',
                        style: AppTypography.displayMedium(AppColors.primary),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Amount Paid:', style: AppTypography.titleSmall(primaryText)),
                      Row(
                        children: [
                          Text('₹${_currentAmountPaid.toStringAsFixed(2)}', style: AppTypography.titleMedium(primaryText)),
                          if (_totalSellingPrice > _currentAmountPaid && _status != 'Completed') ...[
                            const SizedBox(width: 8),
                            TextButton.icon(
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text('Pay'),
                              onPressed: _showAddPaymentDialog,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  if (_currentAmountPaid > 0 && _totalSellingPrice > _currentAmountPaid) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Balance Due:', style: AppTypography.titleMedium(AppColors.error)),
                        Text(
                          '₹${(_totalSellingPrice - _currentAmountPaid).toStringAsFixed(2)}',
                          style: AppTypography.titleLarge(AppColors.error),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Live Digital Receipt Card Preview Section
            Text(
              'Digital Invoice Receipt',
              style: AppTypography.titleLarge(primaryText),
            ),
            const SizedBox(height: 12),
            Center(
              child: InvoiceReceiptCard(
                shopName: _shopName,
                shopLocation: _shopLocation,
                shopPhone: _shopPhone,
                billNo: _getBillNo(),
                dateStr:
                    '${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}',
                customerName: customerName,
                customerPhone: customerPhone,
                modelName: modelName,
                vehicleNo: vehicleNo,
                billItems: _billItems,
                totalAmount: _totalSellingPrice,
                amountPaid: _currentAmountPaid,
                paymentMode: _paymentMode,
              ),
            ),
            const SizedBox(height: 28),

            // Action Buttons
            if (_status != 'Completed') ...[
              CustomButton(
                label: 'Save Progress & Bill',
                icon: Icons.save_rounded,
                isLoading: _isSavingJob,
                backgroundColor: AppColors.primary,
                onPressed: () async {
                  await _saveFullBill(autoShare: false);
                },
              ),
              const SizedBox(height: 14),
              
              if (_status == 'In Progress') ...[
                CustomButton(
                  label: 'Complete Work & Save Invoice',
                  icon: Icons.check_circle_rounded,
                  isLoading: _isSavingJob,
                  backgroundColor: AppColors.statusCompleted,
                  onPressed: () async {
                    if (_currentAmountPaid < _totalSellingPrice) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Cannot save: full amount must be paid to complete work.'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                      return;
                    }
                    setState(() => _status = 'Completed');
                    await _saveFullBill(autoShare: true);
                  },
                ),
                const SizedBox(height: 14),
              ],
            ],

            CustomButton(
              label: 'Generate Invoice (PDF)',
              icon: Icons.picture_as_pdf_rounded,
              isOutline: true,
              isLoading: _isGeneratingPdf,
              onPressed: _generateInvoicePdf,
            ),

            if (_status == 'Completed') ...[
              const SizedBox(height: 14),
              CustomButton(
                label: 'Share Bill via WhatsApp',
                icon: Icons.share_rounded,
                backgroundColor: AppColors.statusCompleted,
                isLoading: _isSharing,
                onPressed: _sendWhatsAppUpdate,
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

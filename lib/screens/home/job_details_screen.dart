import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'dart:convert';
import '../../main.dart';

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
  String _paymentMode = 'Cash';

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

  Future<void> _updateJobStatus(String newStatus) async {
    setState(() => _status = newStatus);
    try {
      await supabase
          .from('jobs')
          .update({'status': newStatus})
          .eq('id', widget.job['id']);

      widget.onJobUpdated();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e')),
        );
      }
    }
  }

  Future<void> _updateWorkDescription() async {
    setState(() => _isSavingJob = true);
    try {
      await supabase
          .from('jobs')
          .update({
            'work_description': _workController.text.trim(),
            'review': _reviewController.text.trim(),
          })
          .eq('id', widget.job['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Details updated!')),
        );
      }
      widget.onJobUpdated();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving work description: $e')),
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
            backgroundColor: Colors.green,
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
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingJob = false);
    }
  }

  Future<pw.Document> _buildPdf() async {
      final user = supabase.auth.currentUser;
      final shopData = await supabase.from('shops').select().eq('id', user?.id ?? '').maybeSingle();
      
      final shopName = shopData?['shop_name'] ?? 'Workshop';
      final place = shopData?['location'] ?? '';
      final shopPhone = shopData?['phone'] ?? '';

      final pdf = pw.Document();

      final customerName = widget.job['customer_name'] ?? 'Unknown Customer';
      final customerPhone = widget.job['customer_phone'] ?? '';
      final vehicleNo = widget.job['vehicle_no'] ?? '';
      final modelName = widget.job['model_name'] ?? '';
      final jobId = widget.job['id'];
      final date = DateTime.now();
      final billNo = '#$jobId${date.year}';
      final dateStr = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Center(
                  child: pw.Text(shopName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Center(
                  child: pw.Text(place, style: const pw.TextStyle(fontSize: 14)),
                ),
                if (shopPhone.isNotEmpty)
                  pw.Center(
                    child: pw.Text('Phone: $shopPhone', style: const pw.TextStyle(fontSize: 14)),
                  ),
                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.SizedBox(height: 10),
                
                // Invoice Details & Customer Info
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Bill No: $billNo', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text('Date: $dateStr'),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Customer: $customerName', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        if (customerPhone.isNotEmpty) pw.Text('Phone: $customerPhone'),
                        pw.Text('Vehicle: $modelName ($vehicleNo)'),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                
                // Service Details Table
                pw.Column(
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          flex: 3,
                          child: pw.Text('Service / Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Expanded(
                          flex: 1,
                          child: pw.Text('Amount', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                      ]
                    ),
                    pw.Divider(),
                    ..._billItems.map((item) {
                      final desc = item['description'] ?? '';
                      final selling = double.tryParse(item['selling_price'].toString()) ?? 0.0;
                      return pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 4),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Expanded(flex: 3, child: pw.Text(desc)),
                            pw.Expanded(flex: 1, child: pw.Text(selling.toStringAsFixed(2), textAlign: pw.TextAlign.right)),
                          ],
                        ),
                      );
                    }).toList(),
                  ]
                ),
                pw.SizedBox(height: 10),
                pw.Divider(),
                pw.SizedBox(height: 10),
                
                // Totals
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Total Amount: Rs. ${_totalSellingPrice.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                        if (_currentAmountPaid > 0)
                          pw.Text('Paid via $_paymentMode', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
                      ],
                    ),
                  ],
                ),
              ],
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
        final shortUrl = await response.transform(utf8.decoder).join();
        return shortUrl;
      }
    } catch (e) {
      debugPrint('Error shortening URL: $e');
    }
    return longUrl;
  }

  bool _isSharing = false;

  Future<void> _sendWhatsAppUpdate() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      final customerPhone = widget.job['customer_phone']?.toString() ?? '';
      if (customerPhone.isEmpty) {
        throw 'No customer phone number available.';
      }

      String cleanPhone = customerPhone.replaceAll(RegExp(r'\D'), '');
      if (!cleanPhone.startsWith('91') && cleanPhone.length == 10) {
        cleanPhone = '91$cleanPhone';
      }

      // Generate PDF
      final pdf = await _buildPdf();
      final bytes = await pdf.save();
      
      final jobId = widget.job['id'];
      final billNo = '#$jobId${DateTime.now().year}';
      final fileName = 'Invoice_$jobId.pdf';

      // Upload PDF to Supabase Storage
      await supabase.storage.from('invoices').uploadBinary(
        fileName,
        bytes,
        fileOptions: const FileOptions(upsert: true, contentType: 'application/pdf'),
      );

      // Get public URL and shorten it
      final pdfUrl = supabase.storage.from('invoices').getPublicUrl(fileName);
      final shortPdfUrl = await _shortenUrl(pdfUrl);

      final user = supabase.auth.currentUser;
      final shopData = await supabase.from('shops').select().eq('id', user?.id ?? '').maybeSingle();
      final shopName = shopData?['shop_name'] ?? 'our workshop';
      final vehicleNo = widget.job['vehicle_no'] ?? '';
      final total = _totalSellingPrice.toStringAsFixed(0);
      final workDesc = _workController.text.trim();
      final review = _reviewController.text.trim();

      String extraDetails = '';
      if (workDesc.isNotEmpty) {
        extraDetails += '\nWork Details: $workDesc\n';
      }
      if (review.isNotEmpty) {
        extraDetails += 'Remarks: $review\n';
      }

      final message = 'Hello! Thank you for choosing $shopName. \nYour vehicle ($vehicleNo) work is completed. $extraDetails\nYour total bill amount is Rs. $total.\n\nYou can download your invoice securely here:\n$shortPdfUrl\n\nWe appreciate your business. Have a great day!';

      final appUrl = Uri.parse('whatsapp://send?phone=$cleanPhone&text=${Uri.encodeComponent(message)}');
      final webUrl = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}');

      if (await canLaunchUrl(appUrl)) {
        await launchUrl(appUrl, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webUrl)) {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      } else {
        final launched = await launchUrl(webUrl, mode: LaunchMode.externalApplication);
        if (!launched) {
          throw 'Could not open WhatsApp. Ensure it is installed.';
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
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
          const SnackBar(content: Text('Bill item added!')),
        );
        _fetchBillItems();
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding bill item: ${error.message}'),
            backgroundColor: Theme.of(context).colorScheme.error,
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

  void _showAddBillItemDialog() {
    final descController = TextEditingController();
    final actualPriceController = TextEditingController();
    final sellingPriceController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Bill Item / Part'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'Item Description *',
                      hintText: 'e.g., Engine Oil 4L / Labor Charge',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Enter item description';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: actualPriceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Actual Price (Cost) (₹)',
                      hintText: 'e.g., 1200',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: sellingPriceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Selling Price (Billed) (₹) *',
                      hintText: 'e.g., 1500',
                      border: OutlineInputBorder(),
                    ),
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
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final actual = double.tryParse(
                          actualPriceController.text.trim()) ??
                      0.0;
                  final selling = double.parse(
                      sellingPriceController.text.trim());

                  _addBillItem(
                    description: descController.text.trim(),
                    actualPrice: actual,
                    sellingPrice: selling,
                  );
                  Navigator.pop(context);
                }
              },
              child: const Text('Add Item'),
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
              title: const Text('Add Payment'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: paymentController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Payment Amount (₹)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        final added = double.tryParse(val?.trim() ?? '') ?? 0.0;
                        if (added <= 0) {
                          return 'Enter a valid amount';
                        }
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
                        border: OutlineInputBorder(),
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
                ElevatedButton(
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
                  child: const Text('Add'),
                ),
              ],
            );
          }
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Completed':
        return Colors.green;
      case 'In Progress':
        return Colors.orange;
      case 'Pending':
      default:
        return Colors.blue;
    }
  }

  @override
  void dispose() {
    _workController.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customerName = widget.job['customer_name'] ?? 'Unknown Customer';
    final customerPhone = widget.job['customer_phone'] ?? '';
    final vehicleNo = widget.job['vehicle_no'] ?? '';
    final modelName = widget.job['model_name'] ?? '';
    final statusColor = _getStatusColor(_status);

    return Scaffold(
      appBar: AppBar(
        title: Text('Job #${widget.job['id']}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save Bill',
            onPressed: _isSavingJob ? null : _saveFullBill,
          ),
          if (_status == 'Pending')
            Padding(
              padding: const EdgeInsets.only(right: 16, left: 8),
              child: Center(
                child: FilledButton.icon(
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Start Work'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onPressed: () => _updateJobStatus('In Progress'),
                ),
              ),
            )
          else
            Container(
              margin: const EdgeInsets.only(right: 16, left: 8, top: 12, bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _status,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Vehicle & Customer Details Card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(
                            Icons.directions_car,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$modelName ($vehicleNo)',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.person,
                                      size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    customerName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                  if (customerPhone.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      '($customerPhone)',
                                      style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. Work Description Section
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Work / Issue Description',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        IconButton(
                          icon: _isSavingJob
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(Icons.save_outlined),
                          tooltip: 'Save Work Description',
                          onPressed: (_isSavingJob || _status == 'Completed') ? null : _updateWorkDescription,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _workController,
                      maxLines: 3,
                      readOnly: _status == 'Completed',
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Enter work description...',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Review / Feedback',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _reviewController,
                      maxLines: 2,
                      readOnly: _status == 'Completed',
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Enter review or feedback...',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 3. Billing Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Bill Items & Invoice (${_billItems.length})',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (_status != 'Completed')
                  ElevatedButton.icon(
                    onPressed: _showAddBillItemDialog,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Item'),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Bill Items Table / List
            _isLoadingBills
                ? const Center(child: CircularProgressIndicator())
                : _billItems.isEmpty
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.receipt_long_outlined,
                                size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text(
                              'No bill items added yet.',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _billItems.length,
                        itemBuilder: (context, index) {
                          final item = _billItems[index];
                          final desc = item['description'] ?? '';
                          final actual = double.tryParse(
                                  item['actual_price'].toString()) ??
                              0.0;
                          final selling = double.tryParse(
                                  item['selling_price'].toString()) ??
                              0.0;
                          final itemId = item['id'];

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(
                                desc,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                'Cost: ₹${actual.toStringAsFixed(2)}',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 12),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '₹${selling.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.green,
                                    ),
                                  ),
                                  if (_status != 'Completed')
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: Colors.red, size: 20),
                                      onPressed: () {
                                        if (itemId != null) {
                                          _deleteBillItem(itemId);
                                        }
                                      },
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
            const SizedBox(height: 20),

            // Total Calculation Card
            Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Actual Cost:',
                        style: TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                      Text(
                        '₹${_totalActualPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TOTAL BILL AMOUNT:',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        '₹${_totalSellingPrice.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  if (_totalSellingPrice > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Estimated Margin / Profit:',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          '₹${(_totalSellingPrice - _totalActualPrice).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const Divider(height: 32),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Expanded(
                        flex: 2,
                        child: Text(
                          'Amount Paid:',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '₹${_currentAmountPaid.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                if (_currentAmountPaid > 0)
                                  Text(
                                    'via $_paymentMode',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                              ],
                            ),
                            if (_totalSellingPrice > _currentAmountPaid && _status != 'Completed') ...[
                              const Spacer(),
                              TextButton.icon(
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Pay'),
                                onPressed: _showAddPaymentDialog,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_currentAmountPaid > 0 && _totalSellingPrice > _currentAmountPaid)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Balance Amount:',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.redAccent),
                          ),
                          Text(
                            '₹${(_totalSellingPrice - _currentAmountPaid).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 4. SAVE BILL & INVOICE BUTTON
            if (_status != 'Completed') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSavingJob ? null : () async {
                    bool justCompleted = false;
                    if (_status == 'In Progress' || _status == 'Completed') {
                      if (_currentAmountPaid < _totalSellingPrice) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cannot save: full amount must be paid to complete work.'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                        return;
                      }
                      if (_status == 'In Progress') {
                        setState(() => _status = 'Completed');
                        justCompleted = true;
                      }
                    }
                    await _saveFullBill(autoShare: justCompleted);
                  },
                  icon: _isSavingJob
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _status == 'In Progress' ? Icons.task_alt : Icons.check_circle_outline,
                          size: 22,
                        ),
                  label: Text(
                    _isSavingJob
                        ? 'Saving...'
                        : (_status == 'In Progress' ? 'Complete Work & Save Invoice' : 'Save Bill'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _status == 'In Progress' ? Colors.green : Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // 5. GENERATE INVOICE BUTTON
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isGeneratingPdf ? null : _generateInvoicePdf,
                icon: _isGeneratingPdf
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined, size: 22),
                label: Text(
                  _isGeneratingPdf ? 'Generating PDF...' : 'Generate Invoice (PDF)',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            
            // 6. WHATSAPP BUTTON (if completed)
            if (_status == 'Completed') ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _sendWhatsAppUpdate,
                  icon: const Icon(Icons.share, size: 22),
                  label: const Text(
                    'Share Bill & Update',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

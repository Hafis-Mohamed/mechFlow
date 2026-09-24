import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class InvoiceReceiptCard extends StatelessWidget {
  final String shopName;
  final String shopLocation;
  final String shopPhone;
  final String billNo;
  final String dateStr;
  final String customerName;
  final String customerPhone;
  final String modelName;
  final String vehicleNo;
  final String meterReading;
  final List<Map<String, dynamic>> billItems;
  final double totalAmount;
  final double amountPaid;
  final String paymentMode;
  final VoidCallback? onPrintPdf;
  final VoidCallback? onShareWhatsApp;

  const InvoiceReceiptCard({
    super.key,
    required this.shopName,
    required this.shopLocation,
    required this.shopPhone,
    required this.billNo,
    required this.dateStr,
    required this.customerName,
    required this.customerPhone,
    required this.modelName,
    required this.vehicleNo,
    this.meterReading = '',
    required this.billItems,
    required this.totalAmount,
    required this.amountPaid,
    required this.paymentMode,
    this.onPrintPdf,
    this.onShareWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryText = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryText = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final altRowBg = isDark ? AppColors.darkSurfaceSecondary : const Color(0xFFF8FAFC);

    final isFullyPaid = amountPaid >= totalAmount && totalAmount > 0;
    final isPartiallyPaid = amountPaid > 0 && amountPaid < totalAmount;

    return Container(
      constraints: const BoxConstraints(maxWidth: 480),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderCol, width: 1),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header Section
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.build_circle_rounded, color: Color(0xFF38BDF8), size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'SERVICE RECEIPT',
                      style: AppTypography.labelMedium(const Color(0xFF94A3B8)).copyWith(
                        letterSpacing: 1.2,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  shopName.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: AppTypography.displayMedium(Colors.white).copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                if (shopLocation.isNotEmpty || shopPhone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (shopLocation.isNotEmpty) ...[
                        const Icon(Icons.location_on_outlined, color: Color(0xFF94A3B8), size: 12),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            shopLocation,
                            style: AppTypography.bodySmall(const Color(0xFFCBD5E1)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      if (shopLocation.isNotEmpty && shopPhone.isNotEmpty)
                        const Text('  •  ', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                      if (shopPhone.isNotEmpty) ...[
                        const Icon(Icons.phone_outlined, color: Color(0xFF94A3B8), size: 12),
                        const SizedBox(width: 2),
                        Text(
                          shopPhone,
                          style: AppTypography.bodySmall(const Color(0xFFCBD5E1)),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 2. Meta Info: Two Column Grid (Bill No & Date vs Customer Name & Phone)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Side: Bill No & Date
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('BILL DETAILS', style: AppTypography.caption(secondaryText).copyWith(fontSize: 9, letterSpacing: 0.8)),
                          const SizedBox(height: 2),
                          Text(billNo, style: AppTypography.titleMedium(primaryText).copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text('Date: $dateStr', style: AppTypography.bodySmall(secondaryText)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Right Side: Customer Name & Phone
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('CUSTOMER', style: AppTypography.caption(secondaryText).copyWith(fontSize: 9, letterSpacing: 0.8)),
                          const SizedBox(height: 2),
                          Text(
                            customerName,
                            style: AppTypography.titleSmall(primaryText).copyWith(fontWeight: FontWeight.w600),
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (customerPhone.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(customerPhone, style: AppTypography.bodySmall(secondaryText), textAlign: TextAlign.end),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Vehicle Details highlighted single-line chip/badge
                if (modelName.isNotEmpty || vehicleNo.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: isDark ? 0.3 : 0.2),
                      ),
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (modelName.isNotEmpty || vehicleNo.isNotEmpty) ...[
                          const Icon(Icons.directions_car_rounded, size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            [
                              if (modelName.isNotEmpty) modelName,
                              if (vehicleNo.isNotEmpty) vehicleNo,
                            ].join('  •  '),
                            style: AppTypography.labelMedium(AppColors.primary).copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                        if (meterReading.isNotEmpty && meterReading != '0') ...[
                          if (modelName.isNotEmpty || vehicleNo.isNotEmpty)
                            Text(
                              '   •   ',
                              style: AppTypography.labelMedium(AppColors.primary).copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          const Icon(Icons.speed_rounded, size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            '$meterReading km',
                            style: AppTypography.labelMedium(AppColors.primary).copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                const SizedBox(height: 12),

                // 3. Itemized Table
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderCol.withValues(alpha: 0.7)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      // Table Header
                      Container(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                'SERVICE / ITEM DESCRIPTION',
                                style: AppTypography.caption(secondaryText).copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Text(
                                'AMOUNT',
                                textAlign: TextAlign.right,
                                style: AppTypography.caption(secondaryText).copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Table Rows
                      if (billItems.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Center(
                            child: Text(
                              'No itemized parts or services added',
                              style: AppTypography.bodySmall(secondaryText),
                            ),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: billItems.length,
                          itemBuilder: (context, index) {
                            final item = billItems[index];
                            final desc = item['description'] ?? 'Service';
                            final selling = double.tryParse(item['selling_price'].toString()) ?? 0.0;
                            final isEven = index % 2 == 0;

                            return Container(
                              color: isEven ? cardBg : altRowBg,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      desc,
                                      style: AppTypography.bodyMedium(primaryText).copyWith(fontSize: 12),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      '₹${selling.toStringAsFixed(2)}',
                                      textAlign: TextAlign.right,
                                      style: AppTypography.labelMedium(primaryText).copyWith(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 4. Total Amount & Payment Mode Bar (No gap under table)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TOTAL AMOUNT',
                            style: AppTypography.caption(const Color(0xFF94A3B8)).copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 9,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          // Payment Badge Pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isFullyPaid
                                  ? const Color(0xFFDCFCE7)
                                  : (isPartiallyPaid ? const Color(0xFFFEF3C7) : const Color(0xFFFEE2E2)),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isFullyPaid
                                      ? Icons.check_circle_rounded
                                      : (isPartiallyPaid ? Icons.timelapse_rounded : Icons.info_outline_rounded),
                                  size: 11,
                                  color: isFullyPaid
                                      ? const Color(0xFF15803D)
                                      : (isPartiallyPaid ? const Color(0xFFB45309) : const Color(0xFFB91C1C)),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isFullyPaid
                                      ? 'Paid via $paymentMode'
                                      : (isPartiallyPaid ? 'Paid ₹${amountPaid.toStringAsFixed(0)} ($paymentMode)' : 'Unpaid'),
                                  style: TextStyle(
                                    color: isFullyPaid
                                        ? const Color(0xFF15803D)
                                        : (isPartiallyPaid ? const Color(0xFFB45309) : const Color(0xFFB91C1C)),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '₹${totalAmount.toStringAsFixed(2)}',
                        style: AppTypography.displayMedium(Colors.white).copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Quick Action Buttons if callbacks provided
                if (onPrintPdf != null || onShareWhatsApp != null) ...[
                  Row(
                    children: [
                      if (onPrintPdf != null)
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.print_rounded, size: 16),
                            label: const Text('Print PDF', style: TextStyle(fontSize: 12)),
                            onPressed: onPrintPdf,
                          ),
                        ),
                      if (onPrintPdf != null && onShareWhatsApp != null) const SizedBox(width: 8),
                      if (onShareWhatsApp != null)
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.statusCompleted,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.share_rounded, size: 16),
                            label: const Text('Share Receipt', style: TextStyle(fontSize: 12)),
                            onPressed: onShareWhatsApp,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],

                // 5. Footer Line
                Center(
                  child: Text(
                    'Thank you for choosing us! • Drive Safe',
                    style: AppTypography.bodySmall(secondaryText).copyWith(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

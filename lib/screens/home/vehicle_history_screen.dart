import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/custom_card.dart';
import '../../main.dart'; // for supabase
import 'package:intl/intl.dart';
import 'job_details_screen.dart';

class VehicleHistoryScreen extends StatefulWidget {
  final String vehicleNo;
  final String modelName;

  const VehicleHistoryScreen({
    super.key,
    required this.vehicleNo,
    required this.modelName,
  });

  @override
  State<VehicleHistoryScreen> createState() => _VehicleHistoryScreenState();
}

class _VehicleHistoryScreenState extends State<VehicleHistoryScreen> {
  List<Map<String, dynamic>> _serviceRecords = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      return DateFormat('MMM dd, yyyy - hh:mm a').format(date);
    } catch (_) {
      return isoString;
    }
  }

  Future<void> _fetchHistory() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final response = await supabase
          .from('jobs')
          .select()
          .eq('shop_id', user.id)
          .ilike('vehicle_no', widget.vehicleNo)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _serviceRecords = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryText = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.vehicleNo, style: AppTypography.titleLarge(primaryText)),
            if (widget.modelName.isNotEmpty)
              Text(
                widget.modelName,
                style: AppTypography.bodySmall(secondaryText),
              ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _serviceRecords.isEmpty
              ? Center(
                  child: Text(
                    'No service records found.',
                    style: AppTypography.titleMedium(secondaryText),
                  ),
                )
              : Column(
                  children: [
                    // Owner Details Top Card
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: CustomCard(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _serviceRecords.first['customer_name'] ?? 'Unknown Owner',
                                    style: AppTypography.titleMedium(primaryText).copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  if ((_serviceRecords.first['customer_phone'] ?? '').isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      _serviceRecords.first['customer_phone'],
                                      style: AppTypography.bodyMedium(secondaryText),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _serviceRecords.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final record = _serviceRecords[index];
                          final status = record['status'] ?? 'Pending';
                          final isCompleted = status == 'Completed';
                          final dateStr = record['created_at'] != null ? _formatDate(record['created_at']) : 'Unknown Date';

                          return InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => JobDetailsScreen(
                                    job: record,
                                    onJobUpdated: _fetchHistory,
                                    hideOwnerDetails: true,
                                  ),
                                ),
                              );
                            },
                      borderRadius: BorderRadius.circular(16),
                      child: CustomCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  dateStr,
                                  style: AppTypography.labelMedium(secondaryText),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isCompleted
                                        ? AppColors.statusCompleted.withValues(alpha: 0.1)
                                        : AppColors.statusPending.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isCompleted ? AppColors.statusCompleted : AppColors.statusPending,
                                    ),
                                  ),
                                  child: Text(
                                    status,
                                    style: AppTypography.labelMedium(
                                      isCompleted ? AppColors.statusCompleted : AppColors.statusPending,
                                    ).copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.build_circle_rounded, color: AppColors.primary, size: 24),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        record['work_description'] ?? 'No Description',
                                        style: AppTypography.titleMedium(primaryText),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if ((record['meter_reading'] ?? '').isNotEmpty && record['meter_reading'] != '0') ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.speed_rounded, size: 14, color: AppColors.primary),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${record['meter_reading']} km',
                                              style: AppTypography.bodySmall(secondaryText).copyWith(fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Amount Paid:',
                                  style: AppTypography.bodyMedium(secondaryText),
                                ),
                                Text(
                                  '₹${record['amount_paid'] ?? '0.0'}',
                                  style: AppTypography.titleMedium(
                                          isCompleted ? AppColors.statusCompleted : primaryText)
                                      .copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ),
          ],
        ),
    );
  }
}

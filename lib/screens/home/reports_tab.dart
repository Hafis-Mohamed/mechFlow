import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as excel;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../main.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/custom_card.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/pressable_scale.dart';
import '../../core/widgets/shimmer_loading.dart';
import 'job_details_screen.dart';

class ReportGroupData {
  final String title;
  final String shortTitle;
  final String sortKey;
  final List<Map<String, dynamic>> jobs = [];
  double revenue = 0;
  double expense = 0;
  double profit = 0;

  ReportGroupData(this.title, this.shortTitle, this.sortKey);

  void addJob(Map<String, dynamic> job) {
    jobs.add(job);
    
    final amount = double.tryParse(job['amount_paid']?.toString() ?? '0') ?? 0.0;
    revenue += amount;
    
    final billItems = job['bill_items'] as List<dynamic>? ?? [];
    for (var item in billItems) {
      if (item is Map) {
        final actualPrice = double.tryParse(item['actual_price']?.toString() ?? '0') ?? 0.0;
        expense += actualPrice;
      }
    }
    
    profit = revenue - expense;
  }
}

class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key});

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allJobs = [];

  @override
  void initState() {
    super.initState();
    _fetchAllJobs();
  }

  Future<void> _fetchAllJobs() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final data = await supabase
          .from('jobs')
          .select('*, bill_items(selling_price, actual_price)')
          .eq('shop_id', user.id);

      if (mounted) {
        setState(() {
          _allJobs = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryText = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: const [
            ShimmerLoading(width: double.infinity, height: 180, borderRadius: 24),
            SizedBox(height: 20),
            ShimmerLoading(width: double.infinity, height: 180, borderRadius: 24),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Financial Reports & Analytics',
            style: AppTypography.displayMedium(primaryText),
          ),
          const SizedBox(height: 6),
          Text(
            'Select a period to view charts, revenue, and profit breakdowns.',
            style: AppTypography.bodyMedium(secondaryText),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.95,
              children: [
                _buildPeriodCard(
                  title: 'Daily',
                  subtitle: 'Day by Day',
                  icon: Icons.today_rounded,
                  gradient: AppColors.primaryGradient,
                  onTap: () => _openReportDetail('Daily'),
                ),
                _buildPeriodCard(
                  title: 'Weekly',
                  subtitle: 'Week by Week',
                  icon: Icons.date_range_rounded,
                  gradient: AppColors.accentGradient,
                  onTap: () => _openReportDetail('Weekly'),
                ),
                _buildPeriodCard(
                  title: 'Monthly',
                  subtitle: 'Month by Month',
                  icon: Icons.calendar_month_rounded,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                  ),
                  onTap: () => _openReportDetail('Monthly'),
                ),
                _buildPeriodCard(
                  title: 'Yearly',
                  subtitle: 'Year by Year',
                  icon: Icons.auto_graph_rounded,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  onTap: () => _openReportDetail('Yearly'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required LinearGradient gradient,
    required VoidCallback onTap,
  }) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -15,
              bottom: -15,
              child: Icon(
                icon,
                size: 90,
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: Colors.white, size: 26),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.displayMedium(Colors.white),
                      ),
                      Text(
                        subtitle,
                        style: AppTypography.caption(Colors.white70),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openReportDetail(String reportType) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => ReportDetailScreen(
          reportType: reportType,
          allJobs: _allJobs,
          onRefresh: _fetchAllJobs,
        ),
        transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
      ),
    );
  }
}

class ReportDetailScreen extends StatefulWidget {
  final String reportType;
  final List<Map<String, dynamic>> allJobs;
  final VoidCallback onRefresh;

  const ReportDetailScreen({
    super.key,
    required this.reportType,
    required this.allJobs,
    required this.onRefresh,
  });

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  DateTime? _selectedDateFilter;

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateFilter ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDateFilter = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryText = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final groupedMap = <String, ReportGroupData>{};

    for (var job in widget.allJobs) {
      if (job['status'] != 'Completed') continue;

      final createdAtStr = (job['date'] ?? job['created_at'])?.toString();
      if (createdAtStr == null) continue;
      final date = DateTime.tryParse(createdAtStr);
      if (date == null) continue;

      String groupKey = '';
      String title = '';
      String shortTitle = '';
      String sortKey = '';

      if (widget.reportType == 'Daily') {
        final year = date.year;
        final monthStr = _getMonthName(date.month);
        final day = date.day.toString().padLeft(2, '0');

        groupKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-$day';
        title = '$day $monthStr $year';
        shortTitle = '$day $monthStr';
        sortKey = groupKey;
      } else if (widget.reportType == 'Weekly') {
        final monday = date.subtract(Duration(days: date.weekday - 1));
        final sunday = monday.add(const Duration(days: 6));

        final monStr = '${monday.day.toString().padLeft(2, '0')} ${_getMonthName(monday.month)}';
        final sunStr = '${sunday.day.toString().padLeft(2, '0')} ${_getMonthName(sunday.month)} ${sunday.year}';

        groupKey = '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
        title = '$monStr - $sunStr';
        shortTitle = '${monday.day}/${monday.month}-${sunday.day}/${sunday.month}';
        sortKey = groupKey;
      } else if (widget.reportType == 'Monthly') {
        final monthStr = _getMonthName(date.month);
        groupKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
        title = '$monthStr ${date.year}';
        shortTitle = monthStr.substring(0, 3);
        sortKey = groupKey;
      } else if (widget.reportType == 'Yearly') {
        groupKey = '${date.year}';
        title = 'Year ${date.year}';
        shortTitle = '${date.year}';
        sortKey = groupKey;
      }

      if (!groupedMap.containsKey(groupKey)) {
        groupedMap[groupKey] = ReportGroupData(title, shortTitle, sortKey);
      }
      groupedMap[groupKey]!.addJob(job);
    }

    final groupsNewestToOldest = groupedMap.values.toList()
      ..sort((a, b) => b.sortKey.compareTo(a.sortKey));
    final groupsOldestToNewest = List<ReportGroupData>.from(groupsNewestToOldest.reversed);

    var filteredGroups = groupsNewestToOldest;
    if (widget.reportType == 'Daily' && _selectedDateFilter != null) {
      final filterGroupKey = '${_selectedDateFilter!.year}-${_selectedDateFilter!.month.toString().padLeft(2, '0')}-${_selectedDateFilter!.day.toString().padLeft(2, '0')}';
      filteredGroups = filteredGroups.where((g) => g.sortKey == filterGroupKey).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.reportType} Reports'),
        actions: [
          if (widget.reportType == 'Daily')
            IconButton(
              icon: Icon(_selectedDateFilter != null ? Icons.filter_alt_off_rounded : Icons.filter_alt_rounded),
              tooltip: _selectedDateFilter != null ? 'Clear Date Filter' : 'Filter by Date',
              onPressed: () {
                if (_selectedDateFilter != null) {
                  setState(() => _selectedDateFilter = null);
                } else {
                  _selectDate();
                }
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.reportType == 'Daily')
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: CustomButton(
                  label: _selectedDateFilter != null
                      ? 'Showing: ${_selectedDateFilter!.day}/${_selectedDateFilter!.month}/${_selectedDateFilter!.year} (Tap to clear)'
                      : 'Select a Date to Filter',
                  icon: _selectedDateFilter != null ? Icons.clear_rounded : Icons.calendar_today_rounded,
                  isOutline: _selectedDateFilter == null,
                  onPressed: () {
                    if (_selectedDateFilter != null) {
                      setState(() => _selectedDateFilter = null);
                    } else {
                      _selectDate();
                    }
                  },
                ),
              ),
            if (filteredGroups.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 60.0),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.bar_chart_rounded, size: 64, color: AppColors.primary),
                      const SizedBox(height: 16),
                      Text(
                        _selectedDateFilter != null ? 'No report found for selected date.' : 'No completed reports found.', 
                        style: AppTypography.titleMedium(primaryText)
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              if (widget.reportType != 'Daily')
                Container(
                  height: 320,
                  padding: const EdgeInsets.only(top: 32, right: 24, left: 16, bottom: 16),
                  margin: const EdgeInsets.only(bottom: 32),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildLegendItem('Revenue', AppColors.primary, isDark),
                          const SizedBox(width: 16),
                          _buildLegendItem('Expense', AppColors.error, isDark),
                          const SizedBox(width: 16),
                          _buildLegendItem('Profit', AppColors.statusCompleted, isDark),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Expanded(child: _buildBarChart(groupsOldestToNewest, isDark)),
                    ],
                  ),
                ),
              
              Text('Detailed Breakdown', style: AppTypography.titleMedium(primaryText)),
              const SizedBox(height: 16),
              
              ...filteredGroups.map((g) {
                if (widget.reportType == 'Daily') {
                  return _buildDailyListTile(context, g, isDark, primaryText, secondaryText);
                } else if (widget.reportType == 'Monthly') {
                  return _buildMonthlyListTile(context, g, isDark, primaryText, secondaryText);
                } else {
                  return _buildStaticGroupCard(g, isDark, primaryText, secondaryText);
                }
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, bool isDark) {
    final textColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: AppTypography.caption(textColor)),
      ],
    );
  }

  Widget _buildBarChart(List<ReportGroupData> groups, bool isDark) {
    final textColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    
    double barWidth = 8;
    if (groups.length > 15) barWidth = 3;
    else if (groups.length > 7) barWidth = 5;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => isDark ? AppColors.darkSurfaceSecondary : AppColors.lightSurfaceSecondary,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              String label;
              if (rodIndex == 0) label = 'Revenue';
              else if (rodIndex == 1) label = 'Expense';
              else label = 'Profit';

              return BarTooltipItem(
                '${groups[groupIndex].shortTitle}\n$label: ₹${rod.toY.toStringAsFixed(0)}',
                AppTypography.labelMedium(isDark ? Colors.white : Colors.black).copyWith(fontWeight: FontWeight.bold),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                final idx = value.toInt();
                if (idx >= 0 && idx < groups.length) {
                  if (groups.length > 15 && idx % 3 != 0 && idx != groups.length - 1) {
                    return const SizedBox();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      groups[idx].shortTitle,
                      style: AppTypography.caption(textColor),
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: groups.asMap().entries.map((e) {
          final idx = e.key;
          final g = e.value;
          return BarChartGroupData(
            x: idx,
            barsSpace: groups.length > 15 ? 1 : 4,
            barRods: [
              BarChartRodData(
                toY: g.revenue,
                color: AppColors.primary,
                width: barWidth,
                borderRadius: BorderRadius.circular(4),
              ),
              BarChartRodData(
                toY: g.expense,
                color: AppColors.error,
                width: barWidth,
                borderRadius: BorderRadius.circular(4),
              ),
              BarChartRodData(
                toY: g.profit > 0 ? g.profit : 0,
                color: AppColors.statusCompleted,
                width: barWidth,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDailyListTile(BuildContext context, ReportGroupData group, bool isDark, Color primaryText, Color secondaryText) {
    return PressableScale(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DailyDetailScreen(
              group: group,
              onRefresh: widget.onRefresh,
            ),
          ),
        );
      },
      child: CustomCard(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(group.title, style: AppTypography.titleMedium(primaryText)),
                const SizedBox(height: 4),
                Text('₹${group.revenue.toStringAsFixed(0)} Revenue • ${group.jobs.length} jobs', style: AppTypography.caption(secondaryText)),
              ],
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyListTile(BuildContext context, ReportGroupData group, bool isDark, Color primaryText, Color secondaryText) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: PressableScale(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MonthlyDetailScreen(
                group: group,
                onRefresh: widget.onRefresh,
              ),
            ),
          );
        },
        child: CustomCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(group.title, style: AppTypography.titleMedium(primaryText)),
                  Row(
                    children: [
                      Text('View Details', style: AppTypography.labelMedium(AppColors.primary)),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.primary),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatColumn('Revenue', group.revenue, AppColors.primary, isDark),
                  _buildStatColumn('Expense', group.expense, AppColors.error, isDark),
                  _buildStatColumn('Profit', group.profit, AppColors.statusCompleted, isDark),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStaticGroupCard(ReportGroupData group, bool isDark, Color primaryText, Color secondaryText) {
    return CustomCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(group.title, style: AppTypography.titleMedium(primaryText)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatColumn('Revenue', group.revenue, AppColors.primary, isDark),
              _buildStatColumn('Expense', group.expense, AppColors.error, isDark),
              _buildStatColumn('Profit', group.profit, AppColors.statusCompleted, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, double amount, Color amountColor, bool isDark) {
    final secondaryText = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.caption(secondaryText)),
        const SizedBox(height: 4),
        Text(
          '₹${amount.toStringAsFixed(0)}',
          style: AppTypography.titleMedium(amountColor),
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}

class DailyDetailScreen extends StatelessWidget {
  final ReportGroupData group;
  final VoidCallback onRefresh;

  const DailyDetailScreen({super.key, required this.group, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryText = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      appBar: AppBar(title: Text(group.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 320,
              padding: const EdgeInsets.only(top: 32, right: 24, left: 16, bottom: 16),
              margin: const EdgeInsets.only(bottom: 32),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLegendItem('Revenue', AppColors.primary, isDark),
                      const SizedBox(width: 16),
                      _buildLegendItem('Expense', AppColors.error, isDark),
                      const SizedBox(width: 16),
                      _buildLegendItem('Profit', AppColors.statusCompleted, isDark),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Expanded(child: _buildSingleBarChart(isDark)),
                ],
              ),
            ),
            
            Text('Jobs Completed', style: AppTypography.titleMedium(primaryText)),
            const SizedBox(height: 16),
            ...group.jobs.map((job) {
              return CustomCard(
                margin: const EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.zero,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    '${job['model_name']} (${job['vehicle_no']})',
                    style: AppTypography.titleSmall(primaryText),
                  ),
                  subtitle: Text(job['customer_name'] ?? 'Walk-in Customer', style: AppTypography.bodySmall(secondaryText)),
                  trailing: Text(
                    '₹${job['amount_paid']}',
                    style: AppTypography.titleSmall(AppColors.primary),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => JobDetailsScreen(
                          job: job,
                          onJobUpdated: onRefresh,
                        ),
                      ),
                    );
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, bool isDark) {
    final textColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: AppTypography.caption(textColor)),
      ],
    );
  }

  Widget _buildSingleBarChart(bool isDark) {
    final textColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => isDark ? AppColors.darkSurfaceSecondary : AppColors.lightSurfaceSecondary,
            getTooltipItem: (groupData, groupIndex, rod, rodIndex) {
              String label;
              if (rodIndex == 0) label = 'Revenue';
              else if (rodIndex == 1) label = 'Expense';
              else label = 'Profit';

              return BarTooltipItem(
                '$label: ₹${rod.toY.toStringAsFixed(0)}',
                AppTypography.labelMedium(isDark ? Colors.white : Colors.black).copyWith(fontWeight: FontWeight.bold),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    group.shortTitle,
                    style: AppTypography.caption(textColor),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: [
          BarChartGroupData(
            x: 0,
            barsSpace: 16,
            barRods: [
              BarChartRodData(
                toY: group.revenue,
                color: AppColors.primary,
                width: 24,
                borderRadius: BorderRadius.circular(6),
              ),
              BarChartRodData(
                toY: group.expense,
                color: AppColors.error,
                width: 24,
                borderRadius: BorderRadius.circular(6),
              ),
              BarChartRodData(
                toY: group.profit > 0 ? group.profit : 0,
                color: AppColors.statusCompleted,
                width: 24,
                borderRadius: BorderRadius.circular(6),
              ),
            ],
          )
        ],
      ),
    );
  }
}

class MonthlyDetailScreen extends StatelessWidget {
  final ReportGroupData group;
  final VoidCallback onRefresh;

  const MonthlyDetailScreen({super.key, required this.group, required this.onRefresh});

  Future<void> _exportExcel(BuildContext context) async {
    try {
      final dailyMap = <String, ReportGroupData>{};
      for (var job in group.jobs) {
        final createdAtStr = (job['date'] ?? job['created_at'])?.toString();
        if (createdAtStr == null) continue;
        final date = DateTime.tryParse(createdAtStr);
        if (date == null) continue;

        final dayKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final dayTitle = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
        if (!dailyMap.containsKey(dayKey)) {
          dailyMap[dayKey] = ReportGroupData(dayTitle, dayKey, dayKey);
        }
        dailyMap[dayKey]!.addJob(job);
      }

      final sortedDays = dailyMap.values.toList()..sort((a, b) => a.sortKey.compareTo(b.sortKey));

      final excel.Workbook workbook = excel.Workbook();
      final excel.Worksheet sheet = workbook.worksheets[0];

      // Title
      sheet.getRangeByName('A1').setText('Monthly Financial Report - ${group.title}');
      sheet.getRangeByName('A1:E1').merge();
      final excel.Style titleStyle = workbook.styles.add('TitleStyle');
      titleStyle.bold = true;
      titleStyle.fontSize = 16;
      titleStyle.hAlign = excel.HAlignType.center;
      sheet.getRangeByName('A1:E1').cellStyle = titleStyle;

      // Header row
      sheet.getRangeByName('A3').setText('Date');
      sheet.getRangeByName('B3').setText('Jobs Completed');
      sheet.getRangeByName('C3').setText('Revenue (INR)');
      sheet.getRangeByName('D3').setText('Expense (INR)');
      sheet.getRangeByName('E3').setText('Profit (INR)');

      final excel.Style headerStyle = workbook.styles.add('HeaderStyle');
      headerStyle.backColor = '#0d47a1';
      headerStyle.fontColor = '#ffffff';
      headerStyle.bold = true;
      headerStyle.hAlign = excel.HAlignType.center;
      sheet.getRangeByName('A3:E3').cellStyle = headerStyle;

      // Rows
      int rowIndex = 4;
      for (var day in sortedDays) {
        sheet.getRangeByIndex(rowIndex, 1).setText(day.title);
        sheet.getRangeByIndex(rowIndex, 2).setNumber(day.jobs.length.toDouble());
        sheet.getRangeByIndex(rowIndex, 3).setNumber(day.revenue);
        sheet.getRangeByIndex(rowIndex, 4).setNumber(day.expense);
        sheet.getRangeByIndex(rowIndex, 5).setNumber(day.profit);
        
        // Center text alignment for cells
        sheet.getRangeByIndex(rowIndex, 1, rowIndex, 5).cellStyle.hAlign = excel.HAlignType.center;
        rowIndex++;
      }

      // Total row
      sheet.getRangeByIndex(rowIndex, 1).setText('TOTAL');
      sheet.getRangeByIndex(rowIndex, 2).setNumber(group.jobs.length.toDouble());
      sheet.getRangeByIndex(rowIndex, 3).setNumber(group.revenue);
      sheet.getRangeByIndex(rowIndex, 4).setNumber(group.expense);
      sheet.getRangeByIndex(rowIndex, 5).setNumber(group.profit);

      final excel.Style totalStyle = workbook.styles.add('TotalStyle');
      totalStyle.bold = true;
      totalStyle.backColor = '#e0e0e0';
      totalStyle.hAlign = excel.HAlignType.center;
      sheet.getRangeByIndex(rowIndex, 1, rowIndex, 5).cellStyle = totalStyle;

      // Auto-fit columns
      sheet.autoFitColumn(1);
      sheet.autoFitColumn(2);
      sheet.autoFitColumn(3);
      sheet.autoFitColumn(4);
      sheet.autoFitColumn(5);

      String businessName = 'MechFlow';
      try {
        final session = supabase.auth.currentSession;
        if (session != null) {
          final response = await supabase.from('shops').select('shop_name').eq('id', session.user.id).maybeSingle();
          if (response != null && response['shop_name'] != null) {
            businessName = response['shop_name'];
          }
        }
      } catch (_) {}

      final cleanTitle = group.title.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(' ', '_');
      final cleanBusinessName = businessName.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(' ', '_');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${cleanBusinessName}_${cleanTitle}_$timestamp.xlsx';

      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
      } else if (Platform.isIOS || Platform.isWindows) {
        downloadsDir = await getApplicationDocumentsDirectory();
      } else {
        downloadsDir = await getDownloadsDirectory();
      }
      downloadsDir ??= await getApplicationDocumentsDirectory();

      final String filePath = '${downloadsDir.path}${Platform.pathSeparator}$fileName';
      final file = File(filePath);
      
      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();
      
      await file.writeAsBytes(bytes);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report downloaded: $fileName'),
            backgroundColor: AppColors.statusCompleted,
            action: SnackBarAction(
              label: 'OPEN',
              textColor: Colors.white,
              onPressed: () {
                launchUrl(Uri.file(file.path));
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating report: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryText = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      appBar: AppBar(title: Text('${group.title} Report')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(group.title, style: AppTypography.displayMedium(primaryText)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${group.jobs.length} Jobs',
                          style: AppTypography.caption(AppColors.primary).copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatBox('Revenue', group.revenue, AppColors.primary, isDark),
                      _buildStatBox('Expense', group.expense, AppColors.error, isDark),
                      _buildStatBox('Profit', group.profit, AppColors.statusCompleted, isDark),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            CustomButton(
              label: 'Download Excel Report (.xls)',
              icon: Icons.table_chart_rounded,
              backgroundColor: const Color(0xFF10B981),
              onPressed: () => _exportExcel(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(String label, double amount, Color color, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.caption(isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
        const SizedBox(height: 4),
        Text(
          '₹${amount.toStringAsFixed(0)}',
          style: AppTypography.titleMedium(color).copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}

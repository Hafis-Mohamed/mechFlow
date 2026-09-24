import 'package:flutter/material.dart';
import '../../main.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/pressable_scale.dart';
import '../../core/widgets/shimmer_loading.dart';

class HomeTab extends StatefulWidget {
  final Map<String, dynamic>? shopDetails;
  final VoidCallback onNavigateToWork;
  final VoidCallback onNavigateToCustomers;

  const HomeTab({
    super.key,
    required this.shopDetails,
    required this.onNavigateToWork,
    required this.onNavigateToCustomers,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  int _activeJobsCount = 0;
  int _completedTodayCount = 0;
  int _totalCustomersCount = 0;
  int _pendingJobsCount = 0;
  
  double _todayRevenue = 0;
  double _todayExpense = 0;
  double _todayProfit = 0;

  bool _isLoadingCounts = true;

  @override
  void initState() {
    super.initState();
    _fetchLiveCounts();
  }

  Future<void> _fetchLiveCounts() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingCounts = false);
      return;
    }

    try {
      final jobsResponse = await supabase
          .from('jobs')
          .select('id, status, created_at, amount_paid, bill_items(actual_price)')
          .eq('shop_id', user.id);

      final jobs = List<Map<String, dynamic>>.from(jobsResponse);

      final now = DateTime.now();
      final todayStr = DateTime(now.year, now.month, now.day).toIso8601String().split('T')[0];

      int active = 0;
      int pending = 0;
      int completedToday = 0;
      
      double dailyRev = 0;
      double dailyExp = 0;

      for (var job in jobs) {
        final status = (job['status'] ?? '').toString().toLowerCase();
        if (status == 'in progress' || status == 'in_progress') {
          active++;
        } else if (status == 'pending') {
          pending++;
        } else if (status == 'completed') {
          final createdAt = job['created_at']?.toString() ?? '';
          if (createdAt.startsWith(todayStr)) {
            completedToday++;
            
            final amount = double.tryParse(job['amount_paid']?.toString() ?? '0') ?? 0.0;
            dailyRev += amount;
            
            final billItems = job['bill_items'] as List<dynamic>? ?? [];
            for (var item in billItems) {
              if (item is Map) {
                final actualPrice = double.tryParse(item['actual_price']?.toString() ?? '0') ?? 0.0;
                dailyExp += actualPrice;
              }
            }
          }
        }
      }

      // Customers count
      final customersResponse = await supabase
          .from('customers')
          .select('id')
          .eq('shop_id', user.id);

      final customerCount = (customersResponse as List).length;

      if (mounted) {
        setState(() {
          _activeJobsCount = active;
          _pendingJobsCount = pending;
          _completedTodayCount = completedToday;
          _totalCustomersCount = customerCount;
          _todayRevenue = dailyRev;
          _todayExpense = dailyExp;
          _todayProfit = dailyRev - dailyExp;
          _isLoadingCounts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCounts = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    final user = supabase.auth.currentUser;
    final shopName = widget.shopDetails?['shop_name'] ?? 'My Workshop';
    final location = widget.shopDetails?['location'] ?? 'Location not set';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Welcome Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: AppShadows.glowPrimary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.storefront_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shopName,
                            style: AppTypography.displayMedium(Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined, color: Colors.white70, size: 14),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  location,
                                  style: AppTypography.bodySmall(Colors.white70),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_user_rounded, color: Colors.amberAccent, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        user?.email ?? 'Logged In',
                        style: AppTypography.caption(Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Today's Financials
          Text(
            "Today's Financials",
            style: AppTypography.titleLarge(primaryText),
          ),
          const SizedBox(height: 14),
          
          if (_isLoadingCounts)
            const ShimmerLoading(width: double.infinity, height: 100, borderRadius: 16)
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildFinancialStat('Revenue', _todayRevenue, AppColors.primary, isDark),
                  _buildFinancialDivider(isDark),
                  _buildFinancialStat('Expense', _todayExpense, AppColors.error, isDark),
                  _buildFinancialDivider(isDark),
                  _buildFinancialStat('Profit', _todayProfit, AppColors.statusCompleted, isDark),
                ],
              ),
            ),
          const SizedBox(height: 28),

          // Quick Actions Section
          Text(
            'Quick Actions',
            style: AppTypography.titleLarge(primaryText),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: CustomButton(
                  label: 'Work Orders',
                  icon: Icons.build_circle_outlined,
                  onPressed: widget.onNavigateToWork,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: CustomButton(
                  label: 'Customers',
                  icon: Icons.person_add_alt_1_outlined,
                  isOutline: true,
                  onPressed: widget.onNavigateToCustomers,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Overview Stats Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Workshop Overview',
                style: AppTypography.titleLarge(primaryText),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                onPressed: _fetchLiveCounts,
                tooltip: 'Refresh Stats',
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Stats Cards Grid
          if (_isLoadingCounts)
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.45,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: List.generate(
                4,
                (_) => const ShimmerLoading(width: double.infinity, height: 100, borderRadius: 16),
              ),
            )
          else
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.45,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStatCard(
                  context,
                  title: 'In Progress',
                  value: '$_activeJobsCount',
                  icon: Icons.engineering_rounded,
                  color: AppColors.statusInProgress,
                  onTap: widget.onNavigateToWork,
                ),
                _buildStatCard(
                  context,
                  title: 'Completed Today',
                  value: '$_completedTodayCount',
                  icon: Icons.check_circle_rounded,
                  color: AppColors.statusCompleted,
                  onTap: widget.onNavigateToWork,
                ),
                _buildStatCard(
                  context,
                  title: 'Total Customers',
                  value: '$_totalCustomersCount',
                  icon: Icons.people_alt_rounded,
                  color: AppColors.secondary,
                  onTap: widget.onNavigateToCustomers,
                ),
                _buildStatCard(
                  context,
                  title: 'Pending Work',
                  value: '$_pendingJobsCount',
                  icon: Icons.hourglass_top_rounded,
                  color: AppColors.statusPending,
                  onTap: widget.onNavigateToWork,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                Text(
                  value,
                  style: AppTypography.displayMedium(color).copyWith(fontSize: 26),
                ),
              ],
            ),
            Text(
              title,
              style: AppTypography.labelMedium(titleColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialStat(String label, double amount, Color amountColor, bool isDark) {
    final secondaryText = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: AppTypography.caption(secondaryText)),
        const SizedBox(height: 6),
        Text(
          '₹${amount.toStringAsFixed(0)}',
          style: AppTypography.titleLarge(amountColor).copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildFinancialDivider(bool isDark) {
    return Container(
      width: 1,
      height: 40,
      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
    );
  }
}

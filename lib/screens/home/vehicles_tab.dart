import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/widgets/custom_card.dart';
import '../../main.dart'; // for supabase
import 'vehicle_history_screen.dart';

class VehiclesTab extends StatefulWidget {
  const VehiclesTab({super.key});

  @override
  State<VehiclesTab> createState() => _VehiclesTabState();
}

class _VehiclesTabState extends State<VehiclesTab> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, String>> _allVehicles = [];
  List<Map<String, String>> _filteredVehicles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchVehicles();
  }

  Future<void> _fetchVehicles() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await supabase
          .from('jobs')
          .select('vehicle_no, model_name')
          .eq('shop_id', user.id)
          .order('created_at', ascending: false);

      final Set<String> seen = {};
      final List<Map<String, String>> uniqueVehicles = [];

      for (var row in response) {
        final vNo = (row['vehicle_no']?.toString() ?? '').trim().toUpperCase();
        final model = (row['model_name']?.toString() ?? '').trim();
        if (vNo.isNotEmpty && !seen.contains(vNo)) {
          seen.add(vNo);
          uniqueVehicles.add({'vehicle_no': vNo, 'model_name': model});
        }
      }

      if (mounted) {
        setState(() {
          _allVehicles = uniqueVehicles;
          _filteredVehicles = uniqueVehicles;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading vehicles: $e')));
      }
    }
  }

  void _filterVehicles(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredVehicles = _allVehicles;
      });
    } else {
      final q = query.toLowerCase();
      setState(() {
        _filteredVehicles = _allVehicles.where((v) {
          final no = v['vehicle_no']!.toLowerCase();
          final model = v['model_name']!.toLowerCase();
          return no.contains(q) || model.contains(q);
        }).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryText = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vehicle Directory',
            style: AppTypography.titleLarge(primaryText),
          ),
          const SizedBox(height: 8),
          Text(
            'Browse or search for vehicles serviced at your shop to view their complete service history.',
            style: AppTypography.bodyMedium(secondaryText),
          ),
          const SizedBox(height: 20),
          CustomTextField(
            controller: _searchController,
            label: '',
            hint: 'Search by Vehicle Number or Model...',
            prefixIcon: Icons.search_rounded,
            onChanged: _filterVehicles,
          ),
          const SizedBox(height: 24),
          
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_filteredVehicles.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.directions_car_outlined, size: 64, color: secondaryText.withValues(alpha: 0.5)),
                    const SizedBox(height: 16),
                    Text(
                      'No vehicles found.',
                      style: AppTypography.titleMedium(secondaryText),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: _filteredVehicles.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final vehicle = _filteredVehicles[index];
                  final vNo = vehicle['vehicle_no']!;
                  final model = vehicle['model_name']!;
                  
                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VehicleHistoryScreen(
                            vehicleNo: vNo,
                            modelName: model,
                          ),
                        ),
                      ).then((_) => _fetchVehicles());
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: CustomCard(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.directions_car_rounded, color: AppColors.primary, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  vNo,
                                  style: AppTypography.titleMedium(primaryText).copyWith(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                if (model.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    model,
                                    style: AppTypography.bodyMedium(secondaryText),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
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

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../main.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/custom_card.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/widgets/empty_state_view.dart';
import '../../core/widgets/shimmer_loading.dart';
import 'job_details_screen.dart';

class CustomersTab extends StatefulWidget {
  const CustomersTab({super.key});

  @override
  State<CustomersTab> createState() => _CustomersTabState();
}

class _CustomersTabState extends State<CustomersTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Map<String, dynamic>> _customers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
  }

  Future<void> _fetchCustomers() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final data = await supabase
          .from('customers')
          .select()
          .eq('shop_id', user.id)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _customers = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addCustomer(String name, String phone) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      await supabase.from('customers').insert({
        'shop_id': user.id,
        'name': name,
        'phone': phone,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Customer added successfully!'),
            backgroundColor: AppColors.statusCompleted,
          ),
        );
        _fetchCustomers();
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save customer: ${error.message}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }



  void _showAddCustomerDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Customer'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomTextField(
                    controller: nameController,
                    label: 'Customer Name',
                    hint: 'e.g., Haris Mohammed',
                    prefixIcon: Icons.person_outline_rounded,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter customer name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: phoneController,
                    label: 'Phone Number',
                    hint: 'e.g., +91 9876543210',
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter phone number';
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
              label: 'Save Customer',
              isFullWidth: false,
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  _addCustomer(
                    nameController.text.trim(),
                    phoneController.text.trim(),
                  );
                  Navigator.pop(context);
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryText = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final filteredCustomers = _customers.where((customer) {
      final name = (customer['name'] ?? '').toString().toLowerCase();
      final phone = (customer['phone'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || phone.contains(query);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Customer Directory (${_customers.length})',
            style: AppTypography.titleLarge(primaryText),
          ),
          const SizedBox(height: 16),

          CustomTextField(
            controller: _searchController,
            label: '',
            hint: 'Search by name or phone number...',
            prefixIcon: Icons.search_rounded,
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
          const SizedBox(height: 20),

          Expanded(
            child: _isLoading
                ? const ShimmerListSkeleton(itemCount: 5)
                : filteredCustomers.isEmpty
                    ? EmptyStateView(
                        icon: Icons.people_outline_rounded,
                        title: _searchQuery.isEmpty ? 'No Customers Yet' : 'No Customer Found',
                        description: _searchQuery.isEmpty
                            ? 'Start building your customer directory by tapping "Add Customer".'
                            : 'No customer matching "$_searchQuery".',
                        actionLabel: _searchQuery.isEmpty ? 'Add Customer' : null,
                        onAction: _searchQuery.isEmpty ? _showAddCustomerDialog : null,
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchCustomers,
                        color: AppColors.primary,
                        child: ListView.separated(
                          itemCount: filteredCustomers.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final customer = filteredCustomers[index];
                            final name = customer['name'] ?? 'Unknown';
                            final phone = customer['phone'] ?? '';
                            final id = customer['id'];

                            return CustomCard(
                              onTap: () => _showCustomerDetailsModal(customer),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: AppColors.primaryGradient,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                                      style: AppTypography.titleLarge(Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: AppTypography.titleMedium(primaryText),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.phone_outlined,
                                              size: 14,
                                              color: AppColors.primary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              phone,
                                              style: AppTypography.bodySmall(secondaryText),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (phone.isNotEmpty)
                                    IconButton(
                                      icon: const Icon(Icons.call_outlined, color: AppColors.statusCompleted),
                                      onPressed: () => launchUrl(Uri.parse('tel:$phone')),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
          const SizedBox(height: 12),
          CustomButton(
            label: 'Add New Customer',
            icon: Icons.person_add_rounded,
            onPressed: _showAddCustomerDialog,
          ),
        ],
      ),
    );
  }

  void _showCustomerDetailsModal(Map<String, dynamic> customer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return CustomerVehiclesModal(
          customer: customer,
          onRefresh: _fetchCustomers,
        );
      },
    );
  }
}

class CustomerVehiclesModal extends StatefulWidget {
  final Map<String, dynamic> customer;
  final VoidCallback onRefresh;

  const CustomerVehiclesModal({
    super.key,
    required this.customer,
    required this.onRefresh,
  });

  @override
  State<CustomerVehiclesModal> createState() => _CustomerVehiclesModalState();
}

class _CustomerVehiclesModalState extends State<CustomerVehiclesModal> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _jobs = [];
  String? _expandedVehicleKey;

  @override
  void initState() {
    super.initState();
    _fetchCustomerJobs();
  }

  Future<void> _fetchCustomerJobs() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final customerId = widget.customer['id'];
      final customerPhone = widget.customer['phone']?.toString().trim() ?? '';
      final customerName = widget.customer['name']?.toString().trim() ?? '';

      var query = supabase.from('jobs').select('*, bill_items(selling_price, actual_price)').eq('shop_id', user.id);

      List<dynamic> response;
      if (customerId != null) {
        response = await query.eq('customer_id', customerId).order('created_at', ascending: false);
      } else if (customerPhone.isNotEmpty) {
        response = await query.eq('customer_phone', customerPhone).order('created_at', ascending: false);
      } else {
        response = await query.eq('customer_name', customerName).order('created_at', ascending: false);
      }

      if (mounted) {
        setState(() {
          _jobs = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryText = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final customerName = widget.customer['name'] ?? 'Customer';
    final customerPhone = widget.customer['phone'] ?? '';

    // Group jobs by vehicle (vehicle_no|model_name)
    final vehicleMap = <String, Map<String, dynamic>>{};
    for (var job in _jobs) {
      final vNo = (job['vehicle_no'] ?? '').toString().trim();
      final mName = (job['model_name'] ?? '').toString().trim();
      final key = vNo.isNotEmpty || mName.isNotEmpty ? '$mName|$vNo' : 'Unspecified Vehicle';

      if (!vehicleMap.containsKey(key)) {
        vehicleMap[key] = {
          'model_name': mName.isNotEmpty ? mName : 'Vehicle',
          'vehicle_no': vNo.isNotEmpty ? vNo : 'No Reg #',
          'jobs': <Map<String, dynamic>>[],
        };
      }
      (vehicleMap[key]!['jobs'] as List<Map<String, dynamic>>).add(job);
    }

    final vehicleList = vehicleMap.values.toList();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 24,
        left: 20,
        right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customerName,
                    style: AppTypography.titleLarge(primaryText),
                  ),
                  if (customerPhone.isNotEmpty)
                    Text(
                      customerPhone,
                      style: AppTypography.bodySmall(AppColors.primary),
                    ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Text(
            'Serviced Vehicles (${vehicleList.length})',
            style: AppTypography.titleSmall(secondaryText),
          ),
          const SizedBox(height: 12),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (vehicleList.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.directions_car_outlined, size: 48, color: AppColors.primary),
                    const SizedBox(height: 8),
                    Text(
                      'No vehicles serviced yet for this customer.',
                      style: AppTypography.bodyMedium(secondaryText),
                    ),
                  ],
                ),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: vehicleList.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final v = vehicleList[index];
                  final mName = v['model_name'];
                  final vNo = v['vehicle_no'];
                  final jobs = v['jobs'] as List<Map<String, dynamic>>;
                  final key = '$mName|$vNo';
                  final isExpanded = _expandedVehicleKey == key || vehicleList.length == 1;

                  return Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceSecondary : AppColors.lightSurfaceSecondary,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                            child: const Icon(Icons.directions_car_rounded, color: AppColors.primary, size: 20),
                          ),
                          title: Text(
                            '$mName ($vNo)',
                            style: AppTypography.titleSmall(primaryText),
                          ),
                          subtitle: Text(
                            '${jobs.length} Service ${jobs.length == 1 ? 'Record' : 'Records'}',
                            style: AppTypography.caption(secondaryText),
                          ),
                          trailing: Icon(
                            isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                            color: AppColors.primary,
                          ),
                          onTap: () {
                            setState(() {
                              _expandedVehicleKey = isExpanded ? null : key;
                            });
                          },
                        ),
                        if (isExpanded) ...[
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: jobs.map((job) {
                                final createdAtStr = job['created_at']?.toString() ?? '';
                                DateTime? date;
                                if (createdAtStr.isNotEmpty) {
                                  date = DateTime.tryParse(createdAtStr);
                                }
                                final dateFormatted = date != null
                                    ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'
                                    : 'Date N/A';
                                final status = job['status'] ?? 'Pending';
                                final desc = job['work_description'] ?? 'General Service';
                                final amountPaid = job['amount_paid']?.toString() ?? '0';

                                return InkWell(
                                  onTap: () {
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => JobDetailsScreen(
                                          job: job,
                                          onJobUpdated: widget.onRefresh,
                                        ),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            dateFormatted,
                                            style: AppTypography.caption(AppColors.primary).copyWith(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                desc,
                                                style: AppTypography.bodySmall(primaryText).copyWith(fontWeight: FontWeight.w600),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Status: $status • Paid: ₹$amountPaid',
                                                style: AppTypography.caption(secondaryText),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.primary),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ],
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/custom_card.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/custom_text_field.dart';
import '../../core/widgets/empty_state_view.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/shimmer_loading.dart';
import 'job_details_screen.dart';

class WorkTab extends StatefulWidget {
  const WorkTab({super.key});

  @override
  State<WorkTab> createState() => _WorkTabState();
}

class _WorkTabState extends State<WorkTab> {
  bool _showCompleted = false;
  List<Map<String, dynamic>> _jobs = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchJobs();
  }

  Future<void> _fetchJobs() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final jobsData = await supabase
          .from('jobs')
          .select('*, bill_items(selling_price)')
          .eq('shop_id', user.id)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _jobs = List<Map<String, dynamic>>.from(jobsData);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addJob({
    required Map<String, dynamic>? selectedCustomer,
    String? customerNameInput,
    required String vehicleNo,
    required String modelName,
    required String workDescription,
    required String status,
    String? meterReading,
    String? vin,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      await supabase.from('jobs').insert({
        'shop_id': user.id,
        'customer_id': selectedCustomer?['id'],
        'customer_name': selectedCustomer?['name'] ?? 
            (selectedCustomer == null && customerNameInput != null && customerNameInput.isNotEmpty 
                ? customerNameInput 
                : 'Walk-in Customer'),
        'customer_phone': selectedCustomer?['phone'] ?? '',
        'vehicle_no': vehicleNo,
        'model_name': modelName,
        'work_description': workDescription,
        'status': status,
        if (meterReading != null && meterReading.isNotEmpty) 'meter_reading': meterReading,
        if (vin != null && vin.isNotEmpty) 'vin': vin,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job order created successfully!'),
            backgroundColor: AppColors.statusCompleted,
          ),
        );
        _fetchJobs();
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save job: ${error.message}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteJob(dynamic jobId) async {
    try {
      await supabase.from('jobs').delete().eq('id', jobId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job order deleted.'),
            backgroundColor: AppColors.statusCompleted,
          ),
        );
        _fetchJobs();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting job: $error'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showAddJobDialog() {
    final formKey = GlobalKey<FormState>();
    Map<String, dynamic>? selectedCustomer;
    TextEditingController? customerSearchController;
    final vehicleNoController = TextEditingController();
    final modelNameController = TextEditingController();
    final meterReadingController = TextEditingController();
    final vinController = TextEditingController();
    final workController = TextEditingController();

    List<Map<String, String>> customerVehicles = [];
    bool isLoadingVehicles = false;
    int selectedVehicleIndex = -1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final primaryText = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
            final secondaryText = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

            return GlassContainer(
              blur: 16,
              opacity: 0.95,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 28,
                left: 24,
                right: 24,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Create Work Order',
                            style: AppTypography.titleLarge(primaryText),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Customer autocomplete search
                      Autocomplete<Map<String, dynamic>>(
                        displayStringForOption: (customer) =>
                            '${customer['name']} (${customer['phone']})',
                        optionsBuilder: (TextEditingValue textEditingValue) async {
                          final query = textEditingValue.text.trim();
                          if (query.isEmpty) {
                            return const Iterable<Map<String, dynamic>>.empty();
                          }

                          final user = supabase.auth.currentUser;
                          if (user == null) {
                            return const Iterable<Map<String, dynamic>>.empty();
                          }

                          try {
                            final response = await supabase
                                .from('customers')
                                .select()
                                .eq('shop_id', user.id)
                                .or('name.ilike.%$query%,phone.ilike.%$query%')
                                .limit(8);

                            return List<Map<String, dynamic>>.from(response);
                          } catch (_) {
                            return const Iterable<Map<String, dynamic>>.empty();
                          }
                        },
                        onSelected: (Map<String, dynamic> selection) async {
                          setModalState(() {
                            selectedCustomer = selection;
                            isLoadingVehicles = true;
                            customerVehicles = [];
                            selectedVehicleIndex = -1;
                            vehicleNoController.clear();
                            modelNameController.clear();
                            vinController.clear();
                          });

                          try {
                            final user = supabase.auth.currentUser;
                            if (user != null) {
                              final response = await supabase
                                  .from('jobs')
                                  .select('vehicle_no, model_name, vin')
                                  .eq('shop_id', user.id)
                                  .eq('customer_id', selection['id']);

                              final uniqueVehicles = <String, Map<String, String>>{};
                              for (var job in response) {
                                final vNo = (job['vehicle_no'] ?? '').toString().trim();
                                final mName = (job['model_name'] ?? '').toString().trim();
                                final vin = (job['vin'] ?? '').toString().trim();
                                if (vNo.isNotEmpty && mName.isNotEmpty) {
                                  final key = '$vNo|$mName';
                                  uniqueVehicles[key] = {'vehicle_no': vNo, 'model_name': mName, 'vin': vin};
                                }
                              }

                              setModalState(() {
                                customerVehicles = uniqueVehicles.values.toList();
                                if (customerVehicles.isNotEmpty) {
                                  selectedVehicleIndex = 0;
                                  vehicleNoController.text = customerVehicles[0]['vehicle_no'] ?? '';
                                  modelNameController.text = customerVehicles[0]['model_name'] ?? '';
                                  vinController.text = customerVehicles[0]['vin'] ?? '';
                                } else {
                                  selectedVehicleIndex = -1;
                                }
                                isLoadingVehicles = false;
                              });
                            }
                          } catch (_) {
                            setModalState(() {
                              selectedVehicleIndex = -1;
                              isLoadingVehicles = false;
                            });
                          }
                        },
                        optionsViewBuilder: (context, onSelected, options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 8.0,
                              borderRadius: BorderRadius.circular(16),
                              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                              child: Container(
                                constraints: const BoxConstraints(maxHeight: 200),
                                width: MediaQuery.of(context).size.width - 48,
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  itemCount: options.length,
                                  itemBuilder: (BuildContext context, int index) {
                                    final option = options.elementAt(index);
                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                                        child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 20),
                                      ),
                                      title: Text(
                                        option['name'] ?? '',
                                        style: AppTypography.titleSmall(primaryText),
                                      ),
                                      subtitle: Text(
                                        option['phone'] ?? '',
                                        style: AppTypography.bodySmall(
                                          isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                        ),
                                      ),
                                      onTap: () => onSelected(option),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                        fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                          customerSearchController = textEditingController;
                          return CustomTextField(
                            controller: textEditingController,
                            focusNode: focusNode,
                            label: 'Customer (Name or Phone)',
                            hint: 'Type customer name to search...',
                            prefixIcon: Icons.search_rounded,
                            inputFormatters: [
                              TextInputFormatter.withFunction((oldValue, newValue) {
                                if (newValue.text.isEmpty) return newValue;
                                StringBuffer newText = StringBuffer();
                                bool capNext = true;
                                for (int i = 0; i < newValue.text.length; i++) {
                                  final char = newValue.text[i];
                                  if (char.trim().isEmpty) { capNext = true; newText.write(char); }
                                  else { newText.write(capNext ? char.toUpperCase() : char); capNext = false; }
                                }
                                return newValue.copyWith(text: newText.toString());
                              }),
                            ],
                            onChanged: (value) {
                              if (selectedCustomer != null) {
                                setModalState(() {
                                  selectedCustomer = null;
                                  customerVehicles = [];
                                  selectedVehicleIndex = -1;
                                  vehicleNoController.clear();
                                  modelNameController.clear();
                                  vinController.clear();
                                });
                              }
                            },
                            suffixIcon: selectedCustomer != null
                                ? const Icon(Icons.check_circle_rounded, color: AppColors.statusCompleted)
                                : null,
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      if (isLoadingVehicles)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.0),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            ),
                          ),
                        )
                      else if (selectedCustomer != null && customerVehicles.isNotEmpty) ...[
                        Text(
                          'Previously Serviced Vehicles',
                          style: AppTypography.labelMedium(secondaryText),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ...List.generate(customerVehicles.length, (index) {
                                final v = customerVehicles[index];
                                final isSelected = selectedVehicleIndex == index;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () {
                                      setModalState(() {
                                        selectedVehicleIndex = index;
                                        vehicleNoController.text = v['vehicle_no'] ?? '';
                                        modelNameController.text = v['model_name'] ?? '';
                                        vinController.text = v['vin'] ?? '';
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.primary
                                            : (isDark ? AppColors.darkSurfaceSecondary : AppColors.lightSurfaceSecondary),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected
                                              ? AppColors.primary
                                              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                          width: isSelected ? 1.5 : 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.directions_car_rounded,
                                            size: 16,
                                            color: isSelected ? Colors.white : AppColors.primary,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${v['model_name']} (${v['vehicle_no']})',
                                            style: AppTypography.bodySmall(
                                              isSelected ? Colors.white : primaryText,
                                            ).copyWith(
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                              InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  setModalState(() {
                                    selectedVehicleIndex = -1;
                                    vehicleNoController.clear();
                                    modelNameController.clear();
                                    vinController.clear();
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: selectedVehicleIndex == -1
                                        ? AppColors.primary
                                        : (isDark ? AppColors.darkSurfaceSecondary : AppColors.lightSurfaceSecondary),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: selectedVehicleIndex == -1
                                          ? AppColors.primary
                                          : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                      width: selectedVehicleIndex == -1 ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.add_rounded,
                                        size: 16,
                                        color: selectedVehicleIndex == -1 ? Colors.white : AppColors.primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'New Vehicle',
                                        style: AppTypography.bodySmall(
                                          selectedVehicleIndex == -1 ? Colors.white : primaryText,
                                        ).copyWith(
                                          fontWeight: selectedVehicleIndex == -1 ? FontWeight.bold : FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      CustomTextField(
                        controller: vehicleNoController,
                        label: 'Vehicle Registration Number',
                        hint: 'e.g., KA-05-AB-1234',
                        prefixIcon: Icons.confirmation_number_outlined,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          TextInputFormatter.withFunction(
                            (oldValue, newValue) => TextEditingValue(
                              text: newValue.text.toUpperCase(),
                              selection: newValue.selection,
                            ),
                          ),
                        ],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter vehicle number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      CustomTextField(
                        controller: modelNameController,
                        label: 'Vehicle Model',
                        hint: 'e.g., Swift Dzire / Royal Enfield',
                        prefixIcon: Icons.directions_car_outlined,
                        inputFormatters: [
                          TextInputFormatter.withFunction((oldValue, newValue) {
                            if (newValue.text.isEmpty) return newValue;
                            StringBuffer newText = StringBuffer();
                            bool capNext = true;
                            for (int i = 0; i < newValue.text.length; i++) {
                              final char = newValue.text[i];
                              if (char.trim().isEmpty) { capNext = true; newText.write(char); }
                              else { newText.write(capNext ? char.toUpperCase() : char); capNext = false; }
                            }
                            return newValue.copyWith(text: newText.toString());
                          }),
                        ],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter vehicle model';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      CustomTextField(
                        controller: meterReadingController,
                        label: 'Odometer Reading (km)',
                        hint: 'e.g., 15000',
                        prefixIcon: Icons.speed_outlined,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),

                      CustomTextField(
                        controller: vinController,
                        label: 'Chassis Number (VIN)',
                        hint: 'e.g., MA1234567890',
                        prefixIcon: Icons.pin_outlined,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          TextInputFormatter.withFunction(
                            (oldValue, newValue) => TextEditingValue(
                              text: newValue.text.toUpperCase(),
                              selection: newValue.selection,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      CustomTextField(
                        controller: workController,
                        label: 'Work Description / Requirements',
                        hint: 'e.g., Engine oil change, brake servicing',
                        prefixIcon: Icons.build_circle_outlined,
                        inputFormatters: [
                          TextInputFormatter.withFunction((oldValue, newValue) {
                            if (newValue.text.isEmpty) return newValue;
                            return newValue.copyWith(text: newValue.text[0].toUpperCase() + newValue.text.substring(1));
                          }),
                        ],
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please describe the work required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),

                      CustomButton(
                        label: 'Create Work Order',
                        icon: Icons.add_task_rounded,
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            _addJob(
                              selectedCustomer: selectedCustomer,
                              customerNameInput: customerSearchController?.text.trim(),
                              vehicleNo: vehicleNoController.text.trim(),
                              modelName: modelNameController.text.trim(),
                              workDescription: workController.text.trim(),
                              status: 'Pending',
                              meterReading: meterReadingController.text.trim(),
                              vin: vinController.text.trim(),
                            );
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryText = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final searchQuery = _searchController.text.trim().toLowerCase();

    final filteredJobs = _jobs.where((job) {
      final status = (job['status'] ?? '').toString();
      bool statusMatches = false;
      if (_showCompleted) {
        statusMatches = (status == 'Completed');
      } else {
        statusMatches = (status == 'Pending' || status == 'In Progress' || status == 'Ready');
      }

      if (!statusMatches) return false;

      if (_showCompleted && searchQuery.isNotEmpty) {
        final custName = (job['customer_name'] ?? '').toString().toLowerCase();
        final vehName = (job['model_name'] ?? '').toString().toLowerCase();
        final vehNo = (job['vehicle_no'] ?? '').toString().toLowerCase();

        return custName.contains(searchQuery) ||
            vehName.contains(searchQuery) ||
            vehNo.contains(searchQuery);
      }

      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Create Action
          Text(
            _showCompleted
                ? 'Completed Works (${filteredJobs.length})'
                : 'Active Work Orders (${filteredJobs.length})',
            style: AppTypography.titleLarge(primaryText),
          ),
          const SizedBox(height: 14),

          // Segmented filter toggle
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  label: 'Ongoing Work',
                  isOutline: _showCompleted,
                  onPressed: () {
                    if (_showCompleted) {
                      setState(() {
                        _showCompleted = false;
                        _searchController.clear();
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomButton(
                  label: 'Completed',
                  isOutline: !_showCompleted,
                  onPressed: () {
                    if (!_showCompleted) {
                      setState(() => _showCompleted = true);
                    }
                  },
                ),
              ),
            ],
          ),
          if (_showCompleted) ...[
            const SizedBox(height: 14),
            CustomTextField(
              controller: _searchController,
              label: '',
              hint: 'Search completed works by vehicle or customer...',
              prefixIcon: Icons.search_rounded,
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 20),

          // List view with loading skeleton & empty state
          Expanded(
            child: _isLoading
                ? const ShimmerListSkeleton(itemCount: 5)
                : filteredJobs.isEmpty
                    ? EmptyStateView(
                        icon: _showCompleted ? Icons.task_alt_rounded : Icons.build_circle_outlined,
                        title: _showCompleted ? 'No Completed Works' : 'No Active Work Orders',
                        description: _showCompleted
                            ? 'Completed jobs will appear here after status updates.'
                            : 'Tap "New Work Order" to create your first workshop job order.',
                        actionLabel: _showCompleted ? null : 'Create Work Order',
                        onAction: _showCompleted ? null : _showAddJobDialog,
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchJobs,
                        color: AppColors.primary,
                        child: ListView.separated(
                          itemCount: filteredJobs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final job = filteredJobs[index];
                            final customerName = job['customer_name'] ?? 'Walk-in Customer';
                            final customerPhone = job['customer_phone'] ?? '';
                            final vehicleNo = job['vehicle_no'] ?? '';
                            final modelName = job['model_name'] ?? '';
                            final workDesc = job['work_description'] ?? '';
                            final statusStr = job['status'] ?? 'Pending';
                            final jobId = job['id'];

                            final billItems = (job['bill_items'] as List?) ?? [];
                            final double totalAmount = billItems.fold(0.0, (sum, item) {
                              final price = double.tryParse(item['selling_price'].toString()) ?? 0.0;
                              return sum + price;
                            });

                            final amountPaid =
                                double.tryParse(job['amount_paid']?.toString() ?? '0') ?? 0.0;
                            final balance = totalAmount - amountPaid;

                            return CustomCard(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (_, __, ___) => JobDetailsScreen(
                                      job: job,
                                      onJobUpdated: _fetchJobs,
                                    ),
                                    transitionsBuilder: (_, a, __, c) => FadeTransition(
                                      opacity: a,
                                      child: c,
                                    ),
                                  ),
                                );
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: const Icon(
                                                Icons.directions_car_rounded,
                                                color: AppColors.primary,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    modelName,
                                                    style: AppTypography.titleMedium(primaryText),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  Text(
                                                    vehicleNo,
                                                    style: AppTypography.labelMedium(secondaryText),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      CustomBadge(status: statusStr),
                                    ],
                                  ),
                                  const SizedBox(height: 14),

                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.person_outline_rounded,
                                        size: 16,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        customerName,
                                        style: AppTypography.labelLarge(primaryText),
                                      ),
                                      if (customerPhone.isNotEmpty) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          '($customerPhone)',
                                          style: AppTypography.bodySmall(secondaryText),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppColors.darkSurfaceSecondary
                                          : AppColors.lightSurfaceSecondary,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      workDesc,
                                      style: AppTypography.bodyMedium(secondaryText),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(height: 14),

                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: AppColors.statusCompleted
                                                  .withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: AppColors.statusCompleted
                                                    .withValues(alpha: 0.3),
                                              ),
                                            ),
                                            child: Text(
                                              'Total: ₹${totalAmount.toStringAsFixed(2)}',
                                              style: AppTypography.labelMedium(
                                                AppColors.statusCompleted,
                                              ),
                                            ),
                                          ),
                                          if (balance > 0) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: AppColors.error.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: AppColors.error.withValues(alpha: 0.3),
                                                ),
                                              ),
                                              child: Text(
                                                'Bal: ₹${balance.toStringAsFixed(2)}',
                                                style: AppTypography.labelMedium(AppColors.error),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      if (statusStr != 'Completed')
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            color: AppColors.error,
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            if (jobId != null) {
                                              _deleteJob(jobId);
                                            }
                                          },
                                        ),
                                    ],
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
            label: 'Create New Work Order',
            icon: Icons.add_rounded,
            onPressed: _showAddJobDialog,
          ),
        ],
      ),
    );
  }
}

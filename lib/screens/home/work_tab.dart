import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../main.dart';
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
      // Fetch Jobs along with bill items for total amount
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
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addJob({
    required Map<String, dynamic>? selectedCustomer,
    required String vehicleNo,
    required String modelName,
    required String workDescription,
    required String status,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      await supabase.from('jobs').insert({
        'shop_id': user.id,
        'customer_id': selectedCustomer?['id'],
        'customer_name': selectedCustomer?['name'] ?? 'Walk-in Customer',
        'customer_phone': selectedCustomer?['phone'] ?? '',
        'vehicle_no': vehicleNo,
        'model_name': modelName,
        'work_description': workDescription,
        'status': status,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job created successfully!')),
        );
        _fetchJobs();
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save job: ${error.message}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _updateJobStatus(dynamic jobId, String newStatus) async {
    try {
      await supabase
          .from('jobs')
          .update({'status': newStatus})
          .eq('id', jobId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Job status updated to $newStatus')),
        );
        _fetchJobs();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $error')),
        );
      }
    }
  }

  Future<void> _deleteJob(dynamic jobId) async {
    try {
      await supabase.from('jobs').delete().eq('id', jobId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job order deleted.')),
        );
        _fetchJobs();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting job: $error')),
        );
      }
    }
  }

  void _showAddJobDialog() {
    final formKey = GlobalKey<FormState>();
    Map<String, dynamic>? selectedCustomer;
    final vehicleNoController = TextEditingController();
    final modelNameController = TextEditingController();
    final workController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 24,
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
                            'Create New Job Order',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 1. Searchable Customer Field (Search results appear while typing)
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
                                .limit(10);

                            return List<Map<String, dynamic>>.from(response);
                          } catch (_) {
                            return const Iterable<Map<String, dynamic>>.empty();
                          }
                        },
                        onSelected: (Map<String, dynamic> selection) {
                          setModalState(() {
                            selectedCustomer = selection;
                          });
                        },
                        optionsViewBuilder: (context, onSelected, options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 6.0,
                              borderRadius: BorderRadius.circular(12),
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
                                      leading: const Icon(Icons.person, color: Colors.deepPurple),
                                      title: Text(
                                        option['name'] ?? '',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Text(option['phone'] ?? ''),
                                      onTap: () {
                                        onSelected(option);
                                      },
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                        fieldViewBuilder: (context, textEditingController, focusNode,
                            onFieldSubmitted) {
                          return TextFormField(
                            controller: textEditingController,
                            focusNode: focusNode,
                            onChanged: (val) {
                              if (val.trim().isEmpty) {
                                setModalState(() {
                                  selectedCustomer = null;
                                });
                              }
                            },
                            decoration: InputDecoration(
                              labelText: 'Search Customer (Name or Phone) *',
                              hintText: 'Type to search customer...',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: selectedCustomer != null
                                  ? const Icon(Icons.check_circle, color: Colors.green)
                                  : null,
                              border: const OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (selectedCustomer == null &&
                                  (value == null || value.trim().isEmpty)) {
                                return 'Please search & select a customer';
                              }
                              return null;
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      // 2. Vehicle Number
                      TextFormField(
                        controller: vehicleNoController,
                        decoration: const InputDecoration(
                          labelText: 'Vehicle Number *',
                          hintText: 'e.g., KA-05-AB-1234',
                          prefixIcon: Icon(Icons.confirmation_number_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter vehicle number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // 3. Model Name
                      TextFormField(
                        controller: modelNameController,
                        decoration: const InputDecoration(
                          labelText: 'Model Name *',
                          hintText: 'e.g., Swift Dzire / Royal Enfield',
                          prefixIcon: Icon(Icons.directions_car_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter vehicle model';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // 4. Work Description
                      TextFormField(
                        controller: workController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Work / Issue Description *',
                          hintText: 'e.g., Engine oil change, brake servicing',
                          prefixIcon: Icon(Icons.build_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please describe the work to be done';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      const SizedBox(height: 20),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            if (formKey.currentState!.validate()) {
                              _addJob(
                                selectedCustomer: selectedCustomer,
                                vehicleNo: vehicleNoController.text.trim(),
                                modelName: modelNameController.text.trim(),
                                workDescription: workController.text.trim(),
                                status: 'Pending',
                              );
                              Navigator.pop(context);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Create Job Order'),
                        ),
                      ),
                      const SizedBox(height: 24),
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
  Widget build(BuildContext context) {
    final searchQuery = _searchController.text.trim().toLowerCase();

    final filteredJobs = _jobs.where((job) {
      final status = job['status'] ?? '';
      
      bool statusMatches = false;
      if (_showCompleted) {
        statusMatches = (status == 'Completed');
      } else {
        statusMatches = (status == 'Pending' || status == 'In Progress');
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
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Create Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _showCompleted ? 'Completed Works (${filteredJobs.length})' : 'Ongoing Work (${filteredJobs.length})',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              ElevatedButton.icon(
                onPressed: _showAddJobDialog,
                icon: const Icon(Icons.add_task, size: 18),
                label: const Text('New Job'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Toggle Completed Works Button
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _showCompleted = !_showCompleted;
                  if (!_showCompleted) {
                    _searchController.clear();
                  }
                });
              },
              icon: Icon(_showCompleted ? Icons.arrow_back : Icons.task_alt),
              label: Text(_showCompleted ? 'Back to Ongoing Work' : 'Show Completed Works'),
            ),
          ),
          if (_showCompleted) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search completed works',
                hintText: 'Customer, Vehicle Model or Number',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (val) {
                setState(() {});
              },
            ),
          ],
          const SizedBox(height: 16),

          // Jobs List View
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredJobs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.build_circle_outlined,
                                size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text(
                              _showCompleted
                                  ? 'No completed works found.'
                                  : 'No ongoing works found.',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchJobs,
                        child: ListView.builder(
                          itemCount: filteredJobs.length,
                          itemBuilder: (context, index) {
                            final job = filteredJobs[index];
                            final customerName =
                                job['customer_name'] ?? 'Unknown Customer';
                            final customerPhone = job['customer_phone'] ?? '';
                            final vehicleNo = job['vehicle_no'] ?? '';
                            final modelName = job['model_name'] ?? '';
                            final workDesc = job['work_description'] ?? '';
                            final statusStr = job['status'] ?? 'Pending';
                            final jobId = job['id'];
                            final statusColor = _getStatusColor(statusStr);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => JobDetailsScreen(
                                        job: job,
                                        onJobUpdated: _fetchJobs,
                                      ),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '$modelName ($vehicleNo)',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: statusColor
                                                  .withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              statusStr,
                                              style: TextStyle(
                                                color: statusColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(Icons.person,
                                              size: 16, color: Colors.grey),
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
                                              style: const TextStyle(
                                                  color: Colors.grey, fontSize: 13),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          workDesc,
                                          style: TextStyle(
                                            color: Colors.grey[800],
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      (() {
                                        final billItems = (job['bill_items'] as List?) ?? [];
                                        final double totalAmount = billItems.fold(0.0, (sum, item) {
                                          final price = double.tryParse(item['selling_price'].toString()) ?? 0.0;
                                          return sum + price;
                                        });
                                        
                                        final amountPaid = double.tryParse(job['amount_paid']?.toString() ?? '0') ?? 0.0;
                                        final balance = totalAmount - amountPaid;

                                        return Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 10, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green.withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(
                                                        color: Colors.green.withValues(alpha: 0.3)),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      const Text(
                                                        'Bill: ',
                                                        style: TextStyle(
                                                            fontSize: 12, color: Colors.grey),
                                                      ),
                                                      Text(
                                                        '₹${totalAmount.toStringAsFixed(2)}',
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 14,
                                                          color: Colors.green,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                if (balance > 0)
                                                  Container(
                                                    margin: const EdgeInsets.only(left: 8),
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 10, vertical: 6),
                                                    decoration: BoxDecoration(
                                                      color: Colors.redAccent.withValues(alpha: 0.12),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(
                                                          color: Colors.redAccent.withValues(alpha: 0.3)),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        const Text(
                                                          'Bal: ',
                                                          style: TextStyle(
                                                              fontSize: 12, color: Colors.grey),
                                                        ),
                                                        Text(
                                                          '₹${balance.toStringAsFixed(2)}',
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 14,
                                                            color: Colors.redAccent,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline,
                                                  color: Colors.red, size: 20),
                                              onPressed: () {
                                                if (jobId != null) {
                                                  _deleteJob(jobId);
                                                }
                                              },
                                            ),
                                          ],
                                        );
                                      }()),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../main.dart';
import 'home_tab.dart';
import 'customers_tab.dart';
import 'work_tab.dart';
import 'profile_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  Map<String, dynamic>? _shopDetails;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadShopDetails();
  }

  Future<void> _loadShopDetails() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      try {
        final data = await supabase
            .from('shops')
            .select()
            .eq('id', user.id)
            .maybeSingle();
        if (mounted) {
          setState(() {
            _shopDetails = data;
            _isLoading = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final List<Widget> tabs = [
      HomeTab(
        shopDetails: _shopDetails,
        onNavigateToWork: () => setState(() => _currentIndex = 2),
        onNavigateToCustomers: () => setState(() => _currentIndex = 1),
      ),
      const CustomersTab(),
      const WorkTab(),
      ProfileTab(
        shopDetails: _shopDetails,
        onRefreshShopDetails: _loadShopDetails,
      ),
    ];

    final List<String> titles = [
      'Dashboard',
      'Customers',
      'Work Orders',
      'Shop Profile',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_currentIndex]),
        centerTitle: false,
        elevation: 0,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: tabs,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'Customers',
          ),
          NavigationDestination(
            icon: Icon(Icons.build_circle_outlined),
            selectedIcon: Icon(Icons.build_circle_rounded),
            label: 'Work',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

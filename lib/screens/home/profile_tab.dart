import 'package:flutter/material.dart';
import '../../main.dart';
import '../startup/shop_details_screen.dart';

class ProfileTab extends StatelessWidget {
  final Map<String, dynamic>? shopDetails;
  final VoidCallback onRefreshShopDetails;

  const ProfileTab({
    super.key,
    required this.shopDetails,
    required this.onRefreshShopDetails,
  });

  Future<void> _signOut(BuildContext context) async {
    await supabase.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final shopName = shopDetails?['shop_name'] ?? 'My Workshop';
    final location = shopDetails?['location'] ?? 'Location not set';
    final phone = shopDetails?['phone'] ?? 'No phone added';
    final email = shopDetails?['email'] ?? user?.email ?? 'No email';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 12),
          CircleAvatar(
            radius: 50,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(
              Icons.storefront,
              size: 50,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            shopName,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          const SizedBox(height: 24),

          // Details List Card
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.business),
                    title: const Text('Shop Name'),
                    subtitle: Text(shopName),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: const Text('Location / Address'),
                    subtitle: Text(location),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.phone_outlined),
                    title: const Text('Contact Phone'),
                    subtitle: Text(phone),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.email_outlined),
                    title: const Text('Account Email'),
                    subtitle: Text(email),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Edit Shop Details Button
          OutlinedButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ShopDetailsScreen(),
                ),
              );
              onRefreshShopDetails();
            },
            icon: const Icon(Icons.edit),
            label: const Text('Edit Shop Details'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Sign Out Button
          ElevatedButton.icon(
            onPressed: () => _signOut(context),
            icon: const Icon(Icons.logout),
            label: const Text('Sign Out'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

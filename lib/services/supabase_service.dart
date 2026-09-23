import 'package:supabase_flutter/supabase_flutter.dart';

/// Helper service for common Supabase actions (Auth, Database, Storage)
class SupabaseService {
  final SupabaseClient client = Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // AUTHENTICATION
  // ---------------------------------------------------------------------------

  /// Sign Up a new user with Email and Password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return await client.auth.signUp(
      email: email,
      password: password,
    );
  }

  /// Sign In an existing user with Email and Password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign Out current user
  Future<void> signOut() async {
    await client.auth.signOut();
  }

  /// Get Current Session User
  User? get currentUser => client.auth.currentUser;

  // ---------------------------------------------------------------------------
  // DATABASE (CRUD)
  // ---------------------------------------------------------------------------

  /// Fetch data from a table
  Future<List<Map<String, dynamic>>> fetchData(String tableName) async {
    final response = await client.from(tableName).select();
    return List<Map<String, dynamic>>.from(response);
  }

  /// Insert a record into a table
  Future<void> insertData({
    required String tableName,
    required Map<String, dynamic> data,
  }) async {
    await client.from(tableName).insert(data);
  }

  /// Update a record by ID
  Future<void> updateData({
    required String tableName,
    required String id,
    required Map<String, dynamic> updates,
  }) async {
    await client.from(tableName).update(updates).eq('id', id);
  }

  /// Delete a record by ID
  Future<void> deleteData({
    required String tableName,
    required String id,
  }) async {
    await client.from(tableName).delete().eq('id', id);
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:mechflow/supabase_constants.dart';

void main() {
  test('Verify Supabase Constants are configured', () {
    expect(SupabaseConstants.supabaseUrl, contains('supabase.co'));
    expect(SupabaseConstants.supabasePublishableKey.isNotEmpty, true);
  });
}

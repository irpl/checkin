import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/campaign.dart';
import '../models/beacon.dart';
import '../models/checkin.dart';
import '../models/form_schema.dart';

class SupabaseService {
  final SupabaseClient _client;

  SupabaseService(this._client);

  // Auth methods
  Future<AuthResponse> signUp(String email, String password) async {
    return await _client.auth.signUp(email: email, password: password);
  }

  Future<AuthResponse> signIn(String email, String password) async {
    return await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  User? get currentUser => _client.auth.currentUser;

  // Client profile methods
  Future<void> createClientProfile(String name, String? phone) async {
    final user = currentUser;
    if (user == null) throw Exception('Not authenticated');

    await _client.from('clients').upsert({
      'id': user.id,
      'email': user.email,
      'name': name,
      'phone': phone,
    });
  }

  /// Ensures a client profile exists for the current user
  Future<void> ensureClientProfile() async {
    final user = currentUser;
    if (user == null) throw Exception('Not authenticated');

    // Check if client profile exists
    final existing = await _client
        .from('clients')
        .select('id')
        .eq('id', user.id)
        .maybeSingle();

    if (existing == null) {
      // Create a basic profile using email
      await _client.from('clients').insert({
        'id': user.id,
        'email': user.email,
        'name': user.email?.split('@').first ?? 'User',
      });
    }
  }

  // Campaign methods
  Future<List<Campaign>> getActiveCampaigns() async {
    final response = await _client
        .from('campaigns')
        .select('*, time_blocks:campaign_time_blocks(*)')
        .eq('is_active', true)
        .order('created_at', ascending: false);

    return (response as List).map((json) => Campaign.fromJson(json)).toList();
  }

  Future<List<Campaign>> getSubscribedCampaigns() async {
    final user = currentUser;
    if (user == null) return [];

    final response = await _client
        .from('subscriptions')
        .select('campaign:campaigns(*, time_blocks:campaign_time_blocks(*))')
        .eq('client_id', user.id)
        .eq('is_active', true);

    return (response as List)
        .map((json) => Campaign.fromJson(json['campaign']))
        .toList();
  }

  Future<Campaign?> getCampaign(String id) async {
    final response = await _client
        .from('campaigns')
        .select('*, time_blocks:campaign_time_blocks(*)')
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return Campaign.fromJson(response);
  }

  // Subscription methods
  Future<void> subscribeToCampaign(String campaignId) async {
    final user = currentUser;
    if (user == null) throw Exception('Not authenticated');

    // Ensure client profile exists before subscribing
    await ensureClientProfile();

    await _client.from('subscriptions').upsert(
      {
        'client_id': user.id,
        'campaign_id': campaignId,
        'is_active': true,
      },
      onConflict: 'client_id,campaign_id',
    );
  }

  Future<void> unsubscribeFromCampaign(String campaignId) async {
    final user = currentUser;
    if (user == null) throw Exception('Not authenticated');

    await _client
        .from('subscriptions')
        .update({'is_active': false})
        .eq('client_id', user.id)
        .eq('campaign_id', campaignId);
  }

  Future<bool> isSubscribed(String campaignId) async {
    final user = currentUser;
    if (user == null) return false;

    final response = await _client
        .from('subscriptions')
        .select('id')
        .eq('client_id', user.id)
        .eq('campaign_id', campaignId)
        .eq('is_active', true)
        .maybeSingle();

    return response != null;
  }

  // Beacon methods
  Future<List<Beacon>> getBeaconsForCampaign(String campaignId) async {
    final response = await _client
        .from('beacons')
        .select()
        .eq('campaign_id', campaignId)
        .eq('is_active', true);

    return (response as List).map((json) => Beacon.fromJson(json)).toList();
  }

  Future<List<Beacon>> getBeaconsForSubscribedCampaigns() async {
    final user = currentUser;
    if (user == null) return [];

    final response = await _client
        .from('beacons')
        .select('*, campaign:campaigns!inner(*)')
        .eq('is_active', true)
        .eq('campaigns.is_active', true)
        .inFilter('campaign_id', await _getSubscribedCampaignIds());

    return (response as List).map((json) => Beacon.fromJson(json)).toList();
  }

  Future<List<String>> _getSubscribedCampaignIds() async {
    final user = currentUser;
    if (user == null) return [];

    final response = await _client
        .from('subscriptions')
        .select('campaign_id')
        .eq('client_id', user.id)
        .eq('is_active', true);

    return (response as List).map((json) => json['campaign_id'] as String).toList();
  }

  // Form methods
  Future<FormSchema?> getFormForCampaign(String campaignId) async {
    final response = await _client
        .from('forms')
        .select()
        .eq('campaign_id', campaignId)
        .maybeSingle();

    if (response == null) return null;
    return FormSchema.fromJson(response);
  }

  // Check-in methods
  Future<Checkin> createCheckin({
    required String campaignId,
    String? beaconId,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('Not authenticated');

    final response = await _client.from('checkins').insert({
      'client_id': user.id,
      'campaign_id': campaignId,
      'beacon_id': beaconId,
      'status': 'pending',
    }).select().single();

    return Checkin.fromJson(response);
  }

  Future<Checkin> confirmCheckin(String checkinId) async {
    final response = await _client
        .from('checkins')
        .update({
          'status': 'confirmed',
          'presence_confirmed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', checkinId)
        .select()
        .single();

    return Checkin.fromJson(response);
  }

  Future<Checkin> completeCheckin(
    String checkinId,
    Map<String, dynamic>? formResponse,
  ) async {
    final response = await _client
        .from('checkins')
        .update({
          'status': 'completed',
          'form_response': formResponse,
          'checked_in_at': DateTime.now().toIso8601String(),
        })
        .eq('id', checkinId)
        .select()
        .single();

    return Checkin.fromJson(response);
  }

  Future<Checkin?> getActiveCheckin(String campaignId) async {
    final user = currentUser;
    if (user == null) return null;

    final response = await _client
        .from('checkins')
        .select()
        .eq('client_id', user.id)
        .eq('campaign_id', campaignId)
        .inFilter('status', ['pending', 'confirmed'])
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) return null;
    return Checkin.fromJson(response);
  }

  Future<List<Checkin>> getCheckinHistory() async {
    final user = currentUser;
    if (user == null) return [];

    final response = await _client
        .from('checkins')
        .select()
        .eq('client_id', user.id)
        .order('created_at', ascending: false)
        .limit(50);

    return (response as List).map((json) => Checkin.fromJson(json)).toList();
  }
}

/// Provider for Supabase service
final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService(Supabase.instance.client);
});

/// Provider for current user
final currentUserProvider = StreamProvider<User?>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange.map((event) => event.session?.user);
});

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../services/supabase_service.dart';
import '../../../models/campaign.dart';
import '../../../models/beacon.dart';

class CampaignDetailScreen extends ConsumerStatefulWidget {
  final String campaignId;

  const CampaignDetailScreen({super.key, required this.campaignId});

  @override
  ConsumerState<CampaignDetailScreen> createState() =>
      _CampaignDetailScreenState();
}

class _CampaignDetailScreenState extends ConsumerState<CampaignDetailScreen> {
  Campaign? _campaign;
  List<Beacon> _beacons = [];
  bool _isSubscribed = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCampaign();
  }

  Future<void> _loadCampaign() async {
    setState(() => _isLoading = true);

    try {
      final supabase = ref.read(supabaseServiceProvider);
      final campaign = await supabase.getCampaign(widget.campaignId);
      final beacons = await supabase.getBeaconsForCampaign(widget.campaignId);
      final isSubscribed = await supabase.isSubscribed(widget.campaignId);

      setState(() {
        _campaign = campaign;
        _beacons = beacons;
        _isSubscribed = isSubscribed;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _toggleSubscription() async {
    final supabase = ref.read(supabaseServiceProvider);

    try {
      if (_isSubscribed) {
        await supabase.unsubscribeFromCampaign(widget.campaignId);
      } else {
        await supabase.subscribeToCampaign(widget.campaignId);
      }

      setState(() {
        _isSubscribed = !_isSubscribed;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isSubscribed
                  ? 'Subscribed to ${_campaign?.name}'
                  : 'Unsubscribed from ${_campaign?.name}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_campaign?.name ?? 'Campaign'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/campaigns'),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _campaign == null
              ? const Center(child: Text('Campaign not found'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Header
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                                  child: Icon(
                                    Icons.location_on,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _campaign!.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall,
                                      ),
                                      const SizedBox(height: 4),
                                      Chip(
                                        label: Text(
                                          _campaign!.campaignType == 'instant'
                                              ? 'Instant Check-in'
                                              : 'Duration-based',
                                        ),
                                        padding: EdgeInsets.zero,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (_campaign!.description != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                _campaign!.description!,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Details
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Details',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            _buildDetailRow(
                              context,
                              'Type',
                              _campaign!.campaignType == 'instant'
                                  ? 'Instant check-in'
                                  : 'Duration-based check-in',
                            ),
                            if (_campaign!.campaignType == 'duration') ...[
                              _buildDetailRow(
                                context,
                                'Required Duration',
                                '${_campaign!.requiredDurationMinutes} minutes',
                              ),
                              _buildDetailRow(
                                context,
                                'Presence Required',
                                '${_campaign!.requiredPresencePercentage}%',
                              ),
                            ],
                            if (_campaign!.proximityDelaySeconds > 0)
                              _buildDetailRow(
                                context,
                                'Proximity Delay',
                                '${_campaign!.proximityDelaySeconds} seconds',
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Beacons/Locations
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Locations (${_beacons.length})',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            if (_beacons.isEmpty)
                              const Text('No locations configured')
                            else
                              ..._beacons.map((beacon) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.bluetooth),
                                    title: Text(beacon.name),
                                    subtitle: beacon.locationDescription != null
                                        ? Text(beacon.locationDescription!)
                                        : null,
                                  )),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Subscribe button
                    _isSubscribed
                        ? OutlinedButton.icon(
                            onPressed: _toggleSubscription,
                            icon: const Icon(Icons.check),
                            label: const Text('Subscribed'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                          )
                        : FilledButton(
                            onPressed: _toggleSubscription,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                            child: const Text('Subscribe to this Campaign'),
                          ),
                  ],
                ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

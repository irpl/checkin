import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../services/supabase_service.dart';
import '../../../models/campaign.dart';

class CampaignsScreen extends ConsumerStatefulWidget {
  const CampaignsScreen({super.key});

  @override
  ConsumerState<CampaignsScreen> createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends ConsumerState<CampaignsScreen> {
  List<Campaign> _campaigns = [];
  Set<String> _subscribedIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCampaigns();
  }

  Future<void> _loadCampaigns() async {
    setState(() => _isLoading = true);

    try {
      final supabase = ref.read(supabaseServiceProvider);
      final campaigns = await supabase.getActiveCampaigns();
      final subscribed = await supabase.getSubscribedCampaigns();

      setState(() {
        _campaigns = campaigns;
        _subscribedIds = subscribed.map((c) => c.id).toSet();
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

  Future<void> _toggleSubscription(Campaign campaign) async {
    final supabase = ref.read(supabaseServiceProvider);
    final isSubscribed = _subscribedIds.contains(campaign.id);

    try {
      if (isSubscribed) {
        await supabase.unsubscribeFromCampaign(campaign.id);
        setState(() {
          _subscribedIds.remove(campaign.id);
        });
      } else {
        await supabase.subscribeToCampaign(campaign.id);
        setState(() {
          _subscribedIds.add(campaign.id);
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isSubscribed
                  ? 'Unsubscribed from ${campaign.name}'
                  : 'Subscribed to ${campaign.name}',
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
        title: const Text('Browse Campaigns'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCampaigns,
              child: _campaigns.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.campaign_outlined, size: 64),
                          const SizedBox(height: 16),
                          Text(
                            'No campaigns available',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _campaigns.length,
                      itemBuilder: (context, index) {
                        final campaign = _campaigns[index];
                        final isSubscribed = _subscribedIds.contains(campaign.id);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () => context.go('/campaigns/${campaign.id}'),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          campaign.name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                      ),
                                      Chip(
                                        label: Text(
                                          campaign.campaignType == 'instant'
                                              ? 'Instant'
                                              : 'Duration',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall,
                                        ),
                                        padding: EdgeInsets.zero,
                                      ),
                                    ],
                                  ),
                                  if (campaign.description != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      campaign.description!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      isSubscribed
                                          ? OutlinedButton.icon(
                                              onPressed: () =>
                                                  _toggleSubscription(campaign),
                                              icon: const Icon(Icons.check),
                                              label: const Text('Subscribed'),
                                            )
                                          : FilledButton(
                                              onPressed: () =>
                                                  _toggleSubscription(campaign),
                                              child: const Text('Subscribe'),
                                            ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

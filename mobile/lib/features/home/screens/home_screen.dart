import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../services/supabase_service.dart';
import '../../../services/ble_service.dart';
import '../../../services/notification_service.dart';
import '../../../models/campaign.dart';
import '../../../models/beacon.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isScanning = false;
  List<Campaign> _subscribedCampaigns = [];
  List<Beacon> _beacons = [];
  final Map<String, DateTime> _detectedCampaigns = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _loadData();
    _requestPermissions();
  }

  Future<void> _initializeNotifications() async {
    final notificationService = ref.read(notificationServiceProvider);
    await notificationService.initialize(
      onTap: (payload) {
        if (payload != null && mounted) {
          context.go('/checkin/$payload');
        }
      },
    );
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
      Permission.notification,
    ].request();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final supabase = ref.read(supabaseServiceProvider);
      final campaigns = await supabase.getSubscribedCampaigns();
      final beacons = await supabase.getBeaconsForSubscribedCampaigns();

      setState(() {
        _subscribedCampaigns = campaigns;
        _beacons = beacons;
        _isLoading = false;
      });

      if (beacons.isNotEmpty) {
        _startScanning();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  Future<void> _startScanning() async {
    if (_isScanning || _beacons.isEmpty) return;

    final bleService = ref.read(bleServiceProvider);

    try {
      setState(() => _isScanning = true);
      await bleService.startScanning(_beacons);

      bleService.detectedBeacons.listen((detected) {
        _handleDetectedBeacon(detected);
      });
    } catch (e) {
      setState(() => _isScanning = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('BLE Error: $e')),
        );
      }
    }
  }

  void _handleDetectedBeacon(DetectedBeacon detected) {
    // Find matching beacon
    final beacon = _beacons.cast<Beacon?>().firstWhere(
          (b) => b != null && b.matches(detected.uuid, detected.major, detected.minor),
          orElse: () => null,
        );

    if (beacon == null) return;

    // Find campaign for this beacon
    final campaign = _subscribedCampaigns.cast<Campaign?>().firstWhere(
          (c) => c != null && c.id == beacon.campaignId,
          orElse: () => null,
        );

    if (campaign == null) return;

    // Check if check-in is allowed at current time
    if (!campaign.isCheckinAllowedNow()) {
      return; // Outside allowed time window
    }

    // Check if we already detected this campaign recently
    final lastDetected = _detectedCampaigns[campaign.id];
    if (lastDetected != null &&
        DateTime.now().difference(lastDetected).inSeconds < 30) {
      return; // Don't prompt again within 30 seconds
    }

    setState(() {
      _detectedCampaigns[campaign.id] = DateTime.now();
    });

    // Check proximity delay
    final delay = campaign.proximityDelaySeconds;
    if (delay > 0) {
      Future.delayed(Duration(seconds: delay), () {
        if (mounted) {
          _showCheckinNotification(campaign, beacon);
        }
      });
    } else {
      _showCheckinNotification(campaign, beacon);
    }
  }

  void _showCheckinNotification(Campaign campaign, Beacon beacon) {
    final notificationService = ref.read(notificationServiceProvider);
    notificationService.showCheckinNotification(
      campaignName: campaign.name,
      campaignId: campaign.id,
      locationDescription: beacon.locationDescription,
    );
  }

  Future<void> _signOut() async {
    final bleService = ref.read(bleServiceProvider);
    await bleService.stopScanning();

    final supabase = ref.read(supabaseServiceProvider);
    await supabase.signOut();

    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Scanning status
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            _isScanning
                                ? Icons.bluetooth_searching
                                : Icons.bluetooth_disabled,
                            color: _isScanning
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isScanning
                                      ? 'Scanning for beacons...'
                                      : 'Not scanning',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                Text(
                                  '${_beacons.length} beacon(s) configured',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          if (!_isScanning && _beacons.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.refresh),
                              onPressed: _startScanning,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Subscribed campaigns
                  Text(
                    'Your Subscriptions',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),

                  if (_subscribedCampaigns.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Icon(Icons.inbox_outlined, size: 48),
                            const SizedBox(height: 16),
                            Text(
                              'No subscriptions yet',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Browse campaigns to subscribe',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton(
                              onPressed: () => context.go('/campaigns'),
                              child: const Text('Browse Campaigns'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._subscribedCampaigns.map((campaign) => Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.location_on),
                            ),
                            title: Text(campaign.name),
                            subtitle: Text(campaign.description ?? ''),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () =>
                                context.go('/campaigns/${campaign.id}'),
                          ),
                        )),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/campaigns'),
        icon: const Icon(Icons.add),
        label: const Text('Find Campaigns'),
      ),
    );
  }
}

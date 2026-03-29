import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../services/supabase_service.dart';
import '../../../services/presence_tracking_service.dart';
import '../../../models/campaign.dart';
import '../../../models/beacon.dart';
import '../../../models/checkin.dart';
import '../../../models/form_schema.dart';
import '../widgets/dynamic_form.dart';

class CheckinScreen extends ConsumerStatefulWidget {
  final String campaignId;

  const CheckinScreen({super.key, required this.campaignId});

  @override
  ConsumerState<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends ConsumerState<CheckinScreen> {
  Campaign? _campaign;
  FormSchema? _form;
  Checkin? _checkin;
  Map<String, dynamic>? _savedResponse;
  bool _isSubmitting = false;
  CheckinStep _currentStep = CheckinStep.loading;

  // Presence tracking state
  PresenceState? _presenceState;
  StreamSubscription<PresenceState>? _presenceSubscription;
  Beacon? _triggerBeacon;

  @override
  void initState() {
    super.initState();
    _initCheckin();
  }

  @override
  void dispose() {
    _presenceSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initCheckin() async {
    setState(() {
      _currentStep = CheckinStep.loading;
    });

    try {
      final supabase = ref.read(supabaseServiceProvider);

      // Load campaign
      final campaign = await supabase.getCampaign(widget.campaignId);
      if (campaign == null) {
        throw Exception('Campaign not found');
      }

      // Validate time restrictions
      if (!campaign.isCheckinAllowedNow()) {
        throw Exception(
          'Check-in is not allowed at this time. '
          '${campaign.timeBlocks.isNotEmpty ? _getNextTimeBlockMessage(campaign) : "Please check the campaign schedule."}',
        );
      }

      // Validate subscriber verification
      if (campaign.requiresSubscriberVerification) {
        final isVerified =
            await supabase.isSubscriptionVerified(widget.campaignId);
        if (!isVerified) {
          throw Exception(
            'Your subscription has not been verified yet. '
            'An admin must verify your subscription before you can check in.',
          );
        }
      }

      // Load form if exists
      final form = await supabase.getFormForCampaign(widget.campaignId);

      // Load saved form response if form exists
      Map<String, dynamic>? savedResponse;
      if (form != null) {
        savedResponse = await DynamicForm.loadSavedResponse(widget.campaignId);
      }

      // Load beacons for this campaign (needed for presence tracking)
      final beacons = await supabase.getBeaconsForCampaign(widget.campaignId);
      if (beacons.isNotEmpty) {
        _triggerBeacon = beacons.first;
      }

      // Check for existing active check-in
      var checkin = await supabase.getActiveCheckin(widget.campaignId);

      // If no active check-in, create one
      checkin ??= await supabase.createCheckin(campaignId: widget.campaignId);

      setState(() {
        _campaign = campaign;
        _form = form;
        _checkin = checkin;
        _savedResponse = savedResponse;
        _currentStep = _determineStep(checkin!, campaign, form);
      });

      // If resuming a duration tracking session, restart tracking
      if (campaign.campaignType == 'duration' &&
          _currentStep == CheckinStep.tracking) {
        _startPresenceTracking();
      }
    } catch (e) {
      setState(() {
        _currentStep = CheckinStep.error;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  CheckinStep _determineStep(
      Checkin checkin, Campaign campaign, FormSchema? form) {
    if (checkin.isCompleted) {
      return CheckinStep.success;
    }

    if (checkin.isConfirmed) {
      // Already confirmed
      if (campaign.campaignType == 'duration' &&
          checkin.sessionStartedAt != null) {
        // Was in a tracking session — resume it
        return CheckinStep.tracking;
      }
      return form != null ? CheckinStep.form : CheckinStep.success;
    }

    // For instant campaigns, go straight to confirmation
    if (campaign.campaignType == 'instant') {
      return CheckinStep.confirm;
    }

    // For duration-based, show confirmation first, then tracking
    return CheckinStep.confirm;
  }

  String _getNextTimeBlockMessage(Campaign campaign) {
    final now = DateTime.now();
    final currentDayOfWeek = now.weekday % 7;

    CampaignTimeBlock? nextBlock;
    int daysUntilNext = 7;

    for (int i = 0; i < 7; i++) {
      final checkDay = (currentDayOfWeek + i) % 7;
      final blocksForDay = campaign.timeBlocks
          .where((block) => block.dayOfWeek == checkDay)
          .toList();

      for (final block in blocksForDay) {
        if (i == 0) {
          final blockStart = _parseTimeString(block.startTime);
          final currentTime = now.hour * 3600 + now.minute * 60 + now.second;
          if (blockStart != null && currentTime < blockStart) {
            nextBlock = block;
            daysUntilNext = 0;
            break;
          }
        } else {
          nextBlock = block;
          daysUntilNext = i;
          break;
        }
      }

      if (nextBlock != null) break;
    }

    if (nextBlock != null) {
      if (daysUntilNext == 0) {
        return 'Next check-in is today at ${nextBlock.timeDisplay}.';
      } else if (daysUntilNext == 1) {
        return 'Next check-in is tomorrow (${nextBlock.dayName}) at ${nextBlock.timeDisplay}.';
      } else {
        return 'Next check-in is on ${nextBlock.dayName} at ${nextBlock.timeDisplay}.';
      }
    }

    return 'Please check the campaign schedule.';
  }

  int? _parseTimeString(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length < 2) return null;
    final hours = int.tryParse(parts[0]);
    final minutes = int.tryParse(parts[1]);
    final seconds = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
    if (hours == null || minutes == null) return null;
    return hours * 3600 + minutes * 60 + seconds;
  }

  Future<void> _confirmPresence() async {
    setState(() => _isSubmitting = true);

    try {
      final supabase = ref.read(supabaseServiceProvider);
      final updated = await supabase.confirmCheckin(_checkin!.id);

      if (_campaign!.campaignType == 'duration') {
        // Mark session start in DB
        await supabase.startCheckinSession(_checkin!.id);

        setState(() {
          _checkin = updated;
          _isSubmitting = false;
          _currentStep = CheckinStep.tracking;
        });

        _startPresenceTracking();
      } else {
        // Instant campaign — same as before
        setState(() {
          _checkin = updated;
          _isSubmitting = false;
          _currentStep =
              _form != null ? CheckinStep.form : CheckinStep.completing;
        });

        if (_form == null) {
          _completeCheckin(null);
        }
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _startPresenceTracking() {
    if (_triggerBeacon == null) return;

    final presenceService = ref.read(presenceTrackingServiceProvider);
    presenceService.startTracking(
      beaconId: _triggerBeacon!.id,
      checkinId: _checkin!.id,
      requiredPercentage: _campaign!.getEffectivePresencePercentage(),
      requiredDurationMinutes: _campaign!.requiredDurationMinutes,
    );

    _presenceSubscription?.cancel();
    _presenceSubscription = presenceService.stateStream.listen((state) {
      if (mounted) {
        setState(() => _presenceState = state);
      }
    });

    // Set initial state
    final initial = presenceService.currentState;
    if (initial != null) {
      setState(() => _presenceState = initial);
    }
  }

  Future<void> _completeDurationCheckin() async {
    if (_presenceState == null || !_presenceState!.meetsRequirement) return;

    setState(() {
      _isSubmitting = true;
      _currentStep = CheckinStep.completing;
    });

    try {
      final supabase = ref.read(supabaseServiceProvider);
      final presenceService = ref.read(presenceTrackingServiceProvider);

      if (_form != null) {
        // Go to form step first, complete after form submission
        await presenceService.stopTracking();
        setState(() {
          _isSubmitting = false;
          _currentStep = CheckinStep.form;
        });
      } else {
        // No form — complete directly via RPC
        await supabase.completeDurationCheckin(
          _checkin!.id,
          _presenceState!.presencePercentage,
          null,
        );
        await presenceService.stopTracking();

        setState(() {
          _isSubmitting = false;
          _currentStep = CheckinStep.success;
        });
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _currentStep = CheckinStep.tracking;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _completeCheckin(Map<String, dynamic>? formData) async {
    setState(() {
      _isSubmitting = true;
      _currentStep = CheckinStep.completing;
    });

    try {
      final supabase = ref.read(supabaseServiceProvider);

      if (_campaign!.campaignType == 'duration' &&
          _presenceState != null) {
        // Duration campaign with form — use RPC
        await supabase.completeDurationCheckin(
          _checkin!.id,
          _presenceState!.presencePercentage,
          formData,
        );
      } else {
        // Instant campaign
        await supabase.completeCheckin(_checkin!.id, formData);
      }

      setState(() {
        _isSubmitting = false;
        _currentStep = CheckinStep.success;
      });
    } catch (e) {
      setState(() => _isSubmitting = false);
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
        title: Text(_campaign?.name ?? 'Check In'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            // If tracking, persist session so it can be resumed
            if (_currentStep == CheckinStep.tracking) {
              final presenceService =
                  ref.read(presenceTrackingServiceProvider);
              presenceService.stopTracking(persist: true);
            }
            context.go('/');
          },
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentStep) {
      case CheckinStep.loading:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Preparing check-in...'),
            ],
          ),
        );

      case CheckinStep.confirm:
        return _buildConfirmStep();

      case CheckinStep.tracking:
        return _buildTrackingStep();

      case CheckinStep.form:
        return _buildFormStep();

      case CheckinStep.completing:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Completing check-in...'),
            ],
          ),
        );

      case CheckinStep.success:
        return _buildSuccessStep();

      case CheckinStep.error:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Something went wrong'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _initCheckin,
                child: const Text('Try Again'),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildConfirmStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_on,
            size: 80,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Confirm Your Presence',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'You are checking in at:',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _campaign?.name ?? '',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          if (_campaign?.description != null) ...[
            const SizedBox(height: 8),
            Text(
              _campaign!.description!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
          if (_campaign?.campaignType == 'duration') ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Duration Required: ${_campaign!.requiredDurationMinutes} min',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Presence Required: ${_campaign!.getEffectivePresencePercentage()}%',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  if (_campaign!.getCurrentTimeBlock()?.presencePercentage !=
                      null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '(Custom for this time slot)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    'Your presence will be tracked via Bluetooth. '
                    'Stay near the beacon for the required duration.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 48),
          FilledButton.icon(
            onPressed: _isSubmitting ? null : _confirmPresence,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_campaign?.campaignType == 'duration'
                    ? Icons.play_arrow
                    : Icons.check),
            label: Text(_campaign?.campaignType == 'duration'
                ? 'Start Session'
                : 'Confirm Check-in'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.go('/'),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingStep() {
    final state = _presenceState;
    final requiredMinutes = _campaign?.requiredDurationMinutes ?? 0;
    final requiredPercentage =
        _campaign?.getEffectivePresencePercentage() ?? 100;

    final elapsedMinutes = state?.elapsed.inMinutes ?? 0;
    final presencePercent = state?.presencePercentage ?? 0;
    final isNearby = state?.isCurrentlyNearby ?? false;
    final meetsRequirement = state?.meetsRequirement ?? false;

    // Progress towards duration requirement (0.0 to 1.0)
    final durationProgress = requiredMinutes > 0
        ? (elapsedMinutes / requiredMinutes).clamp(0.0, 1.0)
        : 1.0;

    // Progress towards presence requirement (0.0 to 1.0)
    final presenceProgress = requiredPercentage > 0
        ? (presencePercent / requiredPercentage).clamp(0.0, 1.0)
        : 1.0;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Nearby indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isNearby
                  ? Colors.green.shade100
                  : Colors.orange.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isNearby ? Icons.bluetooth_connected : Icons.bluetooth_searching,
                  size: 16,
                  color: isNearby ? Colors.green.shade700 : Colors.orange.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  isNearby ? 'Beacon detected' : 'Searching for beacon...',
                  style: TextStyle(
                    color: isNearby ? Colors.green.shade700 : Colors.orange.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Elapsed time
          Text(
            _formatDuration(state?.elapsed ?? Duration.zero),
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFeatures: [const FontFeature.tabularFigures()],
                ),
          ),
          Text(
            'of $requiredMinutes min required',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),

          // Duration progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: durationProgress,
              minHeight: 8,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 32),

          // Presence percentage
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Presence',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '$presencePercent%',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: presencePercent >= requiredPercentage
                                    ? Colors.green.shade700
                                    : Theme.of(context).colorScheme.primary,
                              ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: presenceProgress,
                    minHeight: 8,
                    backgroundColor:
                        Theme.of(context).colorScheme.surface,
                    color: presencePercent >= requiredPercentage
                        ? Colors.green
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$requiredPercentage% required',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Time present
          Text(
            'Present for ${_formatDuration(state?.timePresent ?? Duration.zero)} '
            'of ${_formatDuration(state?.elapsed ?? Duration.zero)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 32),

          // Complete button (only enabled when requirement is met)
          FilledButton.icon(
            onPressed:
                meetsRequirement && !_isSubmitting ? _completeDurationCheckin : null,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(meetsRequirement
                ? 'Complete Check-in'
                : 'Waiting for requirements...'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              final presenceService =
                  ref.read(presenceTrackingServiceProvider);
              presenceService.stopTracking(persist: true);
              context.go('/');
            },
            child: const Text('Leave (session will continue)'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildFormStep() {
    return DynamicForm(
      form: _form!,
      campaignId: widget.campaignId,
      onSubmit: _completeCheckin,
      isSubmitting: _isSubmitting,
      savedResponse: _savedResponse,
    );
  }

  Widget _buildSuccessStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check,
              size: 64,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Check-in Complete!',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'You have successfully checked in at ${_campaign?.name}',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          if (_presenceState != null) ...[
            const SizedBox(height: 8),
            Text(
              'Presence: ${_presenceState!.presencePercentage}%',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
          const SizedBox(height: 48),
          FilledButton(
            onPressed: () => context.go('/'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

enum CheckinStep {
  loading,
  confirm,
  tracking,
  form,
  completing,
  success,
  error,
}

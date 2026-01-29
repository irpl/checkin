import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../services/supabase_service.dart';
import '../../../models/campaign.dart';
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
  bool _isLoading = true;
  bool _isSubmitting = false;
  CheckinStep _currentStep = CheckinStep.loading;

  @override
  void initState() {
    super.initState();
    _initCheckin();
  }

  Future<void> _initCheckin() async {
    setState(() {
      _isLoading = true;
      _currentStep = CheckinStep.loading;
    });

    try {
      final supabase = ref.read(supabaseServiceProvider);

      // Load campaign
      final campaign = await supabase.getCampaign(widget.campaignId);
      if (campaign == null) {
        throw Exception('Campaign not found');
      }

      // Load form if exists
      final form = await supabase.getFormForCampaign(widget.campaignId);

      // Load saved form response if form exists
      Map<String, dynamic>? savedResponse;
      if (form != null) {
        savedResponse = await DynamicForm.loadSavedResponse(widget.campaignId);
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
        _isLoading = false;
        _currentStep = _determineStep(checkin!, campaign, form);
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
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
      // Already confirmed, go to form if exists
      return form != null ? CheckinStep.form : CheckinStep.success;
    }

    // For instant campaigns, go straight to confirmation/form
    if (campaign.campaignType == 'instant') {
      return CheckinStep.confirm;
    }

    // For duration-based, would need to track presence over time
    // For MVP, just go to confirmation
    return CheckinStep.confirm;
  }

  Future<void> _confirmPresence() async {
    setState(() => _isSubmitting = true);

    try {
      final supabase = ref.read(supabaseServiceProvider);
      final updated = await supabase.confirmCheckin(_checkin!.id);

      setState(() {
        _checkin = updated;
        _isSubmitting = false;
        _currentStep =
            _form != null ? CheckinStep.form : CheckinStep.completing;
      });

      if (_form == null) {
        _completeCheckin(null);
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

  Future<void> _completeCheckin(Map<String, dynamic>? formData) async {
    setState(() {
      _isSubmitting = true;
      _currentStep = CheckinStep.completing;
    });

    try {
      final supabase = ref.read(supabaseServiceProvider);
      final updated = await supabase.completeCheckin(_checkin!.id, formData);

      setState(() {
        _checkin = updated;
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
          onPressed: () => context.go('/'),
        ),
      ),
      body: _buildBody(),
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
          const SizedBox(height: 48),
          FilledButton.icon(
            onPressed: _isSubmitting ? null : _confirmPresence,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: const Text('Confirm Check-in'),
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
  form,
  completing,
  success,
  error,
}

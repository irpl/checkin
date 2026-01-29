import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/form_schema.dart';

class DynamicForm extends StatefulWidget {
  final FormSchema form;
  final Function(Map<String, dynamic>) onSubmit;
  final bool isSubmitting;
  final String campaignId;
  final Map<String, dynamic>? savedResponse;

  const DynamicForm({
    super.key,
    required this.form,
    required this.onSubmit,
    required this.campaignId,
    this.isSubmitting = false,
    this.savedResponse,
  });

  static String _storageKey(String campaignId) =>
      'form_response_$campaignId';

  static Future<Map<String, dynamic>?> loadSavedResponse(
      String campaignId) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_storageKey(campaignId));
    if (json == null) return null;
    return Map<String, dynamic>.from(jsonDecode(json));
  }

  @override
  State<DynamicForm> createState() => _DynamicFormState();
}

class _DynamicFormState extends State<DynamicForm> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _formData = {};
  bool _saveForNextTime = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill from saved response if available
    if (widget.savedResponse != null) {
      _formData.addAll(widget.savedResponse!);
      _saveForNextTime = true;
    }
    // Fill remaining defaults
    for (final field in widget.form.fields) {
      if (_formData.containsKey(field.id)) continue;
      if (field.defaultValue != null) {
        _formData[field.id] = field.defaultValue;
      } else if (field.type == 'checkbox') {
        _formData[field.id] = false;
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final prefs = await SharedPreferences.getInstance();
    final key = DynamicForm._storageKey(widget.campaignId);
    if (_saveForNextTime) {
      await prefs.setString(key, jsonEncode(_formData));
    } else {
      await prefs.remove(key);
    }

    widget.onSubmit(_formData);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.form.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (widget.form.description != null) ...[
              const SizedBox(height: 8),
              Text(
                widget.form.description!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
            const SizedBox(height: 24),
            ...widget.form.fields.map((field) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildField(field),
                )),
            const SizedBox(height: 8),
            CheckboxListTile(
              title: const Text('Save my responses for next time'),
              subtitle: const Text(
                'Pre-fill this form on your next check-in',
                style: TextStyle(fontSize: 12),
              ),
              value: _saveForNextTime,
              onChanged: (value) {
                setState(() {
                  _saveForNextTime = value ?? false;
                });
              },
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: widget.isSubmitting ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
              child: widget.isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(CheckinFormField field) {
    switch (field.type) {
      case 'text':
        return TextFormField(
          decoration: InputDecoration(
            labelText: field.label,
            hintText: field.placeholder,
            border: const OutlineInputBorder(),
          ),
          initialValue: _formData[field.id]?.toString(),
          onChanged: (value) => _formData[field.id] = value,
          validator: field.required
              ? (value) {
                  if (value == null || value.isEmpty) {
                    return '${field.label} is required';
                  }
                  return null;
                }
              : null,
        );

      case 'textarea':
        return TextFormField(
          decoration: InputDecoration(
            labelText: field.label,
            hintText: field.placeholder,
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          maxLines: 4,
          initialValue: _formData[field.id]?.toString(),
          onChanged: (value) => _formData[field.id] = value,
          validator: field.required
              ? (value) {
                  if (value == null || value.isEmpty) {
                    return '${field.label} is required';
                  }
                  return null;
                }
              : null,
        );

      case 'number':
        return TextFormField(
          decoration: InputDecoration(
            labelText: field.label,
            hintText: field.placeholder,
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          initialValue: _formData[field.id]?.toString(),
          onChanged: (value) =>
              _formData[field.id] = int.tryParse(value) ?? value,
          validator: field.required
              ? (value) {
                  if (value == null || value.isEmpty) {
                    return '${field.label} is required';
                  }
                  return null;
                }
              : null,
        );

      case 'select':
        return DropdownButtonFormField<String>(
          decoration: InputDecoration(
            labelText: field.label,
            border: const OutlineInputBorder(),
          ),
          value: _formData[field.id]?.toString(),
          items: field.options
              ?.map((option) => DropdownMenuItem(
                    value: option,
                    child: Text(option),
                  ))
              .toList(),
          onChanged: (value) {
            setState(() {
              _formData[field.id] = value;
            });
          },
          validator: field.required
              ? (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select ${field.label.toLowerCase()}';
                  }
                  return null;
                }
              : null,
        );

      case 'checkbox':
        return FormField<bool>(
          initialValue: _formData[field.id] ?? false,
          validator: field.required
              ? (value) {
                  if (value != true) {
                    return '${field.label} is required';
                  }
                  return null;
                }
              : null,
          builder: (state) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CheckboxListTile(
                  title: Text(field.label),
                  value: _formData[field.id] ?? false,
                  onChanged: (value) {
                    setState(() {
                      _formData[field.id] = value;
                    });
                    state.didChange(value);
                  },
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                if (state.hasError)
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      state.errorText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            );
          },
        );

      default:
        return TextFormField(
          decoration: InputDecoration(
            labelText: field.label,
            hintText: field.placeholder,
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) => _formData[field.id] = value,
        );
    }
  }
}

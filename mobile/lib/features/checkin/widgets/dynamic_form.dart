import 'package:flutter/material.dart';

import '../../../models/form_schema.dart';

class DynamicForm extends StatefulWidget {
  final FormSchema form;
  final Function(Map<String, dynamic>) onSubmit;
  final bool isSubmitting;

  const DynamicForm({
    super.key,
    required this.form,
    required this.onSubmit,
    this.isSubmitting = false,
  });

  @override
  State<DynamicForm> createState() => _DynamicFormState();
}

class _DynamicFormState extends State<DynamicForm> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _formData = {};

  @override
  void initState() {
    super.initState();
    // Initialize default values
    for (final field in widget.form.fields) {
      if (field.defaultValue != null) {
        _formData[field.id] = field.defaultValue;
      } else if (field.type == 'checkbox') {
        _formData[field.id] = false;
      }
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      widget.onSubmit(_formData);
    }
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
            const SizedBox(height: 24),
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
          initialValue: _formData[field.id]?.toString(),
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

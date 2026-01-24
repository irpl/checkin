class FormSchema {
  final String id;
  final String campaignId;
  final String title;
  final String? description;
  final List<CheckinFormField> fields;
  final DateTime createdAt;

  FormSchema({
    required this.id,
    required this.campaignId,
    required this.title,
    this.description,
    required this.fields,
    required this.createdAt,
  });

  factory FormSchema.fromJson(Map<String, dynamic> json) {
    final schema = json['schema'] as Map<String, dynamic>;
    final fieldsJson = schema['fields'] as List<dynamic>? ?? [];

    return FormSchema(
      id: json['id'],
      campaignId: json['campaign_id'],
      title: json['title'],
      description: json['description'],
      fields: fieldsJson.map((f) => CheckinFormField.fromJson(f)).toList(),
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class CheckinFormField {
  final String id;
  final String type; // 'text', 'select', 'number', 'checkbox', 'textarea'
  final String label;
  final String? placeholder;
  final bool required;
  final List<String>? options; // For select fields
  final dynamic defaultValue;

  CheckinFormField({
    required this.id,
    required this.type,
    required this.label,
    this.placeholder,
    this.required = false,
    this.options,
    this.defaultValue,
  });

  factory CheckinFormField.fromJson(Map<String, dynamic> json) {
    return CheckinFormField(
      id: json['id'],
      type: json['type'],
      label: json['label'],
      placeholder: json['placeholder'],
      required: json['required'] ?? false,
      options: json['options'] != null
          ? List<String>.from(json['options'])
          : null,
      defaultValue: json['default_value'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'label': label,
      'placeholder': placeholder,
      'required': required,
      'options': options,
      'default_value': defaultValue,
    };
  }
}

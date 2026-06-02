class FilterOption {
  final String label;
  final dynamic value;

  const FilterOption({required this.label, required this.value});
}

class FilterField {
  final String key;
  final String title;
  final List<FilterOption> options;
  final dynamic defaultValue;

  const FilterField({
    required this.key,
    required this.title,
    required this.options,
    required this.defaultValue,
  });
}

class FilterConfig {
  final List<FilterField> fields;

  const FilterConfig({required this.fields});
}

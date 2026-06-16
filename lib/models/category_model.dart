class Category {
  final int? id;
  final String name;
  final String iconCodePoint;
  final bool isDefault;

  Category({
    this.id,
    required this.name,
    required this.iconCodePoint,
    this.isDefault = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'icon_code_point': iconCodePoint,
    'is_default': isDefault ? 1 : 0,
  };

  factory Category.fromMap(Map<String, dynamic> map) => Category(
    id: map['id'] as int?,
    name: map['name'] as String,
    iconCodePoint: map['icon_code_point'] as String,
    isDefault: (map['is_default'] as int) == 1,
  );
}
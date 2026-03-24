class Role {
  final String id;
  final String name; // e.g., 'admin', 'student'
  final String description;

  Role({
    required this.id,
    required this.name,
    this.description = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
    };
  }

  factory Role.fromMap(Map<String, dynamic> map, String id) {
    return Role(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
    );
  }
}

enum UserRole { user, admin }

class User {
  final String id;
  final String email;
  final String name;
  final UserRole role;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.program,
  });

  final String? program;
}

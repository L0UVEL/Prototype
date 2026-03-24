enum UserRole { user, admin }

class User {
  final String id;
  final String studentId;
  final String email;
  final String firstName;
  final String lastName;
  final String roleId;
  final UserRole role; 
  final String? program;
  final bool requiresPasswordChange;

  String get name => '$firstName $lastName';

  User({
    required this.id,
    required this.studentId,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.roleId,
    required this.role,
    this.program,
    this.requiresPasswordChange = false,
  });
}

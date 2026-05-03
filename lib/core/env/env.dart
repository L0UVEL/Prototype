import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '.env')
abstract class Env {
  @EnviedField(varName: 'GEMINI_API_KEY', obfuscate: true)
  static final String geminiApiKey = _Env.geminiApiKey;

  @EnviedField(varName: 'SMTP_USERNAME', obfuscate: true)
  static final String smtpUsername = _Env.smtpUsername;

  @EnviedField(varName: 'SMTP_PASSWORD', obfuscate: true)
  static final String smtpPassword = _Env.smtpPassword;

  @EnviedField(varName: 'SMTP_SERVER')
  static final String smtpServer = _Env.smtpServer;

  @EnviedField(varName: 'SMTP_PORT')
  static final int smtpPort = _Env.smtpPort;
}

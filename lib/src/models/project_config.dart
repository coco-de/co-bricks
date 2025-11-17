import 'dart:convert';

/// Represents a project configuration that can be saved and loaded from JSON
class SavedProjectConfig {
  /// Creates a new [SavedProjectConfig] instance
  const SavedProjectConfig({
    required this.type,
    required this.name,
    required this.description,
    required this.organization,
    required this.tld,
    required this.orgTld,
    required this.githubOrg,
    required this.githubRepo,
    required this.githubVisibility,
    this.backend,
    this.enableAdmin = false,
    this.adminEmail,
    this.appleDeveloperId,
    this.itcTeamId,
    this.teamId,
    this.certCn,
    this.certOu,
    this.certO,
    this.certL,
    this.certSt,
    this.certC,
    this.randomProjectId,
    this.randomAwsId,
    this.awsAccessKeyId,
    this.awsSecretAccessKey,
    this.outputDir,
    this.autoStart = false,
  });

  /// Creates a [SavedProjectConfig] from a JSON map
  factory SavedProjectConfig.fromJson(Map<String, dynamic> json) {
    return SavedProjectConfig(
      type: json['type'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      organization: json['organization'] as String,
      tld: json['tld'] as String,
      orgTld: json['org_tld'] as String,
      githubOrg: json['github_org'] as String,
      githubRepo: json['github_repo'] as String,
      githubVisibility: json['github_visibility'] as String,
      backend: json['backend'] as String?,
      enableAdmin: json['enable_admin'] as bool? ?? false,
      adminEmail: json['admin_email'] as String?,
      appleDeveloperId: json['apple_developer_id'] as String?,
      itcTeamId: json['itc_team_id'] as String?,
      teamId: json['team_id'] as String?,
      certCn: json['cert_cn'] as String?,
      certOu: json['cert_ou'] as String?,
      certO: json['cert_o'] as String?,
      certL: json['cert_l'] as String?,
      certSt: json['cert_st'] as String?,
      certC: json['cert_c'] as String?,
      randomProjectId: json['random_project_id'] as String?,
      randomAwsId: json['random_aws_id'] as String?,
      awsAccessKeyId: json['aws_access_key_id'] as String?,
      awsSecretAccessKey: json['aws_secret_access_key'] as String?,
      outputDir: json['output_dir'] as String?,
      autoStart: json['auto_start'] as bool? ?? false,
    );
  }

  /// Creates a [SavedProjectConfig] from a JSON string
  factory SavedProjectConfig.fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return SavedProjectConfig.fromJson(json);
  }

  /// Project type (monorepo, app, etc)
  final String type;

  /// Project name
  final String name;

  /// Project description
  final String description;

  /// Organization name
  final String organization;

  /// Top-level domain
  final String tld;

  /// Organization TLD
  final String orgTld;

  /// GitHub organization
  final String githubOrg;

  /// GitHub repository name
  final String githubRepo;

  /// GitHub repository visibility (public/private)
  final String githubVisibility;

  /// Backend type (serverpod, etc)
  final String? backend;

  /// Enable admin features
  final bool enableAdmin;

  /// Admin email address
  final String? adminEmail;

  /// Apple Developer ID
  final String? appleDeveloperId;

  /// iTunes Connect Team ID
  final String? itcTeamId;

  /// Apple Team ID
  final String? teamId;

  /// Certificate Common Name
  final String? certCn;

  /// Certificate Organizational Unit
  final String? certOu;

  /// Certificate Organization
  final String? certO;

  /// Certificate Locality
  final String? certL;

  /// Certificate State
  final String? certSt;

  /// Certificate Country
  final String? certC;

  /// Random project ID
  final String? randomProjectId;

  /// Random AWS resource ID (7-digit number for unique resource naming)
  final String? randomAwsId;

  /// AWS Access Key ID
  final String? awsAccessKeyId;

  /// AWS Secret Access Key
  final String? awsSecretAccessKey;

  /// Output directory
  final String? outputDir;

  /// Auto-start the project after creation
  final bool autoStart;

  /// Converts this [SavedProjectConfig] to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'name': name,
      'description': description,
      'organization': organization,
      'tld': tld,
      'org_tld': orgTld,
      'github_org': githubOrg,
      'github_repo': githubRepo,
      'github_visibility': githubVisibility,
      if (backend != null) 'backend': backend,
      'enable_admin': enableAdmin,
      if (adminEmail != null) 'admin_email': adminEmail,
      if (appleDeveloperId != null) 'apple_developer_id': appleDeveloperId,
      if (itcTeamId != null) 'itc_team_id': itcTeamId,
      if (teamId != null) 'team_id': teamId,
      if (certCn != null) 'cert_cn': certCn,
      if (certOu != null) 'cert_ou': certOu,
      if (certO != null) 'cert_o': certO,
      if (certL != null) 'cert_l': certL,
      if (certSt != null) 'cert_st': certSt,
      if (certC != null) 'cert_c': certC,
      if (randomProjectId != null) 'random_project_id': randomProjectId,
      if (randomAwsId != null) 'random_aws_id': randomAwsId,
      if (awsAccessKeyId != null) 'aws_access_key_id': awsAccessKeyId,
      if (awsSecretAccessKey != null) 'aws_secret_access_key': awsSecretAccessKey,
      if (outputDir != null) 'output_dir': outputDir,
      'auto_start': autoStart,
    };
  }

  /// Converts this [SavedProjectConfig] to a JSON string
  String toJsonString({bool pretty = true}) {
    final json = toJson();
    if (pretty) {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(json);
    }
    return jsonEncode(json);
  }
}

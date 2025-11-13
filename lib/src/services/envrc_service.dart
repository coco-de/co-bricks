import 'dart:io';

import 'package:path/path.dart' as path;

/// 프로젝트 설정 정보
class ProjectConfig {
  ProjectConfig({
    required this.projectName,
    required this.orgName,
    required this.orgTld,
    this.projectNameSnake,
    this.githubOrg,
    this.githubRepo,
    this.randomProjectId,
    this.appleDeveloperId,
    this.teamId,
    this.itcTeamId,
  });

  final String projectName;
  final String? projectNameSnake;
  final String orgName;
  final String orgTld;
  final String? githubOrg;
  final String? githubRepo;
  final String? randomProjectId;
  final String? appleDeveloperId;
  final String? teamId;
  final String? itcTeamId;

  /// 프로젝트명 리스트 (.envrc에서 파싱한 값만 사용)
  ///
  /// 전략:
  /// 1. PROJECT_NAME_SNAKE가 있으면: 두 형태 모두 사용
  ///    - 예: PROJECT_NAME="goodteacher" + PROJECT_NAME_SNAKE="good_teacher"
  ///    - 결과: ["goodteacher", "good_teacher"] - 두 케이스 모두 커버
  ///
  /// 2. PROJECT_NAME_SNAKE가 없으면: PROJECT_NAME만 사용
  ///    - 예: PROJECT_NAME="blueprint" (단일 단어)
  ///    - 결과: ["blueprint"] - 단일 단어 케이스
  ///
  /// 이를 통해:
  /// - good_teacher → goodTeacher → goodTeacherService (복합 단어)
  /// - goodteacher → goodteacher → goodteacherService (단일 단어)
  /// - blueprint → blueprint → blueprintService (단일 단어)
  /// 모두 커버 가능
  List<String> get projectNames => [
        projectName,
        if (projectNameSnake != null && projectNameSnake != projectName)
          projectNameSnake!,
      ];
}

/// .envrc 파일 파싱 서비스
class EnvrcService {
  /// 현재 디렉토리에서 상위로 탐색하여 .envrc 파일 찾기
  static File? findEnvrcFile([String? startDir]) {
    var currentDir = startDir != null ? Directory(startDir) : Directory.current;

    while (true) {
      final envrcFile = File(path.join(currentDir.path, '.envrc'));
      if (envrcFile.existsSync()) {
        return envrcFile;
      }

      final parent = currentDir.parent;
      if (parent.path == currentDir.path) {
        // 루트 디렉토리에 도달
        break;
      }
      currentDir = parent;
    }

    return null;
  }

  /// .envrc 파일 파싱
  static ProjectConfig parseEnvrc(File envrcFile) {
    if (!envrcFile.existsSync()) {
      throw FileSystemException('File not found', envrcFile.path);
    }

    final content = envrcFile.readAsStringSync();
    final lines = content.split('\n');

    String? projectName;
    String? projectNameSnake;
    String? orgName;
    String? orgTld;
    String? githubOrg;
    String? githubRepo;
    String? randomProjectId;
    String? appleDeveloperId;
    String? teamId;
    String? itcTeamId;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        continue;
      }

      // export KEY="value" 또는 export KEY='value' 패턴 파싱
      final match = RegExp(
        r'export\s+(\w+)="([^"]*)"|export\s+(\w+)='
        '([^'
        ']*)'
        '',
      ).firstMatch(trimmed);

      if (match != null) {
        final key = match.group(1) ?? match.group(3);
        final value = match.group(2) ?? match.group(4);

        switch (key) {
          case 'PROJECT_NAME':
            projectName = value;
            break;
          case 'PROJECT_NAME_SNAKE':
            projectNameSnake = value;
            break;
          case 'ORG_NAME':
            orgName = value;
            break;
          case 'ORG_TLD':
          case 'TLD':
            orgTld = value;
            break;
          case 'GITHUB_ORG':
            githubOrg = value;
            break;
          case 'GITHUB_REPO':
            githubRepo = value;
            break;
          case 'RANDOM_PROJECT_ID':
            randomProjectId = value;
            break;
          case 'APPLE_DEVELOPER_ID':
            appleDeveloperId = value;
            break;
          case 'TEAM_ID':
            teamId = value;
            break;
          case 'ITC_TEAM_ID':
            itcTeamId = value;
            break;
        }
      }
    }

    if (projectName == null || projectName.isEmpty) {
      throw FormatException(
        'PROJECT_NAME not found in .envrc file',
        envrcFile.path,
      );
    }

    if (orgName == null || orgName.isEmpty) {
      throw FormatException(
        'ORG_NAME not found in .envrc file',
        envrcFile.path,
      );
    }

    if (orgTld == null || orgTld.isEmpty) {
      throw FormatException(
        'ORG_TLD or TLD not found in .envrc file',
        envrcFile.path,
      );
    }

    return ProjectConfig(
      projectName: projectName,
      projectNameSnake: projectNameSnake,
      orgName: orgName,
      orgTld: orgTld,
      githubOrg: githubOrg,
      githubRepo: githubRepo,
      randomProjectId: randomProjectId,
      appleDeveloperId: appleDeveloperId,
      teamId: teamId,
      itcTeamId: itcTeamId,
    );
  }

  /// 프로젝트 디렉토리에서 .envrc 파일 찾기 및 파싱
  static ProjectConfig loadFromProjectDir([String? projectDir]) {
    final envrcFile = findEnvrcFile(projectDir);
    if (envrcFile == null) {
      throw FileSystemException(
        '.envrc file not found. Please run this command from a project directory.',
        projectDir ?? Directory.current.path,
      );
    }

    return parseEnvrc(envrcFile);
  }
}

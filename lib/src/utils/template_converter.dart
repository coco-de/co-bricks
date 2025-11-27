import 'package:co_bricks/src/services/envrc_service.dart';

/// 템플릿 변환 패턴
class ReplacementPattern {
  ReplacementPattern(this.pattern, this.replacement);

  final RegExp pattern;
  final String replacement;
}

/// 템플릿 변환 유틸리티
class TemplateConverter {
  /// 프로젝트 설정 기반으로 변환 패턴 생성
  static List<ReplacementPattern> buildPatterns(ProjectConfig config) {
    final patterns = <ReplacementPattern>[];

    // .envrc에서 파싱한 값만 사용 (하드코딩된 상수 제거)
    final projectNames = config.projectNames;
    final orgNames = [config.orgName];
    final orgTlds = [config.orgTld];
    final randomProjectIds = config.randomProjectId != null
        ? [config.randomProjectId!]
        : <String>[];

    // 패턴 순서가 중요합니다. 더 구체적인 패턴을 먼저 적용해야 합니다.

    // 0. GitHub URL 패턴 (가장 먼저 적용! 프로젝트명 변환 전에 처리)
    if (config.githubOrg != null && config.githubRepo != null) {
      patterns.addAll(
        _buildGitHubUrlPatterns(
          config.githubOrg!,
          config.githubRepo!,
          projectNames,
        ),
      );
    }

    // 0-1. GitHub 조직명 패턴 (URL 패턴 직후에 적용하여 남은 coco-de 처리)
    if (config.githubOrg != null) {
      patterns.addAll(_buildGitHubOrgPatterns(config.githubOrg!));
    }

    // 0.5. Apple App ID 패턴 (team_id + bundle ID 조합, Firebase보다 먼저!)
    if (config.teamId != null) {
      patterns.addAll(
        _buildAppleAppIdPatterns(
          config.teamId!,
          projectNames,
          orgNames,
          orgTlds,
          randomProjectIds,
        ),
      );
    }

    // 1. Apple Developer ID 패턴
    if (config.appleDeveloperId != null) {
      patterns.addAll(_buildAppleDeveloperIdPatterns(config.appleDeveloperId!));
    }

    // 2. 가장 구체적인 패턴 (Firebase 전체 경로 등)
    patterns.addAll(
      _buildFirebasePatterns(projectNames, orgNames, orgTlds, randomProjectIds),
    );

    // 3. 도메인 패턴 (app-staging.good_teacher.im 등)
    patterns.addAll(_buildDomainPatterns(projectNames, orgTlds));

    // 4. 이메일 주소 패턴
    patterns.addAll(
      _buildEmailPatterns(orgNames, orgTlds, config.appleDeveloperId),
    );

    // 5. URL Scheme 패턴
    patterns.addAll(_buildUrlSchemePatterns(projectNames));

    // 6. 프로젝트명 패턴
    patterns.addAll(_buildProjectPatterns(projectNames, orgNames, orgTlds));

    // 7. 조직명 패턴
    patterns.addAll(_buildOrgPatterns(orgNames));

    // 8. 케이스 변환 패턴
    patterns.addAll(_buildCasePatterns(projectNames));

    // 9. Random project ID 단독 패턴 (lgxf 같은 패턴)
    patterns.addAll(_buildRandomProjectIdPatterns(randomProjectIds));

    // 10. Apple Team ID 패턴
    patterns.addAll(_buildAppleTeamIdPatterns(config));

    // 11. GitHub 저장소명 패턴
    if (config.githubRepo != null) {
      patterns.addAll(_buildGitHubRepoPatterns(config.githubRepo!));
    }

    // 13. org_tld 단독 패턴 (im. 같은 패턴, 가장 마지막에 처리)
    patterns.addAll(_buildOrgTldPatterns(orgTlds));

    return patterns;
  }

  /// Random project ID 단독 패턴 생성
  static List<ReplacementPattern> _buildRandomProjectIdPatterns(
    List<String> randomProjectIds,
  ) {
    final patterns = <ReplacementPattern>[];

    for (final randomId in randomProjectIds) {
      patterns.addAll([
        // -lgxf- 패턴 (하이픈 사이)
        ReplacementPattern(
          RegExp('-${_escapeRegex(randomId)}-'),
          '-{{randomprojectid}}-',
        ),
        // -lgxf 패턴 (하이픈 뒤, 단어 경계)
        ReplacementPattern(
          RegExp('-${_escapeRegex(randomId)}\\b'),
          '-{{randomprojectid}}',
        ),
        // .lgxf. 패턴 (점 사이)
        ReplacementPattern(
          RegExp('\\.${_escapeRegex(randomId)}\\.'),
          '.{{randomprojectid}}.',
        ),
        // .lgxf 패턴 (점 뒤, 단어 경계)
        ReplacementPattern(
          RegExp('\\.${_escapeRegex(randomId)}\\b'),
          '.{{randomprojectid}}',
        ),
        // lgxf 패턴 (단독, 단어 경계)
        ReplacementPattern(
          RegExp('\\b${_escapeRegex(randomId)}\\b'),
          '{{randomprojectid}}',
        ),
      ]);
    }

    return patterns;
  }

  /// GitHub URL 패턴 생성 (전체 URL 패턴, 더 구체적)
  static List<ReplacementPattern> _buildGitHubUrlPatterns(
    String githubOrg,
    String githubRepo,
    List<String> projectNames,
  ) {
    final patterns = <ReplacementPattern>[];

    // github.com/coco-de/good-teacher.git 패턴
    // 프로젝트명이 포함된 GitHub URL 패턴 처리
    for (final projectName in projectNames) {
      final projectParam = projectName.replaceAll('_', '-'); // good-teacher
      final projectSnake = projectName; // good_teacher

      // param-case 버전 (good-teacher)
      // https:// 포함 버전
      patterns.add(
        ReplacementPattern(
          RegExp(
            'https://github\\.com/${_escapeRegex(githubOrg)}/${_escapeRegex(projectParam)}\\.git',
          ),
          'https://github.com/{{github_org}}/{{project_name.paramCase()}}.git',
        ),
      );
      patterns.add(
        ReplacementPattern(
          RegExp(
            'https://github\\.com/${_escapeRegex(githubOrg)}/${_escapeRegex(projectParam)}\\b',
          ),
          'https://github.com/{{github_org}}/{{project_name.paramCase()}}',
        ),
      );
      // https:// 없는 버전
      patterns.add(
        ReplacementPattern(
          RegExp(
            'github\\.com/${_escapeRegex(githubOrg)}/${_escapeRegex(projectParam)}\\.git',
          ),
          'github.com/{{github_org}}/{{project_name.paramCase()}}.git',
        ),
      );
      patterns.add(
        ReplacementPattern(
          RegExp(
            'github\\.com/${_escapeRegex(githubOrg)}/${_escapeRegex(projectParam)}\\b',
          ),
          'github.com/{{github_org}}/{{project_name.paramCase()}}',
        ),
      );

      // snake_case 버전 (good_teacher) → GitHub는 paramCase 사용
      // https:// 포함 버전
      patterns.add(
        ReplacementPattern(
          RegExp(
            'https://github\\.com/${_escapeRegex(githubOrg)}/${_escapeRegex(projectSnake)}\\.git',
          ),
          'https://github.com/{{github_org}}/{{project_name.paramCase()}}.git',
        ),
      );
      patterns.add(
        ReplacementPattern(
          RegExp(
            'https://github\\.com/${_escapeRegex(githubOrg)}/${_escapeRegex(projectSnake)}\\b',
          ),
          'https://github.com/{{github_org}}/{{project_name.paramCase()}}',
        ),
      );
      // https:// 없는 버전
      patterns.add(
        ReplacementPattern(
          RegExp(
            'github\\.com/${_escapeRegex(githubOrg)}/${_escapeRegex(projectSnake)}\\.git',
          ),
          'github.com/{{github_org}}/{{project_name.paramCase()}}.git',
        ),
      );
      patterns.add(
        ReplacementPattern(
          RegExp(
            'github\\.com/${_escapeRegex(githubOrg)}/${_escapeRegex(projectSnake)}\\b',
          ),
          'github.com/{{github_org}}/{{project_name.paramCase()}}',
        ),
      );
    }

    return patterns;
  }

  /// GitHub 조직명 패턴 생성
  static List<ReplacementPattern> _buildGitHubOrgPatterns(String githubOrg) {
    final patterns = <ReplacementPattern>[];

    patterns.addAll([
      // 이미 프로젝트명이 변환된 경우 처리
      // github.com/coco-de/{{project_name...}} → github.com/{{github_org}}/{{project_name...}}
      ReplacementPattern(
        RegExp(
          r'github\.com/' + _escapeRegex(githubOrg) + r'/\{\{project_name\.',
        ),
        'github.com/{{github_org}}/{{project_name.',
      ),

      // github.com/coco-de/ 패턴
      ReplacementPattern(
        RegExp('github\\.com/${_escapeRegex(githubOrg)}/'),
        'github.com/{{github_org}}/',
      ),
      // github.com/coco-de 패턴 (끝에 슬래시 없음)
      ReplacementPattern(
        RegExp('github\\.com/${_escapeRegex(githubOrg)}\\b'),
        'github.com/{{github_org}}',
      ),
      // coco-de/ 패턴 (앞에 github.com 없음)
      ReplacementPattern(
        RegExp('\\b${_escapeRegex(githubOrg)}/'),
        '{{github_org}}/',
      ),
      // coco-de 패턴 (단독)
      ReplacementPattern(
        RegExp('\\b${_escapeRegex(githubOrg)}\\b'),
        '{{github_org}}',
      ),
    ]);

    return patterns;
  }

  /// GitHub 저장소명 패턴 생성
  static List<ReplacementPattern> _buildGitHubRepoPatterns(String githubRepo) {
    final patterns = <ReplacementPattern>[];

    patterns.addAll([
      // good-teacher.git 패턴
      ReplacementPattern(
        RegExp('${_escapeRegex(githubRepo)}\\.git'),
        '{{github_repo}}.git',
      ),
      // good-teacher 패턴
      ReplacementPattern(
        RegExp('\\b${_escapeRegex(githubRepo)}\\b'),
        '{{github_repo}}',
      ),
    ]);

    return patterns;
  }

  /// org_tld 단독 패턴 생성 (im. 같은 패턴)
  static List<ReplacementPattern> _buildOrgTldPatterns(List<String> orgTlds) {
    final patterns = <ReplacementPattern>[];

    for (final orgTld in orgTlds) {
      patterns.addAll([
        // im. 패턴 (점 뒤에 공백이나 다른 문자)
        ReplacementPattern(
          RegExp('\\b${_escapeRegex(orgTld)}\\.'),
          '{{org_tld}}.',
        ),
        // im- 패턴 (하이픈 뒤)
        ReplacementPattern(
          RegExp('\\b${_escapeRegex(orgTld)}-'),
          '{{org_tld}}-',
        ),
        // im 패턴 (단독, 단어 경계)
        ReplacementPattern(
          RegExp('\\b${_escapeRegex(orgTld)}\\b'),
          '{{org_tld}}',
        ),
      ]);
    }

    return patterns;
  }

  /// 프로젝트명 패턴 생성
  static List<ReplacementPattern> _buildProjectPatterns(
    List<String> projectNames,
    List<String> orgNames,
    List<String> orgTlds,
  ) {
    final patterns = <ReplacementPattern>[];

    for (final projectName in projectNames) {
      final baseSnake = projectName;
      final baseParam = projectName.replaceAll('_', '-');
      final baseDot = projectName.replaceAll('_', '.');
      final words = projectName.split('_');
      final baseTitle = words
          .map((word) => word[0].toUpperCase() + word.substring(1))
          .join(' ');
      final basePascal = words
          .map(
            (word) => word.isEmpty
                ? ''
                : word[0].toUpperCase() + word.substring(1).toLowerCase(),
          )
          .join();

      // Android notification channel groupKey 패턴
      // groupKey: 'im.cocode.blueprint'
      //   → groupKey: '{{org_tld}}.{{org_name}}.{{project_name.snakeCase()}}'
      for (final orgTld in orgTlds) {
        for (final orgName in orgNames) {
          final orgLower = orgName.toLowerCase();
          final groupKeyPattern = "groupKey: '"
              '${_escapeRegex(orgTld)}\\.'
              '${_escapeRegex(orgLower)}\\.'
              "${_escapeRegex(baseSnake)}'";
          const groupKeyReplacement = "groupKey: "
              "'{{org_tld}}.{{org_name}}.{{project_name.snakeCase()}}'";
          patterns.add(
            ReplacementPattern(
              RegExp(groupKeyPattern),
              groupKeyReplacement,
            ),
          );

          // Kotlin package 문 패턴 (suffix 있는 경우 - randomId 없음)
          // package im.cocode.blueprint.console
          // → package {{org_tld}}.{{org_name.lowerCase()}}.{{project_name.snakeCase()}}.suffix
          for (final suffix in ['console', 'widgetbook']) {
            patterns.add(
              ReplacementPattern(
                RegExp(
                  'package ${_escapeRegex(orgTld)}\\.'
                  '${_escapeRegex(orgLower)}\\.'
                  '${_escapeRegex(baseSnake)}\\.'
                  '$suffix\\b',
                ),
                'package {{org_tld}}.{{org_name.lowerCase()}}.'
                '{{project_name.snakeCase()}}.$suffix',
              ),
            );
          }

          // 일반 Kotlin package 문 패턴 (randomId 없음)
          // package im.cocode.blueprint
          // → package {{org_tld}}.{{org_name.lowerCase()}}.{{project_name.snakeCase()}}
          patterns.add(
            ReplacementPattern(
              RegExp(
                'package ${_escapeRegex(orgTld)}\\.'
                '${_escapeRegex(orgLower)}\\.'
                '${_escapeRegex(baseSnake)}\\b',
              ),
              'package {{org_tld}}.{{org_name.lowerCase()}}.'
              '{{project_name.snakeCase()}}',
            ),
          );
        }
      }

      // Dart/Flutter 컨텍스트 패턴 (최우선 - snakeCase 유지)
      // package: imports, pubspec.yaml name 등 Dart 코드 컨텍스트
      for (final suffix in [
        '_http_module',
        '_service_module',
        '_server',
        '_client',
        '_widgetbook',
        '_console',
        '_service',
        '_module',
      ]) {
        // package: import 패턴 (Dart import 문)
        patterns.add(
          ReplacementPattern(
            RegExp('package:${_escapeRegex(baseSnake)}$suffix/'),
            'package:{{project_name.snakeCase()}}$suffix/',
          ),
        );
      }

      // pubspec.yaml의 name 필드 (Dart 패키지명은 snake_case 필수)
      for (final suffix in [
        '_http_module',
        '_service_module',
        '_server',
        '_client',
        '_widgetbook',
        '_console',
        '_service',
        '_module',
      ]) {
        patterns.add(
          ReplacementPattern(
            RegExp('name:\\s*${_escapeRegex(baseSnake)}$suffix\\b'),
            'name: {{project_name.snakeCase()}}$suffix',
          ),
        );
      }

      // suffix 없는 기본 패키지 패턴 (suffix 패턴 후에 처리)
      // package:blueprint/ → package:{{project_name.snakeCase()}}/
      patterns.add(
        ReplacementPattern(
          RegExp('package:${_escapeRegex(baseSnake)}/'),
          'package:{{project_name.snakeCase()}}/',
        ),
      );

      // suffix 없는 pubspec.yaml name 필드
      // name: blueprint → name: {{project_name.snakeCase()}}
      patterns.add(
        ReplacementPattern(
          RegExp('name:\\s*${_escapeRegex(baseSnake)}\\b'),
          'name: {{project_name.snakeCase()}}',
        ),
      );

      // CMakeLists.txt BINARY_NAME 패턴 (Windows 빌드)
      // set(BINARY_NAME "blueprint") → set(BINARY_NAME "{{project_name.snakeCase()}}")
      patterns.add(
        ReplacementPattern(
          RegExp('set\\(BINARY_NAME "${_escapeRegex(baseSnake)}"\\)'),
          'set(BINARY_NAME "{{project_name.snakeCase()}}")',
        ),
      );

      // Docker 이미지명 패턴 (snake_case 사용)
      // docker build -t project_name_server → docker build -t {{project_name.snakeCase()}}_server
      for (final suffix in [
        '_server',
        '_client',
        '_widgetbook',
        '_console',
      ]) {
        // docker build -t pattern (snake_case 유지)
        patterns.add(
          ReplacementPattern(
            RegExp('docker build -t ${_escapeRegex(baseSnake)}$suffix'),
            'docker build -t {{project_name.snakeCase()}}$suffix',
          ),
        );
        // docker build -t pattern (param-case를 snake_case로 변환)
        final paramSuffix = suffix.replaceAll('_', '-');
        patterns.add(
          ReplacementPattern(
            RegExp('docker build -t ${_escapeRegex(baseParam)}$paramSuffix'),
            'docker build -t {{project_name.snakeCase()}}$suffix',
          ),
        );
      }

      // Docker 컨테이너 이름 패턴 (snake_case 사용)
      // docker exec -it project_name_postgres → docker exec -it {{project_name.snakeCase()}}_postgres
      for (final suffix in [
        '_postgres',
        '_redis',
        '_server',
        '_client',
      ]) {
        // docker exec -it pattern (snake_case 유지)
        patterns.add(
          ReplacementPattern(
            RegExp('docker exec -it ${_escapeRegex(baseSnake)}$suffix'),
            'docker exec -it {{project_name.snakeCase()}}$suffix',
          ),
        );
        // docker exec -it pattern (param-case를 snake_case로 변환)
        final paramSuffix = suffix.replaceAll('_', '-');
        patterns.add(
          ReplacementPattern(
            RegExp('docker exec -it ${_escapeRegex(baseParam)}$paramSuffix'),
            'docker exec -it {{project_name.snakeCase()}}$suffix',
          ),
        );
      }

      // PostgreSQL 데이터베이스명 패턴 (docker exec psql -d 컨텍스트)
      // psql -U postgres -d blueprint → psql -U postgres -d {{project_name.paramCase()}}
      for (final suffix in ['', '_test', '_dev', '_development']) {
        final paramSuffix = suffix.replaceAll('_', '-');
        // snake_case 데이터베이스명
        patterns.add(
          ReplacementPattern(
            RegExp('psql -U postgres -d ${_escapeRegex(baseSnake)}$suffix\\b'),
            'psql -U postgres -d {{project_name.paramCase()}}$paramSuffix',
          ),
        );
        // param-case 데이터베이스명
        patterns.add(
          ReplacementPattern(
            RegExp('psql -U postgres -d ${_escapeRegex(baseParam)}$paramSuffix\\b'),
            'psql -U postgres -d {{project_name.paramCase()}}$paramSuffix',
          ),
        );
      }

      // Serverpod generator.yaml 파일 패턴 (snake_case 유지)
      // client_package_path는 Dart 패키지 경로이므로 snake_case 사용
      // 예: client_package_path: ../blueprint_client →
      //     ../{{project_name.snakeCase()}}_client

      // client_package_path 패턴 (snake_case 유지)
      patterns.add(
        ReplacementPattern(
          RegExp(
            'client_package_path:\\s*\\.\\./\\.\\./\\s*${_escapeRegex(baseSnake)}_client',
          ),
          'client_package_path: ../../{{project_name.snakeCase()}}_client',
        ),
      );
      patterns.add(
        ReplacementPattern(
          RegExp(
            'client_package_path:\\s*\\.\\./\\s*${_escapeRegex(baseSnake)}_client',
          ),
          'client_package_path: ../{{project_name.snakeCase()}}_client',
        ),
      );
      patterns.add(
        ReplacementPattern(
          RegExp(
            'client_package_path:\\s*\\.\\./\\s*${_escapeRegex(baseParam)}-client',
          ),
          'client_package_path: ../{{project_name.snakeCase()}}_client',
        ),
      );

      // VSCode launch.json 패턴 (snake_case 유지)
      // "cwd": "./app/blueprint_console/" →
      // "cwd": "./app/{{project_name.snakeCase()}}_console/"
      for (final suffix in ['_console', '_widgetbook']) {
        patterns.add(
          ReplacementPattern(
            RegExp('"cwd":\\s*"\\./app/${_escapeRegex(baseSnake)}$suffix/"'),
            '"cwd": "./app/{{project_name.snakeCase()}}$suffix/"',
          ),
        );
        patterns.add(
          ReplacementPattern(
            RegExp(
              '"cwd":\\s*"\\./app/${_escapeRegex(baseParam)}${suffix.replaceAll('_', '-')}/"',
            ),
            '"cwd": "./app/{{project_name.snakeCase()}}$suffix/"',
          ),
        );
      }

      // VSCode launch.json program 패턴 (snake_case 유지)
      // "program": "app/blueprint_widgetbook/lib/main.dart"
      for (final suffix in ['_console', '_widgetbook']) {
        patterns.add(
          ReplacementPattern(
            RegExp('"program":\\s*"app/${_escapeRegex(baseSnake)}$suffix/'),
            '"program": "app/{{project_name.snakeCase()}}$suffix/',
          ),
        );
        patterns.add(
          ReplacementPattern(
            RegExp(
              '"program":\\s*"app/${_escapeRegex(baseParam)}${suffix.replaceAll('_', '-')}/',
            ),
            '"program": "app/{{project_name.snakeCase()}}$suffix/',
          ),
        );
      }

      // GitHub workflows WORKING_DIRECTORY 패턴 (snake_case 유지)
      // WORKING_DIRECTORY: app/blueprint_console
      for (final suffix in ['_console', '_widgetbook', '_server']) {
        patterns.add(
          ReplacementPattern(
            RegExp(
              'WORKING_DIRECTORY:\\s*app/${_escapeRegex(baseSnake)}$suffix\\b',
            ),
            'WORKING_DIRECTORY: app/{{project_name.snakeCase()}}$suffix',
          ),
        );
        patterns.add(
          ReplacementPattern(
            RegExp(
              'WORKING_DIRECTORY:\\s*app/${_escapeRegex(baseParam)}${suffix.replaceAll('_', '-')}\\b',
            ),
            'WORKING_DIRECTORY: app/{{project_name.snakeCase()}}$suffix',
          ),
        );
      }

      // Melos scope 패턴 (snake_case 유지)
      // scope: "blueprint_server" → scope: "{{project_name.snakeCase()}}_server"
      for (final suffix in ['_server', '_client']) {
        patterns.add(
          ReplacementPattern(
            RegExp('scope:\\s*"${_escapeRegex(baseSnake)}$suffix"'),
            'scope: "{{project_name.snakeCase()}}$suffix"',
          ),
        );
        patterns.add(
          ReplacementPattern(
            RegExp(
              'scope:\\s*"${_escapeRegex(baseParam)}${suffix.replaceAll('_', '-')}"',
            ),
            'scope: "{{project_name.snakeCase()}}$suffix"',
          ),
        );
      }

      // Melos scope 패턴 - 프로젝트 이름 자체 (suffix 없이)
      // scope: "blueprint" → scope: "{{project_name.snakeCase()}}"
      patterns.add(
        ReplacementPattern(
          RegExp('scope:\\s*"${_escapeRegex(baseSnake)}"'),
          'scope: "{{project_name.snakeCase()}}"',
        ),
      );
      patterns.add(
        ReplacementPattern(
          RegExp('scope:\\s*"${_escapeRegex(baseParam)}"'),
          'scope: "{{project_name.snakeCase()}}"',
        ),
      );

      // Melos CLI flag patterns (--scope blueprint)
      // --scope blueprint → --scope {{project_name.snakeCase()}} (단독, suffix 없이)
      patterns.add(
        ReplacementPattern(
          RegExp('--scope\\s+${_escapeRegex(baseSnake)}\\b'),
          '--scope {{project_name.snakeCase()}}',
        ),
      );
      patterns.add(
        ReplacementPattern(
          RegExp('--scope\\s+${_escapeRegex(baseParam)}\\b'),
          '--scope {{project_name.snakeCase()}}',
        ),
      );

      // Melos CLI flag patterns (--scope blueprint_console)
      // melos exec --scope blueprint_console → melos exec --scope {{project_name.snakeCase()}}_console
      for (final suffix in ['_console', '_widgetbook', '_server', '_client']) {
        // snake_case CLI flags
        patterns.add(
          ReplacementPattern(
            RegExp('--scope\\s+${_escapeRegex(baseSnake)}$suffix\\b'),
            '--scope {{project_name.snakeCase()}}$suffix',
          ),
        );
        // param-case CLI flags
        patterns.add(
          ReplacementPattern(
            RegExp(
              '--scope\\s+${_escapeRegex(baseParam)}${suffix.replaceAll('_', '-')}\\b',
            ),
            '--scope {{project_name.snakeCase()}}$suffix',
          ),
        );
      }

      // Melos script keys (web:run:fixed-port:blueprint:)
      // Scripts와 echo 메시지에서 사용되는 프로젝트 이름은 snakeCase
      patterns.add(
        ReplacementPattern(
          RegExp('web:run:fixed-port:${_escapeRegex(baseSnake)}:'),
          'web:run:fixed-port:{{project_name.snakeCase()}}:',
        ),
      );
      patterns.add(
        ReplacementPattern(
          RegExp('web:run:fixed-port:${_escapeRegex(baseParam)}(?=:)'),
          'web:run:fixed-port:{{project_name.snakeCase()}}',
        ),
      );

      // Melos run 명령어에서의 스크립트 참조
      patterns.add(
        ReplacementPattern(
          RegExp('melos run web:run:fixed-port:${_escapeRegex(baseSnake)}\\b'),
          'melos run web:run:fixed-port:{{project_name.snakeCase()}}',
        ),
      );
      patterns.add(
        ReplacementPattern(
          RegExp('melos run web:run:fixed-port:${_escapeRegex(baseParam)}\\b'),
          'melos run web:run:fixed-port:{{project_name.snakeCase()}}',
        ),
      );

      // Echo 메시지 내의 프로젝트 이름 (예: "blueprint(8082)")
      // 괄호 앞의 단독 프로젝트 이름을 snakeCase로 변환
      patterns.add(
        ReplacementPattern(
          RegExp('${_escapeRegex(baseSnake)}(?=\\()'),
          '{{project_name.snakeCase()}}',
        ),
      );
      patterns.add(
        ReplacementPattern(
          RegExp('${_escapeRegex(baseParam)}(?=\\()'),
          '{{project_name.snakeCase()}}',
        ),
      );

      // Description 내의 프로젝트 이름 (예: description: "blueprint 웹 앱을...")
      // description 문자열 내에서도 snakeCase 사용
      patterns.add(
        ReplacementPattern(
          RegExp('description:\\s*"${_escapeRegex(baseParam)}\\s'),
          'description: "{{project_name.snakeCase()}} ',
        ),
      );
      patterns.add(
        ReplacementPattern(
          RegExp('description:\\s*"${_escapeRegex(baseSnake)}\\s'),
          'description: "{{project_name.snakeCase()}} ',
        ),
      );

      // 문서/설정 파일 경로 패턴 (snake_case 유지)
      // backend/blueprint_client/ → backend/{{project_name.snakeCase()}}_client/
      // backend/blueprint_server/ → backend/{{project_name.snakeCase()}}_server/
      // app/blueprint_console/ → app/{{project_name.snakeCase()}}_console/
      // app/blueprint_widgetbook/ → app/{{project_name.snakeCase()}}_widgetbook/

      // backend/ 경로 패턴
      for (final suffix in ['_client', '_server']) {
        // backend/blueprint_client/ 형태
        patterns.add(
          ReplacementPattern(
            RegExp('backend/${_escapeRegex(baseSnake)}$suffix/'),
            'backend/{{project_name.snakeCase()}}$suffix/',
          ),
        );
        patterns.add(
          ReplacementPattern(
            RegExp(
              'backend/${_escapeRegex(baseParam)}${suffix.replaceAll('_', '-')}/',
            ),
            'backend/{{project_name.snakeCase()}}$suffix/',
          ),
        );

        // backend/blueprint_client 형태 (슬래시 없음)
        patterns.add(
          ReplacementPattern(
            RegExp('backend/${_escapeRegex(baseSnake)}$suffix\\b'),
            'backend/{{project_name.snakeCase()}}$suffix',
          ),
        );
        patterns.add(
          ReplacementPattern(
            RegExp(
              'backend/${_escapeRegex(baseParam)}${suffix.replaceAll('_', '-')}\\b',
            ),
            'backend/{{project_name.snakeCase()}}$suffix',
          ),
        );
      }

      // app/ 경로 패턴
      for (final suffix in ['_console', '_widgetbook']) {
        // app/blueprint_console/ 형태
        patterns.add(
          ReplacementPattern(
            RegExp('app/${_escapeRegex(baseSnake)}$suffix/'),
            'app/{{project_name.snakeCase()}}$suffix/',
          ),
        );
        patterns.add(
          ReplacementPattern(
            RegExp(
              'app/${_escapeRegex(baseParam)}${suffix.replaceAll('_', '-')}/',
            ),
            'app/{{project_name.snakeCase()}}$suffix/',
          ),
        );

        // app/blueprint_console 형태 (슬래시 없음)
        patterns.add(
          ReplacementPattern(
            RegExp('app/${_escapeRegex(baseSnake)}$suffix\\b'),
            'app/{{project_name.snakeCase()}}$suffix',
          ),
        );
        patterns.add(
          ReplacementPattern(
            RegExp(
              'app/${_escapeRegex(baseParam)}${suffix.replaceAll('_', '-')}\\b',
            ),
            'app/{{project_name.snakeCase()}}$suffix',
          ),
        );
      }

      // package import 경로 패턴 (Markdown 코드 블록 등)
      // package:blueprint_client/blueprint_client.dart
      patterns.add(
        ReplacementPattern(
          RegExp(
            'package:${_escapeRegex(baseSnake)}_client/${_escapeRegex(baseSnake)}_client\\.dart',
          ),
          'package:{{project_name.snakeCase()}}_client/{{project_name.snakeCase()}}_client.dart',
        ),
      );
      patterns.add(
        ReplacementPattern(
          RegExp(
            'package:${_escapeRegex(baseParam)}-client/${_escapeRegex(baseParam)}-client\\.dart',
          ),
          'package:{{project_name.snakeCase()}}_client/{{project_name.snakeCase()}}_client.dart',
        ),
      );

      // 파일명 단독 패턴 (blueprint_client.dart)
      // 이미 경로가 변환된 후 파일명만 남은 경우
      patterns.add(
        ReplacementPattern(
          RegExp('/${_escapeRegex(baseSnake)}_client\\.dart'),
          '/{{project_name.snakeCase()}}_client.dart',
        ),
      );
      patterns.add(
        ReplacementPattern(
          RegExp('/${_escapeRegex(baseParam)}-client\\.dart'),
          '/{{project_name.snakeCase()}}_client.dart',
        ),
      );

      // 단독 디렉토리명 패턴 (경로 접두사 없이 나타나는 경우)
      // 디렉토리 트리 표현이나 주석에서 사용
      // blueprint_console/      # 관리자 앱
      // blueprint_client/       # 클라이언트 SDK
      for (final suffix in ['_console', '_widgetbook', '_client', '_server']) {
        // 슬래시가 있는 형태 (디렉토리 표현)
        patterns.add(
          ReplacementPattern(
            RegExp('(?<!/)${_escapeRegex(baseSnake)}$suffix/'),
            '{{project_name.snakeCase()}}$suffix/',
          ),
        );
        patterns.add(
          ReplacementPattern(
            RegExp(
              '(?<!/)${_escapeRegex(baseParam)}${suffix.replaceAll('_', '-')}/',
            ),
            '{{project_name.snakeCase()}}$suffix/',
          ),
        );
      }

      // Glob wildcard patterns for YAML arrays
      // - "*blueprint_client*" → - "*{{project_name.snakeCase()}}_client*"
      for (final suffix in ['_console', '_widgetbook', '_server', '_client']) {
        // snake_case with wildcards
        patterns.add(
          ReplacementPattern(
            RegExp('"\\*${_escapeRegex(baseSnake)}$suffix\\*"'),
            '"*{{project_name.snakeCase()}}$suffix*"',
          ),
        );
        // param-case with wildcards
        patterns.add(
          ReplacementPattern(
            RegExp(
              '"\\*${_escapeRegex(baseParam)}${suffix.replaceAll('_', '-')}\\*"',
            ),
            '"*{{project_name.snakeCase()}}$suffix*"',
          ),
        );
      }

      // Parenthesis context patterns (echo strings, port specifications)
      // blueprint_console(8083) → {{project_name.snakeCase()}}_console(8083)
      for (final suffix in ['_console', '_widgetbook', '_server', '_client']) {
        // snake_case with parenthesis
        patterns.add(
          ReplacementPattern(
            RegExp('${_escapeRegex(baseSnake)}$suffix\\('),
            '{{project_name.snakeCase()}}$suffix(',
          ),
        );
        // param-case with parenthesis
        patterns.add(
          ReplacementPattern(
            RegExp(
              '${_escapeRegex(baseParam)}${suffix.replaceAll('_', '-')}\\(',
            ),
            '{{project_name.snakeCase()}}$suffix(',
          ),
        );
      }

      // YAML string array item patterns
      // - "blueprint_client" → - "{{project_name.snakeCase()}}_client"
      for (final suffix in ['_console', '_widgetbook', '_server', '_client']) {
        // snake_case in YAML string arrays
        patterns.add(
          ReplacementPattern(
            RegExp('- "${_escapeRegex(baseSnake)}$suffix"'),
            '- "{{project_name.snakeCase()}}$suffix"',
          ),
        );
        // param-case in YAML string arrays
        patterns.add(
          ReplacementPattern(
            RegExp(
              '- "${_escapeRegex(baseParam)}${suffix.replaceAll('_', '-')}"',
            ),
            '- "{{project_name.snakeCase()}}$suffix"',
          ),
        );
      }

      // Plain text in descriptions and comments
      // description: "blueprint_console 웹 앱을..." → description: "{{project_name.snakeCase()}}_console 웹 앱을..."
      for (final suffix in ['_console', '_widgetbook', '_server', '_client']) {
        // snake_case in plain text
        patterns.add(
          ReplacementPattern(
            RegExp('\\b${_escapeRegex(baseSnake)}$suffix\\b'),
            '{{project_name.snakeCase()}}$suffix',
          ),
        );
        // param-case in plain text
        patterns.add(
          ReplacementPattern(
            RegExp(
              '\\b${_escapeRegex(baseParam)}${suffix.replaceAll('_', '-')}\\b',
            ),
            '{{project_name.snakeCase()}}$suffix',
          ),
        );
      }

      // PostgreSQL JDBC URL 패턴
      // jdbc:postgresql://localhost:8090/blueprint → jdbc:postgresql://localhost:8090/{{project_name.paramCase()}}
      // jdbc:postgresql://localhost:9090/blueprint_test → jdbc:postgresql://localhost:9090/{{project_name.paramCase()}}-test

      // Base database name (no suffix)
      patterns.add(
        ReplacementPattern(
          RegExp('jdbc:postgresql://([^/]+)/${_escapeRegex(baseSnake)}\\b'),
          r'jdbc:postgresql://$1/{{project_name.paramCase()}}',
        ),
      );
      patterns.add(
        ReplacementPattern(
          RegExp('jdbc:postgresql://([^/]+)/${_escapeRegex(baseParam)}\\b'),
          r'jdbc:postgresql://$1/{{project_name.paramCase()}}',
        ),
      );

      // JDBC URL with database suffix patterns
      for (final suffix in [
        '_test',
        '_dev',
        '_development',
        '_staging',
        '_prod',
        '_production',
      ]) {
        final paramSuffix = suffix.replaceAll('_', '-');
        // snake_case JDBC URLs
        patterns.add(
          ReplacementPattern(
            RegExp(
              'jdbc:postgresql://([^/]+)/${_escapeRegex(baseSnake)}$suffix\\b',
            ),
            'jdbc:postgresql://\$1/{{project_name.paramCase()}}$paramSuffix',
          ),
        );
        // param-case JDBC URLs
        patterns.add(
          ReplacementPattern(
            RegExp(
              'jdbc:postgresql://([^/]+)/${_escapeRegex(baseParam)}$paramSuffix\\b',
            ),
            'jdbc:postgresql://\$1/{{project_name.paramCase()}}$paramSuffix',
          ),
        );
      }

      // AWS Lambda 함수 이름 패턴
      // /aws/lambda/blueprint_push-forwarder-production → /aws/lambda/{{project_name.paramCase()}}-push-forwarder-production
      // --log-group-name "/aws/lambda/blueprint_push-forwarder-production" → "/aws/lambda/{{project_name.paramCase()}}-push-forwarder-production"
      for (final suffix in [
        '-push-forwarder-production',
        '-push-forwarder-staging',
        '-push-forwarder-development',
        '_push-forwarder-production',
        '_push-forwarder-staging',
        '_push-forwarder-development',
      ]) {
        // snake_case Lambda 함수명
        patterns.add(
          ReplacementPattern(
            RegExp('/aws/lambda/${_escapeRegex(baseSnake)}$suffix'),
            '/aws/lambda/{{project_name.paramCase()}}${suffix.replaceAll('_', '-')}',
          ),
        );
        // param-case Lambda 함수명
        patterns.add(
          ReplacementPattern(
            RegExp('/aws/lambda/${_escapeRegex(baseParam)}$suffix'),
            '/aws/lambda/{{project_name.paramCase()}}${suffix.replaceAll('_', '-')}',
          ),
        );
      }

      // Terraform state 파일 키 패턴
      // key = "blueprint/terraform.tfstate" → key = "{{project_name.paramCase()}}/terraform.tfstate"
      patterns.add(
        ReplacementPattern(
          RegExp('key\\s*=\\s*"${_escapeRegex(baseSnake)}/terraform\\.tfstate"'),
          'key    = "{{project_name.paramCase()}}/terraform.tfstate"',
        ),
      );
      patterns.add(
        ReplacementPattern(
          RegExp('key\\s*=\\s*"${_escapeRegex(baseParam)}/terraform\\.tfstate"'),
          'key    = "{{project_name.paramCase()}}/terraform.tfstate"',
        ),
      );

      // AWS SQS 큐 URL 패턴
      // --queue-url "https://sqs.ap-northeast-2.amazonaws.com/YOUR_ACCOUNT/blueprint_push-queue-production"
      // → --queue-url "https://sqs.ap-northeast-2.amazonaws.com/YOUR_ACCOUNT/{{project_name.paramCase()}}-push-queue-production"
      for (final suffix in [
        '-push-queue-production',
        '-push-queue-staging',
        '-push-queue-development',
        '_push-queue-production',
        '_push-queue-staging',
        '_push-queue-development',
      ]) {
        // snake_case SQS 큐명
        patterns.add(
          ReplacementPattern(
            RegExp('amazonaws\\.com/[^/]+/${_escapeRegex(baseSnake)}$suffix'),
            'amazonaws.com/YOUR_ACCOUNT/{{project_name.paramCase()}}${suffix.replaceAll('_', '-')}',
          ),
        );
        // param-case SQS 큐명
        patterns.add(
          ReplacementPattern(
            RegExp('amazonaws\\.com/[^/]+/${_escapeRegex(baseParam)}$suffix'),
            'amazonaws.com/YOUR_ACCOUNT/{{project_name.paramCase()}}${suffix.replaceAll('_', '-')}',
          ),
        );
      }

      // GitHub Actions workflow 패턴 (deployment-aws.yml)
      // PROJECT_NAME: blueprint → PROJECT_NAME: {{project_name.snakeCase()}}
      // AWS_NAME: blueprint → AWS_NAME: {{project_name.paramCase()}}
      // DEPLOYMENT_BUCKET: blueprint-deployment-XXXXXXX
      //   → DEPLOYMENT_BUCKET: {{project_name.paramCase()}}-deployment-{{randomawsid}}
      // working-directory: backend/blueprint_server
      //   → working-directory: backend/{{project_name.snakeCase()}}_server

      // PROJECT_NAME 환경변수
      patterns.add(
        ReplacementPattern(
          RegExp('PROJECT_NAME:\\s*${_escapeRegex(baseSnake)}\\b'),
          'PROJECT_NAME: {{project_name.snakeCase()}}',
        ),
      );
      patterns.add(
        ReplacementPattern(
          RegExp('PROJECT_NAME:\\s*${_escapeRegex(baseParam)}\\b'),
          'PROJECT_NAME: {{project_name.snakeCase()}}',
        ),
      );

      // AWS_NAME 환경변수
      patterns.add(
        ReplacementPattern(
          RegExp('AWS_NAME:\\s*${_escapeRegex(baseSnake)}\\b'),
          'AWS_NAME: {{project_name.paramCase()}}',
        ),
      );
      patterns.add(
        ReplacementPattern(
          RegExp('AWS_NAME:\\s*${_escapeRegex(baseParam)}\\b'),
          'AWS_NAME: {{project_name.paramCase()}}',
        ),
      );

      // DEPLOYMENT_BUCKET 환경변수 (7자리 랜덤 ID 포함)
      // blueprint-deployment-4546499 → {{project_name.paramCase()}}-deployment-{{randomawsid}}
      patterns.add(
        ReplacementPattern(
          RegExp(
            'DEPLOYMENT_BUCKET:\\s*${_escapeRegex(baseSnake)}-deployment-\\d{7}\\b',
          ),
          'DEPLOYMENT_BUCKET: {{project_name.paramCase()}}-deployment-{{randomawsid}}',
        ),
      );
      patterns.add(
        ReplacementPattern(
          RegExp(
            'DEPLOYMENT_BUCKET:\\s*${_escapeRegex(baseParam)}-deployment-\\d{7}\\b',
          ),
          'DEPLOYMENT_BUCKET: {{project_name.paramCase()}}-deployment-{{randomawsid}}',
        ),
      );

      // working-directory 패턴 (GitHub Actions)
      // working-directory: backend/blueprint_server
      for (final suffix in ['_server', '_client']) {
        patterns.add(
          ReplacementPattern(
            RegExp(
              'working-directory:\\s*backend/${_escapeRegex(baseSnake)}$suffix\\b',
            ),
            'working-directory: backend/{{project_name.snakeCase()}}$suffix',
          ),
        );
      }

      // pubspec_overrides.yaml 경로 패턴 (GitHub Actions)
      // backend/blueprint_server/pubspec_overrides.yaml
      for (final suffix in ['_server', '_client']) {
        patterns.add(
          ReplacementPattern(
            RegExp(
              'backend/${_escapeRegex(baseSnake)}$suffix/pubspec_overrides\\.yaml',
            ),
            'backend/{{project_name.snakeCase()}}$suffix/pubspec_overrides.yaml',
          ),
        );
      }

      // URL 경로 패턴 (https://.../.well-known/)
      // https://blueprint.im/.well-known/ → https://{{project_name.paramCase()}}.{{org_tld}}/.well-known/
      for (final orgTld in orgTlds) {
        patterns.add(
          ReplacementPattern(
            RegExp('https://${_escapeRegex(baseSnake)}\\.${_escapeRegex(orgTld)}/\\.well-known/'),
            'https://{{project_name.paramCase()}}.{{org_tld}}/.well-known/',
          ),
        );
        patterns.add(
          ReplacementPattern(
            RegExp('https://${_escapeRegex(baseParam)}\\.${_escapeRegex(orgTld)}/\\.well-known/'),
            'https://{{project_name.paramCase()}}.{{org_tld}}/.well-known/',
          ),
        );
        patterns.add(
          ReplacementPattern(
            RegExp('https://${_escapeRegex(baseDot)}\\.${_escapeRegex(orgTld)}/\\.well-known/'),
            'https://{{project_name.paramCase()}}.{{org_tld}}/.well-known/',
          ),
        );
      }

      // database name 패턴 (_test → -test, _dev → -dev 등)
      for (final suffix in [
        '_test',
        '_dev',
        '_development',
        '_staging',
        '_prod',
        '_production',
      ]) {
        final paramSuffix = suffix.replaceAll('_', '-');
        patterns.add(
          ReplacementPattern(
            RegExp('name:\\s*${_escapeRegex(baseSnake)}$suffix\\b'),
            'name: {{project_name.paramCase()}}$paramSuffix',
          ),
        );
        patterns.add(
          ReplacementPattern(
            RegExp('name:\\s*${_escapeRegex(baseParam)}$paramSuffix\\b'),
            'name: {{project_name.paramCase()}}$paramSuffix',
          ),
        );
      }

      // Docker volume 이름 패턴 (docker-compose.yaml)
      // blueprint_data: → {{project_name.snakeCase()}}_data:
      // blueprint_test_data: → {{project_name.snakeCase()}}_test_data:
      for (final suffix in ['_data', '_test_data']) {
        // volume 선언 (key:)
        patterns.add(
          ReplacementPattern(
            RegExp('\\b${_escapeRegex(baseSnake)}$suffix:'),
            '{{project_name.snakeCase()}}$suffix:',
          ),
        );
        // volume 참조 (- name:path 형태)
        patterns.add(
          ReplacementPattern(
            RegExp('\\b${_escapeRegex(baseSnake)}$suffix\\b'),
            '{{project_name.snakeCase()}}$suffix',
          ),
        );
      }

      // POSTGRES_DB 환경변수 패턴 (docker-compose.yaml)
      // POSTGRES_DB: blueprint → POSTGRES_DB: {{project_name.paramCase()}}
      // POSTGRES_DB: blueprint_test → POSTGRES_DB: {{project_name.paramCase()}}-test
      patterns.add(
        ReplacementPattern(
          RegExp('POSTGRES_DB:\\s*${_escapeRegex(baseSnake)}\\b'),
          'POSTGRES_DB: {{project_name.paramCase()}}',
        ),
      );
      patterns.add(
        ReplacementPattern(
          RegExp('POSTGRES_DB:\\s*${_escapeRegex(baseParam)}\\b'),
          'POSTGRES_DB: {{project_name.paramCase()}}',
        ),
      );
      for (final suffix in ['_test', '_dev', '_staging', '_prod']) {
        final paramSuffix = suffix.replaceAll('_', '-');
        patterns.add(
          ReplacementPattern(
            RegExp('POSTGRES_DB:\\s*${_escapeRegex(baseSnake)}$suffix\\b'),
            'POSTGRES_DB: {{project_name.paramCase()}}$paramSuffix',
          ),
        );
      }

      // URL scheme 패턴 (strings.xml)
      // devblueprint → dev{{project_name.snakeCase()}}
      // stgblueprint → stg{{project_name.snakeCase()}}
      // blueprint (scheme) → {{project_name.snakeCase()}}
      for (final prefix in ['dev', 'stg', 'staging', 'prod']) {
        // devblueprint, stgblueprint 등
        patterns.add(
          ReplacementPattern(
            RegExp('\\b$prefix${_escapeRegex(baseSnake)}\\b'),
            '$prefix{{project_name.snakeCase()}}',
          ),
        );
        // 파스칼케이스: devBlueprint, stgBlueprint 등
        patterns.add(
          ReplacementPattern(
            RegExp('\\b$prefix${_escapeRegex(basePascal)}\\b'),
            '$prefix{{project_name.snakeCase()}}',
          ),
        );
      }

      // macOS xcconfig 패턴 (AppInfo.xcconfig)
      // PRODUCT_NAME = blueprint_widgetbook
      // → PRODUCT_NAME = {{project_name.snakeCase()}}_widgetbook
      for (final suffix in ['_widgetbook', '_console', '_server', '_client']) {
        patterns.add(
          ReplacementPattern(
            RegExp('PRODUCT_NAME\\s*=\\s*${_escapeRegex(baseSnake)}$suffix\\b'),
            'PRODUCT_NAME = {{project_name.snakeCase()}}$suffix',
          ),
        );
      }
      // PRODUCT_NAME 단독 (suffix 없는 경우)
      patterns.add(
        ReplacementPattern(
          RegExp('PRODUCT_NAME\\s*=\\s*${_escapeRegex(baseSnake)}\\b'),
          'PRODUCT_NAME = {{project_name.snakeCase()}}',
        ),
      );

      // macOS PRODUCT_BUNDLE_IDENTIFIER 패턴 (AppInfo.xcconfig)
      // PRODUCT_BUNDLE_IDENTIFIER = im.cocode.blueprint.widgetbook.blueprintWidgetbook
      // → PRODUCT_BUNDLE_IDENTIFIER = {{org_tld}}.{{org_name.lowerCase()}}.{{project_name.snakeCase()}}.suffix.{{project_name.camelCase()}}Suffix
      for (final suffix in ['widgetbook', 'console']) {
        final suffixPascal = suffix[0].toUpperCase() + suffix.substring(1);
        for (final orgTld in orgTlds) {
          for (final orgName in orgNames) {
            final orgLower = orgName.toLowerCase();
            // blueprintWidgetbook 형태 (camelCase + suffix)
            final baseCamel = words.isEmpty
                ? baseSnake.toLowerCase()
                : words[0].toLowerCase() +
                    words
                        .sublist(1)
                        .map(
                          (word) => word.isEmpty
                              ? ''
                              : word[0].toUpperCase() +
                                  word.substring(1).toLowerCase(),
                        )
                        .join();

            patterns.add(
              ReplacementPattern(
                RegExp(
                  'PRODUCT_BUNDLE_IDENTIFIER\\s*=\\s*'
                  '${_escapeRegex(orgTld)}\\.'
                  '${_escapeRegex(orgLower)}\\.'
                  '${_escapeRegex(baseSnake)}\\.'
                  '$suffix\\.'
                  '${_escapeRegex(baseCamel)}$suffixPascal\\b',
                ),
                'PRODUCT_BUNDLE_IDENTIFIER = '
                '{{org_tld}}.{{org_name.lowerCase()}}.{{project_name.snakeCase()}}.$suffix.'
                '{{project_name.camelCase()}}$suffixPascal',
              ),
            );
          }
        }
      }

      // macOS PRODUCT_COPYRIGHT 패턴 (AppInfo.xcconfig)
      // PRODUCT_COPYRIGHT = Copyright © 2025 im.cocode.blueprint.widgetbook. All rights reserved.
      // → PRODUCT_COPYRIGHT = Copyright © 2025 {{org_tld}}.{{org_name.lowerCase()}}.{{project_name.snakeCase()}}.suffix. All rights reserved.
      for (final suffix in ['widgetbook', 'console']) {
        for (final orgTld in orgTlds) {
          for (final orgName in orgNames) {
            final orgLower = orgName.toLowerCase();
            patterns.add(
              ReplacementPattern(
                RegExp(
                  'PRODUCT_COPYRIGHT\\s*=\\s*Copyright © \\d{4} '
                  '${_escapeRegex(orgTld)}\\.'
                  '${_escapeRegex(orgLower)}\\.'
                  '${_escapeRegex(baseSnake)}\\.'
                  '$suffix\\. All rights reserved\\.',
                ),
                'PRODUCT_COPYRIGHT = Copyright © {{current_year}} '
                '{{org_tld}}.{{org_name.lowerCase()}}.{{project_name.snakeCase()}}.$suffix. '
                'All rights reserved.',
              ),
            );
          }
        }
      }

      // HTML title/description 패턴 (web/index.html)
      // <title>Blueprint</title> → <title>{{project_name.titleCase()}}</title>
      // content="Blueprint Service"
      // → content="{{project_name.titleCase()}} Service"
      patterns.add(
        ReplacementPattern(
          RegExp('<title>${_escapeRegex(basePascal)}</title>'),
          '<title>{{project_name.titleCase()}}</title>',
        ),
      );
      patterns.add(
        ReplacementPattern(
          RegExp('<title>${_escapeRegex(baseTitle)}</title>'),
          '<title>{{project_name.titleCase()}}</title>',
        ),
      );
      // meta content 패턴
      patterns.add(
        ReplacementPattern(
          RegExp('content="${_escapeRegex(basePascal)} Service"'),
          'content="{{project_name.titleCase()}} Service"',
        ),
      );
      patterns.add(
        ReplacementPattern(
          RegExp('content="${_escapeRegex(baseTitle)} Service"'),
          'content="{{project_name.titleCase()}} Service"',
        ),
      );
      // apple-mobile-web-app-title 패턴
      patterns.add(
        ReplacementPattern(
          RegExp('content="${_escapeRegex(basePascal)}"'),
          'content="{{project_name.titleCase()}}"',
        ),
      );
      patterns.add(
        ReplacementPattern(
          RegExp('content="${_escapeRegex(baseTitle)}"'),
          'content="{{project_name.titleCase()}}"',
        ),
      );

      // Android manifestPlaceholders 앱 이름 패턴
      // manifestPlaceholders["appName"] = "Blueprint"
      // → manifestPlaceholders["appName"] = "{{project_name.titleCase()}}"
      patterns.add(
        ReplacementPattern(
          RegExp(
            'manifestPlaceholders\\["appName"\\]\\s*=\\s*"${_escapeRegex(basePascal)}"',
          ),
          'manifestPlaceholders["appName"] = "{{project_name.titleCase()}}"',
        ),
      );
      patterns.add(
        ReplacementPattern(
          RegExp(
            'manifestPlaceholders\\["appName"\\]\\s*=\\s*"${_escapeRegex(baseTitle)}"',
          ),
          'manifestPlaceholders["appName"] = "{{project_name.titleCase()}}"',
        ),
      );

      // Android Fastlane $app_name 패턴
      // $app_name = "Blueprint" → $app_name = "{{project_name.titleCase()}}"
      patterns.add(
        ReplacementPattern(
          RegExp(r'\$app_name\s*=\s*"' + _escapeRegex(basePascal) + '"'),
          r'$app_name = "{{project_name.titleCase()}}"',
        ),
      );
      patterns.add(
        ReplacementPattern(
          RegExp(r'\$app_name\s*=\s*"' + _escapeRegex(baseTitle) + '"'),
          r'$app_name = "{{project_name.titleCase()}}"',
        ),
      );

      // Widgetbook build.yaml name 패턴
      // name: "Blueprint Widgetbook" → name: "{{project_name.titleCase()}} Widgetbook"
      patterns.add(
        ReplacementPattern(
          RegExp('name:\\s*"${_escapeRegex(basePascal)} Widgetbook"'),
          'name: "{{project_name.titleCase()}} Widgetbook"',
        ),
      );
      patterns.add(
        ReplacementPattern(
          RegExp('name:\\s*"${_escapeRegex(baseTitle)} Widgetbook"'),
          'name: "{{project_name.titleCase()}} Widgetbook"',
        ),
      );

      // Android strings.xml appName 패턴
      // <string name="appName">Blueprint</string>
      // → <string name="appName">{{project_name.titleCase()}}</string>
      patterns.add(
        ReplacementPattern(
          RegExp(
            '<string name="appName">${_escapeRegex(basePascal)}</string>',
          ),
          '<string name="appName">{{project_name.titleCase()}}</string>',
        ),
      );
      patterns.add(
        ReplacementPattern(
          RegExp(
            '<string name="appName">${_escapeRegex(baseTitle)}</string>',
          ),
          '<string name="appName">{{project_name.titleCase()}}</string>',
        ),
      );
      // app_name 패턴
      patterns.add(
        ReplacementPattern(
          RegExp(
            '<string name="app_name">${_escapeRegex(basePascal)}</string>',
          ),
          '<string name="app_name">{{project_name.titleCase()}}</string>',
        ),
      );
      patterns.add(
        ReplacementPattern(
          RegExp(
            '<string name="app_name">${_escapeRegex(baseTitle)}</string>',
          ),
          '<string name="app_name">{{project_name.titleCase()}}</string>',
        ),
      );

      // Android Keystore alias 패턴
      // -alias blueprint → -alias {{project_name.snakeCase()}}
      patterns.add(
        ReplacementPattern(
          RegExp('-alias ${_escapeRegex(baseSnake)}\\b'),
          '-alias {{project_name.snakeCase()}}',
        ),
      );
      patterns.add(
        ReplacementPattern(
          RegExp('-alias ${_escapeRegex(baseParam)}\\b'),
          '-alias {{project_name.snakeCase()}}',
        ),
      );
      // keyAlias=blueprint → keyAlias={{project_name.snakeCase()}}
      patterns.add(
        ReplacementPattern(
          RegExp('keyAlias=${_escapeRegex(baseSnake)}\\b'),
          'keyAlias={{project_name.snakeCase()}}',
        ),
      );
      patterns.add(
        ReplacementPattern(
          RegExp('keyAlias=${_escapeRegex(baseParam)}\\b'),
          'keyAlias={{project_name.snakeCase()}}',
        ),
      );

      // Golden test configuration comment 패턴
      // /// Golden test configuration for Blueprint Widgetbook
      // → /// Golden test configuration for {{project_name.titleCase()}} Widgetbook
      patterns.add(
        ReplacementPattern(
          RegExp(
            'Golden test configuration for ${_escapeRegex(basePascal)} Widgetbook',
          ),
          'Golden test configuration for {{project_name.titleCase()}} Widgetbook',
        ),
      );
      patterns.add(
        ReplacementPattern(
          RegExp(
            'Golden test configuration for ${_escapeRegex(baseTitle)} Widgetbook',
          ),
          'Golden test configuration for {{project_name.titleCase()}} Widgetbook',
        ),
      );

      // Firebase buildConfigurations 경로 패턴
      // "blueprint/android/app/src/development" → "{{project_name.snakeCase()}}/android/app/src/development"
      for (final env in ['development', 'staging', 'production']) {
        patterns.add(
          ReplacementPattern(
            RegExp('"${_escapeRegex(baseSnake)}/android/app/src/$env"'),
            '"{{project_name.snakeCase()}}/android/app/src/$env"',
          ),
        );
        patterns.add(
          ReplacementPattern(
            RegExp('"${_escapeRegex(baseParam)}/android/app/src/$env"'),
            '"{{project_name.snakeCase()}}/android/app/src/$env"',
          ),
        );
      }

      // Kotlin package 문 패턴 (MainActivity.kt)
      // package im.cocode.blueprint.widgetbook.k9rm
      // → package {{org_tld}}.{{org_name}}.{{project_name.snakeCase()}}.suffix.{{randomprojectid}}
      // 이 패턴은 _buildFirebasePatterns에서 처리됨

      // 복합 이름 패턴 - Dart 모듈명 (snakeCase 유지)
      for (final suffix in [
        '_http_module',
        '_service_module',
        '_service',
        '_module',
      ]) {
        patterns.add(
          ReplacementPattern(
            RegExp('\\b${_escapeRegex(baseSnake)}$suffix\\b'),
            '{{project_name.snakeCase()}}$suffix',
          ),
        );
      }

      // 일반 경로 패턴: 슬래시(/)가 있는 경로는 기본적으로 snakeCase 사용
      // (Dart/Flutter lib/, bin/, test/ 등의 표준 경로)
      // URL을 제외하기 위해 (?<!/) negative lookbehind 추가 (URL은 // 형태)
      patterns.addAll([
        // /projectName/ 패턴 (양쪽에 슬래시, URL의 // 제외)
        ReplacementPattern(
          RegExp('(?<!/)/${_escapeRegex(baseSnake)}/'),
          '/{{project_name.snakeCase()}}/',
        ),
        // /projectName (왼쪽에만 슬래시, 오른쪽은 단어 경계, URL의 // 제외)
        ReplacementPattern(
          RegExp('(?<!/)/${_escapeRegex(baseSnake)}\\b'),
          '/{{project_name.snakeCase()}}',
        ),
        // projectName/ 패턴 (오른쪽에만 슬래시, 왼쪽은 단어 경계)
        ReplacementPattern(
          RegExp('\\b${_escapeRegex(baseSnake)}/'),
          '{{project_name.snakeCase()}}/',
        ),
      ]);

      // 하이픈(-) 패턴: paramCase 사용 (점 패턴보다 먼저 - 더 일반적)
      // URL 컨텍스트를 먼저 처리 (https://, http://, s3:// 등)
      patterns.addAll([
        // URL에서 project-name- 패턴 (예: https://blueprint-private-storage)
        // (?<=://) - positive lookbehind for ://
        // (?:[^/]*\\.)? - optional subdomain with dot
        ReplacementPattern(
          RegExp('(?<=://)(?:[^/]*\\.)?${_escapeRegex(baseParam)}-'),
          '{{project_name.paramCase()}}-',
        ),
        // 일반 하이픈 패턴들
        ReplacementPattern(
          RegExp('-${_escapeRegex(baseParam)}-'),
          '-{{project_name.paramCase()}}-',
        ),
        ReplacementPattern(
          RegExp('(?<!_)(?<!/)\\b${_escapeRegex(baseParam)}-'),
          '{{project_name.paramCase()}}-',
        ),
        ReplacementPattern(
          RegExp('-${_escapeRegex(baseParam)}\\b(?!_)(?!/)'),
          '-{{project_name.paramCase()}}',
        ),
        // 단독 패턴: 밑줄, 점, 슬래시가 전후에 없는 경우 (기본값)
        ReplacementPattern(
          RegExp(
            '(?<!_)(?<!\\.)(?<!/)\\b${_escapeRegex(baseParam)}\\b(?!_)(?!\\.)(?!/)',
          ),
          '{{project_name.paramCase()}}',
        ),
      ]);

      // Serverpod 설정 파일의 호스트명 패턴 (dotCase보다 먼저!)
      // publicHost: api-staging.blueprint. → publicHost: api-staging.{{project_name.paramCase()}}.
      // host: database.private-staging.blueprint. → host: database.private-staging.{{project_name.paramCase()}}.
      // publicHost: api.blueprint. → publicHost: api.{{project_name.paramCase()}}.
      // # comment: database.blueprint.. → # comment: database.{{project_name.paramCase()}}..
      for (final prefix in [
        'api-staging',
        'api-production',
        'insights-staging',
        'insights-production',
        'app-staging',
        'app-production',
        'database.private-staging',
        'database.private-production',
        'redis.private-staging',
        'redis.private-production',
        'database-staging',
        'database-production',
        'redis-staging',
        'redis-production',
        'api',        // production: api.blueprint.
        'insights',   // production: insights.blueprint.
        'app',        // production: app.blueprint.
        'database',   // comment example: database.blueprint..
        'redis',      // comment example: redis.blueprint..
      ]) {
        // snake_case 호스트명
        patterns.add(
          ReplacementPattern(
            RegExp('$prefix\\.${_escapeRegex(baseSnake)}\\.'),
            '$prefix.{{project_name.paramCase()}}.',
          ),
        );
        // param-case 호스트명
        patterns.add(
          ReplacementPattern(
            RegExp('$prefix\\.${_escapeRegex(baseParam)}\\.'),
            '$prefix.{{project_name.paramCase()}}.',
          ),
        );
        // dot.case 호스트명
        patterns.add(
          ReplacementPattern(
            RegExp('$prefix\\.${_escapeRegex(baseDot)}\\.'),
            '$prefix.{{project_name.paramCase()}}.',
          ),
        );
      }

      // 점(.) 패턴: dotCase 사용 (실제로 점이 포함된 경우만)
      // 주의: 양쪽에 점이 있거나 한쪽에 점이 있는 구체적인 경우만 매칭
      patterns.addAll([
        ReplacementPattern(
          RegExp('\\.${_escapeRegex(baseDot)}\\.'),
          '.{{project_name.dotCase()}}.',
        ),
        ReplacementPattern(
          RegExp('(?<!_)\\b${_escapeRegex(baseDot)}\\.'),
          '{{project_name.dotCase()}}.',
        ),
        ReplacementPattern(
          RegExp('\\.${_escapeRegex(baseDot)}\\b(?!_)'),
          '.{{project_name.dotCase()}}',
        ),
      ]);

      // Title case 패턴
      // 주의: 밑줄(_)과 점(.)으로 둘러싸이지 않은 경우만 매칭 (snakeCase, dotCase와 구분)
      patterns.addAll([
        ReplacementPattern(
          RegExp('(?<!_)(?<!\\.)\\b${_escapeRegex(baseTitle)}\\b(?!_)(?!\\.)'),
          '{{project_name.titleCase()}}',
        ),
        ReplacementPattern(
          RegExp('`${_escapeRegex(baseTitle)}`'),
          '`{{project_name.titleCase()}}`',
        ),
      ]);

      // 따옴표 안의 패턴 (paramCase를 기본값으로 우선)
      patterns.addAll([
        ReplacementPattern(
          RegExp('"${_escapeRegex(baseParam)}"'),
          '"{{project_name.paramCase()}}"',
        ),
        ReplacementPattern(
          RegExp("'${_escapeRegex(baseParam)}'"),
          "'{{project_name.paramCase()}}'",
        ),
        ReplacementPattern(
          RegExp('"${_escapeRegex(baseDot)}"'),
          '"{{project_name.dotCase()}}"',
        ),
        ReplacementPattern(
          RegExp("'${_escapeRegex(baseDot)}'"),
          "'{{project_name.dotCase()}}'",
        ),
        ReplacementPattern(
          RegExp('"${_escapeRegex(baseSnake)}"'),
          '"{{project_name.snakeCase()}}"',
        ),
        ReplacementPattern(
          RegExp("'${_escapeRegex(baseSnake)}'"),
          "'{{project_name.snakeCase()}}'",
        ),
        ReplacementPattern(
          RegExp('"${_escapeRegex(baseTitle)}"'),
          '"{{project_name.titleCase()}}"',
        ),
        ReplacementPattern(
          RegExp("'${_escapeRegex(baseTitle)}'"),
          "'{{project_name.titleCase()}}'",
        ),
      ]);

      // 기본 snake_case 패턴 (마지막에 처리)
      // Serverpod 관련 클래스명을 제외하기 위한 negative lookahead 추가
      // 하이픈(-)이 뒤따르는 경우도 제외 (paramCase 패턴이 처리해야 함)
      patterns.addAll([
        ReplacementPattern(
          RegExp(
            '(?<!Servo)\\b${_escapeRegex(baseSnake)}\\b(?!Service|Client|pod|-)',
          ),
          '{{project_name.snakeCase()}}',
        ),
        ReplacementPattern(
          RegExp(
            '(?<!Servo)\\b${_escapeRegex(baseSnake.replaceAll("_", ""))}\\b(?!Service|Client|pod|-)',
          ),
          '{{project_name.snakeCase()}}',
        ),
      ]);
    }

    return patterns;
  }

  /// 조직명 패턴 생성
  static List<ReplacementPattern> _buildOrgPatterns(List<String> orgNames) {
    final patterns = <ReplacementPattern>[];

    for (final orgName in orgNames) {
      final orgLower = orgName.toLowerCase();
      final orgTitle = orgName
          .split('_')
          .map((word) => word[0].toUpperCase() + word.substring(1))
          .join(' ');
      // camelCase: cocode → cocode (첫 글자 소문자)
      final orgCamel = orgLower;
      // PascalCase: cocode → Cocode (첫 글자 대문자)
      final orgPascal = orgLower[0].toUpperCase() + orgLower.substring(1);

      patterns.addAll([
        // 비밀번호 패턴: cocode1477! → {{org_name.lowerCase()}}1477!
        ReplacementPattern(
          RegExp('${_escapeRegex(orgLower)}1477!'),
          '{{org_name.lowerCase()}}1477!',
        ),
        // 변수명 패턴 (camelCase): cocodeUserInfos → scopedUserInfos
        // 이 패턴은 특정 변수명을 일반화된 이름으로 변환
        ReplacementPattern(
          RegExp('${_escapeRegex(orgCamel)}UserInfos'),
          'scopedUserInfos',
        ),
        ReplacementPattern(
          RegExp('${_escapeRegex(orgCamel)}UserInfo'),
          'scopedUserInfo',
        ),
        // 하이픈(-) 패턴: lowerCase 사용
        ReplacementPattern(
          RegExp('-${_escapeRegex(orgLower)}-'),
          '-{{org_name.lowerCase()}}-',
        ),
        ReplacementPattern(
          RegExp('\\b${_escapeRegex(orgLower)}-'),
          '{{org_name.lowerCase()}}-',
        ),
        ReplacementPattern(
          RegExp('-${_escapeRegex(orgLower)}\\b'),
          '-{{org_name.lowerCase()}}',
        ),
        // 점(.) 패턴: dotCase 사용
        ReplacementPattern(
          RegExp('\\.${_escapeRegex(orgLower)}\\.'),
          '.{{org_name.dotCase()}}.',
        ),
        ReplacementPattern(
          RegExp('\\b${_escapeRegex(orgLower)}\\.'),
          '{{org_name.dotCase()}}.',
        ),
        ReplacementPattern(
          RegExp('\\.${_escapeRegex(orgLower)}\\b'),
          '.{{org_name.dotCase()}}',
        ),
        // PascalCase 패턴: Cocode → {{org_name.pascalCase()}}
        ReplacementPattern(
          RegExp('\\b${_escapeRegex(orgPascal)}\\b'),
          '{{org_name.pascalCase()}}',
        ),
        // 타이틀 케이스
        ReplacementPattern(
          RegExp('\\b${_escapeRegex(orgTitle)}\\b'),
          '{{org_name.titleCase()}}',
        ),
        // 단독 패턴 (마지막에 처리)
        ReplacementPattern(
          RegExp('\\b${_escapeRegex(orgLower)}\\b'),
          '{{org_name.lowerCase()}}',
        ),
      ]);
    }

    return patterns;
  }

  /// 케이스 변환 패턴 생성 (Mason 케이스 변환 함수 참고)
  static List<ReplacementPattern> _buildCasePatterns(
    List<String> projectNames,
  ) {
    final patterns = <ReplacementPattern>[];

    for (final baseName in projectNames) {
      final words = baseName.split('_');

      // Mason 케이스 변환 함수에 맞춘 변환
      // snakeCase: hello_world
      final baseSnake = baseName;

      // camelCase: helloWorld (첫 단어 소문자, 나머지 첫 글자 대문자)
      final baseCamel = words.isEmpty
          ? baseName.toLowerCase()
          : words[0].toLowerCase() +
                words
                    .sublist(1)
                    .map(
                      (word) => word.isEmpty
                          ? ''
                          : word[0].toUpperCase() +
                                word.substring(1).toLowerCase(),
                    )
                    .join();

      // pascalCase: HelloWorld (모든 단어 첫 글자 대문자)
      final basePascal = words
          .map(
            (word) => word.isEmpty
                ? ''
                : word[0].toUpperCase() + word.substring(1).toLowerCase(),
          )
          .join();

      // titleCase: Hello World (모든 단어 첫 글자 대문자, 공백으로 구분)
      final baseTitle = words
          .map(
            (word) => word.isEmpty
                ? ''
                : word[0].toUpperCase() + word.substring(1).toLowerCase(),
          )
          .join(' ');

      // paramCase: hello-world (소문자, 하이픈으로 구분)
      final baseParam = words.map((word) => word.toLowerCase()).join('-');

      // dotCase: hello.world (소문자, 점으로 구분)
      final baseDot = words.map((word) => word.toLowerCase()).join('.');

      // constantCase: HELLO_WORLD (대문자, 언더스코어로 구분)
      final baseConstant = baseName.toUpperCase();

      // upperCase: HELLO WORLD (대문자, 공백으로 구분)
      final baseUpper = words.map((word) => word.toUpperCase()).join(' ');

      // lowerCase: hello world (소문자, 공백으로 구분)
      final baseLower = words.map((word) => word.toLowerCase()).join(' ');

      // Mason 케이스 변환 함수에 맞춘 패턴 생성
      // 패턴 순서: 더 구체적인 패턴부터 일반적인 패턴 순서로

      // -1. URL 컨텍스트 패턴 (최우선 처리 - :// 포함된 URL에서는 무조건 paramCase)
      // URL 스킴 (https://, http://, s3://, gs:// 등) 뒤에 오는 프로젝트명은 paramCase 사용
      // 다양한 케이스 변형 모두 처리: Blueprint, blueprint, blueprint-xxx 등

      // URL에서 PascalCase 프로젝트명 (예: https://blueprint-storage.s3.amazonaws.com)
      patterns.add(
        ReplacementPattern(
          RegExp('(?<=://)([^/]*\\.)?${_escapeRegex(basePascal)}'),
          '{{project_name.paramCase()}}',
        ),
      );

      // URL에서 snake_case 프로젝트명 (예: https://blueprint_storage.s3.amazonaws.com)
      patterns.add(
        ReplacementPattern(
          RegExp('(?<=://)([^/]*\\.)?${_escapeRegex(baseSnake)}'),
          '{{project_name.paramCase()}}',
        ),
      );

      // URL에서 param-case 프로젝트명 (예: https://blueprint-storage.s3.amazonaws.com)
      patterns.add(
        ReplacementPattern(
          RegExp('(?<=://)([^/]*\\.)?${_escapeRegex(baseParam)}'),
          '{{project_name.paramCase()}}',
        ),
      );

      // URL에서 dot.case 프로젝트명 (예: https://blueprint.storage.s3.amazonaws.com)
      patterns.add(
        ReplacementPattern(
          RegExp('(?<=://)([^/]*\\.)?${_escapeRegex(baseDot)}'),
          '{{project_name.paramCase()}}',
        ),
      );

      // 0. Title case 컨텍스트 패턴 (가장 먼저 처리 - PascalCase보다 우선)
      // JSON/텍스트 파일에서 자연어 맥락으로 사용되는 경우를 먼저 매칭
      // 구두점(마침표, 쉼표, 느낌표, 물음표, 세미콜론, 콜론) 뒤에 오는 경우 titleCase 유지

      // Markdown 헤더 패턴 (# 뒤에 오는 프로젝트명은 titleCase로 표시)
      // # project_name → # {{project_name.titleCase()}}
      patterns.add(
        ReplacementPattern(
          RegExp('^#+ ${_escapeRegex(baseSnake)}', multiLine: true),
          '# {{project_name.titleCase()}}',
        ),
      );
      // # Project Name (이미 titleCase인 경우)
      patterns.add(
        ReplacementPattern(
          RegExp('^#+ ${_escapeRegex(baseTitle)}', multiLine: true),
          '# {{project_name.titleCase()}}',
        ),
      );

      // 문장 끝 구두점 패턴 (., !, ?, ;, :)
      for (final punctuation in ['.', '!', '?', ';', ':']) {
        patterns.add(
          ReplacementPattern(
            RegExp('${_escapeRegex(baseTitle)}${_escapeRegex(punctuation)}'),
            '{{project_name.titleCase()}}$punctuation',
          ),
        );
      }

      // 쉼표 뒤 공백 패턴
      patterns.add(
        ReplacementPattern(
          RegExp('${_escapeRegex(baseTitle)}, '),
          '{{project_name.titleCase()}}, ',
        ),
      );

      // 따옴표로 감싸진 패턴 (JSON 문자열 값)
      // "ProjectName" or 'ProjectName'
      patterns.add(
        ReplacementPattern(
          RegExp('"${_escapeRegex(baseTitle)}"'),
          '"{{project_name.titleCase()}}"',
        ),
      );
      patterns.add(
        ReplacementPattern(
          RegExp("'${_escapeRegex(baseTitle)}'"),
          "'{{project_name.titleCase()}}'",
        ),
      );

      // JSON key-value 패턴: "key": "ProjectName"
      patterns.add(
        ReplacementPattern(
          RegExp(': "${_escapeRegex(baseTitle)}"'),
          ': "{{project_name.titleCase()}}"',
        ),
      );

      // 문서 주석 특수 패턴들
      patterns.add(
        ReplacementPattern(
          RegExp('for ${_escapeRegex(baseTitle)}\\.'),
          'for {{project_name.titleCase()}}.',
        ),
      );
      patterns.add(
        ReplacementPattern(
          RegExp('the ${_escapeRegex(baseTitle)}'),
          'the {{project_name.titleCase()}}',
        ),
      );
      patterns.add(
        ReplacementPattern(
          RegExp('of ${_escapeRegex(baseTitle)}'),
          'of {{project_name.titleCase()}}',
        ),
      );

      // Fastfile $app_name 패턴 (Ruby 변수 할당)
      // $app_name = "Blueprint" → $app_name = "{{project_name.titleCase()}}"
      patterns.add(
        ReplacementPattern(
          RegExp(r'\$app_name\s*=\s*"' '${_escapeRegex(basePascal)}"'),
          r'$app_name = "{{project_name.titleCase()}}"',
        ),
      );
      patterns.add(
        ReplacementPattern(
          RegExp(r'\$app_name\s*=\s*"' '${_escapeRegex(baseTitle)}"'),
          r'$app_name = "{{project_name.titleCase()}}"',
        ),
      );

      // HTML title 태그 패턴
      // <title>Blueprint</title> → <title>{{project_name.titleCase()}}</title>
      patterns.add(
        ReplacementPattern(
          RegExp('<title>${_escapeRegex(basePascal)}</title>'),
          '<title>{{project_name.titleCase()}}</title>',
        ),
      );
      patterns.add(
        ReplacementPattern(
          RegExp('<title>${_escapeRegex(baseTitle)}</title>'),
          '<title>{{project_name.titleCase()}}</title>',
        ),
      );

      // HTML meta description 패턴
      // content="Blueprint Service" → content="{{project_name.titleCase()}} Service"
      patterns.add(
        ReplacementPattern(
          RegExp('content="${_escapeRegex(basePascal)} Service"'),
          'content="{{project_name.titleCase()}} Service"',
        ),
      );
      patterns.add(
        ReplacementPattern(
          RegExp('content="${_escapeRegex(baseTitle)} Service"'),
          'content="{{project_name.titleCase()}} Service"',
        ),
      );

      // HTML apple-mobile-web-app-title 패턴
      // content="Blueprint" (apple-mobile-web-app-title에서 사용)
      patterns.add(
        ReplacementPattern(
          RegExp(
            '(apple-mobile-web-app-title"\\s*content=")${_escapeRegex(basePascal)}"',
          ),
          r'$1{{project_name.titleCase()}}"',
        ),
      );
      patterns.add(
        ReplacementPattern(
          RegExp(
            '(apple-mobile-web-app-title"\\s*content=")${_escapeRegex(baseTitle)}"',
          ),
          r'$1{{project_name.titleCase()}}"',
        ),
      );

      // build.yaml name 패턴 (Widgetbook)
      // name: "Blueprint Widgetbook" → name: "{{project_name.titleCase()}} Widgetbook"
      patterns.add(
        ReplacementPattern(
          RegExp('name:\\s*"${_escapeRegex(basePascal)} Widgetbook"'),
          'name: "{{project_name.titleCase()}} Widgetbook"',
        ),
      );
      patterns.add(
        ReplacementPattern(
          RegExp('name:\\s*"${_escapeRegex(baseTitle)} Widgetbook"'),
          'name: "{{project_name.titleCase()}} Widgetbook"',
        ),
      );

      // Golden test helper 주석 패턴
      // "Blueprint Widgetbook" → "{{project_name.titleCase()}} Widgetbook"
      patterns.add(
        ReplacementPattern(
          RegExp('${_escapeRegex(basePascal)} Widgetbook'),
          '{{project_name.titleCase()}} Widgetbook',
        ),
      );
      patterns.add(
        ReplacementPattern(
          RegExp('${_escapeRegex(baseTitle)} Widgetbook'),
          '{{project_name.titleCase()}} Widgetbook',
        ),
      );

      // Markdown description 패턴 (privacy.md, terms.md)
      // "BlueprintBook" → "{{project_name.pascalCase()}}Book"
      patterns.add(
        ReplacementPattern(
          RegExp('${_escapeRegex(basePascal)}Book'),
          '{{project_name.pascalCase()}}Book',
        ),
      );

      // 커밋 메시지 규칙 설명 패턴
      // "Blueprint 커밋 메시지 규칙" → "{{project_name.titleCase()}} 커밋 메시지 규칙"
      patterns.add(
        ReplacementPattern(
          RegExp('${_escapeRegex(basePascal)} 커밋'),
          '{{project_name.titleCase()}} 커밋',
        ),
      );
      patterns.add(
        ReplacementPattern(
          RegExp('${_escapeRegex(baseTitle)} 커밋'),
          '{{project_name.titleCase()}} 커밋',
        ),
      );

      // Terraform S3 버킷 이름 패턴
      // blueprint-public-storage-prod-4546499
      // → {{project_name.paramCase()}}-public-storage-prod-{{randomawsid}}
      for (final access in ['public', 'private']) {
        for (final env in ['prod', 'staging', 'dev']) {
          patterns.add(
            ReplacementPattern(
              RegExp(
                '${_escapeRegex(baseParam)}-$access-storage-$env-(\\d{6,8})',
              ),
              '{{project_name.paramCase()}}-$access-storage-$env-{{randomawsid}}',
            ),
          );
        }
      }

      // Terraform Route53 레코드 이름 패턴
      // "stgblueprint" → "stg{{project_name.paramCase()}}"
      // "devblueprint" → "dev{{project_name.paramCase()}}"
      for (final prefix in ['stg', 'dev']) {
        patterns.add(
          ReplacementPattern(
            RegExp('"$prefix${_escapeRegex(baseParam)}"'),
            '"$prefix{{project_name.paramCase()}}"',
          ),
        );
        patterns.add(
          ReplacementPattern(
            RegExp('"$prefix${_escapeRegex(baseSnake)}"'),
            '"$prefix{{project_name.paramCase()}}"',
          ),
        );
      }

      // Terraform Route53 CNAME 레코드 값 패턴
      // "staging.blueprint." → "staging.{{project_name.paramCase()}}."
      // "development.blueprint." → "development.{{project_name.paramCase()}}."
      // "blueprint." → "{{project_name.paramCase()}}."
      for (final envPrefix in ['staging', 'development', '']) {
        final dotPrefix = envPrefix.isEmpty ? '' : '$envPrefix.';
        patterns.add(
          ReplacementPattern(
            RegExp('"$dotPrefix${_escapeRegex(baseParam)}\\."'),
            '"$dotPrefix{{project_name.paramCase()}}."',
          ),
        );
        patterns.add(
          ReplacementPattern(
            RegExp('"$dotPrefix${_escapeRegex(baseSnake)}\\."'),
            '"$dotPrefix{{project_name.paramCase()}}."',
          ),
        );
      }

      // 1. Pascal case (HelloWorld) - suffix가 있는 패턴 먼저 (더 구체적인 순서)
      // Mock 클래스 패턴 (_FakeGoodTeacherService_0)
      for (final suffix in [
        'Service',
        'Repository',
        'Client',
        'Api',
        'Module',
      ]) {
        // _Fake + PascalCase + Suffix + _숫자
        patterns.add(
          ReplacementPattern(
            RegExp('_Fake${_escapeRegex(basePascal)}$suffix' r'(_\d+)\b'),
            '_FakeApp$suffix' r'$1',
          ),
        );
      }

      // 함수명 prefix 패턴 먼저 처리 (create, get, set, build, make 등)
      for (final prefix in [
        'create',
        'get',
        'set',
        'build',
        'make',
        'init',
        'setup',
        'configure',
      ]) {
        for (final suffix in [
          'ServiceModule',
          'HttpModule',
          'Service',
          'App',
          'Console',
          'Widgetbook',
        ]) {
          patterns.add(
            ReplacementPattern(
              RegExp('$prefix${_escapeRegex(basePascal)}$suffix\\b'),
              '$prefix{{project_name.pascalCase()}}$suffix',
            ),
          );
        }
        // prefix + PascalCase 단독 (suffix 없음)
        patterns.add(
          ReplacementPattern(
            RegExp('$prefix${_escapeRegex(basePascal)}\\b'),
            '$prefix{{project_name.pascalCase()}}',
          ),
        );
      }

      // ServiceModule, HttpModule 같은 복합 suffix를 먼저 처리
      for (final suffix in [
        'ServiceModule',
        'HttpModule',
        'App',
        'Console',
        'Widgetbook',
        'Service',
        'Scope',
        'Users',
        'User',
        'Handler',
        'Controller',
        'Manager',
        'Provider',
        'Factory',
        'Builder',
      ]) {
        patterns.add(
          ReplacementPattern(
            RegExp('\\b${_escapeRegex(basePascal)}$suffix\\b'),
            '{{project_name.pascalCase()}}$suffix',
          ),
        );
      }

      // _add, _remove 같은 underscore prefix 패턴도 처리
      for (final prefix in [
        '_add',
        '_remove',
        '_get',
        '_set',
        '_create',
        '_delete',
        '_update',
      ]) {
        // prefix + PascalCase + CamelCaseContinuation (e.g., _addBlueprintUsersToChat)
        // This pattern captures any camelCase continuation after the project name
        patterns.add(
          ReplacementPattern(
            RegExp('$prefix${_escapeRegex(basePascal)}([A-Z][a-zA-Z]*)'),
            '$prefix{{project_name.pascalCase()}}\$1',
          ),
        );

        // prefix + PascalCase (standalone)
        patterns.add(
          ReplacementPattern(
            RegExp('$prefix${_escapeRegex(basePascal)}\\b'),
            '$prefix{{project_name.pascalCase()}}',
          ),
        );
      }

      // Pascal case 단독 패턴 (가장 마지막에 처리)
      patterns.add(
        ReplacementPattern(
          RegExp('\\b${_escapeRegex(basePascal)}\\b'),
          '{{project_name.pascalCase()}}',
        ),
      );

      // 2. Camel case (helloWorld) - suffix가 있는 패턴 먼저
      // 함수명 prefix 패턴도 처리
      for (final prefix in [
        'create',
        'get',
        'set',
        'build',
        'make',
        'init',
        'setup',
        'configure',
      ]) {
        for (final suffix in [
          'ServiceModule',
          'HttpModule',
          'Service',
          'App',
          'Console',
          'Widgetbook',
        ]) {
          patterns.add(
            ReplacementPattern(
              RegExp('\\b$prefix${_escapeRegex(baseCamel)}$suffix\\b'),
              '$prefix{{project_name.camelCase()}}$suffix',
            ),
          );
        }
      }

      for (final suffix in [
        'ServiceModule',
        'HttpModule',
        'App',
        'Console',
        'Widgetbook',
        'Service',
      ]) {
        patterns.add(
          ReplacementPattern(
            RegExp('\\b${_escapeRegex(baseCamel)}$suffix\\b'),
            '{{project_name.camelCase()}}$suffix',
          ),
        );
      }
      // Camel case 단독 패턴
      patterns.add(
        ReplacementPattern(
          RegExp('\\b${_escapeRegex(baseCamel)}\\b'),
          '{{project_name.camelCase()}}',
        ),
      );

      // 3. Title case (Hello World)
      // Title Case + Widgetbook/Console 패턴 (스크립트 주석/출력)
      // "Blueprint Widgetbook" → "{{project_name.titleCase()}} Widgetbook"
      for (final suffix in ['Widgetbook', 'Console', 'Server', 'Client']) {
        patterns.add(
          ReplacementPattern(
            RegExp('${_escapeRegex(baseTitle)} $suffix'),
            '{{project_name.titleCase()}} $suffix',
          ),
        );
      }
      // Title case 단독 패턴
      patterns.add(
        ReplacementPattern(
          RegExp('\\b${_escapeRegex(baseTitle)}\\b'),
          '{{project_name.titleCase()}}',
        ),
      );

      // 4. Constant case (HELLO_WORLD)
      patterns.add(
        ReplacementPattern(
          RegExp('\\b${_escapeRegex(baseConstant)}\\b'),
          '{{project_name.constantCase()}}',
        ),
      );

      // 5. Upper case (HELLO WORLD)
      patterns.add(
        ReplacementPattern(
          RegExp('\\b${_escapeRegex(baseUpper)}\\b'),
          '{{project_name.upperCase()}}',
        ),
      );

      // 6. Lower case (hello world)
      patterns.add(
        ReplacementPattern(
          RegExp('\\b${_escapeRegex(baseLower)}\\b'),
          '{{project_name.lowerCase()}}',
        ),
      );
    }

    return patterns;
  }

  /// Firebase 프로젝트 ID 패턴 생성
  static List<ReplacementPattern> _buildFirebasePatterns(
    List<String> projectNames,
    List<String> orgNames,
    List<String> orgTlds,
    List<String> randomProjectIds,
  ) {
    final patterns = <ReplacementPattern>[];

    for (final orgTld in orgTlds) {
      for (final orgName in orgNames) {
        final orgLower = orgName.toLowerCase();

        for (final projectName in projectNames) {
          final projectParam = projectName.replaceAll('_', '-');
          final projectDot = projectName.replaceAll('_', '.');

          for (final randomId in randomProjectIds) {
            // 단순 하이픈 패턴: projectName-randomId (Firebase project ID용)
            // 가장 먼저 매칭되어야 함 (가장 구체적)

            // projectName-{suffix}-randomId 패턴 (console, widgetbook 등)
            for (final suffix in ['console', 'widgetbook']) {
              patterns.addAll([
                ReplacementPattern(
                  RegExp(
                    '\\b${_escapeRegex(projectParam)}-$suffix-${_escapeRegex(randomId)}-dev\\b',
                  ),
                  '{{project_name.paramCase()}}-$suffix-{{randomprojectid}}-dev',
                ),
                ReplacementPattern(
                  RegExp(
                    '\\b${_escapeRegex(projectParam)}-$suffix-${_escapeRegex(randomId)}-stg\\b',
                  ),
                  '{{project_name.paramCase()}}-$suffix-{{randomprojectid}}-stg',
                ),
                ReplacementPattern(
                  RegExp(
                    '\\b${_escapeRegex(projectParam)}-$suffix-${_escapeRegex(randomId)}\\b',
                  ),
                  '{{project_name.paramCase()}}-$suffix-{{randomprojectid}}',
                ),
              ]);

              // iOS/Android Bundle ID with suffix 패턴
              // im.cocode.blueprint.console.k9rm
              // → {{org_tld}}.{{org_name}}.{{project_name.snakeCase()}}.suffix.{{randomprojectid}}
              patterns.addAll([
                // .dev suffix
                ReplacementPattern(
                  RegExp(
                    '\\b${_escapeRegex(orgTld)}\\.'
                    '${_escapeRegex(orgLower)}\\.'
                    '${_escapeRegex(projectName)}\\.'
                    '$suffix\\.'
                    '${_escapeRegex(randomId)}\\.dev\\b',
                  ),
                  '{{org_tld}}.{{org_name}}.'
                  '{{project_name.snakeCase()}}.$suffix.{{randomprojectid}}.dev',
                ),
                // .stg suffix
                ReplacementPattern(
                  RegExp(
                    '\\b${_escapeRegex(orgTld)}\\.'
                    '${_escapeRegex(orgLower)}\\.'
                    '${_escapeRegex(projectName)}\\.'
                    '$suffix\\.'
                    '${_escapeRegex(randomId)}\\.stg\\b',
                  ),
                  '{{org_tld}}.{{org_name}}.'
                  '{{project_name.snakeCase()}}.$suffix.{{randomprojectid}}.stg',
                ),
                // 기본 (suffix 없음)
                ReplacementPattern(
                  RegExp(
                    '\\b${_escapeRegex(orgTld)}\\.'
                    '${_escapeRegex(orgLower)}\\.'
                    '${_escapeRegex(projectName)}\\.'
                    '$suffix\\.'
                    '${_escapeRegex(randomId)}\\b',
                  ),
                  '{{org_tld}}.{{org_name}}.'
                  '{{project_name.snakeCase()}}.$suffix.{{randomprojectid}}',
                ),
              ]);

              // Kotlin package 문 패턴 (MainActivity.kt)
              // package im.cocode.blueprint.console.k9rm (끝에 _가 없는 형태)
              // → package {{org_tld}}.{{org_name}}.{{project_name.snakeCase()}}.suffix.{{randomprojectid}}
              patterns.add(
                ReplacementPattern(
                  RegExp(
                    'package ${_escapeRegex(orgTld)}\\.'
                    '${_escapeRegex(orgLower)}\\.'
                    '${_escapeRegex(projectName)}\\.'
                    '$suffix\\.'
                    '${_escapeRegex(randomId)}\\b',
                  ),
                  'package {{org_tld}}.{{org_name.lowerCase()}}.'
                  '{{project_name.snakeCase()}}.$suffix.{{randomprojectid}}',
                ),
              );

              // Android namespace/applicationId 패턴 (build.gradle.kts)
              // namespace = "im.cocode.blueprint.console.k9rm"
              // applicationId = "im.cocode.blueprint.console.k9rm"
              patterns.add(
                ReplacementPattern(
                  RegExp(
                    '(namespace|applicationId)\\s*=\\s*"'
                    '${_escapeRegex(orgTld)}\\.'
                    '${_escapeRegex(orgLower)}\\.'
                    '${_escapeRegex(projectName)}\\.'
                    '$suffix\\.'
                    '${_escapeRegex(randomId)}"',
                  ),
                  r'$1 = "{{org_tld}}.{{org_name.lowerCase()}}.'
                  '{{project_name.snakeCase()}}.$suffix.{{randomprojectid}}"',
                ),
              );

              // Android package_name 패턴 (google-services.json)
              // "package_name": "im.cocode.blueprint.console.k9rm.dev"
              patterns.addAll([
                ReplacementPattern(
                  RegExp(
                    '"package_name":\\s*"'
                    '${_escapeRegex(orgTld)}\\.'
                    '${_escapeRegex(orgLower)}\\.'
                    '${_escapeRegex(projectName)}\\.'
                    '$suffix\\.'
                    '${_escapeRegex(randomId)}\\.dev"',
                  ),
                  '"package_name": "{{org_tld}}.{{org_name.lowerCase()}}.'
                  '{{project_name.snakeCase()}}.$suffix.{{randomprojectid}}.dev"',
                ),
                ReplacementPattern(
                  RegExp(
                    '"package_name":\\s*"'
                    '${_escapeRegex(orgTld)}\\.'
                    '${_escapeRegex(orgLower)}\\.'
                    '${_escapeRegex(projectName)}\\.'
                    '$suffix\\.'
                    '${_escapeRegex(randomId)}\\.stg"',
                  ),
                  '"package_name": "{{org_tld}}.{{org_name.lowerCase()}}.'
                  '{{project_name.snakeCase()}}.$suffix.{{randomprojectid}}.stg"',
                ),
                ReplacementPattern(
                  RegExp(
                    '"package_name":\\s*"'
                    '${_escapeRegex(orgTld)}\\.'
                    '${_escapeRegex(orgLower)}\\.'
                    '${_escapeRegex(projectName)}\\.'
                    '$suffix\\.'
                    '${_escapeRegex(randomId)}"',
                  ),
                  '"package_name": "{{org_tld}}.{{org_name.lowerCase()}}.'
                  '{{project_name.snakeCase()}}.$suffix.{{randomprojectid}}"',
                ),
              ]);

              // Android Fastlane package_name 패턴 (Appfile)
              // package_name("im.cocode.blueprint.console.k9rm")
              patterns.add(
                ReplacementPattern(
                  RegExp(
                    'package_name\\("'
                    '${_escapeRegex(orgTld)}\\.'
                    '${_escapeRegex(orgLower)}\\.'
                    '${_escapeRegex(projectName)}\\.'
                    '$suffix\\.'
                    '${_escapeRegex(randomId)}"\\)',
                  ),
                  'package_name("{{org_tld}}.{{org_name.lowerCase()}}.'
                  '{{project_name.snakeCase()}}.$suffix.{{randomprojectid}}")',
                ),
              );

              // Android manifest package 속성 (AndroidManifest.xml)
              // <manifest ... package="im.cocode.blueprint.widgetbook.k9rm">
              patterns.add(
                ReplacementPattern(
                  RegExp(
                    'package="'
                    '${_escapeRegex(orgTld)}\\.'
                    '${_escapeRegex(orgLower)}\\.'
                    '${_escapeRegex(projectName)}\\.'
                    '$suffix\\.'
                    '${_escapeRegex(randomId)}"',
                  ),
                  'package="{{org_tld}}.{{org_name.lowerCase()}}.'
                  '{{project_name.snakeCase()}}.$suffix.{{randomprojectid}}"',
                ),
              );

              // Firebase iosBundleId 패턴 (development/staging/production firebase options)
              // iosBundleId: 'im.cocode.blueprint.console.k9rm.dev'
              patterns.addAll([
                ReplacementPattern(
                  RegExp(
                    "iosBundleId:\\s*'"
                    '${_escapeRegex(orgTld)}\\.'
                    '${_escapeRegex(orgLower)}\\.'
                    '${_escapeRegex(projectName)}\\.'
                    '$suffix\\.'
                    "${_escapeRegex(randomId)}\\.dev'",
                  ),
                  "iosBundleId: '{{org_tld}}.{{org_name.lowerCase()}}."
                  "{{project_name.snakeCase()}}.$suffix.{{randomprojectid}}.dev'",
                ),
                ReplacementPattern(
                  RegExp(
                    "iosBundleId:\\s*'"
                    '${_escapeRegex(orgTld)}\\.'
                    '${_escapeRegex(orgLower)}\\.'
                    '${_escapeRegex(projectName)}\\.'
                    '$suffix\\.'
                    "${_escapeRegex(randomId)}\\.stg'",
                  ),
                  "iosBundleId: '{{org_tld}}.{{org_name.lowerCase()}}."
                  "{{project_name.snakeCase()}}.$suffix.{{randomprojectid}}.stg'",
                ),
                ReplacementPattern(
                  RegExp(
                    "iosBundleId:\\s*'"
                    '${_escapeRegex(orgTld)}\\.'
                    '${_escapeRegex(orgLower)}\\.'
                    '${_escapeRegex(projectName)}\\.'
                    '$suffix\\.'
                    "${_escapeRegex(randomId)}'",
                  ),
                  "iosBundleId: '{{org_tld}}.{{org_name.lowerCase()}}."
                  "{{project_name.snakeCase()}}.$suffix.{{randomprojectid}}'",
                ),
              ]);

              // macOS iosBundleId 패턴 (Firebase options - mac prefix)
              // iosBundleId: 'im.cocode.mac.blueprint.console.o7h1'
              patterns.addAll([
                ReplacementPattern(
                  RegExp(
                    "iosBundleId:\\s*'"
                    '${_escapeRegex(orgTld)}\\.'
                    '${_escapeRegex(orgLower)}\\.mac\\.'
                    '${_escapeRegex(projectName)}\\.'
                    '$suffix\\.'
                    "${_escapeRegex(randomId)}'",
                  ),
                  "iosBundleId: '{{org_tld}}.{{org_name.lowerCase()}}.mac."
                  "{{project_name.snakeCase()}}.$suffix.{{randomprojectid}}'",
                ),
              ]);

              // iOS bundle_id 패턴 (google-services.json 내부)
              // "bundle_id": "im.cocode.blueprint.widgetbook.k9rm"
              patterns.add(
                ReplacementPattern(
                  RegExp(
                    '"bundle_id":\\s*"'
                    '${_escapeRegex(orgTld)}\\.'
                    '${_escapeRegex(orgLower)}\\.'
                    '${_escapeRegex(projectName)}\\.'
                    '$suffix\\.'
                    '${_escapeRegex(randomId)}"',
                  ),
                  '"bundle_id": "{{org_tld}}.{{org_name.lowerCase()}}.'
                  '{{project_name.snakeCase()}}.$suffix.{{randomprojectid}}"',
                ),
              );
            }

            // projectName-randomId 패턴 (기본)
            patterns.addAll([
              ReplacementPattern(
                RegExp(
                  '\\b${_escapeRegex(projectParam)}-${_escapeRegex(randomId)}-dev\\b',
                ),
                '{{project_name.paramCase()}}-{{randomprojectid}}-dev',
              ),
              ReplacementPattern(
                RegExp(
                  '\\b${_escapeRegex(projectParam)}-${_escapeRegex(randomId)}-stg\\b',
                ),
                '{{project_name.paramCase()}}-{{randomprojectid}}-stg',
              ),
              ReplacementPattern(
                RegExp(
                  '\\b${_escapeRegex(projectParam)}-${_escapeRegex(randomId)}\\b',
                ),
                '{{project_name.paramCase()}}-{{randomprojectid}}',
              ),
            ]);

            // 순수 점(.) 패턴 (모두 dotCase) - 가장 먼저! 더 구체적
            patterns.addAll([
              ReplacementPattern(
                RegExp(
                  '\\b${_escapeRegex(orgTld)}\\.${_escapeRegex(orgLower)}\\.${_escapeRegex(projectDot)}\\.${_escapeRegex(randomId)}\\.dev\\b',
                ),
                '{{org_tld}}.{{org_name.dotCase()}}.{{project_name.dotCase()}}.{{randomprojectid}}.dev',
              ),
              ReplacementPattern(
                RegExp(
                  '\\b${_escapeRegex(orgTld)}\\.${_escapeRegex(orgLower)}\\.${_escapeRegex(projectDot)}\\.${_escapeRegex(randomId)}\\.stg\\b',
                ),
                '{{org_tld}}.{{org_name.dotCase()}}.{{project_name.dotCase()}}.{{randomprojectid}}.stg',
              ),
              ReplacementPattern(
                RegExp(
                  '\\b${_escapeRegex(orgTld)}\\.${_escapeRegex(orgLower)}\\.${_escapeRegex(projectDot)}\\.${_escapeRegex(randomId)}\\b',
                ),
                '{{org_tld}}.{{org_name.dotCase()}}.{{project_name.dotCase()}}.{{randomprojectid}}',
              ),
            ]);

            // 혼합 패턴 (점 + 하이픈): im.laputa.good-teacher.iace 형태
            patterns.addAll([
              ReplacementPattern(
                RegExp(
                  '\\b${_escapeRegex(orgTld)}\\.${_escapeRegex(orgLower)}\\.${_escapeRegex(projectParam)}\\.${_escapeRegex(randomId)}\\.dev\\b',
                ),
                '{{org_tld}}.{{org_name.dotCase()}}.{{project_name.paramCase()}}.{{randomprojectid}}.dev',
              ),
              ReplacementPattern(
                RegExp(
                  '\\b${_escapeRegex(orgTld)}\\.${_escapeRegex(orgLower)}\\.${_escapeRegex(projectParam)}\\.${_escapeRegex(randomId)}\\.stg\\b',
                ),
                '{{org_tld}}.{{org_name.dotCase()}}.{{project_name.paramCase()}}.{{randomprojectid}}.stg',
              ),
              ReplacementPattern(
                RegExp(
                  '\\b${_escapeRegex(orgTld)}\\.${_escapeRegex(orgLower)}\\.${_escapeRegex(projectParam)}\\.${_escapeRegex(randomId)}\\b',
                ),
                '{{org_tld}}.{{org_name.dotCase()}}.{{project_name.paramCase()}}.{{randomprojectid}}',
              ),
            ]);

            // 하이픈(-) 패턴
            patterns.addAll([
              ReplacementPattern(
                RegExp(
                  '\\b${_escapeRegex(orgTld)}-${_escapeRegex(orgLower)}-${_escapeRegex(projectParam)}-${_escapeRegex(randomId)}-dev\\b',
                ),
                '{{project_name.paramCase()}}-{{randomprojectid}}-dev',
              ),
              ReplacementPattern(
                RegExp(
                  '\\b${_escapeRegex(orgTld)}-${_escapeRegex(orgLower)}-${_escapeRegex(projectParam)}-${_escapeRegex(randomId)}-stg\\b',
                ),
                '{{project_name.paramCase()}}-{{randomprojectid}}-stg',
              ),
              ReplacementPattern(
                RegExp(
                  '\\b${_escapeRegex(orgTld)}-${_escapeRegex(orgLower)}-${_escapeRegex(projectParam)}-${_escapeRegex(randomId)}\\b',
                ),
                '{{project_name.paramCase()}}-{{randomprojectid}}',
              ),
            ]);
          }

          // 순수 점(.) 패턴 (random ID 없음, 모두 dotCase) - 가장 먼저! 더 구체적
          patterns.addAll([
            ReplacementPattern(
              RegExp(
                '\\b${_escapeRegex(orgTld)}\\.${_escapeRegex(orgLower)}\\.${_escapeRegex(projectDot)}\\.dev\\b',
              ),
              '{{org_tld}}.{{org_name.dotCase()}}.{{project_name.dotCase()}}.dev',
            ),
            ReplacementPattern(
              RegExp(
                '\\b${_escapeRegex(orgTld)}\\.${_escapeRegex(orgLower)}\\.${_escapeRegex(projectDot)}\\.stg\\b',
              ),
              '{{org_tld}}.{{org_name.dotCase()}}.{{project_name.dotCase()}}.stg',
            ),
            ReplacementPattern(
              RegExp(
                '\\b${_escapeRegex(orgTld)}\\.${_escapeRegex(orgLower)}\\.${_escapeRegex(projectDot)}\\b',
              ),
              '{{org_tld}}.{{org_name.dotCase()}}.{{project_name.dotCase()}}',
            ),
          ]);

          // 혼합 패턴 (random ID 없음): im.laputa.good-teacher 형태
          patterns.addAll([
            ReplacementPattern(
              RegExp(
                '\\b${_escapeRegex(orgTld)}\\.${_escapeRegex(orgLower)}\\.${_escapeRegex(projectParam)}\\.dev\\b',
              ),
              '{{org_tld}}.{{org_name.dotCase()}}.{{project_name.paramCase()}}.dev',
            ),
            ReplacementPattern(
              RegExp(
                '\\b${_escapeRegex(orgTld)}\\.${_escapeRegex(orgLower)}\\.${_escapeRegex(projectParam)}\\.stg\\b',
              ),
              '{{org_tld}}.{{org_name.dotCase()}}.{{project_name.paramCase()}}.stg',
            ),
            ReplacementPattern(
              RegExp(
                '\\b${_escapeRegex(orgTld)}\\.${_escapeRegex(orgLower)}\\.${_escapeRegex(projectParam)}\\b',
              ),
              '{{org_tld}}.{{org_name.dotCase()}}.{{project_name.paramCase()}}',
            ),
          ]);

          // 하이픈(-) 패턴 (random ID 없음)
          patterns.addAll([
            ReplacementPattern(
              RegExp(
                '\\b${_escapeRegex(orgTld)}-${_escapeRegex(orgLower)}-${_escapeRegex(projectParam)}-dev\\b',
              ),
              '{{project_name.paramCase()}}-dev',
            ),
            ReplacementPattern(
              RegExp(
                '\\b${_escapeRegex(orgTld)}-${_escapeRegex(orgLower)}-${_escapeRegex(projectParam)}-stg\\b',
              ),
              '{{project_name.paramCase()}}-stg',
            ),
            ReplacementPattern(
              RegExp(
                '\\b${_escapeRegex(orgTld)}-${_escapeRegex(orgLower)}-${_escapeRegex(projectParam)}\\b',
              ),
              '{{org_tld}}-{{org_name.lowerCase()}}-{{project_name.paramCase()}}',
            ),
          ]);
        }
      }
    }

    return patterns;
  }

  /// Apple App ID 패턴 생성 (team_id + bundle ID 조합)
  static List<ReplacementPattern> _buildAppleAppIdPatterns(
    String teamId,
    List<String> projectNames,
    List<String> orgNames,
    List<String> orgTlds,
    List<String> randomProjectIds,
  ) {
    final patterns = <ReplacementPattern>[];

    for (final projectName in projectNames) {
      for (final orgName in orgNames) {
        final orgLower = orgName.toLowerCase();
        final projectDot = projectName.toLowerCase();

        for (final orgTld in orgTlds) {
          if (randomProjectIds.isNotEmpty) {
            for (final randomId in randomProjectIds) {
              // team_id.org_tld.org_name.project_name.randomId.dev
              patterns.add(
                ReplacementPattern(
                  RegExp(
                    '${_escapeRegex(teamId)}\\.${_escapeRegex(orgTld)}\\.${_escapeRegex(orgLower)}\\.${_escapeRegex(projectDot)}\\.${_escapeRegex(randomId)}\\.dev',
                  ),
                  '{{team_id}}.{{org_tld}}.{{org_name.lowerCase()}}.{{project_name.dotCase()}}.{{randomprojectid}}.dev',
                ),
              );

              // team_id.org_tld.org_name.project_name.randomId.stg
              patterns.add(
                ReplacementPattern(
                  RegExp(
                    '${_escapeRegex(teamId)}\\.${_escapeRegex(orgTld)}\\.${_escapeRegex(orgLower)}\\.${_escapeRegex(projectDot)}\\.${_escapeRegex(randomId)}\\.stg',
                  ),
                  '{{team_id}}.{{org_tld}}.{{org_name.lowerCase()}}.{{project_name.dotCase()}}.{{randomprojectid}}.stg',
                ),
              );

              // team_id.org_tld.org_name.project_name.randomId (끝에 console이 올 수 있음)
              patterns.add(
                ReplacementPattern(
                  RegExp(
                    '${_escapeRegex(teamId)}\\.${_escapeRegex(orgTld)}\\.${_escapeRegex(orgLower)}\\.${_escapeRegex(projectDot)}\\.${_escapeRegex(randomId)}(?!\\.)',
                  ),
                  '{{team_id}}.{{org_tld}}.{{org_name.lowerCase()}}.{{project_name.dotCase()}}.{{randomprojectid}}',
                ),
              );

              // console variants
              patterns.addAll([
                ReplacementPattern(
                  RegExp(
                    '${_escapeRegex(teamId)}\\.${_escapeRegex(orgTld)}\\.${_escapeRegex(orgLower)}\\.${_escapeRegex(projectDot)}\\.${_escapeRegex(randomId)}\\.console\\.dev',
                  ),
                  '{{team_id}}.{{org_tld}}.{{org_name.lowerCase()}}.{{project_name.dotCase()}}.{{randomprojectid}}.console.dev',
                ),
                ReplacementPattern(
                  RegExp(
                    '${_escapeRegex(teamId)}\\.${_escapeRegex(orgTld)}\\.${_escapeRegex(orgLower)}\\.${_escapeRegex(projectDot)}\\.${_escapeRegex(randomId)}\\.console\\.stg',
                  ),
                  '{{team_id}}.{{org_tld}}.{{org_name.lowerCase()}}.{{project_name.dotCase()}}.{{randomprojectid}}.console.stg',
                ),
                ReplacementPattern(
                  RegExp(
                    '${_escapeRegex(teamId)}\\.${_escapeRegex(orgTld)}\\.${_escapeRegex(orgLower)}\\.${_escapeRegex(projectDot)}\\.${_escapeRegex(randomId)}\\.console',
                  ),
                  '{{team_id}}.{{org_tld}}.{{org_name.lowerCase()}}.{{project_name.dotCase()}}.{{randomprojectid}}.console',
                ),
              ]);
            }
          }
        }
      }
    }

    // Firebase 서비스 계정 URL 패턴
    // blueprint-{randomId}-dev.iam.gserviceaccount.com
    // → {{project_name.paramCase()}}-{{randomprojectid}}-dev.iam.gserviceaccount.com
    for (final projectName in projectNames) {
      final projectParam = projectName.replaceAll('_', '-');

      for (final randomId in randomProjectIds) {
        for (final env in ['dev', 'stg', 'prod']) {
          // client_x509_cert_url 내부의 Firebase 서비스 계정 URL
          // URL 인코딩된 형태: blueprint-k9rm-dev.iam.gserviceaccount.com
          patterns.add(
            ReplacementPattern(
              RegExp(
                '${_escapeRegex(projectParam)}-${_escapeRegex(randomId)}-$env\\.iam\\.gserviceaccount\\.com',
              ),
              '{{project_name.paramCase()}}-{{randomprojectid}}-$env.iam.gserviceaccount.com',
            ),
          );
        }

        // google-services.json project_id 패턴
        // "project_id": "blueprint-k9rm-dev"
        for (final env in ['dev', 'stg', 'prod']) {
          patterns.add(
            ReplacementPattern(
              RegExp(
                '"project_id":\\s*"${_escapeRegex(projectParam)}-${_escapeRegex(randomId)}-$env"',
              ),
              '"project_id": "{{project_name.paramCase()}}-{{randomprojectid}}-$env"',
            ),
          );
        }
        // 환경 접미사 없는 버전 (production)
        patterns.add(
          ReplacementPattern(
            RegExp(
              '"project_id":\\s*"${_escapeRegex(projectParam)}-${_escapeRegex(randomId)}"',
            ),
            '"project_id": "{{project_name.paramCase()}}-{{randomprojectid}}"',
          ),
        );

        // google-services.json storage_bucket 패턴
        // "storage_bucket": "blueprint-k9rm-dev.firebasestorage.app"
        for (final env in ['dev', 'stg', 'prod']) {
          patterns.add(
            ReplacementPattern(
              RegExp(
                '"storage_bucket":\\s*"${_escapeRegex(projectParam)}-${_escapeRegex(randomId)}-$env\\.firebasestorage\\.app"',
              ),
              '"storage_bucket": "{{project_name.paramCase()}}-{{randomprojectid}}-$env.firebasestorage.app"',
            ),
          );
        }
        // 환경 접미사 없는 버전
        patterns.add(
          ReplacementPattern(
            RegExp(
              '"storage_bucket":\\s*"${_escapeRegex(projectParam)}-${_escapeRegex(randomId)}\\.firebasestorage\\.app"',
            ),
            '"storage_bucket": "{{project_name.paramCase()}}-{{randomprojectid}}.firebasestorage.app"',
          ),
        );

        // Route53/Terraform Firebase web.app 도메인 패턴
        // blueprint-k9rm.web.app → {{project_name.paramCase()}}-{{randomprojectid}}.web.app
        for (final env in ['', '-dev', '-stg']) {
          patterns.add(
            ReplacementPattern(
              RegExp(
                '${_escapeRegex(projectParam)}-${_escapeRegex(randomId)}$env\\.web\\.app',
              ),
              '{{project_name.paramCase()}}-{{randomprojectid}}$env.web.app',
            ),
          );
        }

        // URL 인코딩된 이메일 주소 패턴 (client_x509_cert_url 내부)
        // %40blueprint-k9rm-dev → %40{{project_name.paramCase()}}-{{randomprojectid}}-dev
        for (final env in ['dev', 'stg', 'prod']) {
          patterns.add(
            ReplacementPattern(
              RegExp(
                '%40${_escapeRegex(projectParam)}-${_escapeRegex(randomId)}-$env',
              ),
              '%40{{project_name.paramCase()}}-{{randomprojectid}}-$env',
            ),
          );
        }

        // URL 인코딩된 이메일 주소 패턴 - production 환경 (환경 접미사 없음)
        // %40blueprint-k9rm.iam → %40{{project_name.paramCase()}}-{{randomprojectid}}.iam
        patterns.add(
          ReplacementPattern(
            RegExp(
              '%40${_escapeRegex(projectParam)}-${_escapeRegex(randomId)}\\.iam',
            ),
            '%40{{project_name.paramCase()}}-{{randomprojectid}}.iam',
          ),
        );

        // URL 인코딩된 이메일 주소 패턴 - 이미 변환된 경우 처리
        // %40blueprint-{{randomprojectid}}-dev → %40{{project_name.paramCase()}}-{{randomprojectid}}-dev
        for (final env in ['dev', 'stg', 'prod']) {
          patterns.add(
            ReplacementPattern(
              RegExp(
                '%40${_escapeRegex(projectParam)}-\\{\\{randomprojectid\\}\\}-$env',
              ),
              '%40{{project_name.paramCase()}}-{{randomprojectid}}-$env',
            ),
          );
        }

        // URL 인코딩된 이메일 - production (이미 변환된 경우)
        // %40blueprint-{{randomprojectid}}.iam → %40{{project_name.paramCase()}}-{{randomprojectid}}.iam
        patterns.add(
          ReplacementPattern(
            RegExp(
              '%40${_escapeRegex(projectParam)}-\\{\\{randomprojectid\\}\\}\\.iam',
            ),
            '%40{{project_name.paramCase()}}-{{randomprojectid}}.iam',
          ),
        );
      }
    }

    // Terraform firebase_project_ids 맵 값 패턴
    // "production"  = "blueprint-k9rm"
    for (final projectName in projectNames) {
      final projectParam = projectName.replaceAll('_', '-');

      for (final randomId in randomProjectIds) {
        for (final env in ['dev', 'stg', 'prod', '']) {
          final suffix = env.isEmpty ? '' : '-$env';
          patterns.add(
            ReplacementPattern(
              RegExp(
                '=\\s*"${_escapeRegex(projectParam)}-${_escapeRegex(randomId)}$suffix"',
              ),
              '= "{{project_name.paramCase()}}-{{randomprojectid}}$suffix"',
            ),
          );
        }
      }
    }

    return patterns;
  }

  /// Apple Team ID 패턴 생성
  static List<ReplacementPattern> _buildAppleTeamIdPatterns(
    ProjectConfig config,
  ) {
    final patterns = <ReplacementPattern>[];

    // ITC Team ID 패턴
    if (config.itcTeamId != null) {
      patterns.add(
        ReplacementPattern(
          RegExp('\\b${_escapeRegex(config.itcTeamId!)}\\b'),
          '{{itc_team_id}}',
        ),
      );
    }

    // Developer Team ID 패턴
    if (config.teamId != null) {
      patterns.add(
        ReplacementPattern(
          RegExp('\\b${_escapeRegex(config.teamId!)}\\b'),
          '{{team_id}}',
        ),
      );
    }

    return patterns;
  }

  /// Apple Developer ID 패턴 생성 (가장 먼저 적용)
  static List<ReplacementPattern> _buildAppleDeveloperIdPatterns(
    String appleDeveloperId,
  ) {
    final patterns = <ReplacementPattern>[];

    // 정확한 이메일 주소 매칭 (따옴표 포함)
    patterns.addAll([
      ReplacementPattern(
        RegExp('"${_escapeRegex(appleDeveloperId)}"'),
        '"{{apple_developer_id}}"',
      ),
      ReplacementPattern(
        RegExp("'${_escapeRegex(appleDeveloperId)}'"),
        "'{{apple_developer_id}}'",
      ),
      // 따옴표 없는 경우
      ReplacementPattern(
        RegExp('\\b${_escapeRegex(appleDeveloperId)}\\b'),
        '{{apple_developer_id}}',
      ),
    ]);

    return patterns;
  }

  /// 이메일 주소 패턴 생성
  static List<ReplacementPattern> _buildEmailPatterns(
    List<String> orgNames,
    List<String> orgTlds,
    String? appleDeveloperId,
  ) {
    final patterns = <ReplacementPattern>[];

    for (final orgName in orgNames) {
      final orgLower = orgName.toLowerCase();
      for (final orgTld in orgTlds) {
        // appleDeveloperId와 일치하는 이메일은 이미 처리되었으므로 제외
        final techEmail = 'tech@$orgLower.$orgTld';
        final devEmail = 'dev@$orgLower.$orgTld';

        if (appleDeveloperId != techEmail && appleDeveloperId != devEmail) {
          patterns.addAll([
            ReplacementPattern(
              RegExp(
                'dev@${_escapeRegex(orgLower)}\\.${_escapeRegex(orgTld)}\\b',
              ),
              '{{apple_developer_id}}',
            ),
            ReplacementPattern(
              RegExp(
                'tech@${_escapeRegex(orgLower)}\\.${_escapeRegex(orgTld)}\\b',
              ),
              '{{apple_developer_id}}',
            ),
          ]);
        }

        patterns.addAll([
          ReplacementPattern(
            RegExp(
              'hello@${_escapeRegex(orgLower)}\\.${_escapeRegex(orgTld)}\\b',
            ),
            'hello@{{org_name.lowerCase()}}.{{org_tld}}',
          ),
          ReplacementPattern(
            RegExp(
              'admin@${_escapeRegex(orgLower)}\\.${_escapeRegex(orgTld)}\\b',
            ),
            'admin@{{org_name.lowerCase()}}.{{org_tld}}',
          ),
          ReplacementPattern(
            RegExp(
              'support@${_escapeRegex(orgLower)}\\.${_escapeRegex(orgTld)}\\b',
            ),
            'support@{{org_name.lowerCase()}}.{{org_tld}}',
          ),
        ]);
      }
    }

    return patterns;
  }

  /// URL Scheme 패턴 생성
  static List<ReplacementPattern> _buildUrlSchemePatterns(
    List<String> projectNames,
  ) {
    final patterns = <ReplacementPattern>[];

    for (final projectName in projectNames) {
      final projectParam = projectName.replaceAll('_', '-'); // good-teacher

      // URL scheme은 주로 paramCase(하이픈)를 사용하므로 paramCase 우선
      patterns.addAll([
        // paramCase 버전 (devgood-teacher)
        ReplacementPattern(
          RegExp('\\bdev${_escapeRegex(projectParam)}\\b'),
          'dev{{project_name.paramCase()}}',
        ),
        ReplacementPattern(
          RegExp('\\bstg${_escapeRegex(projectParam)}\\b'),
          'stg{{project_name.paramCase()}}',
        ),
        ReplacementPattern(
          RegExp('\\bprod${_escapeRegex(projectParam)}\\b'),
          'prod{{project_name.paramCase()}}',
        ),
        // snakeCase 버전도 지원 (devgood_teacher)
        ReplacementPattern(
          RegExp('\\bdev${_escapeRegex(projectName)}\\b'),
          'dev{{project_name.snakeCase()}}',
        ),
        ReplacementPattern(
          RegExp('\\bstg${_escapeRegex(projectName)}\\b'),
          'stg{{project_name.snakeCase()}}',
        ),
        ReplacementPattern(
          RegExp('\\bprod${_escapeRegex(projectName)}\\b'),
          'prod{{project_name.snakeCase()}}',
        ),
      ]);
    }

    return patterns;
  }

  /// 도메인 패턴 생성
  static List<ReplacementPattern> _buildDomainPatterns(
    List<String> projectNames,
    List<String> orgTlds,
  ) {
    final patterns = <ReplacementPattern>[];

    for (final projectName in projectNames) {
      final projectParam = projectName.replaceAll('_', '-');

      for (final orgTld in orgTlds) {
        // iOS entitlements 도메인 패턴 (webcredentials, applinks)
        // dev.blueprint.im → dev.{{project_name.paramCase()}}.{{org_tld}}
        // stg.blueprint.im → stg.{{project_name.paramCase()}}.{{org_tld}}
        for (final prefix in ['dev', 'stg', 'staging', 'prod', 'production']) {
          // webcredentials:dev.blueprint.im, applinks:dev.blueprint.im 패턴
          // (prefix가 있는 entitlements 도메인)
          patterns.add(
            ReplacementPattern(
              RegExp(
                '(webcredentials|applinks):$prefix\\.'
                '${_escapeRegex(projectParam)}\\.${_escapeRegex(orgTld)}',
              ),
              '\$1:$prefix.{{project_name.paramCase()}}.{{org_tld}}',
            ),
          );
          patterns.add(
            ReplacementPattern(
              RegExp(
                '(webcredentials|applinks):$prefix\\.'
                '${_escapeRegex(projectName)}\\.${_escapeRegex(orgTld)}',
              ),
              '\$1:$prefix.{{project_name.paramCase()}}.{{org_tld}}',
            ),
          );
          // 일반 도메인 패턴 (prefix 포함)
          patterns.add(
            ReplacementPattern(
              RegExp(
                '$prefix\\.${_escapeRegex(projectParam)}\\.${_escapeRegex(orgTld)}\\b',
              ),
              '$prefix.{{project_name.paramCase()}}.{{org_tld}}',
            ),
          );
          patterns.add(
            ReplacementPattern(
              RegExp(
                '$prefix\\.${_escapeRegex(projectName)}\\.${_escapeRegex(orgTld)}\\b',
              ),
              '$prefix.{{project_name.paramCase()}}.{{org_tld}}',
            ),
          );
        }

        patterns.addAll([
          ReplacementPattern(
            RegExp(
              'app-staging\\.${_escapeRegex(projectName)}\\.${_escapeRegex(orgTld)}\\b',
            ),
            'app-staging.{{project_name.paramCase()}}.{{org_tld}}',
          ),
          ReplacementPattern(
            RegExp(
              'app-staging\\.${_escapeRegex(projectParam)}\\.${_escapeRegex(orgTld)}\\b',
            ),
            'app-staging.{{project_name.paramCase()}}.{{org_tld}}',
          ),
          ReplacementPattern(
            RegExp(
              'app-development\\.${_escapeRegex(projectName)}\\.${_escapeRegex(orgTld)}\\b',
            ),
            'app-development.{{project_name.paramCase()}}.{{org_tld}}',
          ),
          ReplacementPattern(
            RegExp(
              'app-development\\.${_escapeRegex(projectParam)}\\.${_escapeRegex(orgTld)}\\b',
            ),
            'app-development.{{project_name.paramCase()}}.{{org_tld}}',
          ),
          // 기본 도메인 패턴 (blueprint.im)
          ReplacementPattern(
            RegExp(
              '\\b${_escapeRegex(projectParam)}\\.${_escapeRegex(orgTld)}\\b',
            ),
            '{{project_name.paramCase()}}.{{org_tld}}',
          ),
          ReplacementPattern(
            RegExp(
              '\\b${_escapeRegex(projectName)}\\.${_escapeRegex(orgTld)}\\b',
            ),
            '{{project_name.paramCase()}}.{{org_tld}}',
          ),
          // iOS entitlements 도메인 패턴 (webcredentials:, applinks: 뒤에 오는 도메인)
          // webcredentials:blueprint.im → webcredentials:{{project_name.paramCase()}}.{{org_tld}}
          ReplacementPattern(
            RegExp(
              '(webcredentials|applinks):${_escapeRegex(projectParam)}\\.${_escapeRegex(orgTld)}',
            ),
            r'$1:{{project_name.paramCase()}}.{{org_tld}}',
          ),
          ReplacementPattern(
            RegExp(
              '(webcredentials|applinks):${_escapeRegex(projectName)}\\.${_escapeRegex(orgTld)}',
            ),
            r'$1:{{project_name.paramCase()}}.{{org_tld}}',
          ),
        ]);
      }
    }

    return patterns;
  }

  /// 정규식 특수 문자 이스케이프용 캐시된 패턴
  static final _escapeRegexPattern = RegExp(r'[.*+?^${}()|[\]\\]');

  /// 정규식 특수 문자 이스케이프
  static String _escapeRegex(String text) {
    return text.replaceAllMapped(
      _escapeRegexPattern,
      (match) => '\\${match.group(0)}',
    );
  }

  /// 파일 내용 변환
  static String convertContent(
    String content,
    List<ReplacementPattern> patterns,
  ) {
    var result = content;

    // 보호된 타입명 목록
    const protectedTypes = [
      'Failure',
      'Either',
      'Future',
      'List',
      'Map',
      'Set',
      'Iterable',
      'Stream',
      'Optional',
      'Result',
      'Unit',
      'Void',
      'Null',
      'Object',
      'String',
      'int',
      'double',
      'num',
      'bool',
      'DateTime',
      'Duration',
      // Serverpod framework classes and keywords
      'serverpod', // import alias
      'ServerpodService',
      'ServerpodClient',
      'ServerpodClientException',
    ];

    // 보호된 타입명을 임시 플레이스홀더로 치환
    final typePlaceholders = <String, String>{};
    for (var i = 0; i < protectedTypes.length; i++) {
      final placeholder = '__PROTECTED_TYPE_${i}__';
      typePlaceholders[placeholder] = protectedTypes[i];
      result = result.replaceAll(
        RegExp('\\b${_escapeRegex(protectedTypes[i])}\\b'),
        placeholder,
      );
    }

    // 패턴 적용 (이미 변환된 템플릿 변수 보호)
    for (final pattern in patterns) {
      // 임시로 이미 변환된 템플릿 변수를 플레이스홀더로 교체
      final templatePlaceholders = <String, String>{};
      var tempResult = result;

      // {{...}} 형태의 템플릿 변수를 찾아서 보호
      final templatePattern = RegExp(r'\{\{[^}]+\}\}');
      final matches = templatePattern.allMatches(tempResult).toList();

      for (var i = 0; i < matches.length; i++) {
        final match = matches[i];
        final placeholder = '___TEMPLATE_VAR_${i}___';
        final originalValue = match.group(0)!;
        templatePlaceholders[placeholder] = originalValue;
        tempResult = tempResult.replaceFirst(originalValue, placeholder);
      }

      // 패턴 적용 (콜백 함수 사용하여 캡처 그룹 처리)
      tempResult = tempResult.replaceAllMapped(pattern.pattern, (match) {
        var replacement = pattern.replacement;
        // 캡처 그룹을 실제 값으로 치환
        for (var i = 0; i <= match.groupCount; i++) {
          final groupValue = match.group(i) ?? '';
          replacement = replacement.replaceAll('\$$i', groupValue);
        }
        return replacement;
      });

      // 보호된 템플릿 변수 복원
      for (final entry in templatePlaceholders.entries) {
        tempResult = tempResult.replaceAll(entry.key, entry.value);
      }

      result = tempResult;
    }

    // _podService를 _serverpodService로 변환
    result = result.replaceAll('_podService', '_serverpodService');

    // 보호된 타입명 복원
    for (final entry in typePlaceholders.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }

    return result;
  }
}

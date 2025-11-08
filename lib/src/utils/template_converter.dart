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

    // 0. Apple Developer ID 패턴 (가장 먼저 적용)
    if (config.appleDeveloperId != null) {
      patterns.insertAll(0, _buildAppleDeveloperIdPatterns(config.appleDeveloperId!));
    }

    // 1. 가장 구체적인 패턴 (Firebase 전체 경로 등)
    patterns.addAll(
      _buildFirebasePatterns(projectNames, orgNames, orgTlds, randomProjectIds),
    );

    // 2. 도메인 패턴 (app-staging.good_teacher.im 등)
    patterns.addAll(_buildDomainPatterns(projectNames, orgTlds));

    // 3. 이메일 주소 패턴
    patterns.addAll(_buildEmailPatterns(orgNames, orgTlds, config.appleDeveloperId));

    // 4. URL Scheme 패턴
    patterns.addAll(_buildUrlSchemePatterns(projectNames));

    // 5. 프로젝트명 패턴
    patterns.addAll(_buildProjectPatterns(projectNames));

    // 6. 조직명 패턴
    patterns.addAll(_buildOrgPatterns(orgNames));

    // 7. 케이스 변환 패턴
    patterns.addAll(_buildCasePatterns(projectNames));

    // 8. Random project ID 단독 패턴 (lgxf 같은 패턴)
    patterns.addAll(_buildRandomProjectIdPatterns(randomProjectIds));

    // 9. Apple Team ID 패턴
    patterns.addAll(_buildAppleTeamIdPatterns());

    // 10. org_tld 단독 패턴 (im. 같은 패턴, 가장 마지막에 처리)
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
  ) {
    final patterns = <ReplacementPattern>[];

    for (final projectName in projectNames) {
      final baseSnake = projectName;
      final baseParam = projectName.replaceAll('_', '-');
      final baseDot = projectName.replaceAll('_', '.');
      final baseTitle = projectName
          .split('_')
          .map((word) => word[0].toUpperCase() + word.substring(1))
          .join(' ');

      // 복합 이름 패턴
      for (final suffix in ['_server', '_client', '_widgetbook', '_console']) {
        patterns.add(
          ReplacementPattern(
            RegExp('\\b${_escapeRegex(baseSnake)}$suffix\\b'),
            '{{project_name.snakeCase()}}$suffix',
          ),
        );
      }

      // 하이픈(-) 패턴: paramCase 사용
      patterns.addAll([
        ReplacementPattern(
          RegExp('-${_escapeRegex(baseParam)}-'),
          '-{{project_name.paramCase()}}-',
        ),
        ReplacementPattern(
          RegExp('\\b${_escapeRegex(baseParam)}-'),
          '{{project_name.paramCase()}}-',
        ),
        ReplacementPattern(
          RegExp('-${_escapeRegex(baseParam)}\\b'),
          '-{{project_name.paramCase()}}',
        ),
        ReplacementPattern(
          RegExp('\\b${_escapeRegex(baseParam)}\\b'),
          '{{project_name.paramCase()}}',
        ),
      ]);

      // 점(.) 패턴: dotCase 사용
      patterns.addAll([
        ReplacementPattern(
          RegExp('\\.${_escapeRegex(baseDot)}\\.'),
          '.{{project_name.dotCase()}}.',
        ),
        ReplacementPattern(
          RegExp('\\b${_escapeRegex(baseDot)}\\.'),
          '{{project_name.dotCase()}}.',
        ),
        ReplacementPattern(
          RegExp('\\.${_escapeRegex(baseDot)}\\b'),
          '.{{project_name.dotCase()}}',
        ),
        ReplacementPattern(
          RegExp('\\b${_escapeRegex(baseDot)}\\b'),
          '{{project_name.dotCase()}}',
        ),
      ]);

      // Title case 패턴
      patterns.addAll([
        ReplacementPattern(
          RegExp('\\b${_escapeRegex(baseTitle)}\\b'),
          '{{project_name.titleCase()}}',
        ),
        ReplacementPattern(
          RegExp('`${_escapeRegex(baseTitle)}`'),
          '`{{project_name.titleCase()}}`',
        ),
      ]);

      // 따옴표 안의 패턴
      patterns.addAll([
        ReplacementPattern(
          RegExp('"${_escapeRegex(baseSnake)}"'),
          '"{{project_name.snakeCase()}}"',
        ),
        ReplacementPattern(
          RegExp("'${_escapeRegex(baseSnake)}'"),
          "'{{project_name.snakeCase()}}'",
        ),
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
          RegExp('"${_escapeRegex(baseTitle)}"'),
          '"{{project_name.titleCase()}}"',
        ),
        ReplacementPattern(
          RegExp("'${_escapeRegex(baseTitle)}'"),
          "'{{project_name.titleCase()}}'",
        ),
      ]);

      // 기본 snake_case 패턴 (마지막에 처리)
      patterns.addAll([
        ReplacementPattern(
          RegExp('\\b${_escapeRegex(baseSnake)}\\b'),
          '{{project_name.snakeCase()}}',
        ),
        ReplacementPattern(
          RegExp('\\b${_escapeRegex(baseSnake.replaceAll("_", ""))}\\b'),
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

      patterns.addAll([
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
                    .join('');

      // pascalCase: HelloWorld (모든 단어 첫 글자 대문자)
      final basePascal = words
          .map(
            (word) => word.isEmpty
                ? ''
                : word[0].toUpperCase() + word.substring(1).toLowerCase(),
          )
          .join('');

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

      // 1. Pascal case (HelloWorld) - suffix가 있는 패턴 먼저
      for (final suffix in [
        'App',
        'Console',
        'Widgetbook',
        'Service',
        'HttpModule',
      ]) {
        patterns.add(
          ReplacementPattern(
            RegExp('\\b${_escapeRegex(basePascal)}$suffix\\b'),
            '{{project_name.pascalCase()}}$suffix',
          ),
        );
      }
      // Pascal case 단독 패턴
      patterns.add(
        ReplacementPattern(
          RegExp('\\b${_escapeRegex(basePascal)}\\b'),
          '{{project_name.pascalCase()}}',
        ),
      );

      // 2. Camel case (helloWorld) - suffix가 있는 패턴 먼저
      for (final suffix in [
        'App',
        'Console',
        'Widgetbook',
        'Service',
        'HttpModule',
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

            // 점(.) 패턴
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
          }

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

          // 점(.) 패턴 (random ID 없음)
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
        }
      }
    }

    return patterns;
  }

  /// Apple Team ID 패턴 생성
  static List<ReplacementPattern> _buildAppleTeamIdPatterns() {
    return [
      ReplacementPattern(RegExp(r'\b127679498\b'), '{{itc_team_id}}'),
      ReplacementPattern(RegExp(r'\bDNNK8RH9GY\b'), '{{team_id}}'),
      ReplacementPattern(RegExp(r'\bDWKVPW88Q3\b'), '{{team_id}}'),
      ReplacementPattern(RegExp(r'\bY7BR9G2CVC\b'), '{{team_id}}'),
    ];
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
      patterns.addAll([
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
      for (final orgTld in orgTlds) {
        patterns.addAll([
          ReplacementPattern(
            RegExp(
              'app-staging\\.${_escapeRegex(projectName)}\\.${_escapeRegex(orgTld)}\\b',
            ),
            'app-staging.{{project_name.snakeCase()}}.{{org_tld}}',
          ),
          ReplacementPattern(
            RegExp(
              'app-development\\.${_escapeRegex(projectName)}\\.${_escapeRegex(orgTld)}\\b',
            ),
            'app-development.{{project_name.snakeCase()}}.{{org_tld}}',
          ),
          ReplacementPattern(
            RegExp(
              '\\b${_escapeRegex(projectName)}\\.${_escapeRegex(orgTld)}\\b',
            ),
            '{{project_name.snakeCase()}}.{{org_tld}}',
          ),
        ]);
      }
    }

    return patterns;
  }

  /// 정규식 특수 문자 이스케이프
  static String _escapeRegex(String text) {
    return text.replaceAllMapped(
      RegExp(r'[.*+?^${}()|[\]\\]'),
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

    // 패턴 적용
    for (final pattern in patterns) {
      result = result.replaceAll(pattern.pattern, pattern.replacement);
    }

    // 보호된 타입명 복원
    for (final entry in typePlaceholders.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }

    return result;
  }
}

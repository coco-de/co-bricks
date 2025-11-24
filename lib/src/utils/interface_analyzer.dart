import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:path/path.dart' as path;

/// 메서드 시그니처 정보
class MethodSignature {
  MethodSignature({
    required this.name,
    required this.returnType,
    required this.parameters,
    required this.isAsync,
  });

  /// 메서드 이름
  final String name;

  /// 반환 타입
  final String returnType;

  /// 파라미터 목록 (타입 포함)
  final List<String> parameters;

  /// async 메서드 여부
  final bool isAsync;

  /// 메서드 시그니처 전체 문자열
  String get signature {
    final params = parameters.join(', ');
    final asyncModifier = isAsync ? 'async ' : '';
    return '$returnType $name($params) $asyncModifier';
  }

  /// 시그니처 비교 (이름, 반환 타입, 파라미터)
  bool matchesSignature(MethodSignature other) {
    if (name != other.name) return false;
    if (returnType != other.returnType) return false;
    if (parameters.length != other.parameters.length) return false;

    for (var i = 0; i < parameters.length; i++) {
      if (parameters[i] != other.parameters[i]) return false;
    }

    return true;
  }

  @override
  String toString() => signature;
}

/// 시그니처 충돌 정보
class SignatureConflict {
  SignatureConflict({
    required this.methodName,
    required this.signatureA,
    required this.signatureB,
  });

  /// 충돌하는 메서드 이름
  final String methodName;

  /// Project A의 시그니처
  final MethodSignature signatureA;

  /// Project B의 시그니처
  final MethodSignature signatureB;

  @override
  String toString() => 'Conflict in $methodName:\n'
      '  A: ${signatureA.signature}\n'
      '  B: ${signatureB.signature}';
}

/// Interface 비교 결과
class InterfaceDiff {
  InterfaceDiff({
    required this.commonMethods,
    required this.onlyInProjectA,
    required this.onlyInProjectB,
    required this.conflicts,
  });

  /// 두 프로젝트 공통 메서드
  final List<MethodSignature> commonMethods;

  /// Project A에만 있는 메서드
  final List<MethodSignature> onlyInProjectA;

  /// Project B에만 있는 메서드
  final List<MethodSignature> onlyInProjectB;

  /// 시그니처 충돌
  final List<SignatureConflict> conflicts;

  /// 총 메서드 수
  int get totalMethods =>
      commonMethods.length + onlyInProjectA.length + onlyInProjectB.length;

  /// Project A 전체 메서드 수
  int get projectAMethodCount => commonMethods.length + onlyInProjectA.length;

  /// Project B 전체 메서드 수
  int get projectBMethodCount => commonMethods.length + onlyInProjectB.length;
}

/// Repository Interface 분석기
class InterfaceAnalyzer {
  /// 두 Repository 인터페이스 파일을 비교
  ///
  /// [repositoryA] - Project A의 repository interface 파일
  /// [repositoryB] - Project B의 repository interface 파일
  Future<InterfaceDiff> compareInterfaces({
    required File repositoryA,
    required File repositoryB,
  }) async {
    // 각 파일에서 메서드 추출
    final methodsA = await _extractMethods(repositoryA);
    final methodsB = await _extractMethods(repositoryB);

    // 메서드 이름으로 그룹화
    final methodsByNameA = <String, MethodSignature>{
      for (final method in methodsA) method.name: method,
    };
    final methodsByNameB = <String, MethodSignature>{
      for (final method in methodsB) method.name: method,
    };

    // 공통 메서드 및 충돌 찾기
    final common = <MethodSignature>[];
    final conflicts = <SignatureConflict>[];

    for (final name in methodsByNameA.keys) {
      if (methodsByNameB.containsKey(name)) {
        final methodA = methodsByNameA[name]!;
        final methodB = methodsByNameB[name]!;

        if (methodA.matchesSignature(methodB)) {
          // 시그니처 동일
          common.add(methodA);
        } else {
          // 시그니처 충돌
          conflicts.add(
            SignatureConflict(
              methodName: name,
              signatureA: methodA,
              signatureB: methodB,
            ),
          );
        }
      }
    }

    // 각 프로젝트에만 있는 메서드
    final onlyInA = methodsA
        .where((m) => !methodsByNameB.containsKey(m.name))
        .toList();
    final onlyInB = methodsB
        .where((m) => !methodsByNameA.containsKey(m.name))
        .toList();

    return InterfaceDiff(
      commonMethods: common,
      onlyInProjectA: onlyInA,
      onlyInProjectB: onlyInB,
      conflicts: conflicts,
    );
  }

  /// 파일에서 모든 메서드 추출
  Future<List<MethodSignature>> _extractMethods(File file) async {
    if (!file.existsSync()) {
      return [];
    }

    // Analysis Context 생성 (absolute normalized path 사용)
    final absoluteParentPath = path.normalize(file.parent.absolute.path);
    final absoluteFilePath = path.normalize(file.absolute.path);

    final collection = AnalysisContextCollection(
      includedPaths: [absoluteParentPath],
    );

    final context = collection.contextFor(absoluteFilePath);
    final session = context.currentSession;

    // 파일 분석 (absolute path 사용)
    final result = await session.getResolvedUnit(absoluteFilePath);

    if (result is! ResolvedUnitResult) {
      return [];
    }

    // AST 방문하여 메서드 추출
    final visitor = _MethodExtractorVisitor();
    result.unit.accept(visitor);

    return visitor.methods;
  }
}

/// AST 방문자: 메서드 추출
class _MethodExtractorVisitor extends RecursiveAstVisitor<void> {
  final methods = <MethodSignature>[];

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    // abstract interface class 또는 abstract class만 처리
    if (node.abstractKeyword == null) {
      return;
    }

    // 클래스 내 메서드 방문
    super.visitClassDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    // abstract 메서드만 추출 (interface 메서드)
    if (node.body is! EmptyFunctionBody) {
      return;
    }

    final name = node.name.lexeme;
    final returnType = node.returnType?.toSource() ?? 'dynamic';
    final parameters = node.parameters?.parameters
            .map((p) => p.toSource())
            .toList() ??
        [];
    final isAsync = node.body.keyword?.lexeme == 'async';

    methods.add(
      MethodSignature(
        name: name,
        returnType: returnType,
        parameters: parameters,
        isAsync: isAsync,
      ),
    );

    super.visitMethodDeclaration(node);
  }
}

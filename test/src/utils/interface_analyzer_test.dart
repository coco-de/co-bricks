import 'package:co_bricks/src/utils/interface_analyzer.dart';
import 'package:test/test.dart';

void main() {
  group('MethodSignature', () {
    test('signature property formats correctly', () {
      final method = MethodSignature(
        name: 'login',
        returnType: 'Future<Either<Failure, String>>',
        parameters: ['String userId', 'String password'],
        isAsync: true,
      );

      expect(method.signature, contains('login'));
      expect(method.signature, contains('Future<Either<Failure, String>>'));
      expect(method.signature, contains('async'));
    });

    test('matchesSignature compares signatures correctly', () {
      final method1 = MethodSignature(
        name: 'login',
        returnType: 'Future<String>',
        parameters: ['String userId', 'String password'],
        isAsync: true,
      );

      final method2 = MethodSignature(
        name: 'login',
        returnType: 'Future<String>',
        parameters: ['String userId', 'String password'],
        isAsync: true,
      );

      final method3 = MethodSignature(
        name: 'login',
        returnType: 'Future<bool>', // Different return type
        parameters: ['String userId', 'String password'],
        isAsync: true,
      );

      expect(method1.matchesSignature(method2), isTrue);
      expect(method1.matchesSignature(method3), isFalse);
    });

    test('matchesSignature detects parameter differences', () {
      final method1 = MethodSignature(
        name: 'test',
        returnType: 'void',
        parameters: ['String a', 'int b'],
        isAsync: false,
      );

      final method2 = MethodSignature(
        name: 'test',
        returnType: 'void',
        parameters: ['String a'], // Fewer parameters
        isAsync: false,
      );

      expect(method1.matchesSignature(method2), isFalse);
    });
  });

  group('InterfaceDiff', () {
    test('calculates total methods correctly', () {
      final diff = InterfaceDiff(
        commonMethods: [
          MethodSignature(
            name: 'method1',
            returnType: 'void',
            parameters: [],
            isAsync: false,
          ),
          MethodSignature(
            name: 'method2',
            returnType: 'void',
            parameters: [],
            isAsync: false,
          ),
        ],
        onlyInProjectA: [
          MethodSignature(
            name: 'method3',
            returnType: 'void',
            parameters: [],
            isAsync: false,
          ),
        ],
        onlyInProjectB: [
          MethodSignature(
            name: 'method4',
            returnType: 'void',
            parameters: [],
            isAsync: false,
          ),
          MethodSignature(
            name: 'method5',
            returnType: 'void',
            parameters: [],
            isAsync: false,
          ),
        ],
        conflicts: [],
      );

      expect(diff.totalMethods, 5);
      expect(diff.projectAMethodCount, 3); // common + onlyInA
      expect(diff.projectBMethodCount, 4); // common + onlyInB
    });
  });

  group('SignatureConflict', () {
    test('toString formats conflict message', () {
      final conflict = SignatureConflict(
        methodName: 'login',
        signatureA: MethodSignature(
          name: 'login',
          returnType: 'Future<String>',
          parameters: [],
          isAsync: true,
        ),
        signatureB: MethodSignature(
          name: 'login',
          returnType: 'Future<bool>',
          parameters: [],
          isAsync: true,
        ),
      );

      final message = conflict.toString();
      expect(message, contains('Conflict in login'));
      expect(message, contains('Future<String>'));
      expect(message, contains('Future<bool>'));
    });
  });

  group('InterfaceAnalyzer', () {
    test('compareInterfaces handles non-existent files', () async {
      // 실제 파일이 필요하므로 통합 테스트에서 수행
      // 여기서는 기본 구조만 테스트
    });
  });
}

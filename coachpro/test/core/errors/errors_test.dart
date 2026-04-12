import 'package:flutter_test/flutter_test.dart';
import 'package:excellence/core/errors/exceptions.dart';
import 'package:excellence/core/errors/failures.dart';

void main() {
  group('Exceptions', () {
    test('ServerException contains message', () {
      const e = ServerException(message: 'Internal Server Error');
      expect(e.message, equals('Internal Server Error'));
    });

    test('ServerException with status code', () {
      const e = ServerException(message: 'Not Found', statusCode: 404);
      expect(e.statusCode, equals(404));
      expect(e.toString(), contains('404'));
    });

    test('NetworkException has default message', () {
      const e = NetworkException();
      expect(e.message, contains('internet'));
    });

    test('AuthException has default message', () {
      const e = AuthException();
      expect(e.message, contains('Authentication'));
    });

    test('CacheException has default message', () {
      const e = CacheException();
      expect(e.message, contains('Cache'));
    });

    test('SessionExpiredException extends AuthException', () {
      const e = SessionExpiredException();
      expect(e, isA<AuthException>());
      expect(e.message, contains('expired'));
    });

    test('ValidationException with field errors', () {
      const e = ValidationException(
        message: 'Invalid input',
        fieldErrors: {'email': 'Invalid email'},
      );
      expect(e.fieldErrors?['email'], equals('Invalid email'));
    });
  });

  group('Failures', () {
    test('ServerFailure has default message', () {
      const f = ServerFailure();
      expect(f.message, contains('Server'));
    });

    test('ServerFailure with custom message', () {
      const f = ServerFailure('Custom server error');
      expect(f.message, equals('Custom server error'));
    });

    test('NetworkFailure has default message', () {
      const f = NetworkFailure();
      expect(f.message, contains('internet'));
    });

    test('AuthFailure has default message', () {
      const f = AuthFailure();
      expect(f.message, contains('Authentication'));
    });

    test('CacheFailure has default message', () {
      const f = CacheFailure();
      expect(f.message, contains('storage'));
    });

    test('ValidationFailure with field errors', () {
      const f = ValidationFailure('Invalid', {'name': 'Required'});
      expect(f.message, equals('Invalid'));
      expect(f.fieldErrors?['name'], equals('Required'));
    });

    test('Failure equality works via Equatable', () {
      const f1 = ServerFailure('error');
      const f2 = ServerFailure('error');
      const f3 = ServerFailure('other');
      expect(f1, equals(f2));
      expect(f1, isNot(equals(f3)));
    });

    test('different failure types are not equal', () {
      const f1 = ServerFailure('error');
      const f2 = AuthFailure('error');
      expect(f1, isNot(equals(f2)));
    });
  });
}


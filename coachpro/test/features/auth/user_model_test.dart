import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:coachpro/features/auth/data/models/user_model.dart';
import 'package:coachpro/features/auth/domain/entities/user_entity.dart';

void main() {
  group('UserEntity', () {
    test('dashboardPath returns correct path for each role', () {
      for (final role in AppRole.values) {
        final user = UserModel(
          id: 'u1',
          name: 'Test',
          phone: '1234567890',
          role: role,
        );
        expect(user.dashboardPath, equals('/${role.name}'));
      }
    });

    test('equality based on props', () {
      const user1 = UserModel(
        id: 'u1',
        name: 'Test',
        phone: '1234567890',
        role: AppRole.student,
      );
      const user2 = UserModel(
        id: 'u1',
        name: 'Test',
        phone: '1234567890',
        role: AppRole.student,
      );
      expect(user1, equals(user2));
    });

    test('inequality when role differs', () {
      const user1 = UserModel(
        id: 'u1',
        name: 'Test',
        phone: '1234567890',
        role: AppRole.student,
      );
      const user2 = UserModel(
        id: 'u1',
        name: 'Test',
        phone: '1234567890',
        role: AppRole.admin,
      );
      expect(user1, isNot(equals(user2)));
    });
  });

  group('UserModel', () {
    group('fromJson / toJson', () {
      test('roundtrip preserves all fields', () {
        final user = UserModel(
          id: 'user_001',
          name: 'Rahul Sharma',
          phone: '9876543210',
          email: 'rahul@test.com',
          role: AppRole.student,
          avatarUrl: 'https://example.com/avatar.jpg',
          createdAt: DateTime(2026, 1, 15),
        );

        final json = user.toJson();
        final restored = UserModel.fromJson(json);

        expect(restored.id, equals('user_001'));
        expect(restored.name, equals('Rahul Sharma'));
        expect(restored.phone, equals('9876543210'));
        expect(restored.email, equals('rahul@test.com'));
        expect(restored.role, equals(AppRole.student));
        expect(restored.avatarUrl, equals('https://example.com/avatar.jpg'));
        expect(restored.createdAt, equals(DateTime(2026, 1, 15)));
      });

      test('handles null optional fields', () {
        const user = UserModel(
          id: 'user_002',
          name: 'Test',
          phone: '1111111111',
          role: AppRole.teacher,
        );

        final json = user.toJson();
        final restored = UserModel.fromJson(json);

        expect(restored.email, isNull);
        expect(restored.avatarUrl, isNull);
        expect(restored.createdAt, isNull);
      });

      test('survives JSON encode/decode', () {
        final user = UserModel(
          id: 'u3',
          name: 'Admin User',
          phone: '5555555555',
          role: AppRole.admin,
          createdAt: DateTime(2026, 3, 6),
        );

        final encoded = jsonEncode(user.toJson());
        final decoded = UserModel.fromJson(
          jsonDecode(encoded) as Map<String, dynamic>,
        );

        expect(decoded.id, equals('u3'));
        expect(decoded.role, equals(AppRole.admin));
      });

      test('defaults to student for unknown role', () {
        final json = {
          'id': 'u4',
          'name': 'Unknown',
          'phone': '0000000000',
          'role': 'superadmin', // unknown role
        };
        final user = UserModel.fromJson(json);
        expect(user.role, equals(AppRole.student));
      });
    });

    group('mock', () {
      test('creates mock user for each role', () {
        for (final role in AppRole.values) {
          final user = UserModel.mock(role);
          expect(user.role, equals(role));
          expect(user.id, contains(role.name));
          expect(user.name, contains('Demo'));
          expect(user.phone, isNotEmpty);
          expect(user.email, contains('@neurovax.app'));
          expect(user.createdAt, isNotNull);
        }
      });
    });
  });

  group('AppRole', () {
    test('has exactly 4 roles', () {
      expect(AppRole.values.length, equals(4));
    });

    test('includes all expected roles', () {
      expect(
        AppRole.values.map((r) => r.name).toList(),
        containsAll(['admin', 'teacher', 'student', 'parent']),
      );
    });
  });
}

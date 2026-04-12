import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

extension RolePrefixContext on BuildContext {
  /// Returns the role path prefix from the current matched location.
  /// e.g. '/admin', '/teacher', '/student', '/parent'
  String get rolePrefix {
    final loc = GoRouterState.of(this).matchedLocation;
    if (loc.startsWith('/admin')) return '/admin';
    if (loc.startsWith('/teacher')) return '/teacher';
    if (loc.startsWith('/student')) return '/student';
    if (loc.startsWith('/parent')) return '/parent';
    return '';
  }
}

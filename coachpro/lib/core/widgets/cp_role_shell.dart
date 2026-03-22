import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'cp_bottom_nav.dart';

/// Persistent shell scaffold that wraps every role's page tree.
/// [navigationShell] is the StatefulNavigationShell from go_router —
/// it keeps a separate Navigator stack per branch so page state
/// (scroll position, form input, etc.) survives tab switches.
class CPRoleShell extends StatefulWidget {
  const CPRoleShell({
    super.key,
    required this.navigationShell,
    required this.items,
  });

  final StatefulNavigationShell navigationShell;
  final List<CPBottomNavItem> items;

  @override
  State<CPRoleShell> createState() => _CPRoleShellState();
}

class _CPRoleShellState extends State<CPRoleShell> {
  // Local index so the nav bar gives instant visual feedback
  // even for "exit" tabs before the push completes.
  late int _displayIndex;

  @override
  void initState() {
    super.initState();
    _displayIndex = widget.navigationShell.currentIndex;
  }

  @override
  void didUpdateWidget(CPRoleShell old) {
    super.didUpdateWidget(old);
    // Sync back when shell navigates (e.g. deep link, redirect).
    _displayIndex = widget.navigationShell.currentIndex;
  }

  void _onTap(int index) {
    HapticFeedback.selectionClick();
    setState(() => _displayIndex = index);
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final router = GoRouter.of(context);
        if (router.canPop()) {
          router.pop();
          return;
        }
        if (_displayIndex != 0) {
          _onTap(0);
          return;
        }
        SystemNavigator.pop();
      },
      child: Scaffold(
        body: widget.navigationShell,
        bottomNavigationBar: CPBottomNav(
          currentIndex: _displayIndex,
          onTap: _onTap,
          items: widget.items,
        ),
      ),
    );
  }
}

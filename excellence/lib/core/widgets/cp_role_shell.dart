import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'cp_bottom_nav.dart';

class CPRoleShellBack extends InheritedWidget {
  const CPRoleShellBack({
    super.key,
    required this.goBack,
    required super.child,
  });

  final VoidCallback goBack;

  static CPRoleShellBack? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<CPRoleShellBack>();
  }

  @override
  bool updateShouldNotify(CPRoleShellBack oldWidget) => false;
}

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
  final List<int> _tabHistory = [];

  @override
  void initState() {
    super.initState();
    _displayIndex = widget.navigationShell.currentIndex;
    _tabHistory.add(_displayIndex);
  }

  @override
  void didUpdateWidget(CPRoleShell old) {
    super.didUpdateWidget(old);
    // Sync back when shell navigates (e.g. deep link, redirect).
    _displayIndex = widget.navigationShell.currentIndex;
    if (_tabHistory.isEmpty || _tabHistory.last != _displayIndex) {
      _tabHistory.add(_displayIndex);
    }
  }

  void _onTap(int index) {
    HapticFeedback.selectionClick();
    final previous = widget.navigationShell.currentIndex;
    setState(() => _displayIndex = index);
    if (index != previous) {
      _tabHistory.add(index);
    }
    widget.navigationShell.goBranch(
      index,
      // Always land on the root route of a bottom-nav section to avoid
      // reopening stale deep pages from another flow.
      initialLocation: true,
    );
  }

  bool _goBackInShell() {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
      return true;
    }

    if (_tabHistory.length > 1) {
      _tabHistory.removeLast();
      final previousIndex = _tabHistory.last;
      setState(() => _displayIndex = previousIndex);
      widget.navigationShell.goBranch(previousIndex, initialLocation: false);
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_goBackInShell()) return;
        SystemNavigator.pop();
      },
      child: Scaffold(
        body: CPRoleShellBack(
          goBack: _goBackInShell,
          child: widget.navigationShell,
        ),
        bottomNavigationBar: CPBottomNav(
          currentIndex: _displayIndex,
          onTap: _onTap,
          items: widget.items,
        ),
      ),
    );
  }
}

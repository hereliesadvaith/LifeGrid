import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_store.dart';
import '../theme/tokens.dart';
import 'dashboard/dashboard_tab.dart';
import 'dashboard/new_chart_sheet.dart';
import 'home/home_tab.dart';
import 'schema/schema_tab.dart';
import 'schema/new_model_sheet.dart';
import 'settings/settings_tab.dart';
import 'widgets/dotted_background.dart';
import 'widgets/primary_button.dart';

/// Root screen: phone-width frame with a swipeable four-page pager (Dashboard /
/// Record / Schema / Settings) driven by an icon-only bottom navigation bar. A
/// floating "New model" bar sits above the nav on the Schema page only.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _controller = PageController();
  int _index = 0;

  static const _navItems = [
    (icon: Icons.home_outlined, label: 'Dashboard'),
    (icon: Icons.shelves, label: 'Record'),
    (icon: Icons.storage_rounded, label: 'Schema'),
    (icon: Icons.settings_outlined, label: 'Settings'),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int i) {
    _controller.animateToPage(
      i,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final onDashboard = _index == 0;
    final onSchema = _index == 2;
    final showBar = onDashboard || onSchema;

    return Scaffold(
      body: DottedBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: T.maxWidth),
            child: SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  Column(
                    children: [
                      Expanded(
                        child: PageView(
                          controller: _controller,
                          onPageChanged: (i) => setState(() => _index = i),
                          children: [
                            const DashboardTab(),
                            HomeTab(onGoToSchema: () => _goTo(2)),
                            const SchemaTab(),
                            const SettingsTab(),
                          ],
                        ),
                      ),
                      _BottomNav(
                        items: _navItems,
                        index: _index,
                        bottomInset: bottomInset,
                        onTap: _goTo,
                      ),
                    ],
                  ),
                  // Floating action bar — "New chart" on Dashboard, "New model"
                  // on Schema, hidden elsewhere; sits above the nav.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: T.navHeight + bottomInset,
                    child: IgnorePointer(
                      ignoring: !showBar,
                      child: AnimatedOpacity(
                        opacity: showBar ? 1 : 0,
                        duration: const Duration(milliseconds: 150),
                        child: _ActionBar(
                          child: onSchema
                              ? PrimaryButton(
                                  label: 'New model',
                                  plus: true,
                                  onPressed: () => showNewModelSheet(
                                    context,
                                    context.read<AppStore>(),
                                  ),
                                )
                              : PrimaryButton(
                                  label: 'New chart',
                                  plus: true,
                                  onPressed: () => showNewChartSheet(
                                    context,
                                    context.read<AppStore>(),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.items,
    required this.index,
    required this.bottomInset,
    required this.onTap,
  });

  final List<({IconData icon, String label})> items;
  final int index;
  final double bottomInset;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: T.navHeight + bottomInset,
      padding: EdgeInsets.fromLTRB(14, 0, 14, bottomInset),
      decoration: const BoxDecoration(
        color: T.surface,
        border: Border(top: BorderSide(color: T.line)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var i = 0; i < items.length; i++)
            _NavButton(
              icon: items[i].icon,
              label: items[i].label,
              active: i == index,
              onTap: () => onTap(i),
            ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      selected: active,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(T.rChip),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 58,
          height: 44,
          decoration: BoxDecoration(
            color: active ? T.accentSurface : Colors.transparent,
            borderRadius: BorderRadius.circular(T.rChip),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 24, color: active ? T.accent : T.textDim),
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(T.pad, 16, T.pad, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [T.bg, T.bg, Colors.transparent],
          stops: [0, 0.55, 1],
        ),
      ),
      child: child,
    );
  }
}

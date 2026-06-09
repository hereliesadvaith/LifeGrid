import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_store.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'lifegrid/lifegrid_tab.dart';
import 'schemas/schemas_tab.dart';
import 'schemas/new_model_sheet.dart';
import 'widgets/dotted_background.dart';
import 'widgets/primary_button.dart';

/// Root screen: phone-width frame, swipeable two-tab pager with an animated
/// underline, and a "New model" bar that only shows on the Schemas tab.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _controller = PageController();
  double _page = 0; // continuous page offset, drives the underline

  static const _tabs = ['LifeGrid', 'Schemas'];

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() => _page = _controller.page ?? 0);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int i) => _controller.animateToPage(
        i,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );

  @override
  Widget build(BuildContext context) {
    final onSchemas = _page > 0.5;
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
                      _Tabs(tabs: _tabs, page: _page, onTap: _goTo),
                      Expanded(
                        child: PageView(
                          controller: _controller,
                          children: [
                            LifeGridTab(onGoToSchemas: () => _goTo(1)),
                            const SchemasTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // bottom "New model" bar — Schemas tab only
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      ignoring: !onSchemas,
                      child: AnimatedOpacity(
                        opacity: onSchemas ? 1 : 0,
                        duration: const Duration(milliseconds: 150),
                        child: _BottomBar(
                          child: PrimaryButton(
                            label: 'New model',
                            plus: true,
                            onPressed: () => showNewModelSheet(
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

class _Tabs extends StatelessWidget {
  const _Tabs({required this.tabs, required this.page, required this.onTap});

  final List<String> tabs;
  final double page;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(T.pad, 6, T.pad, 0),
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 18),
                  child: GestureDetector(
                    onTap: () => onTap(i),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 14, top: 4),
                      child: Text(
                        tabs[i],
                        style: AppText.display(
                          size: 26,
                          weight: FontWeight.w900,
                          color: (page.round() == i) ? T.text : T.textDim,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // underline: slides between the two tab labels based on page offset
          SizedBox(
            height: 3,
            child: Stack(
              children: [
                Container(height: 1, color: T.lineSoft, margin: const EdgeInsets.only(top: 2)),
                Align(
                  alignment: Alignment(-1 + page * 1.05, 0),
                  child: Container(
                    width: 46,
                    height: 3,
                    decoration: BoxDecoration(
                      color: T.accent,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        T.pad,
        16,
        T.pad,
        20 + MediaQuery.of(context).padding.bottom,
      ),
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

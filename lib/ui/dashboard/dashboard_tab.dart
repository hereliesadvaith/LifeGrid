import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../widgets/common.dart';

/// Dashboard — the app's home page. Empty for now.
class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: T.pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageTitleHeader(title: 'Dashboard'),
          Expanded(child: SizedBox.shrink()),
        ],
      ),
    );
  }
}

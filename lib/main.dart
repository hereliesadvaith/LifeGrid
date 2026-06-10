import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'state/app_store.dart';
import 'theme/tokens.dart';
import 'theme/typography.dart';
import 'ui/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LifegridApp());
}

class LifegridApp extends StatelessWidget {
  const LifegridApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppStore()..load(),
      child: MaterialApp(
        title: 'Lifegrid',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: T.bg,
          colorScheme: const ColorScheme.dark(
            surface: T.bg,
            primary: T.accent,
          ),
          textTheme: TextTheme(bodyMedium: AppText.ui()),
          splashFactory: InkSparkle.splashFactory,
        ),
        home: const HomePage(),
      ),
    );
  }
}

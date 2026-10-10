import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'config/env.dart';
import 'widgets/env_banner.dart';

void main() {
  runApp(
    ProviderScope(
      child: MaterialApp.router(
        title: Env.appTitle,
        builder: (context, child) =>
            EnvBanner(child: child ?? const SizedBox.shrink()),
        theme: FlipBinTheme.dark,
        routerConfig: FlipBinRouter.router,
        debugShowCheckedModeBanner: false,
      ),
    ),
  );
}

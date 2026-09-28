import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/theme.dart';

void main() {
  runApp(
    ProviderScope(
      child: MaterialApp.router(
        title: 'FlipBin',
        theme: FlipBinTheme.dark,
        routerConfig: FlipBinRouter.router,
        debugShowCheckedModeBanner: false,
      ),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flipbin/config/env.dart';

/// Persistent amber strip on every route in non-prod builds (SPEC §12.4).
class EnvBanner extends StatelessWidget {
  final Widget child;
  const EnvBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (kIsProd) return child;
    final top = MediaQuery.of(context).padding.top;
    return Column(
      children: [
        Material(
          color: const Color(0xFFFFB300),
          child: Padding(
            padding: EdgeInsets.fromLTRB(8, top + 4, 8, 4),
            child: const SizedBox(
              width: double.infinity,
              child: Text(
                Env.bannerText,
                key: Key('qaBanner'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: child,
          ),
        ),
      ],
    );
  }
}

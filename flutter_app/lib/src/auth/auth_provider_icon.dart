import 'package:flutter/material.dart';

/// Provider branding shared by registration, account linking, and model setup.
class AuthProviderIcon extends StatelessWidget {
  const AuthProviderIcon({super.key, required this.provider, this.size = 18});

  final String provider;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (provider == 'openrouter') {
      final mode = Theme.of(context).brightness == Brightness.dark
          ? 'dark'
          : 'light';
      return Image.asset(
        'assets/branding/providers/openrouter_$mode.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
      );
    }
    if (provider == 'google') {
      return Text(
        'G',
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF4285F4),
        ),
      );
    }
    return Icon(Icons.link, size: size);
  }
}

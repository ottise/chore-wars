import 'package:flutter/material.dart';

Widget googleButtonSurface(VoidCallback onPressed) => OutlinedButton.icon(
  onPressed: onPressed,
  icon: Image.asset(
    'assets/branding/google-g.png',
    width: 20,
    height: 20,
    excludeFromSemantics: true,
  ),
  style: OutlinedButton.styleFrom(
    backgroundColor: Colors.white,
    foregroundColor: const Color(0xFF1F1F1F),
  ),
  label: const Text('Continue with Google'),
);

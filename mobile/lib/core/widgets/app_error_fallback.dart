import 'package:flutter/material.dart';

class AppErrorFallback extends StatelessWidget {
  const AppErrorFallback({super.key});

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Material(
      color: Color(0xFFF8F6F2),
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Semantics(
            liveRegion: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh_outlined, color: Color(0xFF6845D6)),
                SizedBox(height: 12),
                Text(
                  'This screen could not be displayed.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF27232F), fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'Please reopen this screen or refresh the page.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF6D6775), fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

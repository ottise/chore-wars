import 'dart:io';
import 'dart:ui' as ui;

import 'package:chore_wars/core/theme/app_theme.dart';
import 'package:chore_wars/features/house/domain/entities/house_models.dart';
import 'package:chore_wars/features/house/presentation/providers/house_providers.dart';
import 'package:chore_wars/features/house/presentation/screens/house_more_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'active household management keeps season routes and owner controls',
    (tester) async {
      tester.view.physicalSize = const Size(354, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      if (Platform.environment['UI_SCREENSHOT_PATH'] != null) {
        await tester.runAsync(() async {
          for (final entry in {
            'UI_FONT_PATH': 'Roboto',
            'UI_ICON_FONT_PATH': 'MaterialIcons',
          }.entries) {
            final path = Platform.environment[entry.key];
            if (path == null) continue;
            final loader = FontLoader(entry.value);
            loader.addFont(File(path).readAsBytes().then(ByteData.sublistView));
            await loader.load();
          }
        });
      }
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const HouseMoreScreen(houseId: 'h'),
          ),
          GoRoute(
            path: '/houses/h/seasons/s/review',
            builder: (_, _) => const Scaffold(body: Text('Review route')),
          ),
        ],
      );
      addTearDown(router.dispose);
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            houseDetailProvider.overrideWith(
              (ref, id) async => House(
                id: id,
                name: 'Test Home',
                inviteCode: 'TEST',
                createdAt: DateTime.utc(2026),
                myRole: HouseRole.owner,
              ),
            ),
            activeSeasonProvider.overrideWith(
              (ref, id) async => {'id': 's', 'name': 'Season 1', 'status': 2},
            ),
          ],
          child: RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp.router(
              debugShowCheckedModeBanner: false,
              theme: Platform.environment['UI_FONT_PATH'] == null
                  ? AppTheme.lightTheme
                  : AppTheme.lightTheme.copyWith(
                      textTheme: AppTheme.lightTheme.textTheme.apply(
                        fontFamily: 'Roboto',
                      ),
                      listTileTheme: AppTheme.lightTheme.listTileTheme.copyWith(
                        titleTextStyle: AppTheme
                            .lightTheme
                            .listTileTheme
                            .titleTextStyle
                            ?.copyWith(fontFamily: 'Roboto'),
                        subtitleTextStyle: AppTheme
                            .lightTheme
                            .listTileTheme
                            .subtitleTextStyle
                            ?.copyWith(fontFamily: 'Roboto'),
                      ),
                      appBarTheme: AppTheme.lightTheme.appBarTheme.copyWith(
                        titleTextStyle: AppTheme
                            .lightTheme
                            .appBarTheme
                            .titleTextStyle
                            ?.copyWith(fontFamily: 'Roboto'),
                      ),
                    ),
              routerConfig: router,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Season Active'), findsOneWidget);
      expect(find.text('Create New Season'), findsOneWidget);
      expect(find.text('Leaderboard'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final screenshotPath = Platform.environment['UI_SCREENSHOT_PATH'];
      if (screenshotPath != null) {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(screenshotPath).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.tap(find.text('Household Summary'));
      await tester.pumpAndSettle();
      expect(find.text('Review route'), findsOneWidget);
    },
  );
}

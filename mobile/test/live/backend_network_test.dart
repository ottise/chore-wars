import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:chore_wars/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:chore_wars/features/house/data/datasources/house_remote_data_source.dart';
import 'package:chore_wars/features/house/data/datasources/season_remote_data_source.dart';
import 'package:chore_wars/features/chore/data/datasources/chore_remote_data_source.dart';
import 'package:chore_wars/features/chore/domain/entities/chore_models.dart';
import 'package:chore_wars/features/gamification/data/datasources/gamification_remote_data_source.dart';
import 'package:chore_wars/features/home/data/repositories/home_dashboard_repository.dart';
import 'package:chore_wars/features/supplies/data/datasources/supplies_remote_data_source.dart';
import 'package:chore_wars/features/supplies/data/repositories/supplies_repository_impl.dart';
import 'package:chore_wars/features/chat/data/services/chat_api_service.dart';
import 'package:chore_wars/features/chat/data/services/chat_signalr_service.dart';
import 'package:chore_wars/features/notifications/data/datasources/notification_remote_data_source.dart';

void main() {
  final base = Platform.environment['CHOREWARS_LIVE_API'] ?? '';
  const uuid = Uuid();
  test(
    'real HTTP contracts, two members, media and chat realtime',
    () async {
      final uri = Uri.parse(base);
      expect(
        ['127.0.0.1', 'localhost', '::1'],
        contains(uri.host),
        reason:
            'Live mutation tests must only use the disposable local fixture.',
      );
      BaseOptions options() => BaseOptions(
        baseUrl: base,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
      );
      final a = Dio(options());
      final b = Dio(options());
      for (final client in [a, b]) {
        client.interceptors.add(
          InterceptorsWrapper(
            onResponse: (r, handler) {
              stderr.writeln(
                '${r.requestOptions.method} ${r.requestOptions.path}: ${r.statusCode}',
              );
              handler.next(r);
            },
            onError: (e, handler) {
              stderr.writeln(
                '${e.requestOptions.method} ${e.requestOptions.path}: ${e.response?.statusCode} ${e.response?.data}',
              );
              handler.next(e);
            },
          ),
        );
      }
      addTearDown(() {
        a.close(force: true);
        b.close(force: true);
      });
      final auth = AuthRemoteDataSource(a);
      final authB = AuthRemoteDataSource(b);
      final cors = await a.request(
        '/auth/login',
        options: Options(
          method: 'OPTIONS',
          headers: {
            'Origin': 'http://localhost:7357',
            'Access-Control-Request-Method': 'POST',
            'Access-Control-Request-Headers': 'content-type',
          },
        ),
      );
      expect(
        cors.headers.value('access-control-allow-origin'),
        'http://localhost:7357',
      );
      Future<String> register(
        AuthRemoteDataSource remote,
        Dio dio,
        String name,
      ) async {
        final email = '${uuid.v4()}@test.example';
        const password = 'LocalContractPassword1!';
        await remote.register(
          email: email,
          password: password,
          displayName: name,
        );
        final user = await remote.login(email: email, password: password);
        expect(user.userId, isNotEmpty);
        dio.options.headers['Authorization'] = 'Bearer ${user.accessToken}';
        return user.accessToken;
      }

      final tokenA = await register(auth, a, 'Network A');
      final tokenB = await register(authB, b, 'Network B');
      final profile = await auth.getProfile();
      expect(
        (await auth.updateProfile(displayName: 'Network Owner')).displayName,
        'Network Owner',
      );
      final houses = HouseRemoteDataSource(a);
      final house = await houses.createHouse(name: 'QA network household');
      expect((await houses.getMyHouses()).single.id, house.id);
      await HouseRemoteDataSource(b).joinHouse(inviteCode: house.inviteCode);
      expect(await houses.getMembers(house.id), hasLength(2));
      final otherHouse = await houses.createHouse(
        name: 'QA separate household',
      );
      await expectLater(
        b.get('/houses/${otherHouse.id}'),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'status',
            403,
          ),
        ),
      );

      final chores = ChoreRemoteDataSource(a);
      final tomorrow = DateTime.now().toUtc().add(const Duration(days: 1));
      final start = DateTime.utc(tomorrow.year, tomorrow.month, tomorrow.day);
      await SeasonRemoteDataSource(a).createSeason(house.id, {
        'name': 'QA draft',
        'startDate': start.toIso8601String(),
        'endDate': start.add(const Duration(days: 7)).toIso8601String(),
        'allocationMethod': 0,
      });
      final chore = await chores.createChore(
        house.id,
        const ChoreTemplate(
          id: '',
          name: 'QA wash dishes',
          description: 'Network contract',
          karmaPoints: 10,
          type: ChoreType.normal,
          frequency: ChoreFrequency.daily,
        ),
      );
      expect((await chores.getHouseChores(house.id)).single.id, chore.id);
      expect(await chores.getMyChores(house.id), isEmpty);
      final dashboard = await HomeDashboardRepository(a).getDashboard(house.id);
      expect(dashboard.houseName, 'QA network household');
      final gamification = GamificationRemoteDataSource(a);
      await gamification.getKarma(house.id);
      await gamification.getKarmaHistory(house.id);
      await gamification.getAchievements(house.id);

      final supplies = SuppliesRepositoryImpl(SuppliesRemoteDataSource(a));
      final item = await supplies.mutate('/houses/${house.id}/shop/items', {
        'clientRequestId': uuid.v4(),
        'name': 'QA ST25',
        'unit': 'bag',
        'price': 100000,
        'contactName': 'QA shop',
        'phone': '0900000000',
        'email': 'qa-shop@test.example',
      });
      final supplier = item['supplier']['id'] as String;
      expect(
        await supplies.list('/houses/${house.id}/shop/suppliers'),
        hasLength(1),
      );
      expect(await supplies.products(supplier), hasLength(1));
      expect(await supplies.orders(house.id), isEmpty);
      expect((await supplies.debts(house.id))['debts'], isEmpty);
      final today = DateTime.now()
          .toUtc()
          .add(const Duration(hours: 7))
          .toIso8601String()
          .substring(0, 10);
      for (final path in [
        '/houses/${house.id}/calendar',
        '/houses/${house.id}/summary',
        '/houses/${house.id}/me/payment-history',
      ]) {
        final response = await a.get(
          path,
          queryParameters: {'from': today, 'to': today},
        );
        expect(response.data, isA<Map>());
      }
      final inbox = NotificationRemoteDataSourceImpl(a);
      await inbox.getNotifications();
      await inbox.markAllAsRead();
      final negotiated = await a.post(
        '${uri.origin}/hubs/notifications/negotiate',
        queryParameters: {'negotiateVersion': 1},
      );
      expect(negotiated.data['availableTransports'], isNotEmpty);

      final apiA = ChatApiService(a);
      final room = await apiA.getHouseRoom(house.id);
      expect((await ChatApiService(b).getHouseRoom(house.id)).id, room.id);
      final realtimeA = ChatSignalRService(
        baseUrl: base,
        getToken: () async => tokenA,
      );
      final realtimeB = ChatSignalRService(
        baseUrl: base,
        getToken: () async => tokenB,
      );
      addTearDown(() async {
        await realtimeA.disconnect(room.id);
        await realtimeB.disconnect(room.id);
      });
      final received = Completer<String>();
      await realtimeA.connect(room.id, (_) {});
      await realtimeB.connect(room.id, (message) {
        if (message.content == 'QA live message' && !received.isCompleted) {
          received.complete(message.id);
        }
      });
      final sent = await realtimeA.sendMessage(
        room.id,
        'QA live message',
        uuid.v4(),
      );
      expect(
        await received.future.timeout(const Duration(seconds: 15)),
        sent.id,
      );
      expect(
        (await apiA.getMessages(room.id)).items.any((m) => m.id == sent.id),
        isTrue,
      );
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aWZkAAAAASUVORK5CYII=',
      );
      final avatar = await auth.uploadAvatar(png, 'qa-avatar.png');
      expect(avatar.avatarUrl, isNotEmpty);
      expect(
        (await a.get<List<int>>(
          '/user/avatar-image',
          options: Options(responseType: ResponseType.bytes),
        )).data,
        png,
      );
      final photo = await apiA.sendMedia(
        room.id,
        png,
        'qa-photo.png',
        uuid.v4(),
      );
      expect(photo.id, isNotEmpty);
      expect(
        (await a.get<List<int>>(
          '/media/${photo.attachmentId}',
          options: Options(responseType: ResponseType.bytes),
        )).data,
        png,
      );
      final photos = await a.get('/chat/rooms/${room.id}/photos');
      expect(photos.statusCode, 200);
      expect((await auth.getProfile()).id, profile.id);
    },
    skip: base.isEmpty
        ? 'Requires the disposable Kestrel/Postgres fixture.'
        : false,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

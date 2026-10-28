import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/session_provider.dart';
import '../../domain/entities/house_calendar_models.dart';

typedef CalendarRange = ({String houseId, DateTime from, DateTime to});
final houseCalendarProvider = FutureProvider.autoDispose
    .family<List<HouseCalendarDay>, CalendarRange>((ref, range) async {
      ref.watch(sessionEpochProvider);
      final response = await ref
          .watch(dioProvider)
          .get<Map<String, dynamic>>(
            '/houses/${range.houseId}/calendar',
            queryParameters: {
              'from': DateFormat('yyyy-MM-dd').format(range.from),
              'to': DateFormat('yyyy-MM-dd').format(range.to),
            },
          );
      return (response.data!['days'] as List)
          .map(
            (v) =>
                HouseCalendarDay.fromJson(Map<String, dynamic>.from(v as Map)),
          )
          .toList();
    }, retry: (retryCount, error) => null);

typedef CalendarPhoto = ({String houseId, String evidenceId, bool thumbnail});
final calendarPhotoProvider = FutureProvider.autoDispose
    .family<Uint8List, CalendarPhoto>((ref, key) async {
      ref.watch(sessionEpochProvider);
      final response = await ref
          .watch(dioProvider)
          .get<List<int>>(
            '/evidence/${key.evidenceId}${key.thumbnail ? '/thumbnail' : ''}',
            options: Options(responseType: ResponseType.bytes),
          );
      return Uint8List.fromList(response.data!);
    });

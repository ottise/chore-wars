import 'dart:async';

import 'package:dio/dio.dart';

class RequestCooldown {
  RequestCooldown(this.onChanged);
  final void Function() onChanged;
  Timer? _timer;
  int seconds = 0;

  void start(int duration) {
    _timer?.cancel();
    seconds = duration.clamp(1, 3600);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      seconds--;
      if (seconds == 0) timer.cancel();
      onChanged();
    });
  }

  void afterError(Object error, {int fallback = 60}) {
    final retry = error is DioException
        ? int.tryParse(error.response?.headers.value('retry-after') ?? '')
        : null;
    start(retry ?? fallback);
  }

  void dispose() => _timer?.cancel();
}

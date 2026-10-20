import 'package:flutter_riverpod/flutter_riverpod.dart';

class SessionEpoch extends Notifier<int> {
  @override
  int build() => 0;
  void advance() => state++;
}

final sessionEpochProvider = NotifierProvider<SessionEpoch, int>(
  SessionEpoch.new,
);

final sessionExpiryProvider = NotifierProvider<SessionEpoch, int>(
  SessionEpoch.new,
);

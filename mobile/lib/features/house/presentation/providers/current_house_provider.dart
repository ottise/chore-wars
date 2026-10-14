import 'package:flutter_riverpod/flutter_riverpod.dart';

class CurrentHouseNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setHouse(String houseId) {
    state = houseId;
  }
}

final currentHouseProvider = NotifierProvider<CurrentHouseNotifier, String?>(CurrentHouseNotifier.new);

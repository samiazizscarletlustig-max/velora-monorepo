import 'package:flutter/foundation.dart';
import '../../data/tier_repository.dart';

class TierProvider extends ChangeNotifier {
  String _tier = 'free';
  bool _loading = false;

  String get tier => _tier;
  bool get loading => _loading;
  bool get isFree => _tier == 'free';
  bool get isPro => _tier == 'pro';
  bool get isProPlus => _tier == 'pro_plus';
  bool get isEnterprise => _tier == 'enterprise';

  int get maxCompetitors => TierRepository.getMaxCompetitors(_tier);

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _tier = await TierRepository.getCurrentUserTier();
    _loading = false;
    notifyListeners();
  }
}
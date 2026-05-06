import 'package:flutter/foundation.dart';

/// Oturum değiştiğinde GoRouter redirect'ini tetikler (login / refresh başarısız / logout).
class SessionListenable extends ChangeNotifier {
  void notifySessionChanged() => notifyListeners();
}

final sessionListenable = SessionListenable();

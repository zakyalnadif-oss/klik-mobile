import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/app_config.dart';

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);

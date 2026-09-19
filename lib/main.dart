import 'package:flutter/material.dart';

import 'app.dart';
import 'configs/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Env.load();
  runApp(const MyApp());
}

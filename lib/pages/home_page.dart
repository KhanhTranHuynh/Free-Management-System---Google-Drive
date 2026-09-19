import 'package:flutter/material.dart';

import '../views/home/home_header_view.dart';
import '../views/settings/theme_mode_view.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              HomeHeaderView(),
              Divider(),
              ThemeModeView(),
            ],
          ),
        ),
      ),
    );
  }
}
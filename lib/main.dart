import 'package:flutter/material.dart';

import 'jigsaw_home_page.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jigsaw',
      theme: ThemeData.from(
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.blueGrey,
          primaryColorDark: Colors.blueGrey.shade700,
          backgroundColor: Colors.blueGrey.shade100,
          accentColor: Colors.red,
          cardColor: Colors.yellow,
          errorColor: Colors.orange,
          brightness: Brightness.light,
        ),
        textTheme: Typography.englishLike2018,
      ).copyWith(
        splashFactory: InkRipple.splashFactory,
      ),
      home: JigsawHomePage(),
    );
  }
}

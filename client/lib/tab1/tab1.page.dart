import 'package:flutter/material.dart';
import 'package:audioloca/global/mini.player.dart';

class Tab1 extends StatelessWidget {
  const Tab1({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Tab 1')),
      body: Center(child: Text('Welcome to Tab 1')),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

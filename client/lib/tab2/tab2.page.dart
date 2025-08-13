import 'package:flutter/material.dart';
import 'package:audioloca/global/mini.player.dart';

class Tab2 extends StatelessWidget {
  const Tab2({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Tab 2')),
      body: Center(child: Text('Welcome to Tab 2')),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

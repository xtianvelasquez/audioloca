import 'package:flutter/material.dart';
import 'package:audioloca/player/views/mini.player.dart';

class Tab5 extends StatelessWidget {
  const Tab5({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Tab 5')),
      body: Center(child: Text('Welcome to Tab 5')),
      bottomNavigationBar: const MiniPlayer(),
    );
  }
}

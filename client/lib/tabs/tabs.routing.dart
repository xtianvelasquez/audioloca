import 'package:flutter/material.dart';
import 'package:audioloca/tab1/tab1.page.dart';
import 'package:audioloca/tab2/tab2.page.dart';
import 'package:audioloca/tab3/tab3.page.dart';
import 'package:audioloca/tab4/tab4.page.dart';
import 'package:audioloca/tab5/tab5.page.dart';
import 'package:audioloca/theme.dart';

class TabsRouting extends StatefulWidget {
  const TabsRouting({super.key});

  @override
  State<TabsRouting> createState() => TabsRoutingState();
}

class TabsRoutingState extends State<TabsRouting> {
  int selectedIndex = 0;

  final List<Widget> pages = [Tab1(), Tab2(), Tab3(), Tab4(), Tab5()];

  void onItemTapped(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: selectedIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: onItemTapped,
        selectedItemColor: AppColors.color1,
        unselectedItemColor: AppColors.color2,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Explore'),
          BottomNavigationBarItem(
            icon: Icon(Icons.library_music),
            label: 'Audio',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

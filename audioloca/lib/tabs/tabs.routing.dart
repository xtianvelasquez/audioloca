import 'package:flutter/material.dart';
import 'package:audioloca/tab1/tab1.page.dart';
import 'package:audioloca/tab2/tab2.page.dart';
import 'package:audioloca/tab3/tab3.page.dart';
import 'package:audioloca/tab4/tab4.page.dart';
import 'package:audioloca/tab5/tab5.page.dart';
import 'package:audioloca/theme.dart';

class TabsRouting extends StatefulWidget {
  const TabsRouting({super.key});

  static TabsRoutingState? of(BuildContext context) =>
      context.findAncestorStateOfType<TabsRoutingState>();

  @override
  State<TabsRouting> createState() => TabsRoutingState();
}

class TabsRoutingState extends State<TabsRouting> {
  int selectedIndex = 0;

  final List<Widget> pages = const [
    Tab1(),
    Tab2(),
    Tab3(),
    Tab4(),
    Tab5(),
  ];

  void onItemTapped(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  void setTab(int index) {
    if (index >= 0 && index < pages.length) {
      setState(() {
        selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMid,
      body: IndexedStack(
        index: selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.only(left: 14, right: 14, bottom: 12, top: 8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowDark.withValues(alpha: 0.1),
              offset: const Offset(0, -6),
              blurRadius: 18,
            ),
          ],
        ),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: const Color(0xFFFBF9FF),
            borderRadius: BorderRadius.circular(34),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.9),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowDark.withValues(alpha: 0.22),
                offset: const Offset(0, 8),
                blurRadius: 16,
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.white,
                offset: const Offset(0, -3),
                blurRadius: 10,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(0, Icons.home_rounded, 'Home'),
              _buildNavItem(1, Icons.search_rounded, 'Search'),
              _buildNavItem(2, Icons.photo_camera_rounded, 'Camera'),
              _buildNavItem(3, Icons.library_music_rounded, 'Audio'),
              _buildNavItem(4, Icons.person_rounded, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = selectedIndex == index;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onItemTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 14 : 10,
          vertical: 6,
        ),
        decoration: isSelected
            ? BoxDecoration(
                color: AppColors.pillBg.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadowDark.withValues(alpha: 0.15),
                    offset: const Offset(1, 3),
                    blurRadius: 6,
                  ),
                  const BoxShadow(
                    color: Colors.white,
                    offset: Offset(-1, -1),
                    blurRadius: 4,
                  ),
                ],
              )
            : const BoxDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: isSelected ? 22 : 20,
              color: isSelected ? AppColors.primaryPurple : AppColors.textSecondary,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.primaryPurple : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:rakoon_frontend/features/app_shell/presentation/pages/home_screen.dart';
import 'package:rakoon_frontend/features/profile/presentation/pages/profile_page.dart';
import 'package:rakoon_frontend/features/scan/scan_camera_screen.dart';
import 'package:rakoon_frontend/theme/app_theme.dart';

class AppShell extends StatefulWidget {
  final String? baseUrl;
  final http.Client? httpClient;

  const AppShell({super.key, this.baseUrl, this.httpClient});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  final GlobalKey<HomeScreenState> _homeKey = GlobalKey<HomeScreenState>();

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 0) {
      _homeKey.currentState?.fetchRecentScans();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool showBottomNav = _selectedIndex != 1; // Hide during Scan camera screen

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomeScreen(
            key: _homeKey,
            baseUrl: widget.baseUrl,
            httpClient: widget.httpClient,
          ),
          ScanCameraScreen(
            baseUrl: widget.baseUrl ?? 'http://10.0.2.2:8000',
            onClose: () => _onItemTapped(0),
            isActive: _selectedIndex == 1,
          ),
          const ProfilePage(),
        ],
      ),
      bottomNavigationBar: showBottomNav
          ? Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16.0,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildNavItem(0, Icons.home_outlined, Icons.home_rounded, 'Home'),
                      _buildScanNavItem(1),
                      _buildNavItem(2, Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
                    ],
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildNavItem(
    int index,
    IconData iconOutlined,
    IconData iconFilled,
    String label,
  ) {
    final bool isActive = _selectedIndex == index;
    final IconData icon = isActive ? iconFilled : iconOutlined;
    const Color activeColor = Color(0xFF00A86B);
    const Color inactiveColor = Color(0xFF9CA3AF);

    return Semantics(
      label: '${label.toUpperCase()} Tab',
      selected: isActive,
      child: GestureDetector(
        key: Key('nav_tab_$index'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _onItemTapped(index),
        child: SizedBox(
          width: 72,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isActive ? activeColor : inactiveColor,
                  size: 24,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? activeColor : inactiveColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScanNavItem(int index) {
    const Color activeColor = Color(0xFF00A86B);

    return Semantics(
      label: 'SCAN Tab',
      selected: _selectedIndex == index,
      child: GestureDetector(
        key: Key('nav_tab_$index'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _onItemTapped(index),
        child: SizedBox(
          width: 76,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.4),
                      blurRadius: 12.0,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.crop_free_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Scan',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: activeColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

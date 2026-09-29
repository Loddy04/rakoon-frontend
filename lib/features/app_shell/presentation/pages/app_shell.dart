import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:rakoon_frontend/features/app_shell/presentation/pages/home_screen.dart';
import 'package:rakoon_frontend/features/profile/presentation/pages/profile_page.dart';
import 'package:rakoon_frontend/features/scan/scan_camera_screen.dart';
import 'package:rakoon_frontend/widgets/interactive_scale.dart';

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
      backgroundColor: const Color(0xFFFAF7F2),
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
          ? ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xE6FAF7F2), // rgba(250, 247, 242, 0.9)
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
                    border: const Border(
                      top: BorderSide(
                        color: Color(0xFFE8E4DC),
                        width: 1.0,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
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
    const Color activeColor = Color(0xFF0D2818);
    const Color inactiveColor = Color(0xFF6B6B6B);

    return InteractiveScale(
      onTap: () => _onItemTapped(index),
      child: Semantics(
        label: '${label.toUpperCase()} Tab',
        selected: isActive,
        child: Container(
          key: Key('nav_tab_$index'),
          width: 72,
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          color: Colors.transparent,
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
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? activeColor : inactiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanNavItem(int index) {
    return InteractiveScale(
      onTap: () => _onItemTapped(index),
      child: Semantics(
        label: 'SCAN Tab',
        selected: _selectedIndex == index,
        child: Container(
          key: Key('nav_tab_$index'),
          width: 76,
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0D2818), Color(0xFF2E6644)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0D2818).withValues(alpha: 0.35),
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
              Text(
                'Scan',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0D2818),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


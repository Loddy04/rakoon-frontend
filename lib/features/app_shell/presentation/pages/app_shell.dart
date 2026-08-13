import 'package:flutter/material.dart';
import 'package:rakoon_frontend/features/app_shell/presentation/pages/home_screen.dart';
import 'package:rakoon_frontend/features/scan/scan_camera_screen.dart';
import 'package:rakoon_frontend/features/profile/presentation/pages/profile_page.dart';
import 'package:rakoon_frontend/theme/app_theme.dart';

class AppShell extends StatefulWidget {
  final String? baseUrl;
  const AppShell({super.key, this.baseUrl});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool showBottomNav = _selectedIndex != 1; // Hide during Scan tab

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomeScreen(baseUrl: widget.baseUrl),
          ScanCameraScreen(
            baseUrl: widget.baseUrl ?? 'http://10.0.2.2:8000',
            onClose: () => _onItemTapped(0),
          ),
          const ProfilePage(),
        ],
      ),
      bottomNavigationBar: showBottomNav
          ? Container(
              decoration: const BoxDecoration(
                color: AppColors.paper,
                border: Border(
                  top: BorderSide(color: AppColors.line, width: 1.0),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10.0, bottom: 20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildNavItem(0, Icons.home_outlined, Icons.home, 'Home'),
                      _buildNavItem(
                        1,
                        Icons.qr_code_scanner_outlined,
                        Icons.qr_code_scanner,
                        'Scan',
                      ),
                      _buildNavItem(
                        2,
                        Icons.person_outline,
                        Icons.person,
                        'Profil',
                      ),
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

    return Semantics(
      label: '$label Tab',
      selected: isActive,
      child: GestureDetector(
        key: Key('nav_tab_$index'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _onItemTapped(index),
        child: SizedBox(
          width: 72, // Ensure tap target is large enough (width/height >= 48dp)
          height: 48,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 30,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.ink : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.l),
                ),
                child: Icon(
                  icon,
                  color: isActive ? AppColors.paper : AppColors.muted,
                  size: 20,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isActive ? AppColors.ink : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

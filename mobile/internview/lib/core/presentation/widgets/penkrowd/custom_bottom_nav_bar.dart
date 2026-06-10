import 'package:flutter/material.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const CustomBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      height: 80 + bottomPadding,
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Background bar
          Container(
            height: 80 + bottomPadding,
            decoration: const BoxDecoration(
              color: Color(0xFFFAFAFA),
              border: Border(top: BorderSide(color: Colors.black, width: 3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black,
                  blurRadius: 0,
                  offset: Offset(0, -2),
                ),
              ],
            ),
          ),
          // Nav items
          Padding(
            padding: EdgeInsets.only(bottom: bottomPadding + 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _NavItem(
                  index: 0,
                  selectedIndex: selectedIndex,
                  icon: Icons.home,
                  selectedColor: const Color(0xFF00E5FF),
                  onTap: onItemSelected,
                ),
                _NavItem(
                  index: 1,
                  selectedIndex: selectedIndex,
                  icon: Icons.calendar_month,
                  selectedColor: const Color(0xFFFFD600),
                  onTap: onItemSelected,
                ),
                _NavItem(
                  index: 2,
                  selectedIndex: selectedIndex,
                  icon: Icons.storefront,
                  selectedColor: const Color(0xFFFF9100),
                  onTap: onItemSelected,
                ),
                _NavItem(
                  index: 3,
                  selectedIndex: selectedIndex,
                  icon: Icons.person,
                  selectedColor: const Color(0xFFB388FF),
                  onTap: onItemSelected,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final int index;
  final int selectedIndex;
  final IconData icon;
  final Color selectedColor;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.index,
    required this.selectedIndex,
    required this.icon,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 58,
        height: 50,
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: isSelected ? Border.all(color: Colors.black, width: 3) : null,
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Colors.black,
                    blurRadius: 0,
                    offset: Offset(2, 2),
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          color: isSelected
              ? Colors.black
              : Colors.black.withValues(alpha: 0.65),
          size: 26,
        ),
      ),
    );
  }
}

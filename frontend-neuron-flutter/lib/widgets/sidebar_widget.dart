import 'package:flutter/material.dart';

class SidebarWidget extends StatelessWidget {
  final String userName;
  final String? profilePhotoUrl;
  final bool isDarkMode;
  final String selectedNavItem;
  final ValueChanged<String> onNavItemSelect;
  final String selectedWorkspace;
  final ValueChanged<String> onWorkspaceSelect;
  final List<Map<String, dynamic>> workspaces;
  final VoidCallback onAddWorkspace;
  final VoidCallback onLogout;

  const SidebarWidget({
    super.key,
    required this.userName,
    this.profilePhotoUrl,
    required this.isDarkMode,
    required this.selectedNavItem,
    required this.onNavItemSelect,
    required this.selectedWorkspace,
    required this.onWorkspaceSelect,
    required this.workspaces,
    required this.onAddWorkspace,
    required this.onLogout,
  });

  static const List<String> navItems = [
    'Home',
    'Chat',
    'Knowledge',
    'Connections',
    'Timeline',
    'Reflection',
    'Tasks',
    'Settings',
  ];

  static const Map<String, IconData> navIcons = {
    'Home': Icons.home_rounded,
    'Chat': Icons.chat_bubble_outline_rounded,
    'Knowledge': Icons.menu_book_rounded,
    'Connections': Icons.hub_outlined,
    'Timeline': Icons.timeline_rounded,
    'Reflection': Icons.history_rounded,
    'Tasks': Icons.check_box_outlined,
    'Settings': Icons.settings_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = isDarkMode ? const Color(0xFF22272E) : const Color(0xFFE5E7EB);
    final sidebarBg = isDarkMode ? const Color(0xFF10141B) : Colors.white;

    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: sidebarBg,
        border: Border(right: BorderSide(color: borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 20),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.psychology_alt_outlined,
                    size: 32,
                    color: Color(0xFFA78BFA),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Neuron',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      'Your Second Brain',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Nav links
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                ...navItems.map((item) {
                  final isSelected = selectedNavItem == item;
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDarkMode
                              ? const Color(0xFF261E3E)
                              : const Color(0xFFEDE9FE))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListTile(
                      dense: true,
                      horizontalTitleGap: 10,
                      leading: Icon(
                        navIcons[item],
                        size: 20,
                        color: isSelected
                            ? theme.primaryColor
                            : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                      ),
                      title: Text(
                        item,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected
                              ? (isDarkMode ? Colors.white : theme.primaryColor)
                              : (isDarkMode ? Colors.grey[300] : Colors.grey[700]),
                        ),
                      ),
                      onTap: () => onNavItemSelect(item),
                    ),
                  );
                }),
                const SizedBox(height: 24),

                // Workspaces Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Workspaces',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: onAddWorkspace,
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Icon(
                            Icons.add,
                            size: 16,
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Workspaces List
                ...workspaces.map((ws) {
                  final isSelected = selectedWorkspace == ws['name'];
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDarkMode
                              ? const Color(0xFF261E3E)
                              : const Color(0xFFEDE9FE))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListTile(
                      dense: true,
                      horizontalTitleGap: 10,
                      leading: CircleAvatar(
                        radius: 10,
                        backgroundColor: ws['color'] as Color,
                        child: Text(
                          ws['badge'] as String,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        ws['name'] as String,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected
                              ? (isDarkMode ? Colors.white : theme.primaryColor)
                              : (isDarkMode ? Colors.grey[300] : Colors.grey[700]),
                        ),
                      ),
                      onTap: () => onWorkspaceSelect(ws['name'] as String),
                    ),
                  );
                }),
              ],
            ),
          ),

          // User Profile at bottom
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                CircleAvatar(
  radius: 16,
  backgroundColor:
      isDarkMode ? const Color(0xFF2D333B) : const Color(0xFFE2E8F0),
  backgroundImage:
      profilePhotoUrl != null && profilePhotoUrl!.isNotEmpty
          ? NetworkImage(profilePhotoUrl!)
          : null,
  child: profilePhotoUrl == null || profilePhotoUrl!.isEmpty
      ? Text(
          userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        )
      : null,
),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Premium Plan',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                  onSelected: (val) {
                    if (val == 'logout') {
                      onLogout();
                    } else if (val == 'settings') {
                      onNavItemSelect('Settings');
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'settings',
                      child: Row(
                        children: [
                          Icon(Icons.settings_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Settings'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Log out', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

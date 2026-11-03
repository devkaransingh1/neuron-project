import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/sidebar_widget.dart';
import '../widgets/common_widgets.dart';
import 'landing_screen.dart';
import 'chat_screen.dart';
import 'knowledge_screen.dart';
import 'connections_screen.dart';
import 'timeline_screen.dart';
import 'reflection_screen.dart';
import 'tasks_screen.dart';
import 'settings_screen.dart';

class NeuronDashboard extends StatefulWidget {
  final String userName;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final VoidCallback onLogout;

  const NeuronDashboard({
    super.key,
    required this.userName,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.onLogout,
  });

  @override
  State<NeuronDashboard> createState() => _NeuronDashboardState();
}

class _NeuronDashboardState extends State<NeuronDashboard> {
  String selectedNavItem = 'Home';
  String selectedWorkspace = 'Personal';
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  Map<String, dynamic>? userProfile;
bool isProfileLoading = true;

@override
void initState() {
  super.initState();
  _loadUserProfile();
}

Future<void> _loadUserProfile() async {
  try {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final document = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!mounted) return;

    setState(() {
      userProfile = document.data();
      debugPrint('Neuron User Profile: $userProfile');
      isProfileLoading = false;
    });
  } catch (e) {
    if (!mounted) return;

    setState(() {
      isProfileLoading = false;
    });

    debugPrint('Error loading user profile: $e');
  }
}

  final List<Map<String, dynamic>> workspaces = [
    {'name': 'Personal', 'color': const Color(0xFF8B5CF6), 'badge': 'P'},
    {'name': 'College', 'color': const Color(0xFF10B981), 'badge': 'C'},
    {'name': 'Projects', 'color': const Color(0xFFF59E0B), 'badge': 'P'},
    {'name': 'Research', 'color': const Color(0xFF3B82F6), 'badge': 'R'},
  ];

  @override
  void dispose() {
    _promptController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showNotification(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _submitPrompt() {
    final query = _promptController.text.trim();
    if (query.isNotEmpty) {
      _showNotification('Sent to Neuron: "$query"');
      _promptController.clear();
    }
  }

  void _addWorkspaceDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Workspace'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Workspace Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                setState(() {
                  workspaces.add({
                    'name': nameController.text.trim(),
                    'color': const Color(0xFFEC4899),
                    'badge': nameController.text.trim()[0].toUpperCase(),
                  });
                });
                Navigator.pop(ctx);
                _showNotification('Added workspace: ${nameController.text.trim()}');
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedScreen() {
    switch (selectedNavItem) {
      case 'Home':
        return LandingContentWidget(
          userName: widget.userName,
          isDarkMode: widget.isDarkMode,
          promptController: _promptController,
          onSubmitPrompt: _submitPrompt,
          onPromptSelect: (prompt) {
            _promptController.text = prompt;
            _submitPrompt();
          },
          onNotification: _showNotification,
        );
      case 'Chat':
        return ChatScreen(isDarkMode: widget.isDarkMode);
      case 'Knowledge':
        return KnowledgeScreen(isDarkMode: widget.isDarkMode);
      case 'Connections':
        return ConnectionsScreen(isDarkMode: widget.isDarkMode);
      case 'Timeline':
        return TimelineScreen(isDarkMode: widget.isDarkMode);
      case 'Reflection':
        return ReflectionScreen(isDarkMode: widget.isDarkMode);
      case 'Tasks':
        return TasksScreen(isDarkMode: widget.isDarkMode);
      case 'Settings':
        return SettingsScreen(
          isDarkMode: widget.isDarkMode,
          onToggleTheme: widget.onToggleTheme,
          onLogout: widget.onLogout,
          userName: widget.userName,
        );
      default:
        return Center(
          child: Text(
            'Page: $selectedNavItem',
            style: TextStyle(
              fontSize: 18,
              color: widget.isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          SidebarWidget(
            userName: widget.userName,
            profilePhotoUrl: userProfile?['photoURL'] as String?,
            isDarkMode: widget.isDarkMode,
            selectedNavItem: selectedNavItem,
            onNavItemSelect: (item) {
              setState(() {
                selectedNavItem = item;
              });
            },
            selectedWorkspace: selectedWorkspace,
            onWorkspaceSelect: (ws) {
              setState(() {
                selectedWorkspace = ws;
              });
              _showNotification('Switched to workspace: $ws');
            },
            workspaces: workspaces,
            onAddWorkspace: _addWorkspaceDialog,
            onLogout: widget.onLogout,
          ),

          // Main Center Area
          Expanded(
            child: Column(
              children: [
                // Top Search & Theme Action Bar
                AppHeaderBar(
                  title: selectedNavItem,
                  isDarkMode: widget.isDarkMode,
                  onToggleTheme: widget.onToggleTheme,
                  searchController: _searchController,
                  onSearch: (val) {
                    if (val.trim().isNotEmpty) {
                      _showNotification('Searching: "$val"');
                    }
                  },
                  onNotificationsClick: () => _showNotification('No new notifications'),
                ),

                // Main Content View
                Expanded(
                  child: _buildSelectedScreen(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

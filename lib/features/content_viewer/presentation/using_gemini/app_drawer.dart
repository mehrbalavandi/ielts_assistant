import 'package:flutter/material.dart';
import 'package:ielts_assistant/features/content_viewer/presentation/using_gemini/settings_screen.dart'; // مسیر را تنظیم کنید

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.indigo,
            padding: const EdgeInsets.only(top: 60, bottom: 20),
            child: const Column(
              children: [
                Icon(Icons.library_books, size: 60, color: Colors.white),
                SizedBox(height: 12),
                Text(
                  "IELTS Assistant",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text("تنظیمات"),
            onTap: () {
              Navigator.pop(context); // بستن دراور
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}

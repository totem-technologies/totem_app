import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  // Stub toggle states
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  bool _sessionReminders = true;
  bool _newSpaceNotifications = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Settings')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsetsDirectional.all(16),
            child: Text(
              'Manage your notification preferences',
              style: TextStyle(fontSize: 16),
            ),
          ),

          SwitchListTile(
            title: const Text('Email Notifications'),
            subtitle: const Text('Receive updates via email'),
            value: _emailNotifications,
            onChanged: (value) {
              setState(() {
                _emailNotifications = value;
              });
            },
          ),

          SwitchListTile(
            title: const Text('Push Notifications'),
            subtitle: const Text('Receive alerts on your device'),
            value: _pushNotifications,
            onChanged: (value) {
              setState(() {
                _pushNotifications = value;
              });
            },
          ),

          const Divider(),
          const Padding(
            padding: EdgeInsetsDirectional.all(16),
            child: Text(
              'Notification Types',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

          SwitchListTile(
            title: const Text('Session Reminders'),
            subtitle: const Text('Get notified before your sessions start'),
            value: _sessionReminders,
            onChanged: (value) {
              setState(() {
                _sessionReminders = value;
              });
            },
          ),

          SwitchListTile(
            title: const Text('New Space Announcements'),
            subtitle: const Text('Be notified when new spaces are available'),
            value: _newSpaceNotifications,
            onChanged: (value) {
              setState(() {
                _newSpaceNotifications = value;
              });
            },
          ),

          const Padding(
            padding: EdgeInsetsDirectional.all(16),
            child: Text(
              "Note: These settings are just placeholders and don't affect "
              'anything in this demo.',
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}

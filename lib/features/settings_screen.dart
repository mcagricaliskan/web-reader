import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../core/local_reset.dart';
import '../providers.dart';
import '../storage/cleanup.dart';
import '../ui/status_style.dart';
import 'cleanup_dialogs.dart';
import 'library_screen.dart' show formatBytes;

/// Settings is a list of doors, not a control panel. Everything that changes
/// behaviour lives where the behaviour is; this screen only points at the two
/// stores of accumulated state — taught rules and task history.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(siteRulesStreamProvider).value;
    final tasks = ref.watch(queueTasksProvider).value;
    final chapters = ref.watch(chaptersStreamProvider).value;
    final storedBytes =
        chapters?.fold<int>(0, (sum, c) => sum + c.byteSize) ?? 0;
    final offlineChapters =
        chapters?.where((c) => c.contentPath != null).length ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const SectionLabel('STORAGE'),
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('Storage'),
            subtitle: Text(
              chapters == null
                  ? 'Loading…'
                  : '${formatBytes(storedBytes)} used · $offlineChapters '
                        'chapter${offlineChapters == 1 ? '' : 's'} offline',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => LeaveBrowserGuard.push(context, '/storage'),
          ),
          Consumer(
            builder: (context, ref, _) {
              final pref =
                  ref.watch(afterFinishedPrefProvider).value ??
                  AfterFinishedPref.ask;
              return ListTile(
                leading: const Icon(Icons.auto_delete),
                title: const Text('After finishing a chapter'),
                subtitle: Text(switch (pref) {
                  AfterFinishedPref.ask => 'Ask each time',
                  AfterFinishedPref.keep => 'Keep offline',
                  AfterFinishedPref.remove => 'Remove automatically',
                }),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showAfterFinishedSheet(context, ref),
              );
            },
          ),
          const SectionLabel('CAPTURE & SOURCES'),
          ListTile(
            leading: const Icon(Icons.ads_click),
            title: const Text('Saved rules'),
            subtitle: Text(
              rules == null
                  ? 'Loading…'
                  : '${rules.length} site${rules.length == 1 ? '' : 's'} taught',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => LeaveBrowserGuard.push(context, '/rules'),
          ),
          ListTile(
            leading: const Icon(Icons.list_alt),
            title: const Text('Activity history'),
            subtitle: Text(
              tasks == null
                  ? 'Loading…'
                  : '${tasks.length} task${tasks.length == 1 ? '' : 's'} · '
                        'bounded to ${ref.read(taskQueueProvider).historyLimit}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => LeaveBrowserGuard.push(context, '/activity'),
          ),
          if (developerToolsAvailable) ...[
            const SectionLabel('DEVELOPER'),
            ListTile(
              key: const ValueKey('developerTools'),
              leading: const Icon(Icons.construction),
              title: const Text('Developer'),
              subtitle: const Text('Debug build only · reset local data'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => LeaveBrowserGuard.push(context, '/developer'),
            ),
          ],
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Text(
              'Everything is stored on this device. There is no account, no '
              'sync and no background network activity — captures and update '
              'checks only run when you start them.',
              style: TextStyle(
                fontSize: 13,
                height: 1.55,
                color: Color(0xFF5F5B54),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../browser/saved_sites_repository.dart';
import '../core/local_reset.dart';
import '../providers.dart';
import '../storage/cleanup.dart';
import '../ui/status_style.dart';
import 'appearance_selector.dart';
import 'browser_data_dialogs.dart';
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

    final savedSites = ref.watch(savedSitesProvider).value;
    final visits = ref.watch(browsingHistoryProvider).value;
    final hosts = ref.watch(visitedHostsProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const SectionLabel('APPEARANCE'),
          const AppearanceSelector(),
          const SectionLabel('BROWSER'),
          ListTile(
            key: const ValueKey('settingsBrowsingHistory'),
            leading: const Icon(Icons.history),
            title: const Text('Browsing history'),
            subtitle: Text(
              visits == null
                  ? 'Loading…'
                  : visits.isEmpty
                  ? 'Nothing visited yet'
                  : '${visits.length} page${visits.length == 1 ? '' : 's'} · '
                        '${hosts?.length ?? 0} '
                        'site${(hosts?.length ?? 0) == 1 ? '' : 's'}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => LeaveBrowserGuard.push(context, '/history'),
          ),
          ListTile(
            key: const ValueKey('settingsSavedSites'),
            leading: const Icon(Icons.bookmark),
            title: const Text('Saved sites'),
            subtitle: Text(
              savedSites == null
                  ? 'Loading…'
                  : savedSites.isEmpty
                  ? 'None saved yet'
                  : '${savedSites.length} '
                        'site${savedSites.length == 1 ? '' : 's'} · '
                        '${savedSites.take(2).map(savedSiteDisplayTitle).join(', ')}'
                        '${savedSites.length > 2 ? '…' : ''}',
            ),
            trailing: const Icon(Icons.chevron_right),
            // Saved sites live on Browser Home; this is a door to it, not a
            // second copy of the same list.
            onTap: () async {
              if (!await LeaveBrowserGuard.confirmLeave(context)) return;
              ref.read(browserPresentationProvider).requestHome();
              ref.read(shellTabRequestProvider).value = 1;
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          ListTile(
            key: const ValueKey('settingsClearWebsiteData'),
            leading: Icon(
              Icons.no_encryption,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Clear website data',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            subtitle: const Text(
              'Signs you out of sites · cookies and site storage',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showClearWebsiteDataDialog(context, ref),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Text(
              'Browsing history and saved sites never leave this device. '
              'History is kept for 90 days, or 5,000 pages — whichever comes '
              'first — and you can clear it at any time.',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: Color(0xFF8C877E),
              ),
            ),
          ),
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

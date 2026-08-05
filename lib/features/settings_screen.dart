import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../browser/saved_sites_repository.dart';
import '../capability/foreground_multitasking.dart';
import '../core/local_reset.dart';
import '../providers.dart';
import '../ui/palette.dart';
import '../ui/status_style.dart';
import 'appearance_selector.dart';
import 'browser_data_dialogs.dart';
import 'library_screen.dart' show formatBytes;
import '../library/entry_labels.dart';

/// Settings is a list of doors, not a control panel. Everything that changes
/// behaviour lives where the behaviour is; this screen only points at the two
/// stores of accumulated state — taught rules and task history.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(pageHintsStreamProvider).value;
    final tasks = ref.watch(queueTasksProvider).value;
    final entries = ref.watch(entriesStreamProvider).value;
    final storedBytes =
        entries?.fold<int>(0, (sum, c) => sum + c.byteSize) ?? 0;
    final offlineEntries =
        entries?.where((c) => c.contentPath != null).length ?? 0;

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
          _SettingsNote(
            'Browsing history and saved sites never leave this device. '
            'History is kept for 90 days, or 5,000 pages — whichever comes '
            'first — and you can clear it at any time.',
          ),
          const SectionLabel('STORAGE'),
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('Storage'),
            subtitle: Text(
              entries == null
                  ? 'Loading…'
                  : '${formatBytes(storedBytes)} used · '
                        '${kPlainEntryLabels.count(offlineEntries)} offline',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => LeaveBrowserGuard.push(context, '/storage'),
          ),
          _SettingsNote(
            'What happens to a finished entry\'s downloaded files is set '
            'per collection — open a collection and use Downloaded entries.',
          ),
          const SectionLabel('SAVING & SOURCES'),
          const _KeepWorkingSwitch(),
          _SettingsNote(
            'Nothing runs on its own, and nothing continues once you leave '
            'Scrollary — this only decides whether the page a save or check '
            'is working on keeps being drawn while you look at something '
            'else in the app.',
          ),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Text(
              'Everything is stored on this device. There is no account, no '
              'sync and no background network activity — saves and update '
              'checks only run when you start them.',
              style: TextStyle(
                fontSize: 13,
                height: 1.55,
                color: AppPalette.of(context).inkMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The one control for the foreground-multitasking capability.
///
/// A switch rather than a door: it changes one behaviour and has one state, and
/// it takes effect the moment it moves — a run in flight follows it without a
/// restart. Turning it off never stops anything and never loses anything; the
/// operation simply goes back to needing the Browser on screen, which is what
/// it always did.
class _KeepWorkingSwitch extends ConsumerStatefulWidget {
  const _KeepWorkingSwitch();

  @override
  ConsumerState<_KeepWorkingSwitch> createState() => _KeepWorkingSwitchState();
}

class _KeepWorkingSwitchState extends ConsumerState<_KeepWorkingSwitch> {
  late final ForegroundMultitasking _capability;

  @override
  void initState() {
    super.initState();
    _capability = ref.read(foregroundMultitaskingProvider);
    _capability.addListener(_onChanged);
  }

  @override
  void dispose() {
    _capability.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _set(bool value) async {
    _capability.preference = value;
    await ref
        .read(databaseProvider)
        .setSetting(ForegroundMultitasking.settingKey, _capability.storedValue);
  }

  @override
  Widget build(BuildContext context) {
    // Availability and preference are different questions. Without Pro the
    // switch shows what the user asked for and refuses to act, rather than
    // silently reading back "off" and losing their choice.
    final available = _capability.proAvailable;
    return SwitchListTile(
      key: const ValueKey('settingsKeepWorking'),
      secondary: Icon(available ? Icons.hourglass_bottom : Icons.lock_outline),
      title: const Text('Keep working while I read'),
      subtitle: Text(
        !available
            ? 'A Pro capability. Without it, a save or check waits whenever '
                  'you leave the Browser — everything else is unchanged.'
            : _capability.enabled
            ? 'A save or check you started carries on while you read or use '
                  'the Library. Scrollary has to stay open in front — nothing '
                  'runs in the background.'
            : 'A save or check waits whenever you leave the Browser',
      ),
      value: _capability.preference,
      onChanged: available ? _set : null,
    );
  }
}

/// The quiet explanatory line under a settings group.
///
/// One widget rather than a repeated inline `TextStyle`: these lines are the
/// screen's tertiary voice, and three copies of the same literal is exactly
/// how a tone drifts.
class _SettingsNote extends StatelessWidget {
  const _SettingsNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        height: 1.5,
        color: AppPalette.of(context).inkFaint,
      ),
    ),
  );
}

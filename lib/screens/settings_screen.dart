import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../services/backup_service.dart';
import '../services/export_service.dart';
import '../state/app_state.dart';
import '../state/catalog_provider.dart';
import 'printer_settings_screen.dart';

/// S11 — Settings: shop profile, money (currency/tax/include-tax),
/// printer shortcut, data (backup / restore / export all), About.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _shopName;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _footer;
  late final TextEditingController _taxRate;
  bool _saving = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>().settings;
    _shopName = TextEditingController(text: s.shopName);
    _address = TextEditingController(text: s.shopAddress);
    _phone = TextEditingController(text: s.shopPhone);
    _footer = TextEditingController(text: s.receiptFooter);
    _taxRate = TextEditingController(text: _rateText(s.taxRatePercent));
  }

  static String _rateText(double rate) =>
      rate == rate.roundToDouble() ? rate.toInt().toString() : rate.toString();

  @override
  void dispose() {
    for (final c in [_shopName, _address, _phone, _footer, _taxRate]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save(AppState appState) async {
    setState(() => _saving = true);
    final rate = double.tryParse(_taxRate.text.trim()) ?? 0;
    await appState.saveSettings(appState.settings.copyWith(
      shopName: _shopName.text.trim(),
      shopAddress: _address.text.trim(),
      shopPhone: _phone.text.trim(),
      receiptFooter: _footer.text.trim(),
      taxRatePercent: rate.clamp(0, 100).toDouble(),
    ));
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Settings saved')));
  }

  Future<void> _backup(AppState appState) async {
    setState(() => _busy = true);
    try {
      final json = await appState.backup.exportJson();
      final stamp =
          DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
      await ExportService.shareText(
        json,
        'pocketpos-backup-$stamp.json',
        mimeType: 'application/json',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Backup failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore(AppState appState) async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (files.isEmpty || files.first.path == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore backup?'),
        content: const Text(
            'ALL current data (products, sales, settings) will be replaced by the backup file. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restore')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      final text = await File(files.first.path!).readAsString();
      // Validate before touching anything.
      BackupService.decodeAndValidate(text);
      await appState.backup.importJson(text);
      await appState.reloadSettings();
      if (!mounted) return;
      // Refresh form fields + catalogue with restored data.
      final s = appState.settings;
      _shopName.text = s.shopName;
      _address.text = s.shopAddress;
      _phone.text = s.shopPhone;
      _footer.text = s.receiptFooter;
      _taxRate.text = _rateText(s.taxRatePercent);
      context.read<CatalogProvider>().reloadAll();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup restored successfully.')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Restore failed: ${e is FormatException ? e.message : e}')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportAll(AppState appState) async {
    setState(() => _busy = true);
    try {
      final rows = await appState.reports.getExportRows(
        DateTime(2000),
        DateTime.now().add(const Duration(days: 1)),
      );
      final bytes = ExportService.buildSalesXlsx(
          rows, appState.settings.currencyCode);
      await ExportService.shareBytes(
        bytes,
        'pocketpos-all-sales.xlsx',
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        subject: 'All sales export',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final settings = appState.settings;
    final theme = Theme.of(context);

    InputDecoration deco(String label) => InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Shop profile',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        TextField(controller: _shopName, decoration: deco('Shop name')),
        const SizedBox(height: 12),
        TextField(controller: _address, decoration: deco('Address')),
        const SizedBox(height: 12),
        TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: deco('Phone')),
        const SizedBox(height: 12),
        TextField(
            controller: _footer,
            decoration: deco('Receipt footer text')),
        const SizedBox(height: 20),
        Text('Money',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: settings.currencyCode,
          decoration: deco('Currency'),
          items: [
            for (final c in kCurrencies)
              DropdownMenuItem(
                  value: c.code, child: Text('${c.code} (${c.symbol})')),
          ],
          onChanged: (v) {
            if (v != null) {
              appState.saveSettings(settings.copyWith(currencyCode: v));
            }
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _taxRate,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: deco('Tax rate (%)'),
        ),
        SwitchListTile(
          title: const Text('Prices include tax'),
          subtitle: const Text(
              'On: menu prices already contain tax. Off: tax is added at checkout.'),
          value: settings.pricesIncludeTax,
          onChanged: (v) => appState
              .saveSettings(settings.copyWith(pricesIncludeTax: v)),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _saving ? null : () => _save(appState),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
          child: const Text('Save changes'),
        ),
        const SizedBox(height: 24),
        Text('Printer',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.print_outlined),
          title: Text(settings.savedPrinterName ?? 'No printer connected'),
          subtitle: Text(settings.savedPrinterName == null
              ? 'Receipts are shown as a preview instead'
              : '${settings.paperMm}mm paper · tap to manage'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const PrinterSettingsScreen())),
        ),
        const Divider(height: 32),
        Text('Data',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.backup_outlined),
          title: const Text('Backup data to file'),
          subtitle: const Text(
              'One JSON file with products, sales and settings'),
          trailing: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.chevron_right),
          onTap: _busy ? null : () => _backup(appState),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.restore_outlined),
          title: const Text('Restore from file'),
          subtitle: const Text('Replaces all current data'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _busy ? null : () => _restore(appState),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.table_chart_outlined),
          title: const Text('Export all sales (Excel)'),
          subtitle: const Text('Every sale ever recorded, as .xlsx'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _busy ? null : () => _exportAll(appState),
        ),
        const Divider(height: 32),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('About ${AppConfig.appName}',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Icon(Icons.cloud_off_outlined, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          '100% offline — your data never leaves this device.'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Version ${AppConfig.appVersion}',
                    style: theme.textTheme.bodySmall),
                Text('Support: ${AppConfig.supportEmail}',
                    style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

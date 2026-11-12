import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../services/printer_service.dart';
import '../state/app_state.dart';

/// S10 — Printer settings: connection type tabs (Bluetooth/USB/Network),
/// device scan + connect, manual network-printer entry, paper width,
/// auto-print and cash-drawer toggles, test print. Works with standard
/// ESC/POS thermal printers. Without a printer the app simply uses the
/// receipt preview instead — nothing here blocks selling.
class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  PrinterConnectionType _type = PrinterConnectionType.bluetooth;
  List<PrinterDeviceInfo> _devices = [];
  bool _scanning = false;
  bool _connecting = false;
  bool _testing = false;
  bool _hasScanned = false;

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _hasScanned = false;
    });
    final devices =
        await context.read<AppState>().printer.scan(_type);
    if (!mounted) return;
    setState(() {
      _devices = devices;
      _scanning = false;
      _hasScanned = true;
    });
  }

  Future<void> _connect(PrinterDeviceInfo device) async {
    final appState = context.read<AppState>();
    setState(() => _connecting = true);
    final ok = await appState.printer.connect(device);
    if (!mounted) return;
    setState(() => _connecting = false);
    if (ok) {
      await appState.saveSettings(appState.settings.copyWith(
        savedPrinterJson: device.reconnectPayload,
        savedPrinterName: device.name,
      ));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connected to ${device.name}')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Could not connect. Make sure the printer is on and in range, then try again.')));
    }
  }

  Future<void> _disconnect() async {
    final appState = context.read<AppState>();
    await appState.printer.disconnect();
    await appState
        .saveSettings(appState.settings.copyWith(clearPrinter: true));
    if (mounted) setState(() {});
  }

  Future<void> _addNetworkManually() async {
    final controller = TextEditingController();
    final ip = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add network printer'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Printer IP address',
            hintText: '192.168.1.50',
            helperText: 'Port 9100 (standard ESC/POS raw printing)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Connect')),
        ],
      ),
    );
    if (ip == null || ip.isEmpty || !mounted) return;
    final service = context.read<AppState>().printer;
    if (service is ThermalPrinterService) {
      await _connect(service.manualNetworkPrinter(ip));
    }
  }

  Future<void> _testPrint() async {
    final appState = context.read<AppState>();
    setState(() => _testing = true);
    final result = await appState.printer.printTest(appState.settings);
    if (!mounted) return;
    setState(() => _testing = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(result.message)));
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final settings = appState.settings;
    final connected = appState.printer.connectedDevice;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Printer settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: connected == null
                  ? Row(
                      children: [
                        const Icon(Icons.print_disabled_outlined, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('No printer connected',
                                  style: theme.textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700)),
                              Text(
                                'Sales still work — receipts are shown as a preview instead of printing.',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Icon(Icons.print,
                            size: 32, color: theme.colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(connected.name,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700)),
                              Text(
                                '${connected.connectionType.label} · ${connected.addressLabel}',
                                style: theme.textTheme.bodySmall,
                              ),
                              const Text('● Connected',
                                  style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: _disconnect,
                          child: const Text('Disconnect'),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Paper width',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 58, label: Text('58 mm')),
              ButtonSegment(value: 80, label: Text('80 mm')),
            ],
            selected: {settings.paperMm},
            onSelectionChanged: (s) => appState
                .saveSettings(settings.copyWith(paperMm: s.first)),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Auto-print receipt after payment'),
            value: settings.autoPrint,
            onChanged: (v) =>
                appState.saveSettings(settings.copyWith(autoPrint: v)),
          ),
          SwitchListTile(
            title: const Text('Open cash drawer when printing'),
            subtitle: const Text('Sends the drawer-kick pulse with receipts'),
            value: settings.openDrawerOnPrint,
            onChanged: (v) => appState
                .saveSettings(settings.copyWith(openDrawerOnPrint: v)),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _testing || connected == null ? null : _testPrint,
            icon: _testing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.print_outlined),
            label: const Text('Test print'),
            style:
                OutlinedButton.styleFrom(minimumSize: const Size(0, 50)),
          ),
          const SizedBox(height: 24),
          Text('Find a printer',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SegmentedButton<PrinterConnectionType>(
            segments: const [
              ButtonSegment(
                  value: PrinterConnectionType.bluetooth,
                  icon: Icon(Icons.bluetooth),
                  label: Text('Bluetooth')),
              ButtonSegment(
                  value: PrinterConnectionType.usb,
                  icon: Icon(Icons.usb),
                  label: Text('USB')),
              ButtonSegment(
                  value: PrinterConnectionType.network,
                  icon: Icon(Icons.wifi),
                  label: Text('Network')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() {
              _type = s.first;
              _devices = [];
              _hasScanned = false;
            }),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _scanning ? null : _scan,
                  icon: _scanning
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.search),
                  label: Text(_scanning ? 'Searching…' : 'Search devices'),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 50)),
                ),
              ),
              if (_type == PrinterConnectionType.network) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _addNetworkManually,
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 50)),
                  child: const Text('Add by IP'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (_hasScanned && _devices.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppConfig.accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'No printers found. Check that the printer is powered on, '
                'paired (Bluetooth), plugged in (USB) or on the same Wi-Fi (Network), then search again.',
              ),
            ),
          for (final device in _devices)
            Card(
              child: ListTile(
                leading: Icon(switch (device.connectionType) {
                  PrinterConnectionType.bluetooth => Icons.bluetooth,
                  PrinterConnectionType.usb => Icons.usb,
                  PrinterConnectionType.network => Icons.wifi,
                }),
                title: Text(device.name),
                subtitle: Text(device.addressLabel),
                trailing: FilledButton(
                  onPressed: _connecting ? null : () => _connect(device),
                  child: const Text('Connect'),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            'Works with standard ESC/POS thermal printers (58mm and 80mm).',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:thermal_printer_flutter/thermal_printer_flutter.dart';

import '../data/models.dart';
import 'receipt_builder.dart';

enum PrinterConnectionType {
  bluetooth('Bluetooth'),
  usb('USB'),
  network('Network');

  const PrinterConnectionType(this.label);
  final String label;
}

/// A discovered printer, decoupled from the plugin's own model so the rest
/// of the app (and the interface contract) never depends on plugin types.
class PrinterDeviceInfo {
  final String name;
  final PrinterConnectionType connectionType;

  /// Address shown to the user (MAC, IP:port or USB id).
  final String addressLabel;

  /// Opaque payload used to reconnect (plugin JSON).
  final String reconnectPayload;

  const PrinterDeviceInfo({
    required this.name,
    required this.connectionType,
    required this.addressLabel,
    required this.reconnectPayload,
  });

  @override
  bool operator ==(Object other) =>
      other is PrinterDeviceInfo && other.reconnectPayload == reconnectPayload;

  @override
  int get hashCode => reconnectPayload.hashCode;
}

class PrintResult {
  final bool success;
  final String message;
  const PrintResult.success([this.message = 'Printed']) : success = true;
  const PrintResult.failure(this.message) : success = false;
}

/// Printer contract. The UI only ever talks to this interface, so the
/// transport plugin can be swapped without touching screens.
abstract class PrinterService {
  PrinterDeviceInfo? get connectedDevice;
  bool get hasSavedPrinter;

  /// Restores the printer saved in settings (if any) as the current target.
  void restoreSavedPrinter(String? printerJson, String? printerName);

  Future<List<PrinterDeviceInfo>> scan(PrinterConnectionType type);
  Future<bool> connect(PrinterDeviceInfo device);
  Future<void> disconnect();
  Future<bool> isConnected();

  Future<PrintResult> printSale(Sale sale, AppSettings settings);
  Future<PrintResult> printTest(AppSettings settings);
}

/// ESC/POS implementation on top of the `thermal_printer_flutter` plugin
/// (Bluetooth / USB / Network). Every failure is caught and reported as a
/// [PrintResult.failure] — the app always falls back to the on-screen
/// receipt preview and never crashes for lack of hardware.
class ThermalPrinterService implements PrinterService {
  final ThermalPrinterFlutter _plugin = ThermalPrinterFlutter();
  Printer? _printer;
  PrinterDeviceInfo? _connectedDevice;

  @override
  PrinterDeviceInfo? get connectedDevice => _connectedDevice;

  @override
  bool get hasSavedPrinter => _printer != null;

  @override
  void restoreSavedPrinter(String? printerJson, String? printerName) {
    if (printerJson == null || printerJson.isEmpty) return;
    try {
      _printer = Printer.fromJson(printerJson);
      _connectedDevice = _toInfo(_printer!);
    } catch (_) {
      _printer = null;
      _connectedDevice = null;
    }
  }

  PrinterType _pluginType(PrinterConnectionType type) => switch (type) {
        PrinterConnectionType.bluetooth => PrinterType.bluetooth,
        PrinterConnectionType.usb => PrinterType.usb,
        PrinterConnectionType.network => PrinterType.network,
      };

  PrinterDeviceInfo _toInfo(Printer p) {
    final type = switch (p.type) {
      PrinterType.bluetooth => PrinterConnectionType.bluetooth,
      PrinterType.usb => PrinterConnectionType.usb,
      PrinterType.network => PrinterConnectionType.network,
    };
    final address = switch (type) {
      PrinterConnectionType.bluetooth =>
        p.bleAddress.isNotEmpty ? p.bleAddress : p.name,
      PrinterConnectionType.usb =>
        p.usbAddress.isNotEmpty ? p.usbAddress : p.name,
      PrinterConnectionType.network => '${p.ip}:${p.port}',
    };
    return PrinterDeviceInfo(
      name: p.name.isEmpty ? 'Thermal printer' : p.name,
      connectionType: type,
      addressLabel: address,
      reconnectPayload: p.toJson(),
    );
  }

  @override
  Future<List<PrinterDeviceInfo>> scan(PrinterConnectionType type) async {
    try {
      final found = <String, Printer>{};
      final listed = await _plugin
          .getPrinters(printerType: _pluginType(type))
          .timeout(const Duration(seconds: 20));
      for (final p in listed) {
        found[p.toJson()] = p;
      }
      if (type == PrinterConnectionType.network) {
        final discovered = await _plugin
            .discoverNetworkPrinters(requireConfirmation: true)
            .timeout(const Duration(seconds: 30));
        for (final p in discovered) {
          found[p.toJson()] = p;
        }
      }
      return found.values.map(_toInfo).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Builds a device info for a manually entered network printer (IP).
  PrinterDeviceInfo manualNetworkPrinter(String ip, {int port = 9100}) {
    final p = Printer(
      type: PrinterType.network,
      name: 'Network printer',
      ip: ip.trim(),
      port: port.toString(),
    );
    return _toInfo(p);
  }

  @override
  Future<bool> connect(PrinterDeviceInfo device) async {
    try {
      final printer = Printer.fromJson(device.reconnectPayload);
      final ok = await _plugin
          .connect(printer: printer)
          .timeout(const Duration(seconds: 20));
      if (ok) {
        _printer = printer;
        _connectedDevice = device;
      }
      return ok;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    final printer = _printer;
    if (printer != null) {
      try {
        await _plugin.disconnect(printer: printer);
      } catch (_) {
        // Ignore — the goal state (not connected) is what matters.
      }
    }
    _connectedDevice = null;
  }

  @override
  Future<bool> isConnected() async {
    final printer = _printer;
    if (printer == null) return false;
    try {
      return await _plugin
          .isConnected(printer: printer)
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      return false;
    }
  }

  @override
  Future<PrintResult> printSale(Sale sale, AppSettings settings) async {
    final printer = _printer;
    if (printer == null) {
      return const PrintResult.failure(
          'No printer connected. The receipt preview is shown instead.');
    }
    try {
      final bytes = await ReceiptBuilder.buildEscPosBytes(
        sale,
        settings,
        openDrawer: settings.openDrawerOnPrint,
      );
      await _plugin
          .printBytes(bytes: bytes, printer: printer)
          .timeout(const Duration(seconds: 30));
      return const PrintResult.success('Receipt sent to printer');
    } catch (e) {
      return PrintResult.failure(
          'Printing failed — check the printer and try again.');
    }
  }

  @override
  Future<PrintResult> printTest(AppSettings settings) async {
    final printer = _printer;
    if (printer == null) {
      return const PrintResult.failure(
          'Connect a printer first, then run a test print.');
    }
    try {
      final bytes = await ReceiptBuilder.buildTestBytes(settings);
      await _plugin
          .printBytes(bytes: bytes, printer: printer)
          .timeout(const Duration(seconds: 30));
      return const PrintResult.success('Test page sent to printer');
    } catch (e) {
      return const PrintResult.failure(
          'Test print failed — check the printer connection.');
    }
  }
}

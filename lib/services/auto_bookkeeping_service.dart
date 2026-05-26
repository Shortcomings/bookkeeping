import 'dart:async';
import 'package:flutter/services.dart';

class PendingAutoTransaction {
  final String id;
  final String merchantName;
  final int amountCents;
  final int type; // 0=expense, 1=income
  final String date; // yyyy-MM-dd
  final String sourceApp;
  final String rawContent;

  const PendingAutoTransaction({
    required this.id,
    required this.merchantName,
    required this.amountCents,
    required this.type,
    required this.date,
    required this.sourceApp,
    this.rawContent = '',
  });

  factory PendingAutoTransaction.fromMap(Map<String, dynamic> map) {
    return PendingAutoTransaction(
      id: map['id'] as String,
      merchantName: map['merchantName'] as String,
      amountCents: map['amountCents'] as int,
      type: map['type'] as int,
      date: map['date'] as String,
      sourceApp: map['sourceApp'] as String,
      rawContent: (map['rawContent'] as String?) ?? '',
    );
  }
}

class AutoBookkeepingService {
  static const _channel = MethodChannel('com.bookkeeping/auto_bookkeeping');
  static const _eventChannel =
      EventChannel('com.bookkeeping/auto_bookkeeping/events');

  static final AutoBookkeepingService _instance = AutoBookkeepingService._();
  factory AutoBookkeepingService() => _instance;
  AutoBookkeepingService._();

  StreamSubscription? _eventSub;
  final List<PendingAutoTransaction> _pending = [];
  List<PendingAutoTransaction> get pending => List.unmodifiable(_pending);

  VoidCallback? onPendingUpdated;

  Future<void> initialize() async {
    _eventSub = _eventChannel.receiveBroadcastStream().listen((event) {
      if (event == 'pending_updated') {
        loadPendingTransactions();
        onPendingUpdated?.call();
      }
    });
    await loadPendingTransactions();
  }

  Future<void> loadPendingTransactions() async {
    try {
      final result = await _channel.invokeMethod('getPendingTransactions');
      if (result == null) {
        _pending.clear();
        return;
      }
      final list = result as List<dynamic>;
      _pending.clear();
      for (final item in list) {
        _pending.add(PendingAutoTransaction.fromMap(
            Map<String, dynamic>.from(item as Map)));
      }
    } catch (_) {
      // Platform may not support this (iOS, web), silently ignore
    }
  }

  Future<void> clearPendingTransactions() async {
    try {
      await _channel.invokeMethod('clearPendingTransactions');
      _pending.clear();
    } catch (_) {}
  }

  Future<bool> isNotificationListenerEnabled() async {
    try {
      final result =
          await _channel.invokeMethod('isNotificationListenerEnabled');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> openNotificationSettings() async {
    try {
      await _channel.invokeMethod('openNotificationSettings');
    } catch (_) {}
  }

  void dispose() {
    _eventSub?.cancel();
  }
}

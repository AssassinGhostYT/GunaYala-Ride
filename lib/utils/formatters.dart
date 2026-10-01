import 'package:intl/intl.dart';

final _currency = NumberFormat.currency(symbol: r'$', decimalDigits: 2);
final _dayLabel = DateFormat('EEE d MMM', 'es');
final _timeLabel = DateFormat('h:mm a', 'es');
final _fullLabel = DateFormat("EEEE d 'de' MMMM, h:mm a", 'es');

String money(num value) => _currency.format(value);

String departureLabel(DateTime when) => _timeLabel.format(when);

String dayLabel(DateTime when) => _dayLabel.format(when);

String fullLabel(DateTime when) => _fullLabel.format(when);

String relativeLabel(DateTime when) {
  final now = DateTime.now();
  final diff = when.difference(now);
  if (diff.isNegative) return 'Programado';
  if (diff.inMinutes < 60) return 'Sale en ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'Sale en ${diff.inHours} h';
  return 'Sale en ${diff.inDays} dia${diff.inDays == 1 ? '' : 's'}';
}

String paymentLabel(String method) => switch (method) {
      'efectivo' => 'Efectivo',
      'yapp' => 'Yapp',
      'transferencia' => 'Transferencia',
      _ => method,
    };

/// Los pagos pasan por fuera: la app no cobra ni procesa.
const String paymentNotice =
    'El pago es directo con el chofer. La app no cobra ni procesa dinero.';

String seatsLabel(int total, int reserved) {
  final left = (total - reserved).clamp(0, 1 << 31);
  if (left == 0) return 'LLENO';
  if (left == 1) return 'ULTIMO CUPO';
  return '$left cupos libres';
}

String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
}
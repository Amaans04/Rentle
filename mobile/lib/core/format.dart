String formatMoney(double amount) => '₹${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)}';

String formatDate(DateTime? date) {
  if (date == null) return '—';
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String titleCase(String value) =>
    value.split('_').map((w) => w.isEmpty ? w : '${w[0]}${w.substring(1).toLowerCase()}').join(' ');

import 'parsing.dart';

/// Mirrors server's InvoiceStatus enum: DRAFT/SENT/OVERDUE/PARTIALLY_PAID/PAID/VOID/REFUNDED.
class Invoice {
  Invoice({
    required this.id,
    required this.propertyId,
    required this.tenancyId,
    required this.invoiceNumber,
    required this.periodStart,
    required this.periodEnd,
    required this.dueDate,
    required this.totalAmount,
    required this.paidAmount,
    required this.status,
    required this.lineItems,
  });

  final String id;
  final String propertyId;
  final String tenancyId;
  final String invoiceNumber;
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime dueDate;
  final double totalAmount;
  final double paidAmount;
  final String status;
  final List<InvoiceLineItem> lineItems;

  double get balance => totalAmount - paidAmount;

  factory Invoice.fromJson(Map<String, dynamic> json) => Invoice(
    id: json['id'] as String,
    propertyId: json['propertyId'] as String,
    tenancyId: json['tenancyId'] as String,
    invoiceNumber: json['invoiceNumber'] as String,
    periodStart: DateTime.parse(json['periodStart'] as String),
    periodEnd: DateTime.parse(json['periodEnd'] as String),
    dueDate: DateTime.parse(json['dueDate'] as String),
    totalAmount: parseNum(json['totalAmount']),
    paidAmount: parseNum(json['paidAmount']),
    status: json['status'] as String,
    lineItems:
        (json['lineItems'] as List?)?.map((e) => InvoiceLineItem.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
  );
}

/// GET /invoices/:id shape — line items plus payments allocated to it.
class InvoiceDetail {
  InvoiceDetail({required this.invoice, required this.payments});

  final Invoice invoice;
  final List<Payment> payments;

  factory InvoiceDetail.fromJson(Map<String, dynamic> json) {
    final allocations = json['allocations'] as List? ?? const [];
    return InvoiceDetail(
      invoice: Invoice.fromJson(json),
      payments: allocations
          .map((a) => (a as Map<String, dynamic>)['payment'])
          .whereType<Map<String, dynamic>>()
          .map(Payment.fromJson)
          .toList(),
    );
  }
}

class InvoiceLineItem {
  InvoiceLineItem({required this.description, required this.category, required this.amount});

  final String description;
  final String category;
  final double amount;

  factory InvoiceLineItem.fromJson(Map<String, dynamic> json) => InvoiceLineItem(
    description: json['description'] as String,
    category: json['category'] as String,
    amount: parseNum(json['amount']),
  );
}

/// Manual methods only, per plan: CASH/UPI/BANK_TRANSFER/CHEQUE/WALLET.
class Payment {
  Payment({
    required this.id,
    required this.amount,
    required this.method,
    required this.status,
    this.utr,
    this.paidAt,
  });

  final String id;
  final double amount;
  final String method;
  final String status;
  final String? utr;
  final DateTime? paidAt;

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
    id: json['id'] as String,
    amount: parseNum(json['amount']),
    method: json['method'] as String,
    status: json['status'] as String,
    utr: json['utr'] as String?,
    paidAt: parseDateOrNull(json['paidAt']),
  );
}

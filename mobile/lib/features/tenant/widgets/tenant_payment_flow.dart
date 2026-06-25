import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentle/core/utils/api_errors.dart';
import 'package:rentle/core/utils/payment_utils.dart';
import 'package:rentle/core/widgets/rentle_widgets.dart';
import 'package:rentle/models/rent_record_model.dart';
import 'package:rentle/repositories/tenant_repository.dart';

Future<void> payRentRecord(
  BuildContext context,
  WidgetRef ref, {
  required RentRecordModel record,
  VoidCallback? onSuccess,
}) async {
  try {
    final payment = await ref.read(tenantRepositoryProvider).getPaymentLink(
          record.recordId,
        );
    final deepLink = payment['deepLink'] as String;
    await PaymentUtils.launchPayment(deepLink);

    if (!context.mounted) return;
    final paid = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Payment'),
        content: const Text('Did your UPI payment go through?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (paid == true) {
      await ref.read(tenantRepositoryProvider).markPaid(
            recordId: record.recordId,
            method: 'upi',
          );
      onSuccess?.call();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment marked as paid')),
        );
      }
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiError(e))),
      );
    }
  }
}

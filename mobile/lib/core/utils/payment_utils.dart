import 'package:url_launcher/url_launcher.dart';

class PaymentUtils {
  PaymentUtils._();

  static String generateUpiLink({
    required String upiId,
    required String name,
    required String amount,
    required String note,
    required String transactionRef,
  }) {
    return 'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(name)}'
        '&am=$amount&tn=${Uri.encodeComponent(note)}'
        '&tr=$transactionRef';
  }

  static Future<void> launchPayment(String upiLink) async {
    final uri = Uri.parse(upiLink);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static String generateWhatsAppPaymentLink({
    required String phone,
    required String message,
  }) {
    return 'https://wa.me/91$phone?text=${Uri.encodeComponent(message)}';
  }

  static Future<void> launchWhatsApp(String phone, String message) async {
    final link = generateWhatsAppPaymentLink(phone: phone, message: message);
    final uri = Uri.parse(link);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

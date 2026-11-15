import 'dart:convert';

class CheckoutPreview {
  const CheckoutPreview({
    required this.reference,
    required this.activityId,
    required this.amount,
    required this.createdAt,
    required this.expiresAt,
    this.status = 'pending',
  });
  final String reference, activityId, status;
  final int amount;
  final DateTime createdAt, expiresAt;
  bool expired(DateTime now) => !now.isBefore(expiresAt);
  bool get confirmed => status == 'demo_confirmed';
  String get qrPayload => jsonEncode({
    'app': 'KLIK',
    'purpose': 'checkout-preview',
    'test_only': true,
    'reference': reference,
    'activity_id': activityId,
    'amount': amount,
    'currency': 'IDR',
  });
  factory CheckoutPreview.fromJson(Map<String, dynamic> j) => CheckoutPreview(
    reference: j['reference'] as String,
    activityId: j['activityId'] as String,
    amount: j['amount'] as int,
    status: j['status'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
    expiresAt: DateTime.parse(j['expiresAt'] as String),
  );
  Map<String, dynamic> toJson() => {
    'reference': reference,
    'activityId': activityId,
    'amount': amount,
    'status': status,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'expiresAt': expiresAt.toUtc().toIso8601String(),
  };
}

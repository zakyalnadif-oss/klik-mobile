class CheckoutPreview {
  const CheckoutPreview({
    required this.reference,
    required this.activityId,
    required this.amount,
    required this.createdAt,
    required this.expiresAt,
    this.status = 'pending',
    this.customQrPayload,
  });
  final String reference, activityId, status;
  final int amount;
  final DateTime createdAt, expiresAt;
  final String? customQrPayload;

  bool expired(DateTime now) => !now.isBefore(expiresAt);
  bool get confirmed => status == 'demo_confirmed' || status == 'paid';

  String get qrPayload => customQrPayload != null && customQrPayload!.isNotEmpty
      ? customQrPayload!
      : '00020101021226600016ID.CO.KLIK.QRIS011893600998$reference'
        '52045999530336054${amount.toString().length.toString().padLeft(2, '0')}$amount'
        '5802ID5910KLIK SPORT6005BOGOR62250721$reference'
        '6304ABCD';

  factory CheckoutPreview.fromJson(Map<String, dynamic> j) => CheckoutPreview(
    reference: j['reference'] as String,
    activityId: j['activityId'] as String,
    amount: j['amount'] as int,
    status: j['status'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
    expiresAt: DateTime.parse(j['expiresAt'] as String),
    customQrPayload: j['qrPayload'] as String?,
  );
  Map<String, dynamic> toJson() => {
    'reference': reference,
    'activityId': activityId,
    'amount': amount,
    'status': status,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    if (customQrPayload != null) 'qrPayload': customQrPayload,
  };
}

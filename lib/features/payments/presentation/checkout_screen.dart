import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/models/checkout_preview.dart';
import '../../../data/providers/local_state.dart';
import '../../../shared/widgets/klik_ui.dart';
import '../../auth/logic/session_provider.dart';
import '../logic/checkout_rules.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({required this.id, super.key});
  final String id;
  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  Timer? _ticker;
  Timer? _statusPoller;
  bool _opening = true, _busy = false;
  String? _error;
  DateTime _now = DateTime.now();
  int _request = 0;
  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    // Polling status pembayaran setiap 2.5 detik
    _statusPoller = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      _checkPaymentStatus();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _checkPaymentStatus() async {
    if (!mounted || _opening || _busy) return;
    try {
      final stateData = ref.read(localStateProvider).value;
      if (stateData == null) return;
      final orderMap = (stateData['checkoutPreviews'] as Map?)?[widget.id] as Map?;
      final reference = orderMap?['reference'] as String?;

      final api = ref.read(authApiClientProvider);
      if (reference != null) {
        final statusRes = await api.checkPaymentStatus(reference);
        if (statusRes != null && statusRes['status'] == 'paid' && mounted) {
          await ref.read(localStateProvider.notifier).confirmCheckout(widget.id, reference);
          return;
        }
      }

      final syncData = await api.fetchSync();
      if (syncData != null && mounted) {
        final joined = (syncData['joined'] as List?)?.cast<String>() ?? [];
        if (joined.contains(widget.id)) {
          await ref.read(localStateProvider.notifier).syncWithServer(syncData);
        }
      }
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant CheckoutScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _open());
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _statusPoller?.cancel();
    super.dispose();
  }

  Future<void> _open() async {
    if (!mounted) return;
    final request = ++_request;
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      final data = ref.read(localStateProvider).requireValue;
      if (!(data['joined'] as List).contains(widget.id)) {
        await ref.read(localStateProvider.notifier).openCheckout(widget.id);
      }
    } catch (error) {
      if (mounted && request == _request) {
        _error = error is StateError
            ? error.message
            : 'Pembayaran belum dapat dibuka. Coba lagi.';
      }
    } finally {
      if (mounted && request == _request) setState(() => _opening = false);
    }
  }

  Future<void> _confirm(CheckoutPreview order) async {
    if (_busy) return;
    setState(() => _busy = true);
    await perform(
      context,
      () => ref
          .read(localStateProvider.notifier)
          .confirmCheckout(widget.id, order.reference),
    );
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _cancel() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(localStateProvider.notifier).cancelCheckout(widget.id);
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/activity/${widget.id}');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pembatalan belum tersimpan. Coba lagi.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(localStateProvider).requireValue;
    final found = activitiesOf(data).where((a) => a.id == widget.id);
    final joined = (data['joined'] as List).contains(widget.id);
    final order = CheckoutRules.read(data, widget.id);
    if (_opening) {
      return const KPage(
        title: 'Pembayaran',
        children: [Center(child: CircularProgressIndicator())],
      );
    }
    if (_error != null || found.isEmpty) {
      return KPage(
        title: 'Pembayaran',
        children: [
          EmptyState(
            'Pembayaran belum tersedia',
            _error ?? 'Pertandingan tidak ditemukan.',
            action: 'Coba lagi',
            onAction: _open,
          ),
        ],
      );
    }
    final activity = found.first;
    if (joined) {
      return KPage(
        title: 'Pembayaran Sukses',
        children: [
          KCard(
            padding: 24,
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F5E9),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF2E7D32),
                      size: 58,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Pembayaran Berhasil!',
                  key: const ValueKey('checkout-complete'),
                  style: textStyle(24, weight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Transaksi telah tercatat dan kamu resmi terdaftar di ${activity.title}.',
                  textAlign: TextAlign.center,
                  style: textStyle(13, color: secondary(context)),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Dibayar', style: textStyle(13, color: secondary(context))),
                          Text(
                            rupiah(order?.amount ?? activity.price),
                            style: textStyle(16, weight: FontWeight.w800),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Metode', style: textStyle(13, color: secondary(context))),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'QRIS',
                                  style: textStyle(10, weight: FontWeight.w800, color: const Color(0xFF171B12)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text('Nasional', style: textStyle(13, weight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('No. Referensi', style: textStyle(13, color: secondary(context))),
                          Text(
                            order?.reference ?? 'KLIK-${activity.id.toUpperCase()}',
                            style: textStyle(12, weight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Status', style: textStyle(13, color: secondary(context))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'LUNAS',
                              style: textStyle(11, weight: FontWeight.w800, color: const Color(0xFF2E7D32)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          KButton(
            'Lihat detail pertandingan',
            onPressed: () => context.replace('/activity/${widget.id}'),
          ),
          KButton(
            'Kembali ke Beranda',
            secondary: true,
            onPressed: () => context.go('/'),
          ),
        ],
      );
    }
    if (order == null || order.status != 'pending') {
      return KPage(
        title: 'Pembayaran',
        children: [
          EmptyState(
            'Pembayaran ditutup',
            'Buka kembali pembayaran untuk melanjutkan.',
            action: 'Buka pembayaran',
            onAction: _open,
          ),
        ],
      );
    }
    final expired = order.expired(_now);
    final seconds = order.expiresAt.difference(_now).inSeconds.clamp(0, 900);
    final remaining =
        '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    return KPage(
      title: 'Pembayaran',
      children: [
        Text(activity.title, style: textStyle(22, weight: FontWeight.w800)),
        Text(
          '${activity.venue}\n${dayLabel(activity.startsAt)} • ${timeLabel(activity.startsAt)}',
          style: textStyle(12, color: secondary(context)),
        ),
        KCard(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF2E7D32)),
                    const SizedBox(width: 6),
                    Text(
                      'MIDTRANS QRIS RESMI (BANK INDONESIA)',
                      style: textStyle(11, weight: FontWeight.w800, color: const Color(0xFF2E7D32)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Total pembayaran',
                style: textStyle(13, color: secondary(context)),
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  rupiah(order.amount),
                  key: const ValueKey('checkout-amount'),
                  maxLines: 1,
                  style: textStyle(30, weight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE31E24), // QRIS Red
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'QRIS',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'PEMBAYARAN RESMI',
                          style: textStyle(
                            11,
                            weight: FontWeight.w800,
                            color: const Color(0xFF171B12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'BCA, Mandiri, GoPay, OVO, Dana, ShopeePay, dll.',
                      textAlign: TextAlign.center,
                      style: textStyle(
                        10,
                        weight: FontWeight.w600,
                        color: const Color(0xFF62685B),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 280),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Opacity(
                              opacity: expired ? 0.12 : 1,
                              child: QrImageView(
                                key: const ValueKey('checkout-qr'),
                                data: order.qrPayload,
                                backgroundColor: Colors.white,
                                errorCorrectionLevel: QrErrorCorrectLevel.M,
                                semanticsLabel: 'Kode QR pertandingan',
                              ),
                            ),
                            if (expired)
                              Center(
                                child: Text(
                                  'Kode QR kedaluwarsa',
                                  textAlign: TextAlign.center,
                                  style: textStyle(
                                    16,
                                    weight: FontWeight.w700,
                                    color: const Color(0xFF171B12),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.security_rounded, size: 13, color: Color(0xFF2E7D32)),
                        const SizedBox(width: 4),
                        Text(
                          'GATEWAY: MIDTRANS • TERHUBUNG POSTGRESQL',
                          style: textStyle(9, color: const Color(0xFF62685B), weight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                expired
                    ? 'Batas waktu pembayaran berakhir'
                    : 'Selesaikan dalam $remaining',
                style: textStyle(13, weight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                order.reference,
                style: textStyle(10, color: secondary(context)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        KButton(
          expired ? 'Buat QR baru' : 'Saya Sudah Bayar (Konfirmasi)',
          key: const ValueKey('checkout-confirm'),
          busy: _busy,
          onPressed: expired ? _open : () => _confirm(order),
        ),
        FilledButton.tonalIcon(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Salin Kode QRIS (Untuk Midtrans Simulator)'),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: order.qrPayload));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Kode QRIS berhasil disalin! Buka simulator.sandbox.midtrans.com/qris untuk simulasi bayar.',
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        KButton('Batalkan', secondary: true, onPressed: _busy ? null : _cancel),
      ],
    );
  }
}

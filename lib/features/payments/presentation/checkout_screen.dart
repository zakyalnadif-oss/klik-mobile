import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/models/checkout_preview.dart';
import '../../../data/providers/local_state.dart';
import '../../../shared/widgets/klik_ui.dart';
import '../logic/checkout_rules.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({required this.id, super.key});
  final String id;
  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  Timer? _ticker;
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
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
        title: 'Pembayaran',
        children: [
          KCard(
            child: Column(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF32965C),
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  'Pendaftaran selesai',
                  key: const ValueKey('checkout-complete'),
                  style: textStyle(24, weight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Kamu sudah bergabung ke ${activity.title}.',
                  textAlign: TextAlign.center,
                ),
                if (order?.confirmed == true) ...[
                  const SizedBox(height: 20),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      rupiah(order!.amount),
                      maxLines: 1,
                      style: textStyle(28, weight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Konfirmasi pembayaran diterima'),
                  const SizedBox(height: 8),
                  Text(
                    order.reference,
                    style: textStyle(11, color: secondary(context)),
                  ),
                ],
              ],
            ),
          ),
          KButton(
            'Lihat pertandingan',
            onPressed: () => context.replace('/activity/${widget.id}'),
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
                ),
                child: Column(
                  children: [
                    Text(
                      'QRIS',
                      style: textStyle(
                        24,
                        weight: FontWeight.w800,
                        color: const Color(0xFF171B12),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'KLIK',
                      style: textStyle(
                        12,
                        weight: FontWeight.w700,
                        color: const Color(0xFF62685B),
                      ),
                    ),
                    const SizedBox(height: 12),
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
        const Text('Pastikan nominal sesuai dengan biaya pertandingan.'),
        KButton(
          expired ? 'Buat QR baru' : 'Konfirmasi pembayaran',
          key: const ValueKey('checkout-confirm'),
          busy: _busy,
          onPressed: expired ? _open : () => _confirm(order),
        ),
        KButton('Batalkan', secondary: true, onPressed: _busy ? null : _cancel),
      ],
    );
  }
}

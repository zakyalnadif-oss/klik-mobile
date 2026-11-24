import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/location_helper.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/providers/backend_provider.dart';
import '../../../data/providers/local_state.dart';
import '../../../shared/widgets/klik_ui.dart';
import '../logic/session_provider.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({this.mode = 'login', super.key});
  final String mode;
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController(),
      password = TextEditingController(),
      name = TextEditingController(),
      city = TextEditingController();
  bool busy = false, hide = true, detectingLocation = false;
  String? error, notice;

  @override
  void initState() {
    super.initState();
    if (widget.mode == 'register') {
      _detectLocation();
    }
  }

  @override
  void didUpdateWidget(covariant AuthScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mode == 'register' && (oldWidget.mode != 'register' || city.text.isEmpty)) {
      _detectLocation();
    }
  }

  Future<void> _detectLocation() async {
    if (detectingLocation) return;
    setState(() => detectingLocation = true);
    try {
      final detected = await LocationHelper.detectCurrentCity();
      if (detected != null && detected.isNotEmpty && mounted) {
        setState(() {
          city.text = detected;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => detectingLocation = false);
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    city.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configured = !ref.watch(appConfigProvider).isMissing;
    final register = widget.mode == 'register', reset = widget.mode == 'reset';
    final user = ref.watch(sessionProvider);
    if (user != null && !register && !reset) {
      return KPage(
        title: 'Akun',
        children: [
          KCard(child: Text('Masuk sebagai ${user['email'] ?? user['id']}')),
          const Text(
            'Akun terhubung ke server KLIK dan tersinkronisasi secara real-time.',
          ),
          KButton(
            'Kembali ke Beranda',
            onPressed: () async {
              await perform(
                context,
                () => ref.read(localStateProvider.notifier).start(),
              );
              if (context.mounted &&
                  ref.read(localStateProvider).requireValue['onboarded'] ==
                      true) {
                context.go('/');
              }
            },
          ),
          const LocalNotice(),
        ],
      );
    }
    return KPage(
      title: reset
          ? 'Lupa kata sandi'
          : register
          ? 'Daftar'
          : 'Masuk',
      children: [
        Text(
          reset
              ? 'Kembali bermain.'
              : register
              ? 'Mulai perjalananmu.'
              : 'Selamat datang kembali.',
          style: textStyle(28, weight: FontWeight.w800),
        ),
        if (!configured)
          const KCard(
            child: Text(
              'Server API belum dapat dihubungi. Pastikan server backend KLIK telah berjalan.',
            ),
          ),
        Form(
          key: form,
          child: AutofillGroup(
            child: Column(
              children: [
                if (register) ...[
                  TextFormField(
                    controller: name,
                    maxLength: 50,
                    validator: requiredText,
                    autofillHints: const [AutofillHints.name],
                    decoration: const InputDecoration(
                      labelText: 'Nama lengkap',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: city,
                    maxLength: 60,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Lokasi/domisili wajib diisi'
                        : null,
                    decoration: InputDecoration(
                      labelText: 'Kota / Domisili',
                      hintText: detectingLocation
                          ? 'Mendeteksi lokasi saat ini...'
                          : 'Contoh: Bogor',
                      helperText: detectingLocation
                          ? 'Sedang mencari posisi GPS...'
                          : (city.text.isNotEmpty
                              ? 'Lokasi otomatis terdeteksi saat mendaftar'
                              : 'Otomatis diisi posisi GPS Anda'),
                      prefixIcon: const Icon(Icons.location_on_outlined),
                      suffixIcon: detectingLocation
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: Center(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            )
                          : IconButton(
                              tooltip: 'Deteksi ulang posisi',
                              icon: const Icon(Icons.my_location),
                              onPressed: _detectLocation,
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: email,
                  validator: emailError,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 16),
                if (!reset)
                  TextFormField(
                    controller: password,
                    obscureText: hide,
                    autocorrect: false,
                    enableSuggestions: false,
                    autofillHints: [
                      register
                          ? AutofillHints.newPassword
                          : AutofillHints.password,
                    ],
                    validator: (v) => v == null || v.isEmpty
                        ? 'Kata sandi wajib diisi'
                        : register && v.length < 8
                        ? 'Gunakan minimal 8 karakter'
                        : null,
                    decoration: InputDecoration(
                      labelText: 'Kata sandi',
                      suffixIcon: IconButton(
                        tooltip: hide
                            ? 'Tampilkan kata sandi'
                            : 'Sembunyikan kata sandi',
                        onPressed: () => setState(() => hide = !hide),
                        icon: Icon(
                          hide
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (error != null)
          Text(
            error!,
            style: textStyle(13, color: Theme.of(context).colorScheme.error),
          ),
        if (notice != null) KCard(child: Text(notice!)),
        KButton(
          reset
              ? 'Kirim email pemulihan'
              : register
              ? 'Daftar'
              : 'Masuk',
          busy: busy,
          onPressed: !configured
              ? null
              : () async {
                  if (!form.currentState!.validate()) return;
                  setState(() {
                    busy = true;
                    error = null;
                    notice = null;
                  });
                  try {
                    final api = ref.read(authApiClientProvider);
                    if (reset) {
                      // TODO: implement reset password endpoint
                      if (context.mounted) {
                        setState(
                          () => notice = 'Jika email terdaftar, petunjuk pemulihan akan dikirim ke kotak masuk.',
                        );
                      }
                    } else if (register) {
                      var effectiveCity = city.text.trim();
                      if (effectiveCity.isEmpty) {
                        final detected =
                            await LocationHelper.detectCurrentCity();
                        effectiveCity = (detected != null && detected.isNotEmpty)
                            ? detected
                            : 'Bogor';
                        city.text = effectiveCity;
                      }
                      final userData = await api.register(
                        email: email.text.trim(),
                        password: password.text,
                        displayName: name.text.trim(),
                        city: effectiveCity,
                      );
                      ref.read(sessionProvider.notifier).state = userData;
                      final syncData = await api.fetchSync();
                      if (syncData != null) {
                        await ref.read(localStateProvider.notifier).syncWithServer(syncData);
                      }
                      await ref.read(localStateProvider.notifier).start();
                      if (context.mounted) context.go('/');
                    } else {
                      final userData = await api.login(
                        email: email.text.trim(),
                        password: password.text,
                      );
                      ref.read(sessionProvider.notifier).state = userData;
                      final syncData = await api.fetchSync();
                      if (syncData != null) {
                        await ref.read(localStateProvider.notifier).syncWithServer(syncData);
                      }
                      await ref.read(localStateProvider.notifier).start();
                      if (context.mounted) context.go('/');
                    }
                  } on Exception catch (e) {
                    if (context.mounted) {
                      setState(() => error = e.toString().replaceFirst('Exception: ', ''));
                    }
                  } catch (_) {
                    if (context.mounted) {
                      setState(
                        () => error = 'Akun belum dapat dihubungkan. Periksa koneksi dan server API.',
                      );
                    }
                  } finally {
                    if (context.mounted) setState(() => busy = false);
                  }
                },
        ),
        if (!reset)
          TextButton(
            onPressed: () => context.push('/reset-password'),
            child: const Text('Lupa kata sandi?'),
          ),
        if (!reset)
          TextButton(
            onPressed: () => context.push(register ? '/login' : '/register'),
            child: Text(
              register ? 'Sudah punya akun? Masuk' : 'Belum punya akun? Daftar',
            ),
          ),
        const LocalNotice(),
      ],
    );
  }
}

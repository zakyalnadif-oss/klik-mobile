import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      name = TextEditingController();
  bool busy = false, hide = true;
  String? error, notice;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configured = !ref.watch(appConfigProvider).isMissing;
    final register = widget.mode == 'register', reset = widget.mode == 'reset';
    final user = ref.watch(sessionProvider).asData?.value;
    if (user != null && !register && !reset) {
      return KPage(
        title: 'Akun',
        children: [
          KCard(child: Text('Masuk sebagai ${user.email ?? user.id}')),
          const Text(
            'Sesi akun dikelola Supabase. Data kegiatan pada versi ini tetap berupa uji coba lokal.',
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
              'Akun online belum tersedia karena proyek Supabase belum dihubungkan. Kamu tetap bisa mencoba kegiatan melalui “Coba tanpa akun”.',
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
                    final client = await ref.read(backendProvider.future);
                    if (client == null) {
                      throw StateError('Supabase belum dikonfigurasi.');
                    }
                    if (reset) {
                      await client.auth.resetPasswordForEmail(
                        email.text.trim(),
                      );
                      if (context.mounted) {
                        setState(
                          () => notice = 'Jika email terdaftar, petunjuk pemulihan akan dikirim ke kotak masuk.',
                        );
                      }
                    } else if (register) {
                      final response = await client.auth.signUp(
                        email: email.text.trim(),
                        password: password.text,
                        data: {'display_name': name.text.trim()},
                      );
                      if (response.session == null) {
                        if (context.mounted) {
                          setState(
                            () => notice = 'Periksa email untuk mengonfirmasi pendaftaran, kemudian masuk kembali.',
                          );
                        }
                      } else {
                        await ref.read(localStateProvider.notifier).start();
                        if (context.mounted) context.go('/');
                      }
                    } else {
                      await client.auth.signInWithPassword(
                        email: email.text.trim(),
                        password: password.text,
                      );
                      await ref.read(localStateProvider.notifier).start();
                      if (context.mounted) context.go('/');
                    }
                  } on AuthException catch (e) {
                    if (context.mounted) setState(() => error = e.message);
                  } catch (_) {
                    if (context.mounted) {
                      setState(
                        () => error = 'Akun belum dapat dihubungkan. Periksa koneksi dan konfigurasi proyek.',
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
        KButton(
          'Coba tanpa akun',
          secondary: true,
          onPressed: busy
              ? null
              : () async {
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

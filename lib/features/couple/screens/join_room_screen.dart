import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/providers.dart';

class JoinRoomScreen extends ConsumerStatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  JoinRoomScreenState createState() => JoinRoomScreenState();
}

class JoinRoomScreenState extends ConsumerState<JoinRoomScreen> {
  final _inviteCodeController = TextEditingController();
  bool _isJoining = false;

  @override
  void dispose() {
    _inviteCodeController.dispose();
    super.dispose();
  }

  Future<void> _onJoin() async {
    final code = _inviteCodeController.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _isJoining = true;
    });
    final success = await ref.read(roomStateProvider.notifier).joinRoom(code);
    setState(() {
      _isJoining = false;
    });
    if (success) {
      if (!mounted) return;
      context.go('/couple');
    } else {
      final error = ref.read(roomStateProvider).message;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.isEmpty ? 'Código inválido' : error)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Unirme con código')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Ingresa el código que te compartió tu persona favorita para conectarte.',
                style: TextStyle(fontSize: 18, height: 1.5),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _inviteCodeController,
                decoration: const InputDecoration(
                  labelText: 'Código de pareja',
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isJoining ? null : _onJoin,
                child: _isJoining
                    ? const CircularProgressIndicator()
                    : const Text('Unirme'),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => context.go('/create-room'),
                child: const Text('Crear nueva conexión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

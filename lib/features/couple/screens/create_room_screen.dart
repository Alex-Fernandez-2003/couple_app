import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/providers.dart';

class CreateRoomScreen extends ConsumerStatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  CreateRoomScreenState createState() => CreateRoomScreenState();
}

class CreateRoomScreenState extends ConsumerState<CreateRoomScreen> {
  late final TextEditingController _inviteCodeController;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _inviteCodeController = TextEditingController(text: _generateInviteCode());
  }

  @override
  void dispose() {
    _inviteCodeController.dispose();
    super.dispose();
  }

  String _generateInviteCode() {
    const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    return List.generate(
      6,
      (_) => letters[random.nextInt(letters.length)],
    ).join();
  }

  Future<void> _onCreate() async {
    final code = _inviteCodeController.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() {
      _isCreating = true;
    });
    final success = await ref.read(roomStateProvider.notifier).createRoom(code);
    if (!mounted) return;
    setState(() {
      _isCreating = false;
    });
    if (success) {
      context.go('/couple');
    } else {
      final error = ref.read(roomStateProvider).message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.isEmpty ? 'No se pudo crear la sala' : error),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear conexión')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Genera un código para conectar tu espacio de pareja.',
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
                onPressed: _isCreating ? null : _onCreate,
                child: _isCreating
                    ? const CircularProgressIndicator()
                    : const Text('Crear espacio'),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => context.go('/join-room'),
                child: const Text('Ya tengo un código'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

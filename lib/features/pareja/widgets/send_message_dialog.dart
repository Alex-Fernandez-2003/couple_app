import 'package:flutter/material.dart';

class SendMessageDialog extends StatefulWidget {
  final Future<void> Function(String) onSend;
  final VoidCallback? onCancel;

  const SendMessageDialog({super.key, required this.onSend, this.onCancel});

  @override
  State<SendMessageDialog> createState() => _SendMessageDialogState();
}

class _SendMessageDialogState extends State<SendMessageDialog> {
  late TextEditingController _controller;
  bool _isLoading = false;
  String _validationMessage = '';
  static const int _maxChars = 500;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(_validateInput);
  }

  void _validateInput() {
    setState(() {
      if (_controller.text.length > _maxChars) {
        _validationMessage =
            'Máximo $_maxChars caracteres (${_controller.text.length})';
      } else if (_controller.text.isEmpty) {
        _validationMessage = '';
      } else {
        _validationMessage = '';
      }
    });
  }

  Future<void> _handleSend() async {
    if (_controller.text.isEmpty || _controller.text.length > _maxChars) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await widget.onSend(_controller.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mensaje enviado ❤️'),
            duration: Duration(seconds: 2),
            backgroundColor: Color(0xFFFD8392),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isValid =
        _controller.text.isNotEmpty && _controller.text.length <= _maxChars;

    return AlertDialog(
      title: const Text('Enviar mensaje a mi amor'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'Escribe algo especial...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              counterText: '${_controller.text.length}/$_maxChars caracteres',
              counterStyle: TextStyle(
                color: _controller.text.length > _maxChars
                    ? Colors.red
                    : Colors.grey,
              ),
            ),
            maxLength: _maxChars,
            maxLines: 4,
          ),
          if (_validationMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                _validationMessage,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading
              ? null
              : () {
                  widget.onCancel?.call();
                  Navigator.pop(context);
                },
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading || !isValid ? null : _handleSend,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enviar'),
        ),
      ],
    );
  }
}

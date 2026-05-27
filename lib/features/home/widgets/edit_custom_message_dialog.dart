import 'package:flutter/material.dart';

class EditCustomMessageDialog extends StatefulWidget {
  final String initialValue;
  final Function(String) onSave;
  final VoidCallback? onCancel;

  const EditCustomMessageDialog({
    super.key,
    required this.initialValue,
    required this.onSave,
    this.onCancel,
  });

  @override
  State<EditCustomMessageDialog> createState() =>
      _EditCustomMessageDialogState();
}

class _EditCustomMessageDialogState extends State<EditCustomMessageDialog> {
  late TextEditingController _controller;
  bool _isLoading = false;
  String _validationMessage = '';
  static const int _maxChars = 200;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _controller.addListener(_validateInput);
  }

  void _validateInput() {
    setState(() {
      if (_controller.text.length > _maxChars) {
        _validationMessage =
            'Máximo $_maxChars caracteres (${_controller.text.length})';
      } else if (_controller.text.isEmpty) {
        _validationMessage = 'El mensaje no puede estar vacío';
      } else {
        _validationMessage = '';
      }
    });
  }

  Future<void> _handleSave() async {
    if (_controller.text.isEmpty || _controller.text.length > _maxChars) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      widget.onSave(_controller.text);
      if (mounted) {
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
      title: const Text('Editar mensaje'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'Tu espacio de pareja',
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
            maxLines: 3,
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
          onPressed: _isLoading || !isValid ? null : _handleSave,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

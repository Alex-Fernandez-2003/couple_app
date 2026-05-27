part of '../screens/boxes_screen.dart';

class _BoxDetailsDialog extends StatefulWidget {
  const _BoxDetailsDialog({
    required this.title,
    required this.materialTemplates,
    required this.onSave,
    this.initialTitle,
    this.initialDescription,
  });

  final String title;
  final List<MaterialTemplate> materialTemplates;
  final String? initialTitle;
  final String? initialDescription;
  final Future<void> Function(_BoxDetailsValues values) onSave;

  @override
  State<_BoxDetailsDialog> createState() => _BoxDetailsDialogState();
}

class _BoxDetailsDialogState extends State<_BoxDetailsDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  final Set<String> _selectedTemplateIds = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _descriptionController = TextEditingController(
      text: widget.initialDescription,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    if (title.isEmpty) return;

    setState(() => _saving = true);
    try {
      final selectedTemplates = widget.materialTemplates
          .where((template) => _selectedTemplateIds.contains(template.id))
          .toList();
      await widget.onSave(
        _BoxDetailsValues(
          title: title,
          description: description,
          materialTemplates: selectedTemplates,
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                hintText: 'Materiales de manualidades',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descripción opcional',
                hintText: '¿Para qué sirve esta caja?',
              ),
              maxLines: 2,
            ),
            if (widget.materialTemplates.isNotEmpty) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Insertar materiales',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(height: 8),
              ...widget.materialTemplates.map(
                (template) => CheckboxListTile(
                  value: _selectedTemplateIds.contains(template.id),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(template.title),
                  subtitle: Text(_materialTemplateSubtitle(template)),
                  activeColor: const Color(0xFFFD8392),
                  onChanged: (selected) {
                    setState(() {
                      if (selected == true) {
                        _selectedTemplateIds.add(template.id);
                      } else {
                        _selectedTemplateIds.remove(template.id);
                      }
                    });
                  },
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _MaterialDialog extends StatefulWidget {
  const _MaterialDialog({
    required this.title,
    required this.onSave,
    this.initialTitle,
  });

  final String title;
  final String? initialTitle;
  final Future<void> Function(String title) onSave;

  @override
  State<_MaterialDialog> createState() => _MaterialDialogState();
}

class _MaterialTemplateDialog extends StatefulWidget {
  const _MaterialTemplateDialog({
    required this.title,
    required this.onSave,
    this.initialTitle,
    this.initialKind,
    this.initialItems = const [],
  });

  final String title;
  final String? initialTitle;
  final MaterialTemplateKind? initialKind;
  final List<MaterialItem> initialItems;
  final Future<void> Function(_MaterialTemplateValues values) onSave;

  @override
  State<_MaterialTemplateDialog> createState() =>
      _MaterialTemplateDialogState();
}

class _MaterialTemplateDialogState extends State<_MaterialTemplateDialog> {
  late final TextEditingController _controller;
  late final TextEditingController _materialController;
  late MaterialTemplateKind _kind;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTitle);
    _materialController = TextEditingController(
      text: widget.initialItems.isEmpty
          ? null
          : widget.initialItems.first.title,
    );
    _kind = widget.initialKind ?? MaterialTemplateKind.group;
  }

  @override
  void dispose() {
    _controller.dispose();
    _materialController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    final materialTitle = _materialController.text.trim();
    if (_kind == MaterialTemplateKind.individual && materialTitle.isEmpty) {
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.onSave(
        _MaterialTemplateValues(
          title: title,
          kind: _kind,
          items: _kind == MaterialTemplateKind.individual
              ? [MaterialItem.create(materialTitle)]
              : widget.initialItems,
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                hintText: 'Odontología básica, viaje, manualidades...',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            SegmentedButton<MaterialTemplateKind>(
              segments: const [
                ButtonSegment(
                  value: MaterialTemplateKind.individual,
                  label: Text('Individual'),
                  icon: Icon(Icons.check),
                ),
                ButtonSegment(
                  value: MaterialTemplateKind.group,
                  label: Text('Grupo'),
                  icon: Icon(Icons.checklist),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (selection) {
                setState(() {
                  _kind = selection.single;
                });
              },
            ),
            if (_kind == MaterialTemplateKind.individual) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _materialController,
                decoration: const InputDecoration(
                  labelText: 'Material',
                  hintText: 'Guantes, cinta, tijeras...',
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _MaterialTemplateValues {
  final String title;
  final MaterialTemplateKind kind;
  final List<MaterialItem> items;

  const _MaterialTemplateValues({
    required this.title,
    required this.kind,
    required this.items,
  });
}

class _InsertMaterialTemplatesDialog extends StatefulWidget {
  const _InsertMaterialTemplatesDialog({
    required this.templates,
    required this.onInsert,
  });

  final List<MaterialTemplate> templates;
  final Future<void> Function(List<MaterialTemplate> templates) onInsert;

  @override
  State<_InsertMaterialTemplatesDialog> createState() =>
      _InsertMaterialTemplatesDialogState();
}

class _InsertMaterialTemplatesDialogState
    extends State<_InsertMaterialTemplatesDialog> {
  final Set<String> _selectedIds = {};
  bool _saving = false;

  Future<void> _insert() async {
    final selected = widget.templates
        .where((template) => _selectedIds.contains(template.id))
        .toList();
    if (selected.isEmpty) return;

    setState(() => _saving = true);
    try {
      await widget.onInsert(selected);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Insertar materiales'),
      content: SizedBox(
        width: double.maxFinite,
        child: widget.templates.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Aún no hay plantillas de materiales.',
                  textAlign: TextAlign.center,
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: widget.templates.length,
                itemBuilder: (context, index) {
                  final template = widget.templates[index];
                  return CheckboxListTile(
                    value: _selectedIds.contains(template.id),
                    contentPadding: EdgeInsets.zero,
                    title: Text(template.title),
                    subtitle: Text(_materialTemplateSubtitle(template)),
                    activeColor: const Color(0xFFFD8392),
                    onChanged: (selected) {
                      setState(() {
                        if (selected == true) {
                          _selectedIds.add(template.id);
                        } else {
                          _selectedIds.remove(template.id);
                        }
                      });
                    },
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _saving || _selectedIds.isEmpty ? null : _insert,
          child: const Text('Insertar'),
        ),
      ],
    );
  }
}

class _MaterialDialogState extends State<_MaterialDialog> {
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _controller.text.trim();
    if (title.isEmpty) return;

    setState(() => _saving = true);
    try {
      await widget.onSave(title);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          labelText: 'Material',
          hintText: 'Cinta, marcador, tijeras...',
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _BoxDetailsValues {
  final String title;
  final String description;
  final List<MaterialTemplate> materialTemplates;

  const _BoxDetailsValues({
    required this.title,
    required this.description,
    required this.materialTemplates,
  });
}

part of '../screens/boxes_screen.dart';

String _formatDate(DateTime date) {
  final now = DateTime.now();
  final difference = now.difference(date);

  if (difference.inDays == 0) {
    return 'hoy';
  } else if (difference.inDays == 1) {
    return 'ayer';
  } else if (difference.inDays < 7) {
    return 'hace ${difference.inDays} días';
  } else {
    return '${date.day}/${date.month}/${date.year}';
  }
}

String _materialTemplateKindLabel(MaterialTemplate template) {
  return template.kind == MaterialTemplateKind.individual
      ? 'Material individual'
      : 'Grupo reutilizable de materiales';
}

String _materialTemplateSubtitle(MaterialTemplate template) {
  final count = template.items.length;
  if (template.kind == MaterialTemplateKind.individual) {
    final material = template.items.isEmpty
        ? 'Sin material'
        : template.items.first.title;
    return 'Individual • $material';
  }
  return count == 1 ? 'Grupo • 1 material' : 'Grupo • $count materiales';
}

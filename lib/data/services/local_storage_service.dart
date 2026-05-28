import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note.dart';
import '../models/box_model.dart';
import '../models/shopping_item.dart';
import '../models/study.dart';
import '../models/calendar.dart';

class LocalStorageService {
  static const String _notesKey = 'notes_storage';
  static const String _noteCategoriesKey = 'note_categories_storage';
  static const String _boxesKey = 'boxes_storage';
  static const String _boxTemplatesKey = 'box_templates_storage';
  static const String _materialTemplatesKey = 'material_templates_storage';
  static const String _shoppingItemsKey = 'shopping_items_storage';
  static const String _shoppingTemplatesKey = 'shopping_templates_storage';
  static const String _shoppingCategoriesKey = 'shopping_categories_storage';
  static const String _pendingMessagesKey = 'pending_messages';
  static const String _currentRoomIdKey = 'current_room_id';
  static const String _currentRoomInviteCodeKey = 'current_room_invite_code';
  static const String _customMessageKey = 'couple_message';
  static const String _relationshipStartDateKey = 'relationship_start_date';
  static const String _periodStartedAtKey = 'period_started_at';
  static const String _partnerPhotoPathKey = 'partner_photo_path';
  static const String _studyGoalsKey = 'study_goals_storage';
  static const String _studySessionsKey = 'study_sessions_storage';
  static const String _studyTemplatesKey = 'study_templates_storage';
  static const String _studyProgressGoalsKey = 'study_progress_goals_storage';
  static const String _studyTimerStateKey = 'study_timer_state_storage';
  static const String _studyAlarmToneKey = 'study_alarm_tone_storage';
  static const String _calendarMarksKey = 'calendar_marks_storage';
  static const String _calendarRemindersKey = 'calendar_reminders_storage';

  static Future<SharedPreferences> get _prefs async =>
      await SharedPreferences.getInstance();

  // Notes methods
  static Future<List<Note>> getNotes() async {
    final prefs = await _prefs;
    final notesJson = prefs.getStringList(_notesKey) ?? [];
    return notesJson.map((json) => Note.fromMap(jsonDecode(json))).toList();
  }

  static Future<void> saveNotes(List<Note> notes) async {
    final prefs = await _prefs;
    final notesJson = notes.map((note) => jsonEncode(note.toMap())).toList();
    await prefs.setStringList(_notesKey, notesJson);
  }

  static Future<List<NoteCategory>> getNoteCategories() async {
    final prefs = await _prefs;
    final categoriesJson = prefs.getStringList(_noteCategoriesKey) ?? [];
    return categoriesJson
        .map((json) => NoteCategory.fromMap(jsonDecode(json)))
        .toList();
  }

  static Future<void> saveNoteCategories(List<NoteCategory> categories) async {
    final prefs = await _prefs;
    final categoriesJson = categories
        .map((category) => jsonEncode(category.toMap()))
        .toList();
    await prefs.setStringList(_noteCategoriesKey, categoriesJson);
  }

  static Future<void> addNote(Note note) async {
    final notes = await getNotes();
    notes.add(note);
    await saveNotes(notes);
  }

  static Future<void> updateNote(Note updatedNote) async {
    final notes = await getNotes();
    final index = notes.indexWhere((note) => note.id == updatedNote.id);
    if (index != -1) {
      notes[index] = updatedNote;
      await saveNotes(notes);
    }
  }

  static Future<void> deleteNote(String noteId) async {
    final notes = await getNotes();
    notes.removeWhere((note) => note.id == noteId);
    await saveNotes(notes);
  }

  // Boxes methods
  static Future<List<Box>> getBoxes() async {
    final prefs = await _prefs;
    final boxesJson = prefs.getStringList(_boxesKey) ?? [];
    return boxesJson.map((json) => Box.fromMap(jsonDecode(json))).toList();
  }

  static Future<void> saveBoxes(List<Box> boxes) async {
    final prefs = await _prefs;
    final boxesJson = boxes.map((box) => jsonEncode(box.toMap())).toList();
    await prefs.setStringList(_boxesKey, boxesJson);
  }

  static Future<List<BoxTemplate>> getBoxTemplates() async {
    final prefs = await _prefs;
    final templatesJson = prefs.getStringList(_boxTemplatesKey) ?? [];
    return templatesJson
        .map((json) => BoxTemplate.fromMap(jsonDecode(json)))
        .toList();
  }

  static Future<void> saveBoxTemplates(List<BoxTemplate> templates) async {
    final prefs = await _prefs;
    final templatesJson = templates
        .map((template) => jsonEncode(template.toMap()))
        .toList();
    await prefs.setStringList(_boxTemplatesKey, templatesJson);
  }

  static Future<List<MaterialTemplate>> getMaterialTemplates() async {
    final prefs = await _prefs;
    final templatesJson = prefs.getStringList(_materialTemplatesKey) ?? [];
    return templatesJson
        .map((json) => MaterialTemplate.fromMap(jsonDecode(json)))
        .toList();
  }

  static Future<void> saveMaterialTemplates(
    List<MaterialTemplate> templates,
  ) async {
    final prefs = await _prefs;
    final templatesJson = templates
        .map((template) => jsonEncode(template.toMap()))
        .toList();
    await prefs.setStringList(_materialTemplatesKey, templatesJson);
  }

  static Future<void> addBox(Box box) async {
    final boxes = await getBoxes();
    boxes.add(box);
    await saveBoxes(boxes);
  }

  static Future<void> updateBox(Box updatedBox) async {
    final boxes = await getBoxes();
    final index = boxes.indexWhere((box) => box.id == updatedBox.id);
    if (index != -1) {
      boxes[index] = updatedBox;
      await saveBoxes(boxes);
    }
  }

  static Future<void> deleteBox(String boxId) async {
    final boxes = await getBoxes();
    boxes.removeWhere((box) => box.id == boxId);
    await saveBoxes(boxes);
  }

  // ==================== Current Room Session ====================

  static Future<({String roomId, String inviteCode})?>
  getCurrentRoomSession() async {
    final prefs = await _prefs;
    final roomId = prefs.getString(_currentRoomIdKey);
    final inviteCode = prefs.getString(_currentRoomInviteCodeKey);
    if (roomId == null ||
        roomId.isEmpty ||
        inviteCode == null ||
        inviteCode.isEmpty) {
      return null;
    }
    return (roomId: roomId, inviteCode: inviteCode);
  }

  static Future<void> saveCurrentRoomSession({
    required String roomId,
    required String inviteCode,
  }) async {
    final prefs = await _prefs;
    await prefs.setString(_currentRoomIdKey, roomId);
    await prefs.setString(_currentRoomInviteCodeKey, inviteCode);
  }

  static Future<void> clearCurrentRoomSession() async {
    final prefs = await _prefs;
    await prefs.remove(_currentRoomIdKey);
    await prefs.remove(_currentRoomInviteCodeKey);
  }

  // Shopping methods
  static Future<List<ShoppingItem>> getShoppingItems() async {
    final prefs = await _prefs;
    final itemsJson = prefs.getStringList(_shoppingItemsKey) ?? [];
    return itemsJson
        .map((json) => ShoppingItem.fromMap(jsonDecode(json)))
        .toList();
  }

  static Future<void> saveShoppingItems(List<ShoppingItem> items) async {
    final prefs = await _prefs;
    final itemsJson = items.map((item) => jsonEncode(item.toMap())).toList();
    await prefs.setStringList(_shoppingItemsKey, itemsJson);
  }

  static Future<List<ShoppingTemplate>> getShoppingTemplates() async {
    final prefs = await _prefs;
    final templatesJson = prefs.getStringList(_shoppingTemplatesKey) ?? [];
    return templatesJson
        .map((json) => ShoppingTemplate.fromMap(jsonDecode(json)))
        .toList();
  }

  static Future<void> saveShoppingTemplates(
    List<ShoppingTemplate> templates,
  ) async {
    final prefs = await _prefs;
    final templatesJson = templates
        .map((template) => jsonEncode(template.toMap()))
        .toList();
    await prefs.setStringList(_shoppingTemplatesKey, templatesJson);
  }

  static Future<List<ShoppingCategory>> getShoppingCategories() async {
    final prefs = await _prefs;
    final categoriesJson = prefs.getStringList(_shoppingCategoriesKey) ?? [];
    return categoriesJson
        .map((json) => ShoppingCategory.fromMap(jsonDecode(json)))
        .toList();
  }

  static Future<void> saveShoppingCategories(
    List<ShoppingCategory> categories,
  ) async {
    final prefs = await _prefs;
    final categoriesJson = categories
        .map((category) => jsonEncode(category.toMap()))
        .toList();
    await prefs.setStringList(_shoppingCategoriesKey, categoriesJson);
  }

  // Study methods
  static Future<List<StudyGoal>> getStudyGoals() async {
    final prefs = await _prefs;
    final goalsJson = prefs.getStringList(_studyGoalsKey) ?? [];
    return goalsJson
        .map((json) => StudyGoal.fromMap(jsonDecode(json)))
        .toList();
  }

  static Future<void> saveStudyGoals(List<StudyGoal> goals) async {
    final prefs = await _prefs;
    final goalsJson = goals.map((goal) => jsonEncode(goal.toMap())).toList();
    await prefs.setStringList(_studyGoalsKey, goalsJson);
  }

  static Future<List<StudySession>> getStudySessions() async {
    final prefs = await _prefs;
    final sessionsJson = prefs.getStringList(_studySessionsKey) ?? [];
    return sessionsJson
        .map((json) => StudySession.fromMap(jsonDecode(json)))
        .toList();
  }

  static Future<void> saveStudySessions(List<StudySession> sessions) async {
    final prefs = await _prefs;
    final sessionsJson = sessions
        .map((session) => jsonEncode(session.toMap()))
        .toList();
    await prefs.setStringList(_studySessionsKey, sessionsJson);
  }

  static Future<List<StudyTemplate>> getStudyTemplates() async {
    final prefs = await _prefs;
    final templatesJson = prefs.getStringList(_studyTemplatesKey) ?? [];
    return templatesJson
        .map((json) => StudyTemplate.fromMap(jsonDecode(json)))
        .toList();
  }

  static Future<void> saveStudyTemplates(List<StudyTemplate> templates) async {
    final prefs = await _prefs;
    final templatesJson = templates
        .map((template) => jsonEncode(template.toMap()))
        .toList();
    await prefs.setStringList(_studyTemplatesKey, templatesJson);
  }

  static Future<List<StudyProgressGoal>> getStudyProgressGoals() async {
    final prefs = await _prefs;
    final goalsJson = prefs.getStringList(_studyProgressGoalsKey) ?? [];
    return goalsJson
        .map((json) => StudyProgressGoal.fromMap(jsonDecode(json)))
        .toList();
  }

  static Future<void> saveStudyProgressGoals(
    List<StudyProgressGoal> goals,
  ) async {
    final prefs = await _prefs;
    final goalsJson = goals.map((goal) => jsonEncode(goal.toMap())).toList();
    await prefs.setStringList(_studyProgressGoalsKey, goalsJson);
  }

  static Future<StudyTimerState?> getStudyTimerState() async {
    final prefs = await _prefs;
    final timerJson = prefs.getString(_studyTimerStateKey);
    if (timerJson == null || timerJson.isEmpty) return null;
    return StudyTimerState.fromMap(jsonDecode(timerJson));
  }

  static Future<void> saveStudyTimerState(StudyTimerState timerState) async {
    final prefs = await _prefs;
    await prefs.setString(_studyTimerStateKey, jsonEncode(timerState.toMap()));
  }

  static Future<void> clearStudyTimerState() async {
    final prefs = await _prefs;
    await prefs.remove(_studyTimerStateKey);
  }

  static Future<String?> getStudyAlarmTonePath() async {
    final prefs = await _prefs;
    return prefs.getString(_studyAlarmToneKey);
  }

  static Future<StudyAlarmTone> getStudyAlarmTone() async {
    final prefs = await _prefs;
    return StudyAlarmTone.fromName(prefs.getString(_studyAlarmToneKey));
  }

  static Future<void> saveStudyAlarmTone(StudyAlarmTone tone) async {
    final prefs = await _prefs;
    await prefs.setString(_studyAlarmToneKey, tone.name);
  }

  static Future<void> saveStudyAlarmTonePath(String path) async {
    final prefs = await _prefs;
    await prefs.setString(_studyAlarmToneKey, path);
  }

  static Future<void> clearStudyAlarmTonePath() async {
    final prefs = await _prefs;
    await prefs.remove(_studyAlarmToneKey);
  }

  // Calendar methods
  static Future<List<CalendarDayMark>> getCalendarDayMarks() async {
    final prefs = await _prefs;
    final marksJson = prefs.getStringList(_calendarMarksKey) ?? [];
    return marksJson
        .map((json) => CalendarDayMark.fromMap(jsonDecode(json)))
        .toList();
  }

  static Future<void> saveCalendarDayMarks(List<CalendarDayMark> marks) async {
    final prefs = await _prefs;
    final marksJson = marks.map((mark) => jsonEncode(mark.toMap())).toList();
    await prefs.setStringList(_calendarMarksKey, marksJson);
  }

  static Future<List<CalendarReminder>> getCalendarReminders() async {
    final prefs = await _prefs;
    final remindersJson = prefs.getStringList(_calendarRemindersKey) ?? [];
    return remindersJson
        .map((json) => CalendarReminder.fromMap(jsonDecode(json)))
        .toList();
  }

  static Future<void> saveCalendarReminders(
    List<CalendarReminder> reminders,
  ) async {
    final prefs = await _prefs;
    final remindersJson = reminders
        .map((reminder) => jsonEncode(reminder.toMap()))
        .toList();
    await prefs.setStringList(_calendarRemindersKey, remindersJson);
  }

  // ==================== Offline Message Queue ====================

  /// Get pending messages from local queue
  static Future<List<Map<String, dynamic>>> getPendingMessages() async {
    final prefs = await _prefs;
    final json = prefs.getString(_pendingMessagesKey);
    if (json == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(json));
  }

  /// Add message to pending queue (for offline retry)
  static Future<void> addPendingMessage(Map<String, dynamic> message) async {
    final prefs = await _prefs;
    final queue = await getPendingMessages();
    queue.add(message);
    await prefs.setString(_pendingMessagesKey, jsonEncode(queue));
  }

  /// Remove message from pending queue (after successful send)
  static Future<void> removePendingMessage(String messageId) async {
    final prefs = await _prefs;
    final queue = await getPendingMessages();
    queue.removeWhere((msg) => msg['id'] == messageId);
    await prefs.setString(_pendingMessagesKey, jsonEncode(queue));
  }

  /// Clear all pending messages
  static Future<void> clearPendingMessages() async {
    final prefs = await _prefs;
    await prefs.remove(_pendingMessagesKey);
  }

  // ==================== Custom Message Cache ====================

  /// Get cached custom message
  static Future<String?> getCachedCustomMessage() async {
    final prefs = await _prefs;
    return prefs.getString(_customMessageKey);
  }

  /// Cache custom message locally
  static Future<void> setCachedCustomMessage(String message) async {
    final prefs = await _prefs;
    await prefs.setString(_customMessageKey, message);
  }

  /// Clear cached custom message
  static Future<void> clearCachedCustomMessage() async {
    final prefs = await _prefs;
    await prefs.remove(_customMessageKey);
  }

  // ==================== Partner Photo Cache ====================

  static Future<String?> getPartnerPhotoPath() async {
    final prefs = await _prefs;
    return prefs.getString(_partnerPhotoPathKey);
  }

  static Future<void> setPartnerPhotoPath(String path) async {
    final prefs = await _prefs;
    await prefs.setString(_partnerPhotoPathKey, path);
  }

  static Future<void> clearPartnerPhotoPath() async {
    final prefs = await _prefs;
    await prefs.remove(_partnerPhotoPathKey);
  }

  // ==================== Relationship Tracker Cache ====================

  static Future<DateTime?> getCachedRelationshipStartDate() async {
    return _getCachedDate(_relationshipStartDateKey);
  }

  static Future<void> setCachedRelationshipStartDate(DateTime? date) async {
    await _setCachedDate(_relationshipStartDateKey, date);
  }

  static Future<DateTime?> getCachedPeriodStartedAt() async {
    return _getCachedDate(_periodStartedAtKey);
  }

  static Future<void> setCachedPeriodStartedAt(DateTime? date) async {
    await _setCachedDate(_periodStartedAtKey, date);
  }

  static Future<DateTime?> _getCachedDate(String key) async {
    final prefs = await _prefs;
    final value = prefs.getString(key);
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  static Future<void> _setCachedDate(String key, DateTime? date) async {
    final prefs = await _prefs;
    if (date == null) {
      await prefs.remove(key);
      return;
    }
    await prefs.setString(key, date.toIso8601String());
  }
}

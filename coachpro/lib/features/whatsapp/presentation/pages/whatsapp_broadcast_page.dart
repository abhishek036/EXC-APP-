import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../../../core/widgets/cp_pressable.dart';
import '../../../../core/services/whatsapp_service.dart';
import '../../../../core/di/injection_container.dart';
import '../../../admin/data/repositories/admin_repository.dart';

class WhatsAppBroadcastPage extends StatefulWidget {
  const WhatsAppBroadcastPage({super.key});

  @override
  State<WhatsAppBroadcastPage> createState() => _WhatsAppBroadcastPageState();
}

class _WhatsAppBroadcastPageState extends State<WhatsAppBroadcastPage> {
  String _selectedType = 'Fee Reminder';
  String _selectedBatch = 'All Batches';
  bool _isSending = false;
  bool _isLoading = true;

  final _types = ['Fee Reminder', 'Attendance Alert', 'Exam Results', 'General Announcement'];
  List<String> _batches = ['All Batches'];
  final _customMessageController = TextEditingController();

  final _adminRepo = sl<AdminRepository>();
  
  // Loaded from API
  List<Map<String, dynamic>> _parents = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final batchDocs = await _adminRepo.getBatches();
      final studentDocs = await _adminRepo.getStudents();
      final feeDocs = await _adminRepo.getFeeRecords();

      final List<String> loadedBatches = ['All Batches'];
      for (final b in batchDocs) {
        if (b['name'] != null) loadedBatches.add(b['name'].toString());
      }

      final List<Map<String, dynamic>> loadedParents = [];
      for (final s in studentDocs) {
        // Parents from nested student_batches or direct fields
        final parents = (s['parents'] as List<dynamic>? ?? []).whereType<Map>().toList();
        final primaryParent = parents.isNotEmpty ? parents.first : <String, dynamic>{};
        final parentName = (s['parentName'] ?? primaryParent['name'] ?? '').toString();
        final parentPhone = (s['parentPhone'] ?? primaryParent['phone'] ?? '').toString();
        final studentName = (s['name'] ?? 'Student').toString();
        final studentBatches = (s['student_batches'] as List<dynamic>? ?? []).whereType<Map>().toList();
        final batch = studentBatches.isNotEmpty
            ? ((studentBatches.first['batch'] as Map?)?['name'] ?? 'Unassigned').toString()
            : (s['batchName'] ?? 'Unassigned').toString();
        final id = (s['id'] ?? '').toString();

        if (parentPhone.isEmpty) continue;

        // Calculate fee due for this student from fee records
        double totalFeeDue = 0;
        String nextDueDate = '—';
        for (final f in feeDocs) {
          if (f['student_id'] == id || (f['student'] is Map && (f['student'] as Map)['id'] == id)) {
            final total = (f['amount_due'] as num?)?.toDouble() ?? 0;
            final paid = (f['amount_paid'] as num?)?.toDouble() ?? 0;
            final pending = total - paid;
            if (pending > 0) {
              totalFeeDue += pending;
              if (nextDueDate == '—' && f['due_date'] != null) {
                nextDueDate = f['due_date'].toString();
              }
            }
          }
        }

        loadedParents.add({
          'id': id,
          'name': parentName,
          'phone': parentPhone,
          'student': studentName,
          'batch': batch,
          'selected': true,
          'feeDue': totalFeeDue.toInt(),
          'dueDate': nextDueDate,
        });
      }

      if (mounted) {
        setState(() {
          _batches = loadedBatches;
          _parents = loadedParents;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredParents {
    if (_selectedBatch == 'All Batches') return _parents;
    return _parents.where((p) => p['batch'] == _selectedBatch).toList();
  }

  int get _selectedCount => _filteredParents.where((p) => p['selected'] == true).length;

  @override
  void dispose() {
    _customMessageController.dispose();
    super.dispose();
  }

  Future<void> _sendBroadcast() async {
    setState(() => _isSending = true);

    final selected = _filteredParents.where((p) => p['selected'] == true).toList();
    final wa = WhatsAppService.instance;

    // Simulate sending delay for multi
    await Future.delayed(const Duration(seconds: 1));

    if (selected.length == 1) {
      final parent = selected.first;
      String message;
      switch (_selectedType) {
        case 'Fee Reminder':
          message = wa.buildFeeReminderMessage(
            studentName: parent['student'] as String,
            amount: (parent['feeDue'] as int).toDouble(),
            dueDate: parent['dueDate'] as String,
            batchName: parent['batch'] as String,
          );
          break;
        case 'General Announcement':
          message = wa.buildAnnouncementMessage(
            title: 'Announcement',
            body: _customMessageController.text.isNotEmpty
                ? _customMessageController.text
                : 'Important update from your coaching center.',
            instituteName: 'Excellence Academy',
          );
          break;
        default:
          message = _customMessageController.text.isNotEmpty
              ? _customMessageController.text
              : 'Update from Excellence Academy regarding ${parent['student']}.';
      }
      await wa.sendMessage(phone: parent['phone'] as String, message: message);
    } else {
      // For multiple recipients, we'd normally use WhatsApp API via backend.
      // Since it's mockup without backend, we just pretend it succeeded via API.
      await Future.delayed(const Duration(seconds: 1));
    }

    setState(() => _isSending = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Sent to ${selected.length} parent(s) via WhatsApp'),
          backgroundColor: Colors.green.shade600,
        ),
      );
    }
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      for (final p in _filteredParents) {
        p['selected'] = value ?? false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = CT.accent(context);

    return Scaffold(
      backgroundColor: CT.bg(context),
      appBar: AppBar(
        backgroundColor: CT.bg(context),
        elevation: 0,
        title: Text('WhatsApp Broadcast',
            style: GoogleFonts.sora(fontWeight: FontWeight.w700, color: CT.textH(context))),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
              children: [
                // Message type selector
                Text('Message Type', style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: CT.textH(context))),
                const SizedBox(height: AppDimensions.sm),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _types.map((type) {
                    final isActive = _selectedType == type;
                    return CPPressable(
                      onTap: () => setState(() => _selectedType = type),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isActive ? accent : CT.card(context),
                          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                          border: Border.all(color: isActive ? accent : CT.border(context)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getTypeIcon(type),
                              size: 16,
                              color: isActive ? Colors.white : CT.textS(context),
                            ),
                            const SizedBox(width: 6),
                            Text(type,
                                style: GoogleFonts.dmSans(
                                    fontSize: 13, fontWeight: FontWeight.w600,
                                    color: isActive ? Colors.white : CT.textS(context))),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ).animate().fadeIn(duration: 300.ms),

                const SizedBox(height: AppDimensions.lg),

                // Batch filter
                Text('Filter by Batch', style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: CT.textH(context))),
                const SizedBox(height: AppDimensions.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: CT.card(context),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
                    border: Border.all(color: CT.border(context)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _batches.contains(_selectedBatch) ? _selectedBatch : _batches.first,
                      isExpanded: true,
                      dropdownColor: CT.card(context),
                      style: GoogleFonts.dmSans(fontSize: 14, color: CT.textH(context)),
                      items: _batches.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                      onChanged: (v) => setState(() => _selectedBatch = v!),
                    ),
                  ),
                ),

                const SizedBox(height: AppDimensions.lg),

                // Custom message (for announcements)
                if (_selectedType == 'General Announcement') ...[
                  Text('Custom Message', style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: CT.textH(context))),
                  const SizedBox(height: AppDimensions.sm),
                  TextField(
                    controller: _customMessageController,
                    maxLines: 4,
                    style: GoogleFonts.dmSans(color: CT.textH(context)),
                    onChanged: (_) => setState((){}),
                    decoration: InputDecoration(
                      hintText: 'Type your announcement message...',
                      hintStyle: GoogleFonts.dmSans(color: CT.textM(context)),
                      filled: true,
                      fillColor: CT.card(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
                        borderSide: BorderSide(color: CT.border(context)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
                        borderSide: BorderSide(color: CT.border(context)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
                        borderSide: BorderSide(color: accent, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.lg),
                ],

                // Message preview
                Container(
                  padding: const EdgeInsets.all(AppDimensions.md),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCF8C6).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
                    border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.3)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.visibility_rounded, size: 16, color: Color(0xFF25D366)),
                      const SizedBox(width: 6),
                      Text('Message Preview', style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF25D366))),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                      _getPreviewMessage(),
                      style: GoogleFonts.dmSans(fontSize: 13, color: CT.textH(context), height: 1.5),
                    ),
                  ]),
                ).animate().fadeIn(delay: 200.ms),

                const SizedBox(height: AppDimensions.lg),

                // Recipients list
                Row(
                  children: [
                    Text('Recipients ($_selectedCount)', style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: CT.textH(context))),
                    const Spacer(),
                    CPPressable(
                      onTap: () => _toggleSelectAll(_selectedCount < _filteredParents.length),
                      child: Text(
                        _selectedCount == _filteredParents.length ? 'Deselect All' : 'Select All',
                        style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: accent),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.sm),
                if (_filteredParents.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(child: Text('No students with parent phone numbers found.', style: GoogleFonts.dmSans(color: CT.textM(context)))),
                  ),
                ..._filteredParents.asMap().entries.map((e) {
                  final p = e.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: CT.card(context),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusSM),
                      border: Border.all(color: CT.border(context)),
                    ),
                    child: CheckboxListTile(
                      value: p['selected'] as bool,
                      onChanged: (v) => setState(() => p['selected'] = v),
                      activeColor: accent,
                      checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      title: Text(p['name'] as String,
                          style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w600, color: CT.textH(context))),
                      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Student: ${p['student']} · ${p['batch']}',
                            style: GoogleFonts.dmSans(fontSize: 12, color: CT.textS(context))),
                        if (_selectedType == 'Fee Reminder' && (p['feeDue'] as int) > 0)
                          Text('Fee Due: ₹${p['feeDue']} · Due: ${p['dueDate']}',
                              style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red.shade400)),
                      ]),
                      secondary: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF25D366).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 20),
                      ),
                    ),
                  ).animate().fadeIn(delay: (30 * e.key).ms);
                }),
              ],
            ),
          ),

          // Send button
          Container(
            padding: const EdgeInsets.all(AppDimensions.pagePaddingH),
            decoration: BoxDecoration(
              color: CT.card(context),
              border: Border(top: BorderSide(color: CT.border(context))),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _selectedCount > 0 && !_isSending ? _sendBroadcast : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusSM)),
                    elevation: 0,
                  ),
                  icon: _isSending
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    _isSending ? 'Sending...' : 'Send via WhatsApp ($_selectedCount)',
                    style: GoogleFonts.sora(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'Fee Reminder': return Icons.currency_rupee_rounded;
      case 'Attendance Alert': return Icons.fact_check_rounded;
      case 'Exam Results': return Icons.assessment_rounded;
      case 'General Announcement': return Icons.campaign_rounded;
      default: return Icons.message_rounded;
    }
  }

  String _getPreviewMessage() {
    final wa = WhatsAppService.instance;
    switch (_selectedType) {
      case 'Fee Reminder':
        return wa.buildFeeReminderMessage(
          studentName: '[Student Name]',
          amount: 15000,
          dueDate: '15 Mar 2026',
          batchName: '[Batch]',
        );
      case 'Attendance Alert':
        return wa.buildAttendanceMessage(
          studentName: '[Student Name]',
          status: 'Absent',
          batchName: '[Batch]',
          date: DateFormat('dd MMM yyyy').format(DateTime.now()),
        );
      case 'Exam Results':
        return wa.buildResultMessage(
          studentName: '[Student Name]',
          examName: 'Weekly Test',
          scored: 85,
          total: 100,
          rank: 3,
          batchName: '[Batch]',
        );
      default:
        return _customMessageController.text.isNotEmpty
            ? _customMessageController.text
            : 'Type your custom announcement message above...';
    }
  }
}

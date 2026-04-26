import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/services/app_permission_service.dart';
import '../../../../core/services/cloud_storage_service.dart';
import '../../../../core/theme/theme_aware.dart';
import '../../data/repositories/teacher_repository.dart';

class UploadMaterialPage extends StatefulWidget {
  final String? initialBatchId;
  final String? initialType;
  final String? initialSubject;
  final Map<String, dynamic>? initialItem;

  const UploadMaterialPage({
    super.key,
    this.initialBatchId,
    this.initialType,
    this.initialSubject,
    this.initialItem,
  });

  const UploadMaterialPage.withInitials({
    super.key,
    this.initialBatchId,
    this.initialType,
    this.initialSubject,
    this.initialItem,
  });

  @override
  State<UploadMaterialPage> createState() => _UploadMaterialPageState();
}

class _UploadMaterialPageState extends State<UploadMaterialPage> {
  final _repo = sl<TeacherRepository>();
  final _storage = sl<CloudStorageService>();

  String _selectedType = 'note'; // note, assignment, video
  String? _selectedBatchId;
  String? _selectedSubject;
  List<Map<String, dynamic>> _batches = [];
  bool _isLoadingBatches = true;

  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _linkCtrl = TextEditingController();

  PlatformFile? _selectedFile;
  DateTime? _assignmentDueDate;
  String _youtubeVisibility = 'unlisted';
  bool _allowPublicYoutube = false;

  bool _isUploading = false;

  bool get _isEditMode {
    final id = (widget.initialItem?['id'] ?? '').toString();
    return id.isNotEmpty;
  }

  String get _editingItemId => (widget.initialItem?['id'] ?? '').toString();

  String? get _safeSelectedBatchId {
    if (_selectedBatchId == null || _selectedBatchId!.isEmpty) return null;
    final hasSelected = _batches.any(
      (b) => (b['id'] ?? '').toString() == _selectedBatchId,
    );
    return hasSelected ? _selectedBatchId : null;
  }

  Map<String, dynamic>? _findBatchById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final batch in _batches) {
      if ((batch['id'] ?? '').toString() == id) return batch;
    }
    return null;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _linkCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialType != null && widget.initialType!.trim().isNotEmpty) {
      _selectedType = widget.initialType!.trim();
    }
    if (widget.initialSubject != null &&
        widget.initialSubject!.trim().isNotEmpty) {
      _selectedSubject = widget.initialSubject!.trim();
    }

    final initial = widget.initialItem;
    if (initial != null) {
      _titleCtrl.text = (initial['title'] ?? '').toString();
      _descCtrl.text =
          (initial['description'] ?? initial['instructions'] ?? '').toString();
      final initialVisibility = _extractYoutubeVisibility(initial);
      if (initialVisibility != null) {
        _youtubeVisibility = initialVisibility;
      }
      final existingUrl = (initial['file_url'] ?? '').toString();
      if (existingUrl.isNotEmpty) {
        _linkCtrl.text = existingUrl;
      }
      final dueDateRaw = initial['due_date'];
      if (dueDateRaw != null) {
        _assignmentDueDate = DateTime.tryParse(dueDateRaw.toString())?.toLocal();
      }
    }

    _loadBatches();
    _loadVideoPolicy();
  }

  Future<void> _loadVideoPolicy() async {
    try {
      final profile = await _repo.getProfile();
      final policy = profile['video_policy'];
      if (policy is! Map) return;

      final allowPublic = policy['allow_public_uploads'] == true;
      final defaultVisibility =
          (policy['default_visibility'] ?? 'unlisted').toString().toLowerCase();

      if (!mounted) return;
      setState(() {
        final itemVisibility = _extractYoutubeVisibility(
          widget.initialItem ?? const <String, dynamic>{},
        );
        _allowPublicYoutube = allowPublic;
        if (itemVisibility == null) {
          _youtubeVisibility = allowPublic && defaultVisibility == 'public'
              ? 'public'
              : 'unlisted';
        }
        if (!_allowPublicYoutube && _youtubeVisibility == 'public') {
          _youtubeVisibility = 'unlisted';
        }
      });
    } catch (_) {
      // Keep safe defaults when policy fetch fails.
    }
  }

  String? _extractYoutubeVisibility(Map<String, dynamic> item) {
    final top = (item['youtube_visibility'] ?? '').toString().trim().toLowerCase();
    if (top == 'public' || top == 'unlisted') return top;

    final primary = item['primary_file'];
    final provider = primary is Map
        ? (primary['storage_provider'] ?? '').toString().trim().toLowerCase()
        : '';

    if (provider == 'youtube_public') return 'public';
    if (provider == 'youtube_unlisted') return 'unlisted';
    return null;
  }

  bool _isYoutubeUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    return host.contains('youtube.com') ||
        host.contains('youtu.be') ||
        host.contains('youtube-nocookie.com');
  }

  Future<void> _loadBatches() async {
    try {
      final b = await _repo.getMyBatches();
      if (!mounted) return;
      setState(() {
        _batches = b;
        _isLoadingBatches = false;
        if (b.isNotEmpty) {
          final pre = widget.initialBatchId;
          final matchedList = (pre != null && pre.isNotEmpty)
              ? b.where((item) => (item['id'] ?? '').toString() == pre).toList()
              : const <Map<String, dynamic>>[];
          final selected = matchedList.isNotEmpty ? matchedList.first : b.first;
          _selectedBatchId = (selected['id'] ?? '').toString();
          
          final batchSubs = selected['subjects'];
          List<String> subList = [];
          if (batchSubs is List) subList = batchSubs.map((e) => e.toString()).toList();
          
          _selectedSubject = widget.initialSubject ?? (subList.isNotEmpty ? subList.first : 'General');
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingBatches = false);
    }
  }

  Future<void> _handleUpload() async {
    if (_titleCtrl.text.isEmpty || _selectedBatchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and Batch are required.')),
      );
      return;
    }

    String formattedLink = '';

    if (_selectedType == 'video') {
      final rawLink = _linkCtrl.text.trim();
      if (rawLink.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please provide a video link.')),
        );
        return;
      }
      final normalized = _normalizeUrl(rawLink);
      if (normalized == null || !_isValidHttpUrl(normalized)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invalid link.')));
        return;
      }
      if (!_isYoutubeUrl(normalized)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only YouTube links are allowed for video content.'),
          ),
        );
        return;
      }
      if (!_allowPublicYoutube && _youtubeVisibility == 'public') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Public YouTube videos are disabled by admin policy.'),
          ),
        );
        setState(() => _youtubeVisibility = 'unlisted');
        return;
      }
      formattedLink = normalized;
    } else {
      // For Notes/Assignments, file or link is optional
      final rawLink = _linkCtrl.text.trim();
      if (rawLink.isNotEmpty) {
        final normalized = _normalizeUrl(rawLink);
        if (normalized == null || !_isValidHttpUrl(normalized)) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Invalid link.')));
          return;
        }
        formattedLink = normalized;
      }
    }

    setState(() => _isUploading = true);
    try {
      if (_selectedType != 'video' && _selectedFile != null) {
        if (kIsWeb && _selectedFile!.bytes != null) {
          formattedLink = await _storage.uploadBytes(
            _selectedFile!.bytes!,
            'materials',
            _selectedFile!.name,
          );
        } else if (!kIsWeb && _selectedFile!.path != null) {
          formattedLink = await _storage.uploadFile(
            File(_selectedFile!.path!),
            'materials',
          );
        } else if (_selectedFile!.bytes != null) {
          formattedLink = await _storage.uploadBytes(
            _selectedFile!.bytes!,
            'materials',
            _selectedFile!.name,
          );
        } else {
          throw Exception('Invalid file data chosen');
        }
      }

      if (_isEditMode) {
        await _repo.updateMaterial(
          itemId: _editingItemId,
          batchId: _selectedBatchId,
          subject: _selectedSubject ?? 'General',
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          type: _selectedType,
          fileUrl: formattedLink,
          youtubeVisibility: _selectedType == 'video' ? _youtubeVisibility : null,
          dueDate: _selectedType == 'assignment' ? _assignmentDueDate : null,
        );
      } else {
        await _repo.uploadMaterial(
          batchId: _selectedBatchId,
          subject: _selectedSubject ?? 'General',
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          type: _selectedType,
          fileUrl: formattedLink,
          youtubeVisibility: _selectedType == 'video' ? _youtubeVisibility : null,
          dueDate: _selectedType == 'assignment' ? _assignmentDueDate : null,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditMode
                ? 'Content updated successfully!'
                : 'Material uploaded successfully!',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  String? _normalizeUrl(String input) {
    final value = input.trim();
    if (value.isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.contains('.')) {
      final candidate = 'https://$value';
      final uri = Uri.tryParse(candidate);
      final host = uri?.host ?? '';
      if (!_hasPlausibleDomainHost(host)) return null;
      return candidate;
    }
    return null;
  }

  bool _hasPlausibleDomainHost(String host) {
    final parts = host
        .toLowerCase()
        .split('.')
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length < 2) return false;
    final tld = parts.last;
    final tldValid = RegExp(r'^[a-z]{2,}$').hasMatch(tld);
    return tldValid;
  }

  bool _isValidHttpUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty &&
        _hasPlausibleDomainHost(uri.host);
  }

  @override
  Widget build(BuildContext context) {
    final primary = CT.textH(context);
    final surface = CT.card(context);
    final accent = CT.accent(context);

    return Scaffold(
      backgroundColor: CT.bg(context),
      appBar: AppBar(
        backgroundColor: CT.bg(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: CT.textH(context),
            size: 22,
          ),
          onPressed: () {
            if (GoRouter.of(context).canPop()) {
              GoRouter.of(context).pop();
            } else {
              GoRouter.of(context).go('/teacher');
            }
          },
        ),
        title: Text(
          _isEditMode ? 'EDIT CONTENT' : 'UPLOAD CONTENT',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: CT.textH(context),
            letterSpacing: 1.2,
          ),
        ),
        foregroundColor: CT.textH(context),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTypeSelector(primary, surface, accent),
            const SizedBox(height: 32),
            _buildFormCard(primary, surface, accent),
            const SizedBox(height: 40),
            _buildUploadBtn(primary, surface, accent),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector(Color primary, Color surface, Color accent) {
    final isDark = CT.isDark(context);

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isDark
            ? primary.withValues(alpha: 0.3)
            : Colors.black.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CT.border(context).withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          _typeBtn('note', 'NOTES', Icons.description_rounded, primary, accent),
          _typeBtn(
            'assignment',
            'TASK',
            Icons.assignment_rounded,
            primary,
            accent,
          ),
          _typeBtn(
            'video',
            'VIDEO',
            Icons.play_circle_fill_rounded,
            primary,
            accent,
          ),
        ],
      ),
    );
  }

  Widget _typeBtn(
    String type,
    String label,
    IconData icon,
    Color primary,
    Color accent,
  ) {
    final isSel = _selectedType == type;
    final elevated = CT.elevated(context);
    final isDark = CT.isDark(context);

    return Expanded(
      child: GestureDetector(
        onTap: _isEditMode ? null : () => setState(() => _selectedType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSel ? accent : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSel ? Border.all(color: primary, width: 2) : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSel ? primary : (isDark ? elevated : primary),
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: isSel ? primary : (isDark ? elevated : primary),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard(Color primary, Color surface, Color accent) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: primary, width: 3),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: primary, offset: const Offset(4, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _inputLabel('CONTENT TITLE', primary),
          _textField(
            _titleCtrl,
            'e.g. ORGANIC CHEMISTRY NOTES - VOL 2',
            primary,
          ),
          const SizedBox(height: 24),
          _inputLabel('TARGET BATCH', primary),
          _buildBatchDropdown(primary),
          const SizedBox(height: 24),
          _inputLabel('SUBJECT', primary),
          _buildSubjectDropdown(primary),
          const SizedBox(height: 24),
          _inputLabel('DESCRIPTION', primary),
          _textField(
            _descCtrl,
            'Brief about what you are sharing...',
            primary,
            maxLines: 3,
          ),
          if (_selectedType == 'assignment') ...[
            const SizedBox(height: 24),
            _inputLabel('END DATE (OPTIONAL)', primary),
            _buildOptionalDueDate(primary),
          ],
          if (_selectedType == 'video') ...[
            const SizedBox(height: 24),
            _inputLabel('YOUTUBE VIDEO LINK', primary),
            _textField(
              _linkCtrl,
              'https://youtube.com/watch?v=...',
              primary,
              obscureText: false,
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: primary.withValues(alpha: 0.5)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Paste the YouTube link of your recorded lecture. Ensure embedding is enabled in YouTube Studio.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: primary.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (_selectedType != 'video') ...[
            const SizedBox(height: 24),
            _buildFileDropzone(primary, accent),
          ],
        ],
      ),
    );
  }

  Widget _inputLabel(String label, Color blue) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: blue.withValues(alpha: 0.5),
        letterSpacing: 1,
      ),
    ),
  );

  Widget _textField(
    TextEditingController ctrl,
    String hint,
    Color primary, {
    int maxLines = 1,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final elevated = CT.elevated(context);

    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      obscureText: obscureText,
      enableSuggestions: !obscureText,
      autocorrect: !obscureText,
      keyboardType: keyboardType,
      textCapitalization:
          obscureText ? TextCapitalization.none : TextCapitalization.sentences,
      style: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w800,
        color: primary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: elevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primary, width: 2.5),
        ),
      ),
    );
  }

  Widget _buildBatchDropdown(Color primary) {
    if (_isLoadingBatches) return const CircularProgressIndicator();
    final elevated = CT.elevated(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: elevated,
        border: Border.all(color: primary, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _safeSelectedBatchId,
          isExpanded: true,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: primary,
          ),
          onChanged: (val) {
            final b = _findBatchById(val);
            final batchSubs = b?['subjects'];
            List<String> subList = [];
            if (batchSubs is List) subList = batchSubs.map((e) => e.toString()).toList();
            
            setState(() {
              _selectedBatchId = val;
              _selectedSubject = subList.isNotEmpty ? subList.first : 'General';
            });
          },
          items: _batches
              .map(
                (b) => DropdownMenuItem(
                  value: b['id']?.toString(),
                  child: Text(
                    b['name']?.toString() ?? 'BATCH',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildSubjectDropdown(Color primary) {
    if (_isLoadingBatches) return const SizedBox.shrink();
    final batch = _findBatchById(_selectedBatchId);
    final subsRaw = batch?['subjects'];
    List<String> subjects = [];
    if (subsRaw is List) {
      subjects = subsRaw.map((e) => e.toString()).toList();
    }
    
    if (subjects.isEmpty) subjects = ['General'];

    final elevated = CT.elevated(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: elevated,
        border: Border.all(color: primary, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: subjects.contains(_selectedSubject) ? _selectedSubject : subjects.first,
          isExpanded: true,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: primary,
          ),
          onChanged: (val) {
            setState(() => _selectedSubject = val);
          },
          items: subjects
              .map(
                (s) => DropdownMenuItem(
                  value: s,
                  child: Text(
                    s.toUpperCase(),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }


  Future<void> _pickFile() async {
    try {
      final granted = await AppPermissionService.requestFileAccess(
        context,
        featureName: 'material uploads',
      );
      if (!granted) return;

      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = result.files.first;
          _linkCtrl.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking file: $e')));
      }
    }
  }

  Widget _buildFileDropzone(Color blue, Color yellow) {
    return GestureDetector(
      onTap: _pickFile,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: _selectedFile != null
              ? yellow.withValues(alpha: 0.1)
              : blue.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _selectedFile != null ? yellow : blue.withValues(alpha: 0.2),
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          children: [
            Icon(
              _selectedFile != null
                  ? Icons.check_circle
                  : Icons.cloud_upload_outlined,
              color: _selectedFile != null ? blue : blue,
              size: 32,
            ),
            const SizedBox(height: 12),
            Text(
              _selectedFile != null ? _selectedFile!.name : 'UPLOAD FILE',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: blue,
              ),
              textAlign: TextAlign.center,
            ),
            if (_selectedFile == null)
              Text(
                '(MAX 50MB)',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: blue.withValues(alpha: 0.5),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadBtn(Color blue, Color surface, Color yellow) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: yellow,
          foregroundColor: blue,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: blue, width: 3),
          ),
        ),
        onPressed: _isUploading ? null : _handleUpload,
        child: _isUploading
            ? SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(color: blue, strokeWidth: 3),
              )
            : Text(
                _isEditMode ? 'UPDATE CONTENT' : 'UPLOAD CONTENT',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }

  Widget _buildOptionalDueDate(Color primary) {
    final elevated = CT.elevated(context);
    final label = _assignmentDueDate == null
        ? 'No end date'
        : '${_assignmentDueDate!.day.toString().padLeft(2, '0')}-${_assignmentDueDate!.month.toString().padLeft(2, '0')}-${_assignmentDueDate!.year}';

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: elevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: primary, width: 2),
            ),
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                color: primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: _assignmentDueDate ?? now,
              firstDate: now.subtract(const Duration(days: 1)),
              lastDate: DateTime(now.year + 5),
            );
            if (picked == null) return;
            setState(() {
              _assignmentDueDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
            });
          },
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: primary, width: 2),
            foregroundColor: primary,
          ),
          child: const Text('Set'),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: _assignmentDueDate == null
              ? null
              : () => setState(() => _assignmentDueDate = null),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: primary, width: 2),
            foregroundColor: primary,
          ),
          child: const Text('Clear'),
        ),
      ],
    );
  }
}


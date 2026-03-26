import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/di/injection_container.dart';
import '../../data/repositories/teacher_repository.dart';

class UploadMaterialPage extends StatefulWidget {
  final String? initialBatchId;
  final String? initialType;
  final String? initialSubject;

  const UploadMaterialPage({
    super.key,
    this.initialBatchId,
    this.initialType,
    this.initialSubject,
  });

  const UploadMaterialPage.withInitials({
    super.key,
    this.initialBatchId,
    this.initialType,
    this.initialSubject,
  });

  @override
  State<UploadMaterialPage> createState() => _UploadMaterialPageState();
}

class _UploadMaterialPageState extends State<UploadMaterialPage> {
  final _repo = sl<TeacherRepository>();
  
  String _selectedType = 'note'; // note, assignment, video
  String? _selectedBatchId;
  String? _selectedSubject;
  List<Map<String, dynamic>> _batches = [];
  bool _isLoadingBatches = true;

  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _linkCtrl = TextEditingController();
  
  bool _isUploading = false;

  String? get _safeSelectedBatchId {
    if (_selectedBatchId == null || _selectedBatchId!.isEmpty) return null;
    final hasSelected = _batches.any((b) => (b['id'] ?? '').toString() == _selectedBatchId);
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
    if (widget.initialSubject != null && widget.initialSubject!.trim().isNotEmpty) {
      _selectedSubject = widget.initialSubject!.trim();
    }
    _loadBatches();
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
          final matched = (pre != null && pre.isNotEmpty)
              ? b.where((item) => (item['id'] ?? '').toString() == pre).toList()
              : const <Map<String, dynamic>>[];
          final selected = matched.isNotEmpty ? matched.first : b.first;
          _selectedBatchId = (selected['id'] ?? '').toString();
          _selectedSubject = widget.initialSubject ?? selected['subject']?.toString() ?? 'General';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingBatches = false);
    }
  }

  Future<void> _handleUpload() async {
    if (_titleCtrl.text.isEmpty || _selectedBatchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title and Batch are required.')));
      return;
    }

    final rawLink = _linkCtrl.text.trim();
    if (rawLink.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please provide a valid link.')));
      return;
    }

    final normalizedLink = _normalizeUrl(rawLink);
    if (normalizedLink == null || !_isValidHttpUrl(normalizedLink)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid link. Use full URL like https://example.com/file.pdf')),
      );
      return;
    }

    setState(() => _isUploading = true);
    try {
      await _repo.uploadMaterial(
        batchId: _selectedBatchId,
        subject: _selectedSubject ?? 'General',
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        type: _selectedType,
        fileUrl: normalizedLink,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Material Uploaded Successfully!')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
    final parts = host.toLowerCase().split('.').where((part) => part.isNotEmpty).toList();
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
    const blue = Color(0xFF0D1282);
    const surface = Color(0xFFEEEDED);
    const yellow = Color(0xFFF0DE36);

    return Scaffold(
      backgroundColor: blue,
      appBar: AppBar(
        backgroundColor: blue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('UPLOAD CONTENT', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white, letterSpacing: 1.2)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTypeSelector(blue, surface, yellow),
            const SizedBox(height: 32),
            _buildFormCard(blue, surface, yellow),
            const SizedBox(height: 40),
            _buildUploadBtn(blue, surface, yellow),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector(Color blue, Color surface, Color yellow) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24, width: 2)),
      child: Row(
        children: [
          _typeBtn('note', 'NOTES', Icons.description_rounded, blue, yellow),
          _typeBtn('assignment', 'TASK', Icons.assignment_rounded, blue, yellow),
          _typeBtn('video', 'VIDEO', Icons.play_circle_fill_rounded, blue, yellow),
        ],
      ),
    );
  }

  Widget _typeBtn(String type, String label, IconData icon, Color blue, Color yellow) {
    final isSel = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: isSel ? yellow : Colors.transparent, borderRadius: BorderRadius.circular(8), border: isSel ? Border.all(color: blue, width: 2) : null),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isSel ? blue : Colors.white, size: 20),
              const SizedBox(height: 4),
              Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w900, color: isSel ? blue : Colors.white, letterSpacing: 1)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard(Color blue, Color surface, Color yellow) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: blue, width: 3),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: blue, offset: const Offset(4, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _inputLabel('CONTENT TITLE', blue),
          _textField(_titleCtrl, 'e.g. ORGANIC CHEMISTRY NOTES - VOL 2', blue),
          const SizedBox(height: 24),
          _inputLabel('TARGET BATCH', blue),
          _buildBatchDropdown(blue),
          const SizedBox(height: 24),
          _inputLabel('DESCRIPTION', blue),
          _textField(_descCtrl, 'Brief about what you are sharing...', blue, maxLines: 3),
          const SizedBox(height: 24),
          _selectedType == 'video' ? _inputLabel('VIDEO LINK (Youtube/Drive)', blue) : _inputLabel('ATTACHMENT LINK', blue),
          _textField(_linkCtrl, 'https://...', blue),
          if (_selectedType != 'video') ...[
            const SizedBox(height: 24),
            _buildFileDropzone(blue, yellow),
          ],
        ],
      ),
    );
  }

  Widget _inputLabel(String label, Color blue) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w900, color: blue.withValues(alpha: 0.5), letterSpacing: 1)));

  Widget _textField(TextEditingController ctrl, String hint, Color blue, {int maxLines = 1}) => TextField(
    controller: ctrl,
    maxLines: maxLines,
    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: blue),
    decoration: InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: blue, width: 2)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: blue, width: 2.5)),
    ),
  );

  Widget _buildBatchDropdown(Color blue) {
    if (_isLoadingBatches) return const CircularProgressIndicator();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: blue, width: 2), borderRadius: BorderRadius.circular(8)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _safeSelectedBatchId,
          isExpanded: true,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: blue),
          onChanged: (val) {
             final b = _findBatchById(val);
             setState(() {
               _selectedBatchId = val;
               _selectedSubject = b?['subject']?.toString() ?? 'General';
             });
          },
          items: _batches.map((b) => DropdownMenuItem(value: b['id']?.toString(), child: Text(b['name']?.toString() ?? 'BATCH', overflow: TextOverflow.ellipsis))).toList(),
        ),
      ),
    );
  }

  Widget _buildFileDropzone(Color blue, Color yellow) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: blue.withValues(alpha: 0.2), width: 2, style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Icon(Icons.cloud_upload_outlined, color: blue, size: 32),
          const SizedBox(height: 12),
          Text('UPLOAD FILE', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w900, color: blue)),
          Text('(MAX 10MB)', style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: blue.withValues(alpha: 0.5))),
        ],
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: blue, width: 3)),
        ),
        onPressed: _isUploading ? null : _handleUpload,
        child: _isUploading 
          ? const CircularProgressIndicator() 
          : Text('UPLOAD CONTENT', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
      ),
    );
  }
}

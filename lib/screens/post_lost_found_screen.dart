import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/lost_found_model.dart';
import '../models/stay_model.dart' show kSpitiVillages;
import '../services/local_storage_service.dart';
import '../services/storage_service.dart';
import '../widgets/photo_picker_field.dart';

/// Report a lost or found item — photo, details, location, contact.
/// Posting push-notifies every Spiti Setu user (Cloud Function onLostFound).
class PostLostFoundScreen extends StatefulWidget {
  const PostLostFoundScreen({super.key});

  @override
  State<PostLostFoundScreen> createState() => _PostLostFoundScreenState();
}

class _PostLostFoundScreenState extends State<PostLostFoundScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  String _type = 'lost';
  String _location = 'Kaza Center';
  DateTime _date = DateTime.now();
  String _photoPath = '';
  bool _submitting = false;

  static const Color _purple = Color(0xFF8B5CF6);
  static const Color _red = Color(0xFFEF4444);
  static const Color _green = Color(0xFF10B981);

  @override
  void initState() {
    super.initState();
    LocalStorageService.getProfile().then((p) {
      if (mounted) {
        setState(() {
          _nameCtrl.text = p.name;
          _phoneCtrl.text = p.phone;
        });
      }
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: now.subtract(const Duration(days: 60)),
      lastDate: now,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: _purple),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final provider = context.read<LostFoundProvider>();

    try {
      // Save contact for next time.
      final profile = await LocalStorageService.getProfile();
      if (profile.name.isEmpty || profile.phone.isEmpty) {
        profile.name = _nameCtrl.text.trim();
        profile.phone = _phoneCtrl.text.trim();
        await LocalStorageService.saveProfile(profile);
      }

      final photo = await StorageService.uploadPhoto(_photoPath, 'lost_found');
      await provider.post(LostFoundItem(
        id: 'lf_${DateTime.now().millisecondsSinceEpoch}',
        type: _type,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        location: _location,
        date: _date.toString().split(' ')[0],
        contactName: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        photoPath: photo,
        createdAt: DateTime.now(),
      ));

      messenger.showSnackBar(
        SnackBar(
          backgroundColor: _green,
          content: Text(
            _type == 'lost'
                ? '🔍 Post live! Sab users ko notification gayi — koi dekhega to call karega.'
                : '🎒 Post live! Jiska saaman hai wo aap tak pahunch jayega.',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
      navigator.pop();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _typeCard(String value, String emoji, String title, String sub, Color color) {
    final selected = _type == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _type = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? color
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(height: 6),
              Text(title,
                  style: TextStyle(
                      color: selected ? color : Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w900,
                      fontSize: 13)),
              const SizedBox(height: 2),
              Text(sub,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _dec(String label, String hint) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
        filled: true,
        fillColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.03),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15)),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: _purple),
          borderRadius: BorderRadius.circular(12),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.red),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.red),
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC);
    final primaryText = isDark ? Colors.white : Colors.black87;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryText),
        title: Text('Report Lost / Found',
            style: TextStyle(color: primaryText, fontWeight: FontWeight.w800, fontSize: 17)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _typeCard('lost', '😟', 'KHO GAYA', 'Mera saaman kho gaya hai', _red),
                  const SizedBox(width: 10),
                  _typeCard('found', '🙌', 'MILA HAI', 'Mujhe kisi ka saaman mila hai', _green),
                ],
              ),
              const SizedBox(height: 18),

              Text('Item Photo (bahut zaroori — pehchan aasan hoti hai)',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: _purple)),
              const SizedBox(height: 8),
              PhotoPickerField(
                path: _photoPath,
                accent: _purple,
                label: 'Add Item Photo',
                onPicked: (p) => setState(() => _photoPath = p),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _titleCtrl,
                style: TextStyle(color: onSurface, fontSize: 14),
                decoration: _dec('ITEM KA NAAM', 'e.g. Black DSLR camera bag, brown purse'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Item ka naam likhein' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                style: TextStyle(color: onSurface, fontSize: 14),
                decoration: _dec('DETAILS (optional)',
                    'Pehchan, andar kya tha, kis waqt kho gaya/mila...'),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _location,
                      isExpanded: true,
                      dropdownColor: Theme.of(context).colorScheme.surface,
                      style: TextStyle(color: onSurface, fontSize: 13),
                      decoration: _dec('JAGAH (KAHAN)', ''),
                      items: kSpitiVillages
                          .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                          .toList(),
                      onChanged: (v) => setState(() => _location = v!),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: _dec('KIS DIN', ''),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 14, color: _purple),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _date.toString().split(' ')[0],
                                style: TextStyle(
                                    color: onSurface, fontSize: 13, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _nameCtrl,
                      style: TextStyle(color: onSurface, fontSize: 14),
                      decoration: _dec('AAPKA NAAM', ''),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Naam likhein' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      style: TextStyle(color: onSurface, fontSize: 14),
                      decoration: _dec('PHONE NUMBER', ''),
                      validator: (v) =>
                          v == null || v.replaceAll(RegExp(r'\D'), '').length < 10
                              ? 'Valid phone dalein'
                              : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _purple,
                    disabledBackgroundColor: _purple.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('📢 Post & Notify Everyone',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Post hote hi saare Spiti Setu users ko push notification jayegi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

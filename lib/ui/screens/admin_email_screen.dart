import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../data/services/admin_service.dart';

class AdminEmailScreen extends StatefulWidget {
  const AdminEmailScreen({super.key});

  @override
  State<AdminEmailScreen> createState() => _AdminEmailScreenState();
}

class _AdminEmailScreenState extends State<AdminEmailScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];
  Set<String> _selectedEmails = {};
  bool _isSending = false;

  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    final users = await AdminService().getAllUsers();
    if (mounted) {
      setState(() {
        _users = users.where((u) => u['email'] != null).toList();
        _isLoading = false;
      });
    }
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedEmails.length == _users.length) {
        _selectedEmails.clear();
      } else {
        _selectedEmails = _users.map((u) => u['email'].toString()).toSet();
      }
    });
  }

  Future<void> _sendEmail() async {
    if (_selectedEmails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار مستخدم واحد على الأقل')),
      );
      return;
    }
    
    if (_subjectController.text.isEmpty || _messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال الموضوع والرسالة')),
      );
      return;
    }

    setState(() => _isSending = true);

    // Using AdminService to send broadcast via Edge Function
    final success = await AdminService().sendBroadcast(
      emails: _selectedEmails.toList(),
      subject: _subjectController.text,
      message: _messageController.text,
    );

    if (mounted) {
      setState(() => _isSending = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال البريد بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل في إرسال البريد'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: AppTheme.imperialGradient),
        child: SafeArea(
          child: Column(
            children: [
               // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.accentColor.withAlpha(40),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.accentColor.withAlpha(80)),
                        ),
                        child: const Icon(Icons.arrow_forward_ios, color: AppTheme.accentColor, size: 20),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'مراسلة المستخدمين',
                        textAlign: TextAlign.right,
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.accentColor))
                    : Column(
                        children: [
                          // Select All Bar
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            color: Colors.black26,
                            child: Row(
                              textDirection: TextDirection.rtl,
                              children: [
                                Checkbox(
                                  value: _users.isNotEmpty && _selectedEmails.length == _users.length,
                                  onChanged: (v) => _toggleSelectAll(),
                                  activeColor: AppTheme.accentColor,
                                ),
                                const Text('تحديد الكل', style: TextStyle(color: Colors.white)),
                                const Spacer(),
                                Text(
                                  '${_selectedEmails.length} مختار',
                                  style: const TextStyle(color: AppTheme.accentColor),
                                ),
                              ],
                            ),
                          ),

                          // User List
                          Expanded(
                            child: ListView.builder(
                              itemCount: _users.length,
                              itemBuilder: (context, index) {
                                final user = _users[index];
                                final email = user['email'] as String;
                                final isSelected = _selectedEmails.contains(email);

                                return ListTile(
                                  onTap: () {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedEmails.remove(email);
                                      } else {
                                        _selectedEmails.add(email);
                                      }
                                    });
                                  },
                                  leading: Checkbox(
                                    value: isSelected,
                                    onChanged: (v) {
                                      setState(() {
                                        if (v == true) {
                                          _selectedEmails.add(email);
                                        } else {
                                          _selectedEmails.remove(email);
                                        }
                                      });
                                    },
                                    activeColor: AppTheme.accentColor,
                                  ),
                                  title: Text(
                                    user['display_name'] ?? 'مستخدم',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  subtitle: Text(
                                    email,
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(color: Colors.white60),
                                  ),
                                  trailing: CircleAvatar(
                                    backgroundColor: AppTheme.accentColor,
                                    radius: 15,
                                    child: Text(
                                      '${user['score'] ?? 0}',
                                      style: const TextStyle(fontSize: 10, color: Colors.black),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          
                          // Message Input Area
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: const BoxDecoration(
                              color: AppTheme.cardColor,
                              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                            ),
                            child: Column(
                              children: [
                                TextField(
                                  controller: _subjectController,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    hintText: 'عنوان الرسالة',
                                    hintStyle: TextStyle(color: Colors.white38),
                                    filled: true,
                                    fillColor: Colors.black12,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _messageController,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(color: Colors.white),
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                    hintText: 'نص الرسالة...',
                                    hintStyle: TextStyle(color: Colors.white38),
                                    filled: true,
                                    fillColor: Colors.black12,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _isSending ? null : _sendEmail,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.accentColor,
                                      padding: const EdgeInsets.all(15),
                                    ),
                                    child: _isSending
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                          )
                                        : const Text('إرسال', style: TextStyle(fontSize: 18, color: Colors.black)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

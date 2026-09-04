import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/admin_colors.dart';

class AdminSearchBar extends StatefulWidget {
  final String hintText;
  final ValueChanged<String> onChanged;

  const AdminSearchBar({super.key, required this.hintText, required this.onChanged});

  @override
  State<AdminSearchBar> createState() => _AdminSearchBarState();
}

class _AdminSearchBarState extends State<AdminSearchBar> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => widget.onChanged(value));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: TextField(
        controller: _controller,
        onChanged: _onChanged,
        style: TextStyle(color: AdminColors.textPrimary(isDark), fontSize: 14),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: TextStyle(color: AdminColors.textSecondaryColor(isDark), fontSize: 13.5),
          prefixIcon: Icon(Icons.search, color: AdminColors.textSecondaryColor(isDark), size: 20),
          filled: true,
          fillColor: AdminColors.surface(isDark),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

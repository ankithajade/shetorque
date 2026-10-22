import 'package:flutter/material.dart';

/// Floating animated shield button that expands into an "I Am Safe" pill
/// for riders to safely dismiss stealth tracking.
class SafeCancelButton extends StatefulWidget {
  final VoidCallback onConfirmed;
  const SafeCancelButton({super.key, required this.onConfirmed});

  @override
  State<SafeCancelButton> createState() => _SafeCancelButtonState();
}

class _SafeCancelButtonState extends State<SafeCancelButton>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 0.6).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: _expanded ? _buildExpanded() : _buildCollapsed(),
    );
  }

  Widget _buildCollapsed() {
    return FadeTransition(
      opacity: _pulseAnimation,
      child: FloatingActionButton.small(
        heroTag: 'safe_cancel_fab',
        backgroundColor: const Color(0xFF2E7D32),
        onPressed: () => setState(() => _expanded = true),
        child: const Icon(Icons.shield_outlined, color: Colors.white),
      ),
    );
  }

  Widget _buildExpanded() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2E7D32),
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = false),
            child: const Icon(Icons.close, color: Colors.white70, size: 18),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF2E7D32),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
            ),
            onPressed: widget.onConfirmed,
            child: const Text('I Am Safe',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

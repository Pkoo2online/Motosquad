import 'dart:async';
import 'package:flutter/material.dart';

class SosDialog extends StatefulWidget {
  final Function(String reason) onConfirmSos;

  const SosDialog({super.key, required this.onConfirmSos});

  @override
  State<SosDialog> createState() => _SosDialogState();
}

class _SosDialogState extends State<SosDialog> {
  int _secondsRemaining = 5;
  Timer? _countdownTimer;
  String _selectedReason = 'Crash / Incident';

  final List<String> _reasons = [
    'Crash / Incident',
    'Mechanical Breakdown',
    'Medical Emergency',
    'Lost / Stranded',
    'Out of Fuel',
  ];

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 1) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _countdownTimer?.cancel();
        Navigator.of(context).pop();
        widget.onConfirmSos(_selectedReason);
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1B0505),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.redAccent, width: 2),
      ),
      title: Column(
        children: [
          const Icon(Icons.emergency_rounded, color: Colors.redAccent, size: 64),
          const SizedBox(height: 8),
          const Text(
            'BROADCAST SOS BEACON',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Broadcasting distress in $_secondsRemaining seconds...',
            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select emergency type:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 10),
            ..._reasons.map((reason) {
              final isSelected = _selectedReason == reason;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.red.withOpacity(0.3) : const Color(0xFF2A1010),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? Colors.redAccent : Colors.white10,
                  ),
                ),
                child: ListTile(
                  dense: true,
                  title: Text(
                    reason,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  leading: Radio<String>(
                    value: reason,
                    groupValue: _selectedReason,
                    activeColor: Colors.redAccent,
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedReason = val);
                      }
                    },
                  ),
                  onTap: () {
                    setState(() => _selectedReason = reason);
                  },
                ),
              );
            }),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () {
            _countdownTimer?.cancel();
            Navigator.of(context).pop();
          },
          child: const Text('CANCEL (FALSE ALARM)', style: TextStyle(color: Colors.white60)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          onPressed: () {
            _countdownTimer?.cancel();
            Navigator.of(context).pop();
            widget.onConfirmSos(_selectedReason);
          },
          child: const Text('BROADCAST NOW', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

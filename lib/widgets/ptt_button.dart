import 'package:flutter/material.dart';

class PttButton extends StatefulWidget {
  final bool isTransmitting;
  final bool isLockedByOther;
  final String? activeSpeakerName;
  final VoidCallback onStartTalking;
  final VoidCallback onStopTalking;

  const PttButton({
    super.key,
    required this.isTransmitting,
    required this.isLockedByOther,
    this.activeSpeakerName,
    required this.onStartTalking,
    required this.onStopTalking,
  });

  @override
  State<PttButton> createState() => _PttButtonState();
}

class _PttButtonState extends State<PttButton> with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color buttonColor;
    String statusText;
    IconData icon;

    if (widget.isTransmitting) {
      buttonColor = Colors.greenAccent.shade700;
      statusText = 'TRANSMITTING (LIVE)';
      icon = Icons.mic;
    } else if (widget.isLockedByOther) {
      buttonColor = Colors.amber.shade800;
      statusText = '${widget.activeSpeakerName ?? "Rider"} is talking...';
      icon = Icons.volume_up;
    } else {
      buttonColor = const Color(0xFF2A2D34);
      statusText = 'HOLD TO TALK (PTT)';
      icon = Icons.mic_none;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTapDown: (_) {
            if (!widget.isLockedByOther) {
              widget.onStartTalking();
            }
          },
          onTapUp: (_) {
            if (widget.isTransmitting) {
              widget.onStopTalking();
            }
          },
          onTapCancel: () {
            if (widget.isTransmitting) {
              widget.onStopTalking();
            }
          },
          child: AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              final double scale = widget.isTransmitting ? 1.0 + (_animController.value * 0.08) : 1.0;
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: buttonColor,
                    boxShadow: [
                      BoxShadow(
                        color: widget.isTransmitting
                            ? Colors.greenAccent.withOpacity(0.6)
                            : (widget.isLockedByOther ? Colors.amber.withOpacity(0.4) : Colors.black45),
                        blurRadius: widget.isTransmitting ? 20 : 10,
                        spreadRadius: widget.isTransmitting ? 5 : 2,
                      ),
                    ],
                    border: Border.all(
                      color: widget.isTransmitting ? Colors.white : Colors.white24,
                      width: 3,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      size: 42,
                      color: Colors.white,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isTransmitting ? Colors.greenAccent : Colors.white12,
            ),
          ),
          child: Text(
            statusText,
            style: TextStyle(
              color: widget.isTransmitting ? Colors.greenAccent : Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}

import 'dart:ui';
import 'package:flutter/material.dart';

/// Bottom camera control bar with shutter button, gallery picker, and flash toggle.
class CameraControls extends StatefulWidget {
  final VoidCallback onCapture;
  final VoidCallback onGalleryPick;
  final VoidCallback? onFlashToggle;
  final bool isFlashOn;
  final bool isCapturing;

  const CameraControls({
    super.key,
    required this.onCapture,
    required this.onGalleryPick,
    this.onFlashToggle,
    this.isFlashOn = false,
    this.isCapturing = false,
  });

  @override
  State<CameraControls> createState() => _CameraControlsState();
}

class _CameraControlsState extends State<CameraControls>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
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
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: EdgeInsets.only(
              left: 32,
              right: 32,
              top: 20,
              bottom: 16 + bottomPadding,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.0),
                  Colors.black.withValues(alpha: 0.5),
                  Colors.black.withValues(alpha: 0.7),
                ],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Gallery button
                _ControlButton(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  onTap: widget.onGalleryPick,
                ),

                // Shutter button
                GestureDetector(
                  onTap: widget.isCapturing ? null : widget.onCapture,
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale:
                            widget.isCapturing ? 0.9 : _pulseAnimation.value,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.8),
                              width: 4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    const Color(0xFF1DB954).withValues(alpha: 0.3),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: widget.isCapturing
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFFFF5252),
                                        Color(0xFFFF1744),
                                      ],
                                    )
                                  : const LinearGradient(
                                      colors: [
                                        Color(0xFF1DB954),
                                        Color(0xFF1ED760),
                                      ],
                                    ),
                            ),
                            child: widget.isCapturing
                                ? const Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                : const Icon(
                                    Icons.camera_alt_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Flash toggle
                _ControlButton(
                  icon: widget.isFlashOn
                      ? Icons.flash_on_rounded
                      : Icons.flash_off_rounded,
                  label: widget.isFlashOn ? 'Flash On' : 'Flash Off',
                  onTap: widget.onFlashToggle,
                  isActive: widget.isFlashOn,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isActive;

  const _ControlButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? const Color(0xFF1DB954).withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.1),
              border: Border.all(
                color: isActive
                    ? const Color(0xFF1DB954).withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.15),
              ),
            ),
            child: Icon(
              icon,
              color: isActive
                  ? const Color(0xFF1DB954)
                  : Colors.white.withValues(alpha: 0.7),
              size: 22,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

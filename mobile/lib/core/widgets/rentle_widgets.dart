import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rentle/core/constants/colors.dart';

class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 400),
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(_fade);
    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

class PressableCard extends StatefulWidget {
  const PressableCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.color,
    this.borderRadius = 16,
    this.border,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final double borderRadius;
  final BoxBorder? border;

  @override
  State<PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<PressableCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scale = Tween<double>(begin: 1, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap != null ? (_) => _controller.forward() : null,
      onTapUp: widget.onTap != null ? (_) => _controller.reverse() : null,
      onTapCancel: widget.onTap != null ? () => _controller.reverse() : null,
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          margin: widget.margin,
          padding: widget.padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.color ?? RentleColors.white,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: widget.border ??
                Border.all(color: RentleColors.skyBlue, width: 1.2),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class RentleButton extends StatefulWidget {
  const RentleButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.color,
    this.textColor,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Color? color;
  final Color? textColor;
  final bool enabled;

  @override
  State<RentleButton> createState() => _RentleButtonState();
}

class _RentleButtonState extends State<RentleButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1, end: 0.97).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = !widget.enabled || widget.loading || widget.onPressed == null;
  final bgColor = widget.color ?? RentleColors.coral;

    return GestureDetector(
      onTapDown: isDisabled ? null : (_) => _controller.forward(),
      onTapUp: isDisabled ? null : (_) => _controller.reverse(),
      onTapCancel: isDisabled ? null : () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: isDisabled ? null : widget.onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: bgColor,
              foregroundColor: widget.textColor ?? RentleColors.white,
              disabledBackgroundColor: bgColor.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: widget.loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: RentleColors.white,
                    ),
                  )
                : Text(
                    widget.label,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: widget.textColor ?? RentleColors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class OtpBox extends StatefulWidget {
  const OtpBox({
    super.key,
    required this.onCompleted,
    this.onChanged,
    this.hasError = false,
  });

  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;
  final bool hasError;

  @override
  State<OtpBox> createState() => OtpBoxState();
}

class OtpBoxState extends State<OtpBox> with SingleTickerProviderStateMixin {
  static const int _length = 6;
  final List<TextEditingController> _controllers =
      List.generate(_length, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(_length, (_) => FocusNode());
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  @override
  void didUpdateWidget(covariant OtpBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasError && !oldWidget.hasError) {
      _shakeController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _shakeController.dispose();
    super.dispose();
  }

  String get value => _controllers.map((c) => c.text).join();

  void clear() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes.first.requestFocus();
    widget.onChanged?.call('');
  }

  void _onChanged(int index, String value) {
    if (value.length > 1) {
      _controllers[index].text = value.characters.last;
    }
    if (value.isNotEmpty && index < _length - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    final otp = this.value;
    widget.onChanged?.call(otp);
    if (otp.length == _length) {
      widget.onCompleted(otp);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        final offset = widget.hasError
            ? Offset(
                (_shakeAnimation.value * 10 * (1 - _shakeAnimation.value)) *
                    (widget.hasError ? 1 : 0),
                0,
              )
            : Offset.zero;
        return Transform.translate(offset: offset, child: child);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(_length, (index) {
          return SizedBox(
            width: 48,
            height: 56,
            child: Focus(
              onFocusChange: (_) => setState(() {}),
              child: TextField(
                controller: _controllers[index],
                focusNode: _focusNodes[index],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: RentleColors.charcoal,
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: RentleColors.skyBlue.withValues(alpha: 0.25),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: RentleColors.trustBlue,
                      width: 2,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: widget.hasError
                        ? const BorderSide(color: RentleColors.coral, width: 2)
                        : BorderSide.none,
                  ),
                ),
                onChanged: (v) => _onChanged(index, v),
                onTap: () => _controllers[index].selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: _controllers[index].text.length,
                ),
                onSubmitted: (_) {
                  if (index < _length - 1) {
                    _focusNodes[index + 1].requestFocus();
                  }
                },
              ),
            ),
          );
        }),
      ),
    );
  }
}

class RoleCard extends StatelessWidget {
  const RoleCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: selected
          ? Border.all(color: RentleColors.trustBlue, width: 2)
          : Border.all(color: RentleColors.skyBlue, width: 1.2),
      color: selected
          ? RentleColors.skyBlue.withValues(alpha: 0.35)
          : RentleColors.white,
      child: SizedBox(
        height: 88 - 24,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: RentleColors.skyBlue.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: RentleColors.charcoal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: RentleColors.charcoal.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: RentleColors.charcoal.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}

/// App bar with an explicit back button for GoRouter navigation.
class RentleAppBar extends StatelessWidget implements PreferredSizeWidget {
  const RentleAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.actions,
    this.showBack = true,
    this.fallbackRoute,
  }) : assert(title != null || titleWidget != null);

  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final bool showBack;
  final String? fallbackRoute;

  void _handleBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else if (fallbackRoute != null) {
      context.go(fallbackRoute!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canNavigateBack =
        showBack && (context.canPop() || fallbackRoute != null);

    return AppBar(
      automaticallyImplyLeading: false,
      leading: canNavigateBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => _handleBack(context),
            )
          : null,
      title: titleWidget ?? Text(title!),
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

import 'package:flutter/material.dart';
import '../services/pin_service.dart';
import 'document_list_screen.dart';

enum _PinMode { loading, set, confirm, verify }

class PinScreen extends StatefulWidget {
  const PinScreen({super.key});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen>
    with SingleTickerProviderStateMixin {
  _PinMode _mode = _PinMode.loading;
  String _entered = '';
  String _pendingPin = '';
  String _errorText = '';

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeOut));

    _checkStoredPin();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _checkStoredPin() async {
    final has = await PinService.hasPin();
    if (!mounted) return;
    setState(() => _mode = has ? _PinMode.verify : _PinMode.set);
  }

  void _onKey(String digit) {
    if (_entered.length >= 4) return;
    setState(() {
      _entered += digit;
      _errorText = '';
    });
    if (_entered.length == 4) _handleComplete();
  }

  void _onDelete() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  Future<void> _handleComplete() async {
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;

    switch (_mode) {
      case _PinMode.set:
        // Advance to confirm step
        setState(() {
          _pendingPin = _entered;
          _entered = '';
          _mode = _PinMode.confirm;
        });

      case _PinMode.confirm:
        if (_entered == _pendingPin) {
          await PinService.setPin(_entered);
          if (!mounted) return;
          _goToVault();
        } else {
          await _shakeController.forward(from: 0);
          if (!mounted) return;
          setState(() {
            _entered = '';
            _pendingPin = '';
            _errorText = "PINs don't match — try again";
            _mode = _PinMode.set;
          });
        }

      case _PinMode.verify:
        final ok = await PinService.verifyPin(_entered);
        if (!mounted) return;
        if (ok) {
          _goToVault();
        } else {
          await _shakeController.forward(from: 0);
          if (!mounted) return;
          setState(() {
            _entered = '';
            _errorText = 'Incorrect PIN';
          });
        }

      case _PinMode.loading:
        break;
    }
  }

  void _goToVault() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DocumentListScreen()),
    );
  }

  String get _subtitle {
    switch (_mode) {
      case _PinMode.loading:
        return '';
      case _PinMode.set:
        return 'Choose a 4-digit PIN';
      case _PinMode.confirm:
        return 'Re-enter your PIN to confirm';
      case _PinMode.verify:
        return 'Enter your PIN to unlock';
    }
  }

  String get _stepLabel {
    if (_mode == _PinMode.confirm) return 'Step 2 of 2';
    if (_mode == _PinMode.set) return 'Step 1 of 2';
    return '';
  }

  bool get _hasError => _errorText.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (_mode == _PinMode.loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _mode == _PinMode.verify
                      ? Icons.lock_rounded
                      : Icons.lock_open_rounded,
                  size: 48,
                  color: const Color(0xFF90CAF9),
                ),
                const SizedBox(height: 16),
                const Text(
                  'AccessVault',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    _subtitle,
                    key: ValueKey(_mode),
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (_stepLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _stepLabel,
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ],
                const SizedBox(height: 36),
                AnimatedBuilder(
                  animation: _shakeAnimation,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(_shakeAnimation.value, 0),
                    child: child,
                  ),
                  child: _PinDots(filled: _entered.length, hasError: _hasError),
                ),
                const SizedBox(height: 10),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _hasError
                      ? Text(
                          _errorText,
                          key: ValueKey(_errorText),
                          style: const TextStyle(
                            color: Color(0xFFEF5350),
                            fontSize: 13,
                          ),
                        )
                      : const SizedBox(height: 18, key: ValueKey('empty')),
                ),
                const SizedBox(height: 24),
                _NumPad(onKey: _onKey, onDelete: _onDelete),
                // Allow going back from confirm to set
                if (_mode == _PinMode.confirm) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => setState(() {
                      _mode = _PinMode.set;
                      _entered = '';
                      _pendingPin = '';
                      _errorText = '';
                    }),
                    child: Text(
                      'Start over',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PinDots extends StatelessWidget {
  final int filled;
  final bool hasError;

  const _PinDots({required this.filled, required this.hasError});

  @override
  Widget build(BuildContext context) {
    final dotColor =
        hasError ? const Color(0xFFEF5350) : const Color(0xFF90CAF9);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final active = i < filled;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? dotColor : Colors.transparent,
            border: Border.all(
              color: active ? dotColor : Colors.grey[600]!,
              width: 2,
            ),
          ),
        );
      }),
    );
  }
}

class _NumPad extends StatelessWidget {
  final void Function(String) onKey;
  final VoidCallback onDelete;

  const _NumPad({required this.onKey, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'del'],
    ];

    return Column(
      children: keys.map((row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: row.map((key) {
            if (key.isEmpty) return const SizedBox(width: 80, height: 64);
            return _NumKey(
              label: key,
              onTap: key == 'del' ? onDelete : () => onKey(key),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}

class _NumKey extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _NumKey({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDel = label == 'del';
    return SizedBox(
      width: 80,
      height: 64,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          shape: const CircleBorder(),
          foregroundColor: Colors.white,
        ),
        child: isDel
            ? const Icon(Icons.backspace_outlined, size: 22, color: Colors.white70)
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w400,
                ),
              ),
      ),
    );
  }
}

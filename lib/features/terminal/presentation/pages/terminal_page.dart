import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/error_state_widget.dart';
import '../../../ssh_connection/presentation/widgets/host_key_dialog.dart';
import '../cubit/terminal_cubit.dart';
import '../cubit/terminal_state.dart';
import '../widgets/terminal_keyboard_bar.dart';
import '../widgets/terminal_painter.dart';

class TerminalPage extends StatelessWidget {
  final String host;
  final int port;
  final String username;
  final String? password;
  final String? privateKey;

  const TerminalPage({
    super.key,
    required this.host,
    required this.port,
    required this.username,
    this.password,
    this.privateKey,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TerminalCubit(),
      child: _TerminalView(
        host: host,
        port: port,
        username: username,
        password: password,
        privateKey: privateKey,
      ),
    );
  }
}

class _TerminalView extends StatefulWidget {
  final String host;
  final int port;
  final String username;
  final String? password;
  final String? privateKey;

  const _TerminalView({
    required this.host,
    required this.port,
    required this.username,
    this.password,
    this.privateKey,
  });

  @override
  State<_TerminalView> createState() => _TerminalViewState();
}

class _TerminalViewState extends State<_TerminalView> {
  final _inputController = TextEditingController();
  final _focusNode = FocusNode();
  final _keyboardBarKey = GlobalKey<TerminalKeyboardBarState>();
  String _prevText = '';
  bool _hostKeyDialogShown = false;
  int _lastCols = 0;
  int _lastRows = 0;
  Timer? _resizeDebounce;

  @override
  void initState() {
    super.initState();
    _inputController.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<TerminalCubit>().connectAndOpenShell(
              widget.host, widget.port, widget.username,
              password: widget.password, privateKey: widget.privateKey);
      }
    });
  }

  @override
  void dispose() {
    _resizeDebounce?.cancel();
    _inputController.removeListener(_onTextChanged);
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleResize(double width, double height) {
    final cell = TerminalPainter.cellSize(14);
    final cols = (width / cell.width).floor();
    final rows = (height / cell.height).floor();
    if (cols < 1 || rows < 1) return;
    if (cols == _lastCols && rows == _lastRows) return;
    _lastCols = cols;
    _lastRows = rows;
    _resizeDebounce?.cancel();
    _resizeDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) context.read<TerminalCubit>().resize(cols, rows);
    });
  }

  void _onTextChanged() {
    final current = _inputController.text;
    if (current.length > _prevText.length) {
      final newChars = current.substring(_prevText.length);
      _sendInput(newChars);
    }
    _prevText = current;
    Future.microtask(() {
      _inputController.value = const TextEditingValue();
      _prevText = '';
    });
  }

  void _sendInput(String input) {
    final barState = _keyboardBarKey.currentState;
    if (barState != null && barState.isCtrlActive) {
      final ctrl = String.fromCharCode(input.toLowerCase().codeUnitAt(0) - 96);
      context.read<TerminalCubit>().sendInput(ctrl);
      barState.deactivateCtrl();
    } else {
      context.read<TerminalCubit>().sendInput(input);
    }
  }

  void _onSpecialKey(String sequence) {
    context.read<TerminalCubit>().sendInput(sequence);
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Terminal'),
        backgroundColor: AppColors.surface,
      ),
      body: BlocBuilder<TerminalCubit, TerminalState>(
        builder: (context, state) {
          if (state is TerminalConnecting || state is TerminalIdle) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (state is TerminalHostKeyPrompt) {
            _showHostKeyDialog(state);
            return const Center(
              child: Text('Verifying host key...',
                  style: TextStyle(color: AppColors.onSurface)),
            );
          }
          if (state is TerminalError) {
            return ErrorStateWidget(
              message: state.message,
              onRetry: () => context.read<TerminalCubit>().manualReconnect(),
            );
          }
          if (state is TerminalDisconnected) {
            return Center(
              child: ElevatedButton(
                onPressed: () => context.read<TerminalCubit>().manualReconnect(),
                child: const Text('Reconnect'),
              ),
            );
          }
          if (state is TerminalReconnecting) {
            return Center(
              child: Text('Reconnecting... (${state.attempt}/${state.maxAttempts})',
                  style: const TextStyle(color: AppColors.onSurface)),
            );
          }
          // TerminalActive
          return _buildTerminal(state as TerminalActive);
        },
      ),
    );
  }

  Widget _buildTerminal(TerminalActive state) {
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _handleResize(constraints.maxWidth, constraints.maxHeight);
              return Stack(
                children: [
                  CustomPaint(
                    painter: TerminalPainter(
                      buffer: state.buffer,
                      tick: state.tick,
                    ),
                    size: Size.infinite,
                  ),
                  // Transparent input field overlaid on terminal
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 48,
                    child: TextField(
                      controller: _inputController,
                      focusNode: _focusNode,
                      keyboardType: TextInputType.text,
                      enableSuggestions: false,
                      autocorrect: false,
                      showCursor: false,
                      style: const TextStyle(color: Colors.transparent, fontSize: 1),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  // Tap target
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => _focusNode.requestFocus(),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        TerminalKeyboardBar(
          key: _keyboardBarKey,
          onKeyPress: _onSpecialKey,
        ),
      ],
    );
  }

  void _showHostKeyDialog(TerminalHostKeyPrompt state) {
    if (_hostKeyDialogShown) return;
    _hostKeyDialogShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final accepted = await HostKeyDialog.show(
        context,
        host: state.host,
        port: state.port,
        fingerprint: state.fingerprint,
        keyType: state.keyType,
        type: state.isChanged
            ? HostKeyDialogType.keyChanged
            : HostKeyDialogType.firstConnection,
      );
      _hostKeyDialogShown = false;
      if (!mounted) return;
      if (accepted) {
        context.read<TerminalCubit>().acceptHostKeyAndConnect(
              fingerprint: state.fingerprint,
              keyType: state.keyType,
              isChanged: state.isChanged,
            );
      } else {
        Navigator.of(context).pop();
      }
    });
  }
}

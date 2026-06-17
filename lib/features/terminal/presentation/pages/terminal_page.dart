import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  Timer? _clearTimer;

  @override
  void initState() {
    super.initState();
    _inputController.addListener(_onTextChanged);
    _focusNode.onKeyEvent = _onKeyEvent;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<TerminalCubit>().connectAndOpenShell(
              widget.host, widget.port, widget.username,
              password: widget.password, privateKey: widget.privateKey);
      }
    });
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (event.logicalKey == LogicalKeyboardKey.backspace) {
        _sendInput('\x08');
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _resizeDebounce?.cancel();
    _clearTimer?.cancel();
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
    _resizeDebounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) context.read<TerminalCubit>().resize(cols, rows);
    });
  }

  void _onTextChanged() {
    final current = _inputController.text;
    if (current.length > _prevText.length) {
      final newChars = current.substring(_prevText.length);
      final toSend = newChars.replaceAll('\n', '\r');
      _sendInput(toSend);
    }
    _prevText = current;
    _clearTimer?.cancel();
    _clearTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted && _inputController.text.isNotEmpty) {
        _prevText = '';
        _inputController.value = const TextEditingValue();
      }
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

  Future<bool> _confirmExit() async {
    _focusNode.unfocus();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect?'),
        content: const Text('Are you sure you want to close the terminal session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    return confirm == true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmExit() && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Terminal'),
          backgroundColor: AppColors.surface,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (await _confirmExit()) {
                if (!context.mounted) return;
                Navigator.pop(context);
              }
            },
          ),
        ),
        body: BlocConsumer<TerminalCubit, TerminalState>(
          listener: (context, state) {
            if (state is TerminalHostKeyPrompt) {
              _showHostKeyDialog(state);
            }
          },
          builder: (context, state) {
            return Column(
              children: [
                Expanded(child: _buildBody(state)),
                TerminalKeyboardBar(
                  key: _keyboardBarKey,
                  onKeyPress: _onSpecialKey,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(TerminalState state) {
    if (state is TerminalConnecting || state is TerminalIdle) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (state is TerminalHostKeyPrompt) {
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
        child: Text(
          'Reconnecting... (${state.attempt}/${state.maxAttempts})',
          style: const TextStyle(color: AppColors.onSurface),
        ),
      );
    }
    // TerminalActive
    final active = state as TerminalActive;
    return LayoutBuilder(
      builder: (context, constraints) {
        _handleResize(constraints.maxWidth, constraints.maxHeight);
        return Stack(
          children: [
            CustomPaint(
              painter: TerminalPainter(
                buffer: active.buffer,
                tick: active.tick,
              ),
              size: Size(constraints.maxWidth, constraints.maxHeight),
            ),
            Positioned.fill(
              child: TextField(
                controller: _inputController,
                focusNode: _focusNode,
                keyboardType: TextInputType.multiline,
                enableSuggestions: false,
                autocorrect: false,
                showCursor: false,
                maxLines: null,
                expands: true,
                style: const TextStyle(
                  color: Colors.transparent,
                  fontSize: 1,
                  height: 1,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isCollapsed: true,
                ),
              ),
            ),
          ],
        );
      },
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

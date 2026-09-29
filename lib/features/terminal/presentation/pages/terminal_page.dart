import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/error_state_widget.dart';
import '../../../ai_command/data/repositories/ai_config_repository.dart';
import '../../../ai_command/presentation/widgets/ai_input_panel.dart';
import '../../../settings/presentation/pages/ai_config_page.dart';
import '../../../ssh_connection/presentation/widgets/host_key_dialog.dart';
import '../cubit/terminal_cubit.dart';
import '../cubit/terminal_state.dart';
import '../widgets/terminal_keyboard_bar.dart';
import '../widgets/terminal_painter.dart';
import '../widgets/terminal_selection.dart';

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
  final _selection = TerminalSelection();
  bool _isSelecting = false;
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
    _showKeyboard();
  }

  void _showKeyboard() {
    _focusNode.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _openAiPanel(BuildContext context) {
    // Ambil cubit dari context terminal sebelum membuka sheet (sheet punya
    // context sendiri). Command yang disetujui dijalankan sebagai satu baris
    // utuh (dikirim + Enter + dicatat ke history sekali).
    final terminalCubit = context.read<TerminalCubit>();
    _focusNode.unfocus();
    _guardAndOpenAi(context, terminalCubit);
  }

  Future<void> _guardAndOpenAi(
      BuildContext context, TerminalCubit terminalCubit) async {
    final config = await AiConfigRepository.create().load();
    if (!context.mounted) return;
    if (!config.isConfigured) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('AI belum dikonfigurasi'),
          content: const Text(
              'Atur provider base URL, API key, dan model terlebih dahulu.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Nanti')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Buka Settings')),
          ],
        ),
      );
      if (go == true && context.mounted) {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AiConfigPage()));
      }
      return;
    }
    if (!context.mounted) return;
    AiInputPanel.show(
      context,
      onRun: (command) => terminalCubit.runCommand(command),
    );
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
          actions: [
            IconButton(
              icon: const Icon(Icons.terminal),
              tooltip: 'AI Command',
              onPressed: () => _openAiPanel(context),
            ),
            IconButton(
              icon: const Icon(Icons.keyboard),
              onPressed: _showKeyboard,
            ),
          ],
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
        final cellH = TerminalPainter.cellSize(14).height;
        final cellW = TerminalPainter.cellSize(14).width;
        return Stack(
          children: [
            Positioned.fill(
              child: TextField(
                controller: _inputController,
                focusNode: _focusNode,
                keyboardType: TextInputType.multiline,
                enableSuggestions: false,
                autocorrect: false,
                enableInteractiveSelection: false,
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
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: (details) {
                  if (_isSelecting) return;
                  final delta = -details.delta.dy;
                  final lines = (delta / cellH).round();
                  if (lines != 0) {
                    final buf = active.buffer;
                    final newOffset =
                        (buf.scrollOffset + lines).clamp(0, buf.maxScrollBack);
                    if (newOffset != buf.scrollOffset) {
                      buf.scrollOffset = newOffset;
                      context.read<TerminalCubit>().notifyRepaint();
                    }
                  }
                },
                onLongPressStart: (details) {
                  _isSelecting = true;
                  _selection.clear();
                  final col = (details.localPosition.dx / cellW).floor();
                  final row = (details.localPosition.dy / cellH).floor();
                  _selection.start(row, col);
                  context.read<TerminalCubit>().notifyRepaint();
                },
                onLongPressMoveUpdate: (details) {
                  final col = (details.localPosition.dx / cellW).floor();
                  final row = (details.localPosition.dy / cellH).floor();
                  _selection.update(row, col);
                  context.read<TerminalCubit>().notifyRepaint();
                },
                onLongPressEnd: (_) {
                  if (_selection.isSelecting) {
                    final text = _selection.getSelectedText(active.buffer);
                    if (text.isNotEmpty) {
                      Clipboard.setData(ClipboardData(text: text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Copied to clipboard'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    }
                  }
                  _isSelecting = false;
                },
                onTap: () {
                  if (_selection.isSelecting) {
                    _selection.clear();
                    _isSelecting = false;
                    context.read<TerminalCubit>().notifyRepaint();
                  }
                  if (active.buffer.scrollOffset != 0) {
                    active.buffer.scrollOffset = 0;
                    context.read<TerminalCubit>().notifyRepaint();
                  }
                  _showKeyboard();
                },
                onDoubleTap: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  if (data?.text != null && data!.text!.isNotEmpty) {
                    _sendInput(data.text!.replaceAll('\n', '\r'));
                  }
                },
                child: CustomPaint(
                  painter: TerminalPainter(
                    buffer: active.buffer,
                    tick: active.tick,
                    selection: _selection,
                  ),
                  size: Size(constraints.maxWidth, constraints.maxHeight),
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

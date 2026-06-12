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
import '../widgets/terminal_selection.dart';

class TerminalPage extends StatelessWidget {
  final String host;
  final int port;
  final String username;
  final String? password;

  const TerminalPage({
    super.key,
    required this.host,
    required this.port,
    required this.username,
    this.password,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TerminalCubit()
        ..connectAndOpenShell(host, port, username, password: password),
      child: const _TerminalView(),
    );
  }
}

class _TerminalView extends StatefulWidget {
  const _TerminalView();

  @override
  State<_TerminalView> createState() => _TerminalViewState();
}

class _TerminalViewState extends State<_TerminalView>
    with WidgetsBindingObserver {
  final _inputController = TextEditingController();
  final _focusNode = FocusNode();
  final _selection = TerminalSelection();
  final _keyboardBarKey = GlobalKey<TerminalKeyboardBarState>();
  String _prevText = '';
  double _fontSize = 14;
  double _baseScaleFontSize = 14;
  bool _hostKeyDialogShown = false;

  int _lastCols = 0;
  int _lastRows = 0;
  Timer? _resizeDebounce;
  StreamSubscription<void>? _keepAliveSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _inputController.addListener(_onTextChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _keepAliveSub ??= context.read<TerminalCubit>().sshChannel.keepAliveExpiredStream.listen((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Background session expired')),
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _keepAliveSub?.cancel();
    _resizeDebounce?.cancel();
    _inputController.removeListener(_onTextChanged);
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // Keyboard show/hide triggers a layout change
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cubit = context.read<TerminalCubit>();
    if (state == AppLifecycleState.paused) {
      cubit.sshChannel.startKeepAlive();
    } else if (state == AppLifecycleState.resumed) {
      cubit.sshChannel.stopKeepAlive();
    }
  }

  void _handleResize(double width, double height) {
    final cell = TerminalPainter.cellSize(_fontSize);
    final cols = (width / cell.width).floor();
    final rows = (height / cell.height).floor();
    if (cols < 1 || rows < 1) return;
    if (cols == _lastCols && rows == _lastRows) return;
    _lastCols = cols;
    _lastRows = rows;
    _resizeDebounce?.cancel();
    _resizeDebounce = Timer(const Duration(milliseconds: 150), () {
      context.read<TerminalCubit>().resize(cols, rows);
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
      final ctrl = String.fromCharCode(
        input.toLowerCase().codeUnitAt(0) - 96,
      );
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

  (int, int) _posToCell(Offset pos, TerminalPainter painter) {
    final row = (pos.dy / painter.cellHeight).floor();
    final col = (pos.dx / painter.cellWidth).floor();
    return (row.clamp(0, painter.buffer.rows - 1), col.clamp(0, painter.buffer.cols - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Terminal'),
        backgroundColor: AppColors.surface,
      ),
      body: Column(
        children: [
          Expanded(
            child: BlocBuilder<TerminalCubit, TerminalState>(
              builder: (context, state) {
                if (state is TerminalConnecting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }
                if (state is TerminalHostKeyPrompt) {
                  if (!_hostKeyDialogShown) {
                    _hostKeyDialogShown = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) async {
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
                      if (!context.mounted) return;
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
                  return const Center(
                    child: Text(
                      'Verifying host key...',
                      style: TextStyle(color: AppColors.onSurface),
                    ),
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Disconnected',
                          style: TextStyle(color: AppColors.onSurface),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () =>
                              context.read<TerminalCubit>().manualReconnect(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }
                if (state is TerminalReconnecting) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                            color: AppColors.primary),
                        const SizedBox(height: 16),
                        Text(
                          'Reconnecting... (attempt ${state.attempt}/${state.maxAttempts})',
                          style: const TextStyle(color: AppColors.onSurface),
                        ),
                      ],
                    ),
                  );
                }
                if (state is TerminalActive) {
                  // Auto-scroll to bottom on new output
                  state.buffer.scrollOffset = 0;
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      _handleResize(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      );
                      final painter = TerminalPainter(
                        buffer: state.buffer,
                        selection: _selection,
                        fontSize: _fontSize,
                        tick: state.tick,
                      );
                      return GestureDetector(
                        onTap: () => _focusNode.requestFocus(),
                        onVerticalDragUpdate: (details) {
                          setState(() {
                            final delta = -(details.delta.dy / painter.cellHeight).round();
                            state.buffer.scrollOffset = (state.buffer.scrollOffset + delta)
                                .clamp(0, state.buffer.maxScrollBack);
                          });
                        },
                        onScaleStart: (_) {
                          _baseScaleFontSize = _fontSize;
                        },
                        onScaleUpdate: (details) {
                          if (details.pointerCount >= 2) {
                            setState(() {
                              _fontSize = (_baseScaleFontSize * details.scale)
                                  .clamp(8.0, 24.0);
                            });
                          }
                        },
                        onLongPressStart: (details) {
                          final (row, col) = _posToCell(details.localPosition, painter);
                          setState(() => _selection.start(row, col));
                        },
                        onLongPressMoveUpdate: (details) {
                          final (row, col) = _posToCell(details.localPosition, painter);
                          setState(() => _selection.update(row, col));
                        },
                        onLongPressEnd: (_) {
                          final text = _selection.getSelectedText(state.buffer);
                          _selection.clear();
                          setState(() {});
                          if (text.trim().isNotEmpty) {
                            Clipboard.setData(ClipboardData(text: text));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Copied!'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          }
                        },
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: painter,
                            size: painter.preferredSize,
                          ),
                        ),
                      );
                    },
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          TerminalKeyboardBar(
            key: _keyboardBarKey,
            onKeyPress: _onSpecialKey,
          ),
          // Hidden TextField to capture soft keyboard input
          SizedBox(
            height: 1,
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: _inputController,
                focusNode: _focusNode,
                autofocus: true,
                keyboardType: TextInputType.text,
                enableSuggestions: false,
                autocorrect: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ANSI/VT100 escape sequence parser using a state machine.
enum _State { normal, escape, csi }

enum AnsiActionType {
  print,
  newline,
  carriageReturn,
  backspace,
  tab,
  cursorUp,
  cursorDown,
  cursorForward,
  cursorBack,
  cursorPosition,
  eraseDisplay,
  eraseLine,
  sgr,
}

class AnsiAction {
  final AnsiActionType type;
  final String? char;
  final List<int> params;

  const AnsiAction(this.type, {this.char, this.params = const []});
}

class AnsiParser {
  _State _state = _State.normal;
  String _paramBuffer = '';

  /// Parse raw data and return a list of actions.
  List<AnsiAction> parse(String data) {
    final actions = <AnsiAction>[];
    for (var i = 0; i < data.length; i++) {
      final c = data[i];
      switch (_state) {
        case _State.normal:
          _handleNormal(c, actions);
          break;
        case _State.escape:
          _handleEscape(c, actions);
          break;
        case _State.csi:
          _handleCsi(c, actions);
          break;
      }
    }
    return actions;
  }

  void _handleNormal(String c, List<AnsiAction> actions) {
    switch (c) {
      case '\x1B':
        _state = _State.escape;
        break;
      case '\n':
        actions.add(const AnsiAction(AnsiActionType.newline));
        break;
      case '\r':
        actions.add(const AnsiAction(AnsiActionType.carriageReturn));
        break;
      case '\b':
        actions.add(const AnsiAction(AnsiActionType.backspace));
        break;
      case '\t':
        actions.add(const AnsiAction(AnsiActionType.tab));
        break;
      default:
        // Ignore other control characters
        if (c.codeUnitAt(0) >= 0x20) {
          actions.add(AnsiAction(AnsiActionType.print, char: c));
        }
    }
  }

  void _handleEscape(String c, List<AnsiAction> actions) {
    if (c == '[') {
      _state = _State.csi;
      _paramBuffer = '';
    } else {
      // Unrecognized escape — discard and return to normal
      _state = _State.normal;
    }
  }

  void _handleCsi(String c, List<AnsiAction> actions) {
    final code = c.codeUnitAt(0);
    // Parameter bytes: 0x30-0x3F (digits, semicolons, etc.)
    if (code >= 0x30 && code <= 0x3F) {
      _paramBuffer += c;
      return;
    }
    // Intermediate bytes: 0x20-0x2F — collect but we don't use them
    if (code >= 0x20 && code <= 0x2F) {
      return;
    }
    // Final byte: 0x40-0x7E — dispatch
    _state = _State.normal;
    final params = _parseParams();
    switch (c) {
      case 'A':
        actions.add(AnsiAction(AnsiActionType.cursorUp, params: params));
        break;
      case 'B':
        actions.add(AnsiAction(AnsiActionType.cursorDown, params: params));
        break;
      case 'C':
        actions.add(AnsiAction(AnsiActionType.cursorForward, params: params));
        break;
      case 'D':
        actions.add(AnsiAction(AnsiActionType.cursorBack, params: params));
        break;
      case 'H':
      case 'f':
        actions.add(AnsiAction(AnsiActionType.cursorPosition, params: params));
        break;
      case 'J':
        actions.add(AnsiAction(AnsiActionType.eraseDisplay, params: params));
        break;
      case 'K':
        actions.add(AnsiAction(AnsiActionType.eraseLine, params: params));
        break;
      case 'm':
        actions.add(AnsiAction(AnsiActionType.sgr, params: params));
        break;
      // Ignore unrecognized final bytes
    }
  }

  List<int> _parseParams() {
    if (_paramBuffer.isEmpty) return [];
    return _paramBuffer.split(';').map((s) => int.tryParse(s) ?? 0).toList();
  }
}

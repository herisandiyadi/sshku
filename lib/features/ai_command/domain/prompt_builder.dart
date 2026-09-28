/// Merakit system prompt untuk generator command. Dibuat terpisah agar mudah
/// disesuaikan tanpa menyentuh datasource.
class PromptBuilder {
  /// System prompt: minta AI membalas JSON murni berisi daftar command.
  /// [osHint] opsional (mis. "Ubuntu 22.04, bash") untuk akurasi; default asumsi
  /// bash/Linux sesuai keputusan desain v1.
  String systemPrompt({String? osHint}) {
    final target = osHint == null || osHint.trim().isEmpty
        ? 'bash on Linux (assume POSIX if unknown)'
        : osHint.trim();
    return '''
You are a shell command generator for an SSH terminal.
Target shell: $target.
Return ONLY valid minified JSON, no prose, no markdown fences, matching:
{"commands":[{"cmd":"string","desc":"string"}]}
Rules:
- Prefer safe, reversible commands.
- Never include destructive filesystem or disk commands (no rm -rf /, mkfs, dd to disk, fork bombs).
- If the request is ambiguous, return a single command that inspects state first.
- Output one command per logical step.
- Write "desc" in the same language as the user's instruction.''';
  }
}

final _varPattern = RegExp(r'\{\{(\w+)\}\}');

List<String> extractVariables(String command) =>
    _varPattern.allMatches(command).map((m) => m.group(1)!).toSet().toList();

String substituteVariables(String command, Map<String, String> values) =>
    command.replaceAllMapped(_varPattern, (m) => values[m.group(1)] ?? m.group(0)!);

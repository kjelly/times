import "dart:io";
import 'package:args/args.dart';
import 'package:uuid/uuid.dart';
import 'package:sprintf/sprintf.dart';

Future<int> measure(int timeout, String command) async {
  var start = DateTime.now();
  var p =
      await Process.run("timeout", [timeout.toString(), 'bash', '-c', command]);
  var end = DateTime.now();
  if (p.exitCode != 0 && p.exitCode != 124) {
    print(p.stdout);
    print(p.stderr);
    var v = end.difference(start).inMilliseconds;
    return -v;
  }
  return (end.difference(start)).inMilliseconds;
}

int MillisecondsToSeconds(int s) {
  if (s < 0) {
    return (-s) ~/ 1000;
  }
  return s ~/ 1000;
}

void main(List<String> args) async {
  var parser = new ArgParser();
  parser.addFlag('async',
      abbr: 'a', negatable: false, help: "save the image to the file.");
  parser.addFlag('help', abbr: 'h', negatable: false, help: "Show usages.");
  parser.addFlag('timestamp', negatable: false, help: "Show timestamp.");
  parser.addFlag('skip-zero', negatable: false, help: "skip zero.");
  parser.addOption('command',
      abbr: 'c',
      defaultsTo: "",
      help: "The command to run.",
      valueHelp: "command");
  parser.addOption('count',
      defaultsTo: "10",
      help: "How many times does the command run?",
      valueHelp: "number");
  parser.addOption('worker',
      abbr: 'w',
      defaultsTo: '10',
      help: "The worker numbers to run command.",
      valueHelp: "number");
  parser.addOption('timeout',
      abbr: 't', defaultsTo: '5', help: "timeout", valueHelp: "seconds");
  parser.addOption('post-command',
      defaultsTo: '', help: "The command to clear resources.", valueHelp: "");

  var results = parser.parse(args);

  int maxWorker = int.tryParse(results['worker']) ?? 10;
  int worker = maxWorker;
  int count = int.tryParse(results['count']) ?? 10;
  var command = results['command'] ?? '';
  var timeout = int.tryParse(results['timeout']) ?? 10;
  var errors = 0;

  if (command.length == 0 || results['help']) {
    print(parser.usage);
    return;
  }

  if (results['timestamp']) {
    var now = DateTime.now();
    print('timestamp: $now');
  }

  var times = List(timeout + 1);
  for (var i = 0; i < timeout + 1; i++) {
    times[i] = 0;
  }

  var uuid = Uuid();

  for (var i = 0; i < count; i++) {
    while (worker == 0) {
      await Future.delayed(Duration(microseconds: 1));
    }
    worker -= 1;
    var argsList = [
      'sundial-' + uuid.v4(),
      'sundial-' + uuid.v4(),
      'sundial-' + uuid.v4(),
      'sundial-' + uuid.v4(),
      'sundial-' + uuid.v4(),
    ];
    var newCommand = sprintf(command, argsList);
    var postCommand = sprintf(results['post-command'], argsList);
    measure(timeout, newCommand).then((v) {
      if (v < 0) {
        errors += 1;
      }
      times[MillisecondsToSeconds(v)] += 1;
    }).then((v) async {
      if (postCommand.length > 0) {
        await measure(timeout, postCommand);
      }
      worker += 1;
    });
  }

  while (worker < maxWorker) {
    await Future.delayed(Duration(seconds: 1));
  }

  for (var i = 0; i < timeout + 1; i++) {
    times[i] = times[i] * 100 ~/ count;
  }
  for (var i = 0; i < timeout + 1; i++) {
    if (results['skip-zero'] && times[i] == 0) {
      continue;
    }
    stdout.write(
        '${formatNumber(i, timeout.toString().length)}s: ${formatNumber(times[i], 3)}%: |');
    stdout.write(generateBar(times[i]) + '\n');
  }
  print("errors: $errors");
  print("total: $count");
}

String generateBar(int c) {
  var ret = '';
  for (var i = 0; i < c; i++) {
    ret += '=';
  }
  return ret;
}

String formatNumber(int n, int width) {
  var ret = n.toString();
  return ret.padLeft(width);
}



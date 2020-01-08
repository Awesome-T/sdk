// Copyright (c) 2018, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:args/args.dart';
import 'package:cli_util/cli_logging.dart';
import 'package:dartfix/src/context.dart';
import 'package:path/path.dart' as path;

// TODO(brianwilkerson) Deprecate 'excludeFix' and replace it with 'exclude-fix'
const excludeFixOption = 'excludeFix';
const forceOption = 'force';
const includeFixOption = 'fix';
const overwriteOption = 'overwrite';
const pedanticOption = 'pedantic';
const previewDirOption = 'preview-dir';
const previewPortOption = 'preview-port';
const requiredOption = 'required';
const sdkOption = 'sdk';

const _binaryName = 'dartfix';
const _colorOption = 'color';
const _helpOption = 'help';

// options only supported by server 1.22.2 and greater
const _previewOption = 'preview';
const _serverSnapshot = 'server';
const _verboseOption = 'verbose';

// options not supported yet by any server
const _dependencies = 'migrate-dependencies';

/// Command line options for `dartfix upgrade`.
class UpgradeOptions {
  final bool dependencies;
  final bool preview;

  UpgradeOptions._fromCommand(ArgResults results)
      : dependencies = results[_dependencies] as bool,
        preview = results[_previewOption] as bool;
}

/// Command line options for `dartfix`.
class Options {
  final Context context;
  Logger logger;

  UpgradeOptions upgradeOptions;
  List<String> targets;
  final String sdkPath;
  final String serverSnapshot;

  final bool pedanticFixes;
  final bool requiredFixes;
  final List<String> includeFixes;
  final List<String> excludeFixes;

  final bool force;
  final bool showHelp;
  bool overwrite;
  final bool useColor;
  final bool verbose;

  Options._fromArgs(this.context, ArgResults results)
      : force = results[forceOption] as bool,
        includeFixes = (results[includeFixOption] as List ?? []).cast<String>(),
        excludeFixes = (results[excludeFixOption] as List ?? []).cast<String>(),
        overwrite = results[overwriteOption] as bool,
        pedanticFixes = results[pedanticOption] as bool,
        requiredFixes = results[requiredOption] as bool,
        sdkPath = results[sdkOption] as String ?? _getSdkPath(),
        serverSnapshot = results[_serverSnapshot] as String,
        showHelp = results[_helpOption] as bool || results.arguments.isEmpty,
        targets = results.rest,
        useColor = results.wasParsed(_colorOption)
            ? results[_colorOption] as bool
            : null,
        verbose = results[_verboseOption] as bool;

  bool get isUpgrade => upgradeOptions != null;

  String makeAbsoluteAndNormalize(String target) {
    if (!path.isAbsolute(target)) {
      target = path.join(context.workingDir, target);
    }
    return path.normalize(target);
  }

  static Options parse(List<String> args, Context context, Logger logger) {
    final parser = ArgParser(allowTrailingOptions: true)
      ..addSeparator('Choosing fixes to be applied:')
      ..addMultiOption(includeFixOption,
          help: 'Include a specific fix.', valueHelp: 'name-of-fix')
      ..addMultiOption(excludeFixOption,
          help: 'Exclude a specific fix.', valueHelp: 'name-of-fix')
      ..addFlag(pedanticOption,
          help: 'Apply pedantic fixes.', defaultsTo: false, negatable: false)
      ..addFlag(requiredOption,
          help: 'Apply required fixes.', defaultsTo: false, negatable: false)
      ..addSeparator('Modifying files:')
      ..addFlag(overwriteOption,
          abbr: 'w',
          help: 'Overwrite files with the changes.',
          defaultsTo: false,
          negatable: false)
      ..addFlag(forceOption,
          abbr: 'f',
          help: 'Overwrite files even if there are errors.',
          defaultsTo: false,
          negatable: false)
      ..addSeparator('Miscellaneous:')
      ..addFlag(_helpOption,
          abbr: 'h',
          help: 'Display this help message.',
          defaultsTo: false,
          negatable: false)
      ..addOption(sdkOption,
          help: 'Path to the SDK to analyze against.',
          valueHelp: 'path',
          hide: true)
      ..addOption(_serverSnapshot,
          help: 'Path to the analysis server snapshot file.',
          valueHelp: 'path',
          hide: true)
      ..addFlag(_verboseOption,
          abbr: 'v',
          help: 'Verbose output.',
          defaultsTo: false,
          negatable: false)
      ..addFlag(_colorOption,
          help: 'Use ansi colors when printing messages.',
          defaultsTo: Ansi.terminalSupportsAnsi);

    //
    // Commands.
    //
    parser.addCommand('upgrade')
      ..addFlag(_dependencies,
          help: 'Upgrade dependencies automatically (not yet implemented)',
          defaultsTo: false,
          negatable: true,
          hide: true)
      ..addFlag(_previewOption,
          help: 'Open the preview tool to view changes.',
          defaultsTo: true,
          negatable: true,
          hide: true);

    context ??= Context();

    ArgResults results;
    try {
      results = parser.parse(args);
    } on FormatException catch (e) {
      logger ??= Logger.standard(ansi: Ansi(Ansi.terminalSupportsAnsi));
      logger.stderr(e.message);
      _showUsage(parser, logger);
      context.exit(17);
    }

    Options options = Options._fromArgs(context, results);

    if (logger == null) {
      if (options.verbose) {
        logger = Logger.verbose();
      } else {
        logger = Logger.standard(
            ansi: Ansi(
          options.useColor ?? Ansi.terminalSupportsAnsi,
        ));
      }
    }
    options.logger = logger;

    // For '--help', we short circuit the logic to validate the sdk and project.
    if (options.showHelp) {
      _showUsage(parser, logger, showHelpHint: false);
      return options;
    }

    // Validate the Dart SDK location
    String sdkPath = options.sdkPath;
    if (sdkPath == null) {
      logger.stderr('No Dart SDK found.');
      context.exit(18);
    }

    if (!context.exists(sdkPath)) {
      logger.stderr('Invalid Dart SDK path: $sdkPath');
      context.exit(19);
    }

    var command = results.command;
    if (command != null) {
      if (command.name == 'upgrade') {
        options.upgradeOptions = UpgradeOptions._fromCommand(results.command);
        var rest = command.rest;
        if (rest.isNotEmpty) {
          if (rest[0] == 'sdk') {
            if (results.wasParsed(includeFixOption)) {
              logger.stderr('Cannot define includeFixes when using upgrade.');
              context.exit(22);
            }
            if (results.wasParsed(excludeFixOption)) {
              logger.stderr('Cannot define excludeFixes when using upgrade.');
              context.exit(22);
            }
            if (results.wasParsed(pedanticOption) && options.pedanticFixes) {
              logger.stderr('Cannot use pedanticFixes when using upgrade.');
              context.exit(22);
            }
            if (results.wasParsed(requiredOption) && options.requiredFixes) {
              logger.stderr('Cannot use requiredFixes when using upgrade.');
              context.exit(22);
            }
            // TODO(jcollins-g): prevent non-nullable outside of upgrade
            // command.
            options.includeFixes.add('non-nullable');
            if (rest.length > 1) {
              options.targets = command.rest.sublist(1);
            } else {
              options.targets = [Directory.current.path];
            }
          } else {
            logger
                .stderr('Missing or invalid specification of what to upgrade.');
            logger.stderr("(Currently 'sdk' is the only supported option.)");
            context.exit(22);
          }
        }
      }
    }

    // Check for files and/or directories to analyze.
    if (options.targets == null || options.targets.isEmpty) {
      logger.stderr('Expected at least one file or directory to analyze.');
      context.exit(20);
    }

    // Normalize and verify paths
    options.targets =
        options.targets.map<String>(options.makeAbsoluteAndNormalize).toList();
    for (String target in options.targets) {
      if (!context.isDirectory(target)) {
        if (!context.exists(target)) {
          logger.stderr('Target does not exist: $target');
        } else {
          logger.stderr('Expected directory, but found: $target');
        }
        context.exit(21);
      }
    }

    if (options.verbose) {
      logger.trace('Targets:');
      for (String target in options.targets) {
        logger.trace('  $target');
      }
    }

    return options;
  }

  static String _getSdkPath() {
    return Platform.environment['DART_SDK'] ??
        path.dirname(path.dirname(Platform.resolvedExecutable));
  }

  static void _showUsage(ArgParser parser, Logger logger,
      {bool showHelpHint = true}) {
    Function(String message) out = showHelpHint ? logger.stderr : logger.stdout;
    // show help on stdout when showHelp is true and showHelpHint is false
    out('''
Usage: $_binaryName [options...] <directory paths>
''');
    out(parser.usage);
    out(showHelpHint
        ? '''

Use --$_helpOption to display the fixes that can be specified using either
--$includeFixOption or --$excludeFixOption.'''
        : '');
  }
}
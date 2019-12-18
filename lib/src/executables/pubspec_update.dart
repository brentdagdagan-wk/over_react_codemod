// Copyright 2019 Workiva Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:io';

import 'package:logging/logging.dart';
import 'package:codemod/codemod.dart';
import 'package:over_react_codemod/src/creator_utils.dart';
import 'package:over_react_codemod/src/react16_suggestors/constants.dart';
import 'package:over_react_codemod/src/react16_suggestors/pubspec_updater.dart';
import 'package:over_react_codemod/src/react16_suggestors/react_dom_render_migrator.dart';
import 'package:over_react_codemod/src/react16_suggestors/react_style_maps_updater.dart';
import 'package:over_react_codemod/src/dart2_suggestors/pubspec_over_react_upgrader.dart';
import 'package:over_react_codemod/src/react16_suggestors/pubspec_react_upgrader.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

import '../react16_suggestors/constants.dart';

const _changesRequiredOutput = """
  To update your code, run the following commands in your repository:
  pub global activate over_react_codemod
  pub global run over_react_codemod:react16_upgrade
  pub run dart_dev format (If you format this repository).
Then, review the the changes, address any FIXMEs, and commit.
""";

void main(List<String> args) {
  // Update Pubspec
  final pubspecYamlQuery = FileQuery.dir(
    pathFilter: (path) => p.basename(path) == 'pubspec.yaml',
    recursive: true,
  );

  exitCode = runInteractiveCodemod(
    pubspecYamlQuery,
    AggregateSuggestor([
      PubspecUpdater(
        [
          DependencyCreator(
            'over_react_test',
            gitOverride: 'https://github.com/Workiva/over_react_test.git',
            ref: 'CPLAT-8702-update-zone-utilities'
          )
        ],
        shouldAdd: (existingDeps, target, sectionsFound) {
          return true;
        },
      ),
    ]),
    args: args,
    defaultYes: true,
    changesRequiredOutput: _changesRequiredOutput,
  );

  if (exitCode != 0) {
    return;
  }
}
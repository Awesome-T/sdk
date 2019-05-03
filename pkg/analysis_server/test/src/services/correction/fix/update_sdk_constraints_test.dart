// Copyright (c) 2018, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analysis_server/src/services/correction/fix.dart';
import 'package:analyzer/src/dart/analysis/experiments.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'fix_processor.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(UpdateSdkConstraintsTest);
  });
}

@reflectiveTest
class UpdateSdkConstraintsTest extends FixProcessorTest {
  @override
  FixKind get kind => DartFixKind.UPDATE_SDK_CONSTRAINTS;

  test_any() async {
    await testUpdate(from: 'any', to: '^2.1.0');
  }

  test_asInConstContext() async {
    createAnalysisOptionsFile(experiments: [EnableString.constant_update_2018]);
    await testUpdate(content: '''
const dynamic a = 2;
const c = a as int;
''', to: '^2.2.2');
  }

  test_boolOperator() async {
    createAnalysisOptionsFile(experiments: [EnableString.constant_update_2018]);
    await testUpdate(content: '''
const c = true & false;
''', to: '^2.2.2');
  }

  test_caret() async {
    await testUpdate(from: '^2.0.0', to: '^2.1.0');
  }

  test_compound() async {
    await testUpdate(from: "'>=2.0.0 <3.0.0'", to: "'>=2.1.0 <3.0.0'");
  }

  test_eqEqOperatorInConstContext() async {
    await testUpdate(content: '''
class A {
  const A();
}
const a = A();
const c = a == null;
''', to: '^2.2.2');
  }

  test_gt() async {
    await testUpdate(from: "'>2.0.0'", to: "'>=2.1.0'");
  }

  test_gte() async {
    await testUpdate(from: "'>=2.0.0'", to: "'>=2.1.0'");
  }

  test_gtGtGtOperator() async {
    createAnalysisOptionsFile(experiments: [EnableString.triple_shift]);
    await testUpdate(content: '''
class C {
  C operator >>>(C other) => this;
}
''', to: '^2.2.2');
  }

  test_isInConstContext() async {
    createAnalysisOptionsFile(experiments: [EnableString.constant_update_2018]);
    await testUpdate(content: '''
const a = 0;
const c = a is int;
''', to: '^2.2.2');
  }

  test_setLiteral() async {
    await testUpdate(content: '''
var s = <int>{};
''', to: '^2.2.0');
  }

  testUpdate({String content, String from: '^2.0.0', String to}) async {
    updateTestPubspecFile('''
environment:
  sdk: $from
''');
    await resolveTestUnit(content ??
        '''
Future<int> zero() async => 0;
''');
    await assertHasFix('''
environment:
  sdk: $to
''', target: testPubspecPath);
  }
}

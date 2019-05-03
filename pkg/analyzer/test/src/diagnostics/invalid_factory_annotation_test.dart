// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/src/error/codes.dart';
import 'package:analyzer/src/test_utilities/package_mixin.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../dart/resolution/driver_resolution.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(InvalidFactoryAnnotationTest);
  });
}

@reflectiveTest
class InvalidFactoryAnnotationTest extends DriverResolutionTest
    with PackageMixin {
  test_class() async {
    addMetaPackage();
    await assertErrorCodesInCode(r'''
import 'package:meta/meta.dart';
@factory
class X {
}
''', [HintCode.INVALID_FACTORY_ANNOTATION]);
  }

  test_field() async {
    addMetaPackage();
    await assertErrorCodesInCode(r'''
import 'package:meta/meta.dart';
class X {
  @factory
  int x;
}
''', [HintCode.INVALID_FACTORY_ANNOTATION]);
  }

  test_topLevelFunction() async {
    addMetaPackage();
    await assertErrorCodesInCode(r'''
import 'package:meta/meta.dart';
@factory
main() { }
''', [HintCode.INVALID_FACTORY_ANNOTATION]);
  }
}

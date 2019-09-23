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

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:codemod/codemod.dart';
import 'package:over_react_codemod/src/component2_suggestors/component2_utilities.dart';

//TODO copy this for initialState (maybe just add to this suggestor?)
/// Suggestor that replaces `getDefaultProps` with the getter `defaultProps`.
class GetDefaultPropsMigrator extends GeneralizingAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
  final bool allowPartialUpgrades;
  final bool shouldUpgradeAbstractComponents;

  GetDefaultPropsMigrator({
    this.allowPartialUpgrades = true,
    this.shouldUpgradeAbstractComponents = false,
  });

  @override
  visitMethodDeclaration(MethodDeclaration node) {
    super.visitMethodDeclaration(node);

    ClassDeclaration containingClass = node.parent;

    if ((!allowPartialUpgrades &&
            !fullyUpgradableToComponent2(containingClass)) ||
        (!shouldUpgradeAbstractComponents &&
            canBeExtendedFrom(containingClass))) {
      return;
    }

    if (extendsComponent2(containingClass)) {
      if (node.name.name == 'getDefaultProps' ||
          node.name.name == 'getInitialState') {
        // Remove return type.
        if (node.returnType != null) {
          yieldPatch(
            node.returnType.offset,
            node.returnType.end,
            '',
          );
        }

        // Replace with getter.
        yieldPatch(
          node.name.offset,
          node.parameters.end,
          'get defaultProps',
        );

        if (node.body is BlockFunctionBody) {
          var methodBody = (node.body as BlockFunctionBody).block;

          if (methodBody.statements.length == 1 &&
              methodBody.statements.single is ReturnStatement) {
            var returnStatement =
            (methodBody.statements.single as ReturnStatement);

            updateSuperCalls(returnStatement.returnKeyword.end, returnStatement.semicolon.offset);

            // Convert to arrow function if method body is a single return.
            yieldPatch(
              methodBody.leftBracket.offset,
              returnStatement.returnKeyword.end,
              '=> (',
            );
            yieldPatch(
              returnStatement.semicolon.offset,
              returnStatement.semicolon.offset,
              '\n)',
            );
            yieldPatch(
              methodBody.rightBracket.offset,
              methodBody.rightBracket.end,
              '',
            );
          } else {
            updateSuperCalls(methodBody.leftBracket.end, methodBody.rightBracket.offset);
          }
        } else if (node.body is ExpressionFunctionBody) {
          var expression = (node.body as ExpressionFunctionBody).expression;

          updateSuperCalls(expression.offset, expression.end);

          // Add parenthesis if needed.
          if (expression is! ParenthesizedExpression &&
              expression is CascadeExpression &&
              expression.target is MethodInvocation &&
              (expression.target as MethodInvocation).methodName.name ==
                  'newProps') {
            yieldPatch(
              expression.offset,
              expression.offset,
              '(',
            );
            yieldPatch(
              expression.end,
              expression.end,
              '\n)',
            );
          }
        }
      }
    }
  }

  void updateSuperCalls(int offset, int end) {
    var methodBodyString = sourceFile.getText(offset, end);
    if (methodBodyString.contains('super.getDefaultProps()')) {
      methodBodyString = methodBodyString.replaceAll(
        'super.getDefaultProps()',
        'super.defaultProps',
      );
      yieldPatch(offset, end, methodBodyString);
    }
  }
}

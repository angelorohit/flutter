// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import 'binding.dart';
import 'focus_manager.dart';
import 'framework.dart';

/// Creates actions for use in defining shortcuts.
///
/// Used by clients of [ShortcutMap] to define shortcut maps.
typedef ActionFactory = Action Function();

/// A class representing a particular configuration of an action.
///
/// This class is what a key map in a [ShortcutMap] has as values, and is used
/// by an [ActionDispatcher] to look up an action and invoke it, giving it this
/// object to extract configuration information from.
///
/// If this intent returns false from [isEnabled], then its associated action will
/// not be invoked if requested.
class Intent extends Diagnosticable {
  /// A const constructor for an [Intent].
  ///
  /// The [key] argument must not be null.
  const Intent(this.key) : assert(key != null);

  /// An intent that can't be mapped to an action.
  ///
  /// This Intent is mapped to an action in the [WidgetsApp] that does nothing,
  /// so that it can be bound to a key in a [Shortcuts] widget in order to
  /// disable a key binding made above it in the hierarchy.
  static const Intent doNothing = DoNothingIntent();

  /// The key for the action this intent is associated with.
  final LocalKey key;

  /// Returns true if the associated action is able to be executed in the
  /// given `context`.
  ///
  /// Returns true by default.
  bool isEnabled(BuildContext context) => true;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<LocalKey>('key', key));
  }
}

/// Base class for actions.
///
/// As the name implies, an [Action] is an action or command to be performed.
/// They are typically invoked as a result of a user action, such as a keyboard
/// shortcut in a [Shortcuts] widget, which is used to look up an [Intent],
/// which is given to an [ActionDispatcher] to map the [Intent] to an [Action]
/// and invoke it.
///
/// The [ActionDispatcher] can invoke an [Action] on the primary focus, or
/// without regard for focus.
///
/// See also:
///
///  - [Shortcuts], which is a widget that contains a key map, in which it looks
///    up key combinations in order to invoke actions.
///  - [Actions], which is a widget that defines a map of [Intent] to [Action]
///    and allows redefining of actions for its descendants.
///  - [ActionDispatcher], a class that takes an [Action] and invokes it using a
///    [FocusNode] for context.
abstract class Action extends Diagnosticable {
  /// A const constructor for an [Action].
  ///
  /// The [intentKey] parameter must not be null.
  const Action(this.intentKey) : assert(intentKey != null);

  /// The unique key for this action.
  ///
  /// This key will be used to map to this action in an [ActionDispatcher].
  final LocalKey intentKey;

  /// Called when the action is to be performed.
  ///
  /// This is called by the [ActionDispatcher] when an action is accepted by a
  /// [FocusNode] by returning true from its `onAction` callback, or when an
  /// action is invoked using [ActionDispatcher.invokeAction].
  ///
  /// This method is only meant to be invoked by an [ActionDispatcher], or by
  /// subclasses.
  ///
  /// Actions invoked directly with [ActionDispatcher.invokeAction] may receive a
  /// null `node`. If the information available from a focus node is
  /// needed in the action, use [ActionDispatcher.invokeFocusedAction] instead.
  @protected
  @mustCallSuper
  void invoke(FocusNode node, covariant Intent intent);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<LocalKey>('intentKey', intentKey));
  }
}

/// The signature of a callback accepted by [CallbackAction].
typedef OnInvokeCallback = void Function(FocusNode node, Intent tag);

/// An [Action] that takes a callback in order to configure it without having to
/// subclass it.
///
/// See also:
///
///  - [Shortcuts], which is a widget that contains a key map, in which it looks
///    up key combinations in order to invoke actions.
///  - [Actions], which is a widget that defines a map of [Intent] to [Action]
///    and allows redefining of actions for its descendants.
///  - [ActionDispatcher], a class that takes an [Action] and invokes it using a
///    [FocusNode] for context.
class CallbackAction extends Action {
  /// A const constructor for an [Action].
  ///
  /// The `intentKey` and [onInvoke] parameters must not be null.
  /// The [onInvoke] parameter is required.
  const CallbackAction(LocalKey intentKey, {@required this.onInvoke})
      : assert(onInvoke != null),
        super(intentKey);

  /// The callback to be called when invoked.
  ///
  /// Must not be null.
  @protected
  final OnInvokeCallback onInvoke;

  @override
  void invoke(FocusNode node, Intent intent) => onInvoke.call(node, intent);
}

/// An action manager that simply invokes the actions given to it.
class ActionDispatcher extends Diagnosticable {
  /// Const constructor so that subclasses can be const.
  const ActionDispatcher();

  /// Invokes the given action, optionally without regard for the currently
  /// focused node in the focus tree.
  ///
  /// Actions invoked will receive the given `focusNode`, or the
  /// [FocusManager.primaryFocus] if the given `focusNode` is null.
  ///
  /// The `action` and `intent` arguments must not be null.
  ///
  /// Returns true if the action was successfully invoked.
  bool invokeAction(Action action, Intent intent, {FocusNode focusNode}) {
    assert(action != null);
    assert(intent != null);
    focusNode ??= WidgetsBinding.instance.focusManager.primaryFocus;
    if (action != null && intent.isEnabled(focusNode.context)) {
      action.invoke(focusNode, intent);
      return true;
    }
    return false;
  }
}

/// A widget that establishes an [ActionDispatcher] and a map of [Intent] to
/// [Action] to be used by its descendants when invoking an [Action].
///
/// Actions are typically invoked using [Actions.invoke] with the context
/// containing the ambient [Actions] widget.
///
/// See also:
///
///   * [ActionDispatcher], the object that this widget uses to manage actions.
///   * [Action], a class for containing and defining an invocation of a user
///     action.
///   * [Intent], a class that holds a unique [LocalKey] identifying an action,
///     as well as configuration information for running the [Action].
///   * [Shortcuts], a widget used to bind key combinations to [Intent]s.
class Actions extends InheritedWidget {
  /// Creates an [Actions] widget.
  ///
  /// The [child], [actions], and [dispatcher] arguments must not be null.
  const Actions({
    Key key,
    this.dispatcher,
    @required this.actions,
    @required Widget child,
  })  : assert(actions != null),
        super(key: key, child: child);

  /// The [ActionDispatcher] object that invokes actions.
  ///
  /// This is what is returned from [Actions.of], and used by [Actions.invoke].
  ///
  /// If this [dispatcher] is null, then [Actions.of] and [Actions.invoke] will
  /// look up the tree until they find an Actions widget that has a dispatcher
  /// set. If not such widget is found, then they will return/use a
  /// default-constructed [ActionDispatcher].
  final ActionDispatcher dispatcher;

  /// A map of [Intent] keys to [ActionFactory] factory methods that defines
  /// which actions this widget knows about.
  final Map<LocalKey, ActionFactory> actions;

  // Finds the nearest valid ActionDispatcher, or creates a new one if it
  // doesn't find one.
  static ActionDispatcher _findDispatcher(Element element) {
    assert(element.widget is Actions);
    final Actions actions = element.widget;
    ActionDispatcher dispatcher = actions.dispatcher;
    if (dispatcher == null) {
      bool visitAncestorElement(Element visitedElement) {
        if (visitedElement.widget is! Actions) {
          // Continue visiting.
          return true;
        }
        final Actions actions = visitedElement.widget;
        if (actions.dispatcher == null) {
          // Continue visiting.
          return true;
        }
        dispatcher = actions.dispatcher;
        // Stop visiting.
        return false;
      }

      element.visitAncestorElements(visitAncestorElement);
    }
    return dispatcher ?? const ActionDispatcher();
  }

  /// Returns the [ActionDispatcher] associated with the [Actions] widget that
  /// most tightly encloses the given [BuildContext].
  ///
  /// Will throw if no ambient [Actions] widget is found.
  ///
  /// If `nullOk` is set to true, then if no ambient [Actions] widget is found,
  /// this will return null.
  ///
  /// The `context` argument must not be null.
  static ActionDispatcher of(BuildContext context, {bool nullOk = false}) {
    assert(context != null);
    final InheritedElement inheritedElement = context.ancestorInheritedElementForWidgetOfExactType(Actions);
    final Actions inherited = context.inheritFromElement(inheritedElement);
    assert(() {
      if (nullOk) {
        return true;
      }
      if (inherited == null) {
        throw FlutterError('Unable to find an $Actions widget in the context.\n'
            '$Actions.of() was called with a context that does not contain an '
            '$Actions widget.\n'
            'No $Actions ancestor could be found starting from the context that '
            'was passed to $Actions.of(). This can happen if the context comes '
            'from a widget above those widgets.\n'
            'The context used was:\n'
            '  $context');
      }
      return true;
    }());
    return inherited?.dispatcher ?? _findDispatcher(inheritedElement);
  }

  /// Invokes the action associated with the given [Intent] using the
  /// [Actions] widget that most tightly encloses the given [BuildContext].
  ///
  /// The `context`, `intent` and `nullOk` arguments must not be null.
  ///
  /// If the given `intent` isn't found in the first [Actions.actions] map, then
  /// it will move up to the next [Actions] widget in the hierarchy until it
  /// reaches the root.
  ///
  /// Will throw if no ambient [Actions] widget is found, or if the given
  /// `intent` doesn't map to an action in any of the [Actions.actions] maps
  /// that are found.
  ///
  /// Returns true if an action was successfully invoked.
  ///
  /// Setting `nullOk` to true means that if no ambient [Actions] widget is
  /// found, then this method will return false instead of throwing.
  static bool invoke(
    BuildContext context,
    Intent intent, {
    FocusNode focusNode,
    bool nullOk = false,
  }) {
    assert(context != null);
    assert(intent != null);
    Element actionsElement;
    Action action;

    bool visitAncestorElement(Element element) {
      if (element.widget is! Actions) {
        // Continue visiting.
        return true;
      }
      // Below when we invoke the action, we need to use the dispatcher from the
      // Actions widget where we found the action, in case they need to match.
      actionsElement = element;
      final Actions actions = element.widget;
      action = actions.actions[intent.key]?.call();
      // Keep looking if we failed to find and create an action.
      return action == null;
    }

    context.visitAncestorElements(visitAncestorElement);
    assert(() {
      if (nullOk) {
        return true;
      }
      if (actionsElement == null) {
        throw FlutterError('Unable to find a $Actions widget in the context.\n'
            '$Actions.invoke() was called with a context that does not contain an '
            '$Actions widget.\n'
            'No $Actions ancestor could be found starting from the context that '
            'was passed to $Actions.invoke(). This can happen if the context comes '
            'from a widget above those widgets.\n'
            'The context used was:\n'
            '  $context');
      }
      if (action == null) {
        throw FlutterError('Unable to find an action for an intent in the $Actions widget in the context.\n'
            '$Actions.invoke() was called on an $Actions widget that doesn\'t '
            'contain a mapping for the given intent.\n'
            'The context used was:\n'
            '  $context\n'
            'The intent requested was:\n'
            '  $intent');
      }
      return true;
    }());
    if (action == null) {
      // Will only get here if nullOk is true.
      return false;
    }

    // Invoke the action we found using the dispatcher from the Actions Element
    // we found, using the given focus node.
    return _findDispatcher(actionsElement).invokeAction(action, intent, focusNode: focusNode);
  }

  @override
  bool updateShouldNotify(Actions oldWidget) {
    return oldWidget.dispatcher != dispatcher || oldWidget.actions != actions;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ActionDispatcher>('dispatcher', dispatcher));
    properties.add(DiagnosticsProperty<Map<LocalKey, ActionFactory>>('actions', actions));
  }
}

/// An [Action], that, as the name implies, does nothing.
///
/// This action is bound to the [Intent.doNothing] intent inside of
/// [WidgetsApp.build] so that a [Shortcuts] widget can bind a key to it to
/// override another shortcut binding defined above it in the hierarchy.
class DoNothingAction extends Action {
  /// Const constructor for [DoNothingAction].
  const DoNothingAction() : super(key);

  /// The Key used for the [DoNothingIntent] intent, and registered at the top
  /// level actions in [WidgetsApp.build].
  static const LocalKey key = ValueKey<Type>(DoNothingAction);

  @override
  void invoke(FocusNode node, Intent intent) { }
}

/// An [Intent] that can be used to disable [Shortcuts] key bindings defined
/// above a widget in the hierarchy.
///
/// The [Intent.doNothing] intent is of this type.
class DoNothingIntent extends Intent {
  /// Const constructor for [DoNothingIntent].
  const DoNothingIntent() : super(DoNothingAction.key);
}

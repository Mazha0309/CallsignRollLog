import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef AppAutocompleteOptionBuilder<T extends Object> = Widget Function(
  BuildContext context,
  T option,
);

/// Completes the desktop keyboard contract that [RawAutocomplete] exposes via
/// its field builder. Arrow-key intents remain owned by [RawAutocomplete]; an
/// unmodified Enter accepts the currently highlighted option. Mobile IME
/// actions still use the text field's `onFieldSubmitted` callback.
class AppAutocompleteKeyboardSubmit extends StatelessWidget {
  const AppAutocompleteKeyboardSubmit({
    super.key,
    required this.controller,
    required this.onSubmitted,
    required this.child,
  });

  final TextEditingController controller;
  final VoidCallback onSubmitted;
  final Widget child;

  @override
  Widget build(BuildContext context) => Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent ||
              (event.logicalKey != LogicalKeyboardKey.enter &&
                  event.logicalKey != LogicalKeyboardKey.numpadEnter)) {
            return KeyEventResult.ignored;
          }
          final composing = controller.value.composing;
          if (composing.isValid && !composing.isCollapsed) {
            return KeyEventResult.ignored;
          }
          onSubmitted();
          return KeyEventResult.handled;
        },
        child: child,
      );
}

/// Material autocomplete options with visible keyboard highlighting and
/// automatic scrolling as the highlighted option moves.
class AppAutocompleteOptionsList<T extends Object> extends StatefulWidget {
  const AppAutocompleteOptionsList({
    super.key,
    required this.options,
    required this.highlightedIndex,
    required this.onSelected,
    required this.optionBuilder,
  });

  final List<T> options;
  final int highlightedIndex;
  final ValueChanged<T> onSelected;
  final AppAutocompleteOptionBuilder<T> optionBuilder;

  @override
  State<AppAutocompleteOptionsList<T>> createState() =>
      _AppAutocompleteOptionsListState<T>();
}

class _AppAutocompleteOptionsListState<T extends Object>
    extends State<AppAutocompleteOptionsList<T>> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(AppAutocompleteOptionsList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlightedIndex != oldWidget.highlightedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _revealHighlightedOption();
      });
    }
  }

  void _revealHighlightedOption() {
    final index = widget.highlightedIndex;
    if (index < 0 || index >= widget.options.length) return;
    final optionContext = GlobalObjectKey(
      widget.options[index],
    ).currentContext;
    if (optionContext != null) {
      Scrollable.ensureVisible(
        optionContext,
        alignment: 0.5,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
      return;
    }
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(
      index == 0
          ? _scrollController.position.minScrollExtent
          : _scrollController.position.maxScrollExtent,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextFieldTapRegion(
        // The autocomplete overlay lives outside the text field subtree.
        // Treating it as part of the field prevents a touch drag from firing
        // TextField.onTapOutside and closing the menu before it can scroll.
        child: ScrollConfiguration(
          behavior: const _AutocompleteScrollBehavior(),
          child: Scrollbar(
            controller: _scrollController,
            child: ListView.builder(
              key: const Key('app-autocomplete-options'),
              controller: _scrollController,
              primary: false,
              physics: const ClampingScrollPhysics(),
              dragStartBehavior: DragStartBehavior.start,
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: widget.options.length,
              itemBuilder: (context, index) {
                final option = widget.options[index];
                final highlighted = index == widget.highlightedIndex;
                return Semantics(
                  selected: highlighted,
                  button: true,
                  child: InkWell(
                    key: GlobalObjectKey(option),
                    onTap: () => widget.onSelected(option),
                    child: ColoredBox(
                      color: highlighted
                          ? Theme.of(context).focusColor
                          : Colors.transparent,
                      child: widget.optionBuilder(context, option),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
}

bool isGlobalOffsetInside(Offset globalOffset, GlobalKey key) {
  final renderObject = key.currentContext?.findRenderObject();
  if (renderObject is! RenderBox || !renderObject.attached) return false;
  final local = renderObject.globalToLocal(globalOffset);
  return local.dx >= 0 &&
      local.dy >= 0 &&
      local.dx <= renderObject.size.width &&
      local.dy <= renderObject.size.height;
}

class _AutocompleteScrollBehavior extends MaterialScrollBehavior {
  const _AutocompleteScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const <PointerDeviceKind>{
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.trackpad,
      };
}

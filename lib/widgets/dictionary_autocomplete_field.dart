import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:openlogtool/models/dictionary_item.dart';
import 'package:openlogtool/utils/dictionary_ranking.dart';
import 'package:openlogtool/utils/dictionary_usage_store.dart';
import 'package:openlogtool/utils/ime_safe_upper_case_formatter.dart';
import 'package:openlogtool/widgets/autocomplete_options_list.dart';
import 'package:openlogtool/widgets/scroll_safe_unfocus.dart';

class DictionaryAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String label;
  final String hintText;
  final List<DictionaryItem> options;
  final bool upperCase;
  final bool isCompact;
  final TextInputAction? textInputAction;
  final bool enabled;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final DictionaryUsageStore? usageStore;

  const DictionaryAutocompleteField({
    super.key,
    required this.controller,
    this.focusNode,
    required this.label,
    required this.hintText,
    required this.options,
    this.upperCase = true,
    this.isCompact = false,
    this.textInputAction,
    this.enabled = true,
    this.validator,
    this.onChanged,
    this.usageStore,
  });

  @override
  State<DictionaryAutocompleteField> createState() =>
      _DictionaryAutocompleteFieldState();
}

class _DictionaryAutocompleteFieldState
    extends State<DictionaryAutocompleteField> {
  final GlobalKey _optionsKey = GlobalKey();
  final _outsideTap = ScrollSafeUnfocus();
  late final DictionaryUsageStore _usageStore;

  @override
  void initState() {
    super.initState();
    _usageStore = widget.usageStore ?? DictionaryUsageStore.shared();
    _usageStore.ensureLoaded();
  }

  @override
  void dispose() {
    _outsideTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textCapitalization = widget.upperCase
        ? TextCapitalization.characters
        : TextCapitalization.none;
    final inputFormatters = widget.upperCase
        ? const [ImeSafeUpperCaseTextFormatter()]
        : const <TextInputFormatter>[];

    return Autocomplete<_DictionaryOption>(
      textEditingController: widget.controller,
      focusNode: widget.focusNode,
      optionsBuilder: (TextEditingValue value) {
        return [
          for (final option in rankDictionaryMatches(
            query: value.text,
            options: widget.options,
            usageCount: (item) => _usageStore.countFor(item.type, item.raw),
          ))
            _DictionaryOption(option),
        ];
      },
      displayStringForOption: (option) => option.value,
      onSelected: (_DictionaryOption selection) {
        _usageStore.recordSelection(selection.item.type, selection.value);
        widget.controller.value = TextEditingValue(
          text: selection.value,
          selection: TextSelection.collapsed(offset: selection.value.length),
        );
      },
      fieldViewBuilder: (
        BuildContext context,
        TextEditingController fieldController,
        FocusNode fieldFocusNode,
        VoidCallback onFieldSubmitted,
      ) {
        return AppAutocompleteKeyboardSubmit(
          controller: fieldController,
          onSubmitted: onFieldSubmitted,
          child: TextFormField(
            controller: fieldController,
            focusNode: fieldFocusNode,
            enabled: widget.enabled,
            validator: widget.validator,
            decoration: InputDecoration(
              labelText: widget.label,
              hintText: widget.hintText,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: widget.isCompact ? 10 : 14,
              ),
            ),
            onChanged: widget.onChanged,
            onFieldSubmitted: (_) => onFieldSubmitted(),
            textInputAction: widget.textInputAction ?? TextInputAction.next,
            textCapitalization: textCapitalization,
            inputFormatters: inputFormatters,
            onTapOutside: (event) {
              if (isGlobalOffsetInside(event.position, _optionsKey)) return;
              _outsideTap.onTapOutside(event, fieldFocusNode);
            },
          ),
        );
      },
      optionsViewBuilder: (
        BuildContext context,
        AutocompleteOnSelected<_DictionaryOption> onSelected,
        Iterable<_DictionaryOption> options,
      ) {
        final theme = Theme.of(context);
        final optionList = options.toList(growable: false);
        final highlightedIndex = AutocompleteHighlightedOption.of(context);
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            key: _optionsKey,
            elevation: 3,
            color: theme.colorScheme.surfaceContainer,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260, maxWidth: 320),
              child: AppAutocompleteOptionsList<_DictionaryOption>(
                options: optionList,
                highlightedIndex: highlightedIndex,
                onSelected: onSelected,
                optionBuilder: (context, item) {
                  return ListTile(
                    dense: true,
                    title: Text(item.value),
                    subtitle: item.item.abbreviation.isNotEmpty ||
                            item.item.pinyin.isNotEmpty
                        ? Text(
                            [
                              if (item.item.abbreviation.isNotEmpty)
                                item.item.abbreviation,
                              if (item.item.pinyin.isNotEmpty) item.item.pinyin,
                            ].join(' · '),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : null,
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DictionaryOption {
  final DictionaryItem item;
  _DictionaryOption(this.item);
  String get value => item.raw;
}

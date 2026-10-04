import 'package:flutter/material.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/models/dictionary_item.dart';
import 'package:openlogtool/models/log_entry.dart';
import 'package:openlogtool/providers/dictionary_provider.dart';
import 'package:openlogtool/utils/log_time.dart';
import 'package:openlogtool/widgets/dictionary_autocomplete_field.dart';
import 'package:openlogtool/widgets/scroll_safe_unfocus.dart';
import 'package:provider/provider.dart';

Future<LogEntry?> showRecordEditorDialog(
  BuildContext context, {
  required LogEntry log,
  required bool readOnly,
}) {
  return showDialog<LogEntry>(
    context: context,
    builder: (dialogContext) => RecordEditorDialog(
      log: log,
      readOnly: readOnly,
    ),
  );
}

class RecordEditorDialog extends StatefulWidget {
  final LogEntry log;
  final bool readOnly;
  final String? title;

  const RecordEditorDialog({
    super.key,
    required this.log,
    this.readOnly = false,
    this.title,
  });

  @override
  State<RecordEditorDialog> createState() => _RecordEditorDialogState();
}

class _RecordEditorDialogState extends State<RecordEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _outsideTap = ScrollSafeUnfocus();
  late final Map<String, TextEditingController> _controllers;
  late final Map<String, FocusNode> _focusNodes;
  bool _saving = false;

  static const _fields = <String>[
    'time',
    'controller',
    'callsign',
    'rstSent',
    'rstRcvd',
    'qth',
    'device',
    'power',
    'antenna',
    'height',
    'remarks',
  ];

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final field in _fields)
        field: TextEditingController(text: _initialText(widget.log, field)),
    };
    _focusNodes = {
      for (final field in _fields) field: FocusNode(),
    };
  }

  static String _initialText(LogEntry log, String field) => switch (field) {
        'time' => formatLogTimeForDisplay(log.time),
        'controller' => log.controller,
        'callsign' => log.callsign,
        'rstSent' => log.report,
        'rstRcvd' => log.rstRcvd,
        'qth' => log.qth,
        'device' => log.device,
        'power' => log.power,
        'antenna' => log.antenna,
        'height' => log.height,
        'remarks' => log.remarks,
        _ => '',
      };

  @override
  void dispose() {
    _outsideTap.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  LogEntry _buildPatch() {
    final log = widget.log;
    return LogEntry(
      id: log.id,
      sessionId: log.sessionId,
      time: _controllers['time']!.text,
      controller: _controllers['controller']!.text,
      callsign: _controllers['callsign']!.text,
      report: _controllers['rstSent']!.text,
      rstRcvd: _controllers['rstRcvd']!.text,
      qth: _controllers['qth']!.text,
      device: _controllers['device']!.text,
      power: _controllers['power']!.text,
      antenna: _controllers['antenna']!.text,
      height: _controllers['height']!.text,
      createdAt: log.createdAt,
    )..remarks = _controllers['remarks']!.text;
  }

  @override
  Widget build(BuildContext context) {
    final dictionary = Provider.of<DictionaryProvider>(context);
    final theme = Theme.of(context);
    final isNarrow = MediaQuery.sizeOf(context).width < 560;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.edit_outlined, size: 22, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(widget.title ?? context.l10n.editRecord)),
        ],
      ),
      content: SizedBox(
        width: isNarrow ? 320 : 520,
        child: Form(
          key: _formKey,
          child: FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildField(
                    field: 'time',
                    label: context.l10n.fieldTime,
                    width: isNarrow ? null : 140,
                    validator: (value) => isValidLogTimeInput(value ?? '')
                        ? null
                        : context.l10n.logTimeInvalid,
                  ),
                  _buildField(
                    field: 'controller',
                    label: context.l10n.fieldController,
                  ),
                  _buildField(
                    field: 'callsign',
                    label: context.l10n.fieldCallsign,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return context.l10n.callsignRequired;
                      }
                      return null;
                    },
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildField(
                          field: 'rstSent',
                          label: context.l10n.fieldRstSent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildField(
                          field: 'rstRcvd',
                          label: context.l10n.fieldRstRcvd,
                        ),
                      ),
                    ],
                  ),
                  _buildDictionaryField(
                    field: 'qth',
                    label: context.l10n.fieldQth,
                    options: dictionary.qthDict,
                    upperCase: false,
                  ),
                  _buildDictionaryField(
                    field: 'device',
                    label: context.l10n.fieldDevice,
                    options: dictionary.deviceDict,
                    upperCase: false,
                  ),
                  _buildDictionaryField(
                    field: 'antenna',
                    label: context.l10n.fieldAntenna,
                    options: dictionary.antennaDict,
                    upperCase: false,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildField(
                          field: 'power',
                          label: context.l10n.fieldPower,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildField(
                          field: 'height',
                          label: context.l10n.fieldHeight,
                        ),
                      ),
                    ],
                  ),
                  _buildField(
                    field: 'remarks',
                    label: context.l10n.fieldRemarks,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        Focus(
          canRequestFocus: false,
          skipTraversal: true,
          descendantsAreTraversable: false,
          child: TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
        ),
        Focus(
          canRequestFocus: false,
          skipTraversal: true,
          descendantsAreTraversable: false,
          child: FilledButton(
            key: const Key('record-editor-save'),
            onPressed: _saving || widget.readOnly ? null : _submit,
            child: Text(context.l10n.saveRecord),
          ),
        ),
      ],
    );
  }

  Widget _buildField({
    required String field,
    required String label,
    double? width,
    String? Function(String?)? validator,
  }) {
    final fieldWidget = Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        key: Key('record-editor-field-$field'),
        controller: _controllers[field],
        focusNode: _focusNodes[field],
        onTapOutside: (event) =>
            _outsideTap.onTapOutside(event, _focusNodes[field]),
        enabled: !widget.readOnly,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      ),
    );
    return width == null
        ? fieldWidget
        : SizedBox(width: width, child: fieldWidget);
  }

  Widget _buildDictionaryField({
    required String field,
    required String label,
    required List<DictionaryItem> options,
    bool upperCase = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DictionaryAutocompleteField(
        key: Key('record-editor-field-$field'),
        controller: _controllers[field]!,
        focusNode: _focusNodes[field],
        label: label,
        hintText: label,
        options: options,
        upperCase: upperCase,
        enabled: !widget.readOnly,
        textInputAction: TextInputAction.next,
      ),
    );
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    Navigator.pop(context, _buildPatch());
  }
}

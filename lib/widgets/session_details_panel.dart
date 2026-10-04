import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/src/bridge/models/session.dart';
import 'package:openlogtool/theme/app_theme.dart';

class SessionDetailsPanel extends StatelessWidget {
  const SessionDetailsPanel(
      {super.key,
      required this.session,
      required this.recordCount,
      required this.collaborative});
  final Session session;
  final int recordCount;
  final bool collaborative;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    String time(String value) {
      final parsed = DateTime.tryParse(value);
      return parsed == null
          ? value
          : DateFormat('yyyy-MM-dd HH:mm:ss').format(parsed.toLocal());
    }

    Widget field(String name, String label, String value,
            {bool selectable = false}) =>
        Column(
          key: ValueKey('session-detail-$name'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: AppSpace.xxs),
            if (selectable)
              SelectableText(value,
                  // EditableText stores a double scroll offset. Keep it separate from
                  // ExpansionTile's boolean expansion state and the outer ListView.
                  key:
                      PageStorageKey('session-details-id-${session.sessionId}'),
                  style: theme.textTheme.bodyMedium)
            else
              Text(value, style: theme.textTheme.bodyMedium),
          ],
        );
    return ExpansionTile(
      key: PageStorageKey('session-details-expanded-${session.sessionId}'),
      tilePadding: EdgeInsets.zero,
      title: Text(l.hubSessionDetails),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final fieldWidth = constraints.maxWidth < AppBreakpoints.compact
                ? constraints.maxWidth
                : (constraints.maxWidth - AppSpace.lg) / 2;
            final fields = [
              field('type', l.detailsType,
                  collaborative ? l.detailsShared : l.detailsLocal),
              field(
                  'status',
                  l.detailsStatus,
                  session.status == 'active'
                      ? l.sessionActive
                      : l.sessionClosed),
              field('records', l.detailsRecords, l.recordCount(recordCount)),
              field('created', l.detailsCreated, time(session.createdAt)),
              field('updated', l.detailsUpdated, time(session.updatedAt)),
              if (session.closedAt != null)
                field('ended', l.detailsEnded, time(session.closedAt!)),
            ];
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: AppSpace.lg,
                    runSpacing: AppSpace.md,
                    children: [
                      for (final detail in fields)
                        SizedBox(width: fieldWidth, child: detail),
                    ],
                  ),
                  const Divider(height: AppSpace.lg),
                  field('id', l.detailsId, session.sessionId, selectable: true),
                ],
              ),
            );
          },
        )
      ],
    );
  }
}

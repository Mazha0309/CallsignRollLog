import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:openlogtool/l10n/l10n.dart';
import 'package:openlogtool/src/bridge/models/session.dart';

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
    String time(String value) {
      final parsed = DateTime.tryParse(value);
      return parsed == null
          ? value
          : DateFormat('yyyy-MM-dd HH:mm:ss').format(parsed.toLocal());
    }

    Widget row(String label, String value, {bool selectable = false}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 2),
            if (selectable)
              SelectableText(value,
                  // EditableText stores a double scroll offset. Keep it separate from
                  // ExpansionTile's boolean expansion state and the outer ListView.
                  key:
                      PageStorageKey('session-details-id-${session.sessionId}'))
            else
              Text(value),
          ]),
        );
    return ExpansionTile(
      key: PageStorageKey('session-details-expanded-${session.sessionId}'),
      tilePadding: EdgeInsets.zero,
      title: Text(l.hubSessionDetails),
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            row(l.detailsType,
                collaborative ? l.detailsShared : l.detailsLocal),
            row(l.detailsStatus,
                session.status == 'active' ? l.sessionActive : l.sessionClosed),
            row(l.detailsRecords, l.recordCount(recordCount)),
            row(l.detailsCreated, time(session.createdAt)),
            row(l.detailsUpdated, time(session.updatedAt)),
            if (session.closedAt != null)
              row(l.detailsEnded, time(session.closedAt!)),
            row(l.detailsId, session.sessionId, selectable: true),
          ]),
        )
      ],
    );
  }
}

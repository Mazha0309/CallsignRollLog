import 'package:flutter/material.dart';

/// Page navigation uses tabs; segmented buttons are reserved for input choices.
class AppSectionTabs<T> extends StatelessWidget {
  const AppSectionTabs(
      {super.key,
      required this.segments,
      required this.selected,
      required this.onSelectionChanged,
      this.secondary = false});
  final List<ButtonSegment<T>> segments;
  final Set<T> selected;
  final ValueChanged<Set<T>> onSelectionChanged;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final index = segments.indexWhere((item) => selected.contains(item.value));
    final tabs = [
      for (final item in segments)
        Tab(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (item.icon != null) ...[item.icon!, const SizedBox(width: 8)],
          if (item.label != null) item.label!
        ]))
    ];
    return DefaultTabController(
      key: ValueKey(Object.hashAll(
          [secondary, index, ...segments.map((item) => item.value)])),
      length: segments.length,
      initialIndex: index < 0 ? 0 : index,
      child: secondary
          ? TabBar.secondary(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: tabs,
              onTap: (index) => onSelectionChanged({segments[index].value}))
          : TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: tabs,
              onTap: (index) => onSelectionChanged({segments[index].value})),
    );
  }
}

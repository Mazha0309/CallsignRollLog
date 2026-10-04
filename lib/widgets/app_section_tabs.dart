import 'package:flutter/material.dart';
import 'package:openlogtool/theme/app_theme.dart';

/// Inline icon and label with a common minimum width, even for short labels.
class AppSectionTab extends StatelessWidget {
  const AppSectionTab({super.key, this.icon, required this.label});

  final Widget? icon;
  final Widget label;

  @override
  Widget build(BuildContext context) => Tab(
        height: 48,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 128),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                IconTheme.merge(
                    data: const IconThemeData(size: 20), child: icon!),
                const SizedBox(width: AppSpace.xs),
              ],
              label,
            ],
          ),
        ),
      );
}

/// Shared page navigation, also usable with an ancestor DefaultTabController
/// and TabBarView. Long labels and narrow windows scroll horizontally.
class AppSectionTabBar extends StatelessWidget implements PreferredSizeWidget {
  const AppSectionTabBar({
    super.key,
    required this.tabs,
    this.onTap,
    this.secondary = false,
  });

  final List<Widget> tabs;
  final ValueChanged<int>? onTap;
  final bool secondary;

  @override
  Size get preferredSize =>
      Size.fromHeight(secondary ? 48 : 48 + AppSpace.xs * 2);

  @override
  Widget build(BuildContext context) {
    final bar = secondary
        ? TabBar.secondary(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorSize: TabBarIndicatorSize.tab,
            labelPadding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
            tabs: tabs,
            onTap: onTap,
          )
        : TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorSize: TabBarIndicatorSize.tab,
            labelPadding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
            dividerHeight: 0,
            tabs: tabs,
            onTap: onTap,
          );
    if (secondary) return bar;
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < AppBreakpoints.compact;
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? AppSpace.sm : AppSpace.lg,
            vertical: AppSpace.xs,
          ),
          child: Align(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppDimensions.standardContentWidth,
              ),
              child: SizedBox(width: double.infinity, child: bar),
            ),
          ),
        );
      }),
    );
  }
}

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
    return DefaultTabController(
      key: ValueKey(Object.hashAll(
          [secondary, index, ...segments.map((item) => item.value)])),
      length: segments.length,
      initialIndex: index < 0 ? 0 : index,
      child: AppSectionTabBar(
        secondary: secondary,
        tabs: [
          for (final item in segments)
            AppSectionTab(
              icon: item.icon,
              label: item.label ?? const SizedBox.shrink(),
            ),
        ],
        onTap: (index) => onSelectionChanged({segments[index].value}),
      ),
    );
  }
}

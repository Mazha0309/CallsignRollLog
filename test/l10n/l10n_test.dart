import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openlogtool/l10n/l10n.dart';

void main() {
  test('uses zh_CN by default and maps English variants to en_US', () {
    expect(
      resolveAppLocale(
        const Locale('ja', 'JP'),
        AppLocalizations.supportedLocales,
      ),
      const Locale('zh', 'CN'),
    );
    expect(
      resolveAppLocale(
        const Locale('en', 'GB'),
        AppLocalizations.supportedLocales,
      ),
      const Locale('en', 'US'),
    );
  });

  test('zh_CN and en_US include the four primary destinations', () async {
    final zh = await AppLocalizations.delegate.load(const Locale('zh', 'CN'));
    final en = await AppLocalizations.delegate.load(const Locale('en', 'US'));

    expect(
      [zh.navWorkbench, zh.navSessions, zh.navData, zh.navSettings],
      ['点名台', '会话', '数据', '设置'],
    );
    expect(
      [en.navWorkbench, en.navSessions, en.navData, en.navSettings],
      ['Net Desk', 'Sessions', 'Data', 'Settings'],
    );
    expect(collaborationStateLabel(zh, 'ready'), '已连接');
    expect(collaborationStateLabel(en, 'ready'), 'Connected');
    expect(zh.callsignHistoryFillSetting, '呼号历史一键复用');
    expect(en.callsignHistoryFillSetting, 'Reuse callsign history');
    expect(zh.limitWorkbenchWidthSetting, '限制点名台内容宽度');
    expect(en.limitWorkbenchWidthSetting, 'Limit Net Desk content width');
    expect(zh.historySessions, '历史会话');
    expect(zh.historySessionsHint, isNot(contains('历史记录')));
    expect(en.historySessionOpen, 'Open session');
    expect(zh.logTimeInvalid, '请输入有效时间（HH:mm）');
    expect(en.logTimeInvalid, 'Enter a valid time (HH:mm)');
    expect(zh.offlineReviewTitle, '离线记录待复核');
    expect(en.offlineReviewTitle, 'Offline records need review');
    expect(zh.collapseSidebar, '收起侧边栏');
    expect(zh.expandSidebar, '展开侧边栏');
    expect(en.collapseSidebar, 'Collapse sidebar');
    expect(en.expandSidebar, 'Expand sidebar');
    expect(zh.finishEditing, '结束编辑');
    expect(en.finishEditing, 'Finish editing');
    expect(zh.inputFieldHint(zh.fieldDevice), '输入设备');
    expect(en.inputFieldHint(en.fieldDevice), 'Enter Radio');
    expect(zh.optionalFieldHint(zh.fieldRemarks), '备注（可选）');
    expect(en.optionalFieldHint(en.fieldRemarks), 'Remarks (optional)');
    expect(zh.noSavedRecords, '暂无已保存记录');
    expect(en.noSavedRecords, 'No saved records');
    expect(zh.deleteRecordConfirmation, '确定要删除这条记录吗？');
    expect(en.deleteRecordConfirmation, 'Delete this record?');
    expect(zh.recordDeleted, '记录已删除');
    expect(en.recordDeleted, 'Record deleted');
    expect(zh.serverSettingsTitle, '服务器与账户');
    expect(en.serverSettingsTitle, 'Server and account');
    expect(zh.tokenStoragePrivateFileWarning, contains('Linux 用户'));
    expect(en.tokenStoragePrivateFileWarning, contains('private file'));
    expect(zh.tokenStorageMemoryOnlyWarning, contains('退出后需要重新登录'));
    expect(en.tokenStorageMemoryOnlyWarning, contains('after exiting'));
    expect(zh.collaborationConnectionSection, '连接与会话');
    expect(en.collaborationConnectionSection, 'Connection and session');
    expect(zh.logNotOwnedReadOnlyHint, '只能修改或删除自己创建的记录。');
    expect(
      en.logNotOwnedReadOnlyHint,
      'You can change or delete only records that you created.',
    );
    expect(zh.aboutAppTitle, '关于 OpenLogTool');
    expect(zh.aboutAppDescription, contains('点名现场工作流'));
    expect(en.aboutAppTitle, 'About OpenLogTool');
    expect(en.aboutAppDescription, contains('net-control workflows'));
    expect(zh.aboutCheckUpdates, '检查更新');
    expect(en.aboutCheckUpdates, 'Check for updates');
    expect(zh.aboutUpToDate('2.1.0-R'), contains('2.1.0-R'));
    expect(en.aboutUpToDate('2.1.0-R'), contains('up to date'));
    expect(
      zh.aboutUpdateAvailableMessage('2.1.0-R', '2.2.0-R'),
      contains('最新版本：2.2.0-R'),
    );
    expect(
      en.aboutUpdateAvailableMessage('2.1.0-R', '2.2.0-R'),
      contains('Latest version: 2.2.0-R'),
    );
    expect(zh.createEditableLocalCopy, '另存独立会话');
    expect(
      zh.createEditableLocalCopyConfirmation('周日晚间点名'),
      contains('原协作会话和你的成员身份不变'),
    );
    expect(
      en.createEditableLocalCopy,
      'Save independent copy',
    );
    expect(zh.historySessionCloseTitle, '结束记录');
    expect(zh.closeSharedSession, '结束共同记录');
    expect(zh.leaveSession, '离开协作');
    expect(en.historySessionCloseTitle, 'End recording');
    expect(en.closeSharedSession, 'End shared recording');
    expect(en.leaveSession, 'Leave collaboration');
    expect(
      zh.deleteLibraryItemConfirmation('FT-991A', '设备词库'),
      '确定从设备词库中删除“FT-991A”吗？',
    );
    expect(
      en.clearLibraryConfirmation('Radio library', 3),
      contains('all 3 entries'),
    );
    expect(zh.localDataOperationsTitle, '本机数据');
    expect(en.localDataOperationsTitle, 'On-device data');
    expect(zh.personalCloudTitle, '个人云同步');
    expect(zh.personalCloudUpToDate, '个人记录和词库改动均已同步');
    expect(zh.personalCloudHint, contains('自动双向同步'));
    expect(en.personalCloudTitle, 'Personal cloud sync');
    expect(en.personalCloudUpToDate, contains('up to date'));
    expect(en.personalCloudHint, contains('synchronize automatically'));
    expect(zh.settingsAppearanceTitle, '外观与语言');
    expect(en.settingsAppearanceTitle, 'Appearance & language');
    expect(zh.appLanguageSetting, '界面语言');
    expect(en.appLanguageSetting, 'Interface language');
    expect(zh.languageFollowSystem, '跟随系统');
    expect(en.languageFollowSystem, 'Follow system');
    expect(zh.databaseClearConfirmationPhrase, '清空全部数据');
    expect(en.databaseClearConfirmationPhrase, 'DELETE ALL DATA');
    expect(zh.databaseImportPreviewWarning, contains('登录凭据'));
    expect(en.databaseImportPreviewWarning, contains('Server sessions'));
    expect(zh.databaseStatusLocalContentSection, '本机内容');
    expect(en.databaseStatusLocalContentSection, 'On-device content');
    expect(zh.databaseStatusAdvancedTitle, contains('原始表计数'));
    expect(en.databaseStatusAdvancedTitle, contains('raw table counts'));
  });
}

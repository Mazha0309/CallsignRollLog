// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get detailsType => '记录方式';

  @override
  String get detailsLocal => '本地记录 · 无需服务器';

  @override
  String get detailsShared => '共同记录 · 保留本机副本';

  @override
  String get detailsStatus => '会话状态';

  @override
  String get detailsRecords => '本机已保存记录';

  @override
  String get detailsCreated => '创建时间';

  @override
  String get detailsUpdated => '更新时间';

  @override
  String get detailsEnded => '结束时间';

  @override
  String get detailsId => '会话 ID';

  @override
  String get sessionPeopleTitle => '参与者与邀请';

  @override
  String get sessionPeopleHint => '好友不等于会话成员。邀请被接受或申请获批后，对方才能查看此会话记录；公开页面单独管理。';

  @override
  String get sessionPendingRequests => '本会话的邀请与申请';

  @override
  String get legacyInviteCodes => '邀请码（兼容旧版）';

  @override
  String get collaborationTechnicalDetails => '连接与诊断详情';

  @override
  String get collaborationOverviewOnline => '已连接，正在与参与者同步记录。';

  @override
  String get collaborationOverviewOffline => '连接暂时不可用，已有记录仍保留在本机。';

  @override
  String get collaborationOverviewAttention => '有待处理的记录或同步问题，请打开“同步”查看。';

  @override
  String collaborationOverviewPending(int count) {
    return '已保存到本机，$count 项修改等待同步。';
  }

  @override
  String get historySessionCollaborationCloseRequired =>
      '这是共同记录，请在“协作与成员”中结束共同记录或离开协作；不能把它作为本地会话结束。';

  @override
  String get collaborationLifecycleHint =>
      '切换页面或暂时断网不会退出协作。发起人可以结束共同记录，参与者可以离开协作；已有记录会保留。';

  @override
  String get hubLocalStart => '新建会话即可开始记录，无需服务器或账号。记录保存在本机，可随时查看和导出。';

  @override
  String get hubLocalHint => '本地记录可独立使用；同步与多人协作按需启用。';

  @override
  String get hubOptionalOnline => '同步与协作（可选）';

  @override
  String get hubOptionalOnlineHint => '需要多设备同步或与搭档共同记录时，再连接服务器。';

  @override
  String get hubConfigureServer => '设置可选服务器';

  @override
  String get hubOnlineConnected => '好友与协作使用当前服务器，本地记录仍可独立使用。';

  @override
  String get hubEnableCollaboration => '邀请搭档一起记录';

  @override
  String get hubConfirmUpload => '上传此会话并开启协作';

  @override
  String get hubUploadExplanation =>
      '这会把当前会话及其中已有的记录上传到下面的服务器，并开始协作同步。此操作只上传当前会话，不改变其他会话的同步设置。会话仍为私有，之后再选择要邀请的好友；此操作不会发布公开页面。';

  @override
  String get hubContextChanged => '服务器、账号或当前会话已切换，请关闭后重新操作。';

  @override
  String get hubAlreadyMember => '对方已经加入这个会话，可在参与者管理中查看。';

  @override
  String get hubInvitationHint => '对方接受后才能查看此会话的记录，不会开放你的其他会话。';

  @override
  String get hubContinueRecording => '继续记录';

  @override
  String get hubViewRecords => '查看记录';

  @override
  String get hubSessionDetails => '会话详细信息';

  @override
  String get hubHistoryHint => '查看本机已有记录。“已结束”只按会话状态筛选，不代表公开归档。';

  @override
  String get hubAllRecords => '全部';

  @override
  String get hubMyRecords => '我的记录';

  @override
  String get hubTogetherRecords => '共同记录';

  @override
  String get hubEndedRecords => '已结束';

  @override
  String get socialTitle => '好友与邀请';

  @override
  String get socialAddFriend => '添加好友';

  @override
  String get socialFriends => '好友';

  @override
  String get socialMessages => '消息';

  @override
  String get socialSessions => '会话';

  @override
  String get socialIntro => '添加搭档为好友，再邀请他们一起点名。好友关系不会自动开放个人记录。';

  @override
  String get socialUsername => '对方的用户名（注册时使用的呼号）';

  @override
  String get socialSend => '发送申请';

  @override
  String get socialInvite => '邀请参与';

  @override
  String get socialApply => '申请加入';

  @override
  String get socialAccept => '接受';

  @override
  String get socialReject => '拒绝';

  @override
  String get socialPending => '等待对方处理';

  @override
  String get socialAccepted => '已接受';

  @override
  String get socialView => '只能查看';

  @override
  String get socialEdit => '共同记录';

  @override
  String get socialOpen => '打开会话';

  @override
  String get socialPrivate => '仅邀请可加入';

  @override
  String get socialDiscoverable => '好友可见，可申请加入';

  @override
  String get socialVisibilityHint => '好友只能看到会话标题，获准加入后才能查看记录。';

  @override
  String get socialNoFriends => '还没有好友，输入搭档的用户名发送申请。';

  @override
  String get socialNoMessages => '暂无邀请或申请';

  @override
  String get socialNoSessions => '暂无好友开放的会话。你也可以把当前会话用于协作。';

  @override
  String get socialPublish => '开启当前会话协作';

  @override
  String get socialRemove => '删除好友';

  @override
  String get socialRemoveHint => '会取消彼此待处理的邀请和申请。已加入的会话成员由会话负责人单独管理。';

  @override
  String get socialBlock => '屏蔽';

  @override
  String get socialUnblock => '取消屏蔽';

  @override
  String get socialBlocked => '已屏蔽';

  @override
  String get socialDone => '操作已完成';

  @override
  String get socialFriendRequest => '好友申请';

  @override
  String get socialInvitation => '会话邀请';

  @override
  String get socialApplication => '加入申请';

  @override
  String get socialSent => '我发出的';

  @override
  String get socialReceived => '收到的';

  @override
  String get socialManage => '管理参与者';

  @override
  String get socialConnect => '连接服务器并登录后，即可添加好友。';

  @override
  String get socialUpgrade => '此服务器尚不支持好友功能，请更新服务器。';

  @override
  String get socialLoadFailed => '暂时无法刷新，请重试。';

  @override
  String get socialChooseFriend => '选择好友';

  @override
  String get socialErrorUser => '没有找到这个用户名。请确认对方已在同一服务器注册。';

  @override
  String get socialErrorFriends => '请先添加对方为好友。';

  @override
  String get socialErrorClosed => '这条申请已处理或已过期，请刷新。';

  @override
  String get socialErrorSelf => '不能添加自己为好友。';

  @override
  String get socialErrorBlocked => '目前无法向这个用户发送请求。';

  @override
  String get socialServerLink => '复制服务器连接信息';

  @override
  String get socialServerLinkHint => '可粘贴服务器地址或服务器网页链接，连接后再登录。';

  @override
  String get socialLegacy => '旧版共享';

  @override
  String get navWorkbench => '点名台';

  @override
  String get navSessions => '会话';

  @override
  String get navData => '数据';

  @override
  String get navSettings => '设置';

  @override
  String get workbenchNoSession => '尚未开始点名';

  @override
  String get workbenchLocalRecording => '单机记录';

  @override
  String get collaborationLocalOnly => '仅本地';

  @override
  String get collaborationPublishing => '发布中';

  @override
  String get collaborationJoining => '加入中';

  @override
  String get collaborationSnapshotting => '下载快照';

  @override
  String get collaborationCatchingUp => '追赶更新';

  @override
  String get collaborationReady => '已连接';

  @override
  String get collaborationResyncing => '重新同步';

  @override
  String get collaborationRevoked => '权限已撤销';

  @override
  String get collaborationFailed => '同步失败';

  @override
  String collaborationState(String state) {
    return '协作 $state';
  }

  @override
  String pendingSyncCount(int count) {
    return '待同步 $count';
  }

  @override
  String conflictCount(int count) {
    return '冲突 $count';
  }

  @override
  String get localSessionTooltip => '当前为本地会话';

  @override
  String collaborationStatusTooltip(String state, int count) {
    return '协作状态 $state，待同步 $count';
  }

  @override
  String get currentRecord => '当前记录';

  @override
  String get startNewRecord => '开始新记录';

  @override
  String get newRecordName => '新记录名称';

  @override
  String get newRecordNameHint => '输入本次记录名称（可留空）';

  @override
  String get automaticName => '自动命名';

  @override
  String newRecordStarted(String name) {
    return '已开始新记录：$name';
  }

  @override
  String createNewRecordFailed(String error) {
    return '创建新记录失败：$error';
  }

  @override
  String currentOrdinal(int ordinal) {
    return '当前第 $ordinal 位';
  }

  @override
  String get sessionsTitle => '会话';

  @override
  String get sessionsSubtitle => '管理本次点名、协作书记员和主控显示设备。';

  @override
  String get noCurrentSession => '当前没有点名会话';

  @override
  String get noCurrentSessionHint => '创建一个点名会话，或加入协作后即可开始记录。';

  @override
  String get workbenchNoSessionHint => '请先到会话页新建会话，或加入协作后再开始记录。';

  @override
  String get createOrJoinSessionFirst => '请先新建会话或加入协作';

  @override
  String get goCreateSession => '去新建会话';

  @override
  String get sessionActive => '进行中';

  @override
  String get sessionClosed => '已结束';

  @override
  String savedPositions(int count) {
    return '$count 位已保存';
  }

  @override
  String get localSession => '本地会话';

  @override
  String get manageCollaboration => '协作与成员';

  @override
  String get openLiveShare => 'Live Share 公开页面';

  @override
  String get enterControllerScreen => '进入主控屏';

  @override
  String get localControllerDisplay => '本机主控显示';

  @override
  String get localControllerDisplayHint => '书记员继续使用主窗口，主控内容在独立只读窗口显示。';

  @override
  String get openFloatingWindow => '打开悬浮窗';

  @override
  String get openControllerTab => '打开主控屏标签页';

  @override
  String get openControllerInApp => '当前标签页打开主控屏';

  @override
  String get openSecondDisplayWindow => '打开第二屏窗口';

  @override
  String get historySessions => '历史会话';

  @override
  String get historySessionsHint => '查看和切换过去的点名会话；已关闭会话将以只读方式打开。';

  @override
  String get historySessionsEmpty => '暂无历史会话';

  @override
  String historySessionsLoadFailed(String error) {
    return '加载历史会话失败：$error';
  }

  @override
  String get historySessionOpen => '打开会话';

  @override
  String get historySessionCurrent => '当前会话';

  @override
  String historySessionSwitched(String title) {
    return '已打开会话：$title';
  }

  @override
  String historySessionOpenFailed(String error) {
    return '打开会话失败：$error';
  }

  @override
  String get historySessionCloseTitle => '结束记录';

  @override
  String historySessionCloseConfirmation(String title) {
    return '结束“$title”的记录吗？已有记录会保留，可随时查看或恢复记录。此操作不会删除数据。';
  }

  @override
  String get historySessionClosed => '记录已结束，已有记录已保留';

  @override
  String historySessionCloseFailed(String error) {
    return '结束记录失败：$error';
  }

  @override
  String get historySessionCollaborationCloseRequiresOpen =>
      '这是协作会话。请先打开该会话，再进入“协作与成员”关闭它。';

  @override
  String get historySessionCollaborationCloseOwnerRequired =>
      '只有已完成同步的会话所有者才能关闭协作会话。请进入“协作与成员”刷新权限后重试。';

  @override
  String get historySessionReopenAction => '重新激活';

  @override
  String get historySessionReopenTitle => '重新激活本地会话';

  @override
  String historySessionReopenConfirmation(String title) {
    return '恢复“$title”并切换过去继续记录吗？其他会话不受影响。协作会话请由发起人在“协作与成员”中恢复。';
  }

  @override
  String historySessionReopened(String title) {
    return '已重新激活并切换到会话：$title';
  }

  @override
  String historySessionReopenFailed(String error) {
    return '重新激活本地会话失败：$error';
  }

  @override
  String historySessionReopenedLogsUnavailable(String title) {
    return '会话“$title”已重新激活，但日志暂时加载失败。为安全起见当前保持只读，请重试加载。';
  }

  @override
  String get historySessionCollaborationReopenRequired =>
      '这是协作会话。请先打开该会话，再到“协作与成员”中重新打开。';

  @override
  String get historySessionDeleteTitle => '永久删除本机会话';

  @override
  String historySessionDeleteWarning(String title) {
    return '将永久删除本机“$title”的所有日志及本地协作副本。此操作不可撤销，但不会删除或关闭服务器上的共享会话。请输入完整会话名以确认：';
  }

  @override
  String get historySessionDeleteNameLabel => '完整会话名';

  @override
  String historySessionDeleteExpectedName(String title) {
    return '期望输入：$title';
  }

  @override
  String get historySessionDeleteNameMismatch => '输入的会话名不匹配，请逐字核对。';

  @override
  String get historySessionDeleteAction => '永久删除本机数据';

  @override
  String get historySessionDeleted => '已永久删除本机会话';

  @override
  String historySessionDeleteFailed(String error) {
    return '永久删除本机会话失败：$error';
  }

  @override
  String get historySessionReadOnly => '当前为已关闭的历史会话，只能查看已有记录。';

  @override
  String controllerWindowOpenFailed(String error) {
    return '无法打开主控窗口：$error';
  }

  @override
  String get controllerDisplaySettingsTitle => '主控显示';

  @override
  String get enableControllerDeviceEntry => '启用主控设备入口';

  @override
  String get enableControllerDeviceEntryHint =>
      '开启后可从“会话”进入全屏只读主控屏，适用于安卓平板、手机或独立电脑。';

  @override
  String get defaultInformationDetail => '默认信息详细程度';

  @override
  String get desktopControllerDisplayHint => '本机桌面还可从会话页打开置顶悬浮窗或第二显示器窗口。';

  @override
  String get inAppControllerDisplayHint => '当前设备使用应用内全屏主控模式。';

  @override
  String get controllerScreenTitle => 'OpenLogTool 主控屏';

  @override
  String get controllerFloatingWindowTitle => 'OpenLogTool 主控悬浮窗';

  @override
  String get controllerScreenFallbackTitle => '点名主控屏';

  @override
  String savedPositionCount(int count) {
    return '已保存 $count 位';
  }

  @override
  String get notReceivedDraftUpdate => '尚未收到草稿更新';

  @override
  String updatedAt(String time) {
    return '更新 $time';
  }

  @override
  String editorEditing(String name) {
    return '$name 编辑';
  }

  @override
  String get connectionConnected => '实时连接';

  @override
  String get connectionReconnecting => '正在重连';

  @override
  String get connectionOffline => '连接中断';

  @override
  String get staleControllerDataWarning => '连接已中断，正在显示最后一次收到的内容，数据可能已过期。';

  @override
  String get previousSavedRecord => '上一位已保存记录';

  @override
  String recordOrdinal(int ordinal) {
    return '第 $ordinal 位';
  }

  @override
  String get noPreviousRecord => '暂无上一位记录';

  @override
  String get waitingForCallsign => '等待来台呼号…';

  @override
  String get beingEdited => '正在编辑';

  @override
  String configureControllerDisplay(String detail) {
    return '显示内容（$detail）';
  }

  @override
  String get exitControllerScreen => '退出主控屏';

  @override
  String get controllerDisplayConfiguration => '主控屏显示内容';

  @override
  String get informationDetail => '信息详细程度';

  @override
  String get controllerDisplayScale => '主控屏缩放';

  @override
  String get controllerDisplayScaleHint => '仅调整主控屏的显示比例，不影响主应用界面。';

  @override
  String get currentFields => '当前项字段';

  @override
  String get previousFields => '上一位字段';

  @override
  String get cancel => '取消';

  @override
  String get apply => '应用';

  @override
  String get detailMinimal => '极简';

  @override
  String get detailStandard => '标准';

  @override
  String get detailFull => '完整';

  @override
  String get detailCustom => '自定义';

  @override
  String get fieldController => '主控';

  @override
  String get fieldControllerCallsign => '主控呼号';

  @override
  String get fieldCallsign => '来台呼号';

  @override
  String get fieldTime => '时间';

  @override
  String get logTimeInvalid => '请输入有效时间（HH:mm）';

  @override
  String get fieldRstSent => 'RST 发';

  @override
  String get fieldRstRcvd => 'RST 收';

  @override
  String get fieldQth => 'QTH';

  @override
  String get fieldDevice => '设备';

  @override
  String get fieldPower => '功率';

  @override
  String get fieldAntenna => '天线';

  @override
  String get fieldHeight => '高度';

  @override
  String get fieldRemarks => '备注';

  @override
  String get fieldActions => '操作';

  @override
  String inputFieldHint(String field) {
    return '输入$field';
  }

  @override
  String optionalFieldHint(String field) {
    return '$field（可选）';
  }

  @override
  String get noSavedRecords => '暂无已保存记录';

  @override
  String get logTableSearchHint => '搜索呼号 / QTH / 备注…';

  @override
  String get logTableSearchClear => '清除搜索';

  @override
  String get logTableSearchNoMatches => '没有匹配的记录';

  @override
  String get addFirstRecordHint => '在上方表单中添加第一条记录。';

  @override
  String get editRecord => '编辑记录';

  @override
  String get deleteRecord => '删除记录';

  @override
  String get deleteRecordConfirmation => '确定要删除这条记录吗？';

  @override
  String get delete => '删除';

  @override
  String get recordDeleted => '记录已删除';

  @override
  String get savedRecords => '已保存记录';

  @override
  String recordCount(int count) {
    return '$count 条';
  }

  @override
  String get restoreLastDeletedRecord => '恢复最近删除';

  @override
  String get restoreLastDeletedRecordTitle => '恢复最近删除的记录？';

  @override
  String get restoreLastDeletedRecordConfirmation => '将恢复最近一次删除的点名记录，不会影响其他记录。';

  @override
  String get recordRestored => '记录已恢复';

  @override
  String get saveRecord => '保存记录';

  @override
  String get savingRecord => '正在保存';

  @override
  String get clearEnteredFields => '清空已填内容';

  @override
  String get enteredFieldsCleared => '已清空，主控呼号已保留';

  @override
  String get recordAdded => '记录已添加';

  @override
  String get recordQueuedOffline => '网络不可用，记录已保存到本机待复核';

  @override
  String get sharedDraftReadOnly => '当前协作草稿只读';

  @override
  String fieldLockedBy(String name) {
    return '$name 正在编辑';
  }

  @override
  String get finishEditing => '结束编辑';

  @override
  String get offlineReviewTitle => '离线记录待复核';

  @override
  String get resolutionDiscard => '丢弃';

  @override
  String get resolutionSubmitDuplicate => '作为重复记录提交';

  @override
  String get resolutionCopyCurrent => '带入当前草稿';

  @override
  String get callsignRequired => '请输入点名呼号';

  @override
  String get leaveSession => '离开协作';

  @override
  String get leaveSessionConfirmation =>
      '离开后你将不再收到此会话的更新，本机已有记录保留为只读，其他成员可继续记录。以后需要重新邀请或申请加入。此操作需要连接服务器；只是暂时离开页面，无需退出协作。';

  @override
  String get moreLocalCollaborationActions => '更多操作';

  @override
  String get createEditableLocalCopy => '另存独立会话';

  @override
  String get createEditableLocalCopyTitle => '另存独立会话？';

  @override
  String createEditableLocalCopyConfirmation(String title) {
    return '将“$title”当前表格中已保存的记录复制到一个新会话，并切换过去独立记录，无需服务器。原协作会话和你的成员身份不变，稍后仍可切回。未同步队列、冲突、离线待复核记录及未提交草稿保留在原会话，不会复制到新会话，也不会删除。';
  }

  @override
  String editableLocalCopySessionTitle(String title) {
    return '$title（本地副本）';
  }

  @override
  String get editableLocalCopySucceeded => '已另存并切换到独立会话，原协作会话已保留';

  @override
  String get collaborationScreenTitle => '协作与成员';

  @override
  String get collaborationConnectionSection => '连接与会话';

  @override
  String get collaborationConnectionSectionHint => '查看服务器账号、当前会话和同步入口。';

  @override
  String get collaborationSyncSection => '待处理同步';

  @override
  String get collaborationSyncSectionHint => '复核离线记录，并解决需要人工选择的冲突。';

  @override
  String get collaborationAccessSection => '成员与共享';

  @override
  String get collaborationAccessSectionHint => '管理书记员权限、邀请码和只读公开页面。';

  @override
  String get serverLoggedIn => '已登录';

  @override
  String get serverNotLoggedIn => '尚未登录服务器';

  @override
  String collaborationServerAccount(String url, String id) {
    return '$url\n账号 $id';
  }

  @override
  String get collaborationServerLoginHint => '请先在“设置 → 服务器与账户”中检测服务器并登录。';

  @override
  String get remoteCommitPendingLocalApplyHint =>
      '远端已经提交；客户端只会恢复本地确认，不会重复创建新修改。';

  @override
  String get accountSharing => '跨账号共享';

  @override
  String get accountSharingHint => '先申请再接受。共享会话只读，加入协作仍需口令。';

  @override
  String get sharedSessionBadge => '共享';

  @override
  String sharedSessionFrom(String username) {
    return '来自 $username 的共享';
  }

  @override
  String get acceptShare => '接受';

  @override
  String get pendingInboundShares => '待处理申请';

  @override
  String get browseSharedSession => '浏览共享会话';

  @override
  String get joinSharedSession => '口令加入';

  @override
  String get joinCollaborationTitle => '加入协作';

  @override
  String get joinCollaborationHint => '输入成员邀请码。成功后会以远端相同的 Session ID 安装完整本地副本。';

  @override
  String get inviteCodeLabel => '邀请码';

  @override
  String get join => '加入';

  @override
  String get joinCollaborationSucceeded => '已加入协作会话';

  @override
  String get localCollaborationSessionHint => '本地会话尚未发布。发布时会锁定一致快照并分批上传全部记录。';

  @override
  String collaborationSessionSummary(String state, String role) {
    return '状态 $state · 角色 $role';
  }

  @override
  String collaborationSyncSummary(String transport, int applied, int head) {
    return '同步 $transport · 游标 $applied/$head';
  }

  @override
  String collaborationQueueSummary(int pending, int conflicts, int rejected) {
    return '待同步 $pending · 冲突 $conflicts · 拒绝 $rejected';
  }

  @override
  String get collaborationReliableQueueHint => '本地保存后会进入可靠队列，并由规范事件确认同步。';

  @override
  String collaborationLastSync(String time) {
    return '最近同步 $time';
  }

  @override
  String get collaborationSessionConflictHint =>
      '会话存在未解决冲突。请先在冲突中心处理；重命名、关闭和重新打开暂时不可用。';

  @override
  String get publishSessionSucceeded => '协作会话发布完成';

  @override
  String get publishCollaborationSession => '发布为协作会话';

  @override
  String get retryPublishSession => '重试发布';

  @override
  String get syncNowAndRefreshAccess => '立即同步并刷新权限';

  @override
  String get closeSession => '关闭会话';

  @override
  String get reopenSession => '重新打开';

  @override
  String get transportStopped => '已停止';

  @override
  String get transportConnecting => '连接中';

  @override
  String get transportOnline => '在线';

  @override
  String get transportBackingOff => '等待重连';

  @override
  String get transportAuthRequired => '需要登录';

  @override
  String get transportIncompatible => '协议异常';

  @override
  String get readOnlyRevoked => '成员权限已撤销，本地缓存保持只读。';

  @override
  String get readOnlyClosePending => '结束请求已保存，等待同步确认；确认前暂时只读。';

  @override
  String get readOnlyReopenPending => '重新打开请求已保存到本地，服务器确认前保持只读。';

  @override
  String get readOnlySessionClosed => '共同记录已结束，已有记录可继续查看。';

  @override
  String get readOnlyViewer => '当前账号是只读成员。';

  @override
  String get readOnlyResyncing => '正在恢复同步，已保存的修改会保留。';

  @override
  String get readOnlyCheckingAccess => '正在确认你的参与权限，暂时只能查看。';

  @override
  String get logNotOwnedReadOnlyHint => '只能修改或删除自己创建的记录。';

  @override
  String get logAuthorUnknownReadOnlyHint => '这条历史记录没有作者信息，普通成员只能查看。';

  @override
  String get logSessionReadOnlyHint => '当前成员角色、会话状态或同步状态不允许修改记录。';

  @override
  String get logConflictReadOnlyHint => '请先在冲突中心解决这条记录。';

  @override
  String get renameCollaborationSession => '重命名协作会话';

  @override
  String get saveLocally => '保存到本地';

  @override
  String get sessionTitleQueued => '标题已保存到本地，等待同步确认';

  @override
  String get closeCollaborationSessionTitle => '结束共同记录';

  @override
  String get closeCollaborationSessionMessage =>
      '结束后，所有成员都不能继续添加或修改记录，已有记录和成员关系会保留。你可以稍后恢复记录。此操作需要同步到服务器；只是暂时离开，无需结束。';

  @override
  String get closeSharedSession => '结束共同记录';

  @override
  String get closeCollaborationDraftNotEmpty =>
      '当前点名草稿还有内容。请先提交这条完整记录，或明确丢弃草稿后再结束。';

  @override
  String get closeCollaborationDraftIncomplete =>
      '当前草稿缺少时间、主控呼号或点名呼号，不能提交；仍可明确丢弃后结束。';

  @override
  String closeCollaborationDraftLocked(int count) {
    return '其他成员或设备仍在编辑 $count 个草稿字段。请等待对方完成编辑并刷新后再结束。';
  }

  @override
  String get closeCollaborationDiscardAndClose => '丢弃草稿并结束';

  @override
  String get closeCollaborationSubmitAndClose => '提交并结束';

  @override
  String get closeCollaborationQueuedOffline =>
      '记录仅保存到离线队列，尚未提交到服务器；共同记录尚未结束。请恢复网络并处理该记录后重试。';

  @override
  String get closeSessionQueued => '结束共同记录的请求已保存，等待同步确认';

  @override
  String get reopenCollaborationSessionTitle => '重新打开协作会话';

  @override
  String get reopenCollaborationSessionMessage =>
      '重新打开会作为一项同步修改提交；服务器确认前仍保持只读。';

  @override
  String get reopenSessionQueued => '重新打开请求已保存到本地，等待同步确认';

  @override
  String get conflictUseRemoteTitle => '采用远端版本';

  @override
  String get conflictKeepLocalTitle => '保留本地版本';

  @override
  String get conflictCopyLocalTitle => '复制为新日志';

  @override
  String get conflictUseRemoteMessage => '本地未同步修改会被远端规范版本替换，此操作不会再次提交修改。';

  @override
  String get conflictKeepLocalMessage => '将基于最新远端版本创建一项新修改。若远端再次变化，仍可能产生新冲突。';

  @override
  String get conflictCopyLocalMessage => '远端原日志会保留，本地内容将使用新的日志 ID 创建副本并重新同步。';

  @override
  String get conflictUseRemoteSucceeded => '已采用远端版本';

  @override
  String get conflictKeepLocalSucceeded => '已保留本地版本并进入重试队列';

  @override
  String get conflictCopyLocalSucceeded => '已复制为新日志并进入同步队列';

  @override
  String get conflictCenterTitle => '冲突中心';

  @override
  String get refreshConflicts => '刷新冲突';

  @override
  String get conflictCenterHint => '可用操作由本地副本按最新权限和实体状态给出；保留或复制会生成新的同步修改。';

  @override
  String get noConflicts => '没有待处理冲突。';

  @override
  String get conflictSession => '会话';

  @override
  String get conflictLog => '日志';

  @override
  String get conflictNoOverlappingFields => '无重叠字段（版本已变化）';

  @override
  String conflictVersionSummary(String fields, int base, int remote) {
    return '字段 $fields · 基线 v$base → 远端 v$remote';
  }

  @override
  String get conflictBase => '基线';

  @override
  String get conflictLocal => '本地';

  @override
  String get conflictRemote => '远端';

  @override
  String get conflictUseRemoteAction => '采用远端';

  @override
  String get conflictKeepLocalAction => '保留本地重试';

  @override
  String get conflictCopyLocalAction => '复制为新日志';

  @override
  String get memberInvitesTitle => '成员邀请';

  @override
  String get roleOwner => '所有者';

  @override
  String get roleEditor => '编辑者';

  @override
  String get roleViewer => '只读成员';

  @override
  String get inviteCreated => '邀请码已生成';

  @override
  String get generate => '生成';

  @override
  String get inviteCodeOneTimeHint => '邀请码只在本次创建响应中显示：';

  @override
  String get noInvites => '暂无邀请';

  @override
  String inviteSummary(int used, int max, String status) {
    return '$used/$max 次 · $status';
  }

  @override
  String inviteExpiresAt(String time) {
    return '有效至 $time';
  }

  @override
  String get inviteRevoked => '已撤销';

  @override
  String get membersTitle => '成员';

  @override
  String get currentAccount => '当前账号';

  @override
  String get memberSetEditor => '成员已设为编辑者';

  @override
  String get memberSetViewer => '成员已设为只读';

  @override
  String get setAsEditor => '设为编辑者';

  @override
  String get setAsViewer => '设为只读成员';

  @override
  String get transferOwnership => '转移所有权';

  @override
  String get removeMember => '移除成员';

  @override
  String transferOwnershipConfirmation(String name) {
    return '转移给 $name 后，你将变为编辑者。';
  }

  @override
  String get ownershipTransferred => '所有权已转移';

  @override
  String removeMemberConfirmation(String name) {
    return '确定移除 $name？权限会立即失效。';
  }

  @override
  String get memberRemoved => '成员已移除';

  @override
  String operationFailed(String error) {
    return '操作失败：$error';
  }

  @override
  String get unknown => '未知';

  @override
  String get confirm => '确认';

  @override
  String get duplicateCallsignWarningSetting => '重复呼号提醒';

  @override
  String get duplicateCallsignWarningHint =>
      '输入完呼号后立即检查同一场点名中的既有记录，弹窗询问是更新旧记录还是新增记录。';

  @override
  String get autoAppendPowerWSetting => '功率自动加 W';

  @override
  String get autoAppendPowerWHint => '保存时若功率为纯数字（如 50、50.5）自动补上 W；已带单位或含中文的不动。';

  @override
  String get duplicateCallsignTitle => '呼号已经记录过';

  @override
  String duplicateCallsignMessage(String callsign) {
    return '$callsign 已在本次点名中记录过，仍要保存吗？';
  }

  @override
  String get saveAnyway => '仍然保存';

  @override
  String get duplicateUpdateOldRecord => '更新旧记录';

  @override
  String get duplicateAddNewRecord => '添加新记录';

  @override
  String get duplicateContinueDialogTitle => '呼号已记录过';

  @override
  String duplicateContinueDialogMessage(String callsign, int ordinal) {
    return '$callsign 已在第 $ordinal 位记录过，继续添加吗？';
  }

  @override
  String get duplicateContinueAdd => '继续添加';

  @override
  String get duplicateUpdateDialogTitle => '呼号已记录过';

  @override
  String duplicateUpdateDialogMessage(String callsign) {
    return '$callsign 在本次点名中已有记录，选择处理方式：';
  }

  @override
  String duplicateOldRecordSummary(int ordinal, String time, String callsign,
      String rstSent, String rstRcvd, String qth) {
    return '原记录（第 $ordinal 位）：$time $callsign $rstSent/$rstRcvd $qth';
  }

  @override
  String get recordUpdated => '记录已更新';

  @override
  String get callsignHistoryFillSetting => '呼号历史一键复用';

  @override
  String get callsignHistoryFillHint => '匹配数据库中的既有呼号记录，并可一键带入设备、天线、QTH 等字段。';

  @override
  String get publicShareManagement => 'Live Share · 公开只读页面';

  @override
  String get publicShareManagementHint =>
      '为主控、远程书记员或观众生成只读网页；无需登录即可查看当前点名进度。链接密钥仅在创建时显示。';

  @override
  String get publicShareAccessRequired =>
      'Live Share 由当前协作会话的 Owner 管理。请先登录并发布此会话；如果你是协作成员，请联系 Owner 创建公开链接。';

  @override
  String get publicShareUnsupported =>
      '当前服务器未提供安全的 Live Share 公开页面。升级或启用服务端公开分享功能后即可创建。';

  @override
  String get publicShareCreatedTitle => '公开只读页面已创建';

  @override
  String get publicShareCreatedHint => '请立即保存此链接；出于安全考虑，刷新或重新登录后无法再次取回链接密钥。';

  @override
  String get createPublicShare => '创建公开链接';

  @override
  String get publicShareExpiryDialogTitle => '设置 Live Share 有效期';

  @override
  String get publicShareExpiryDialogHint => '公开链接将在所选时长后自动失效。';

  @override
  String get publicShareExpiryPresets => '快捷选择';

  @override
  String get publicShareExpiryOneHour => '1小时';

  @override
  String get publicShareExpirySixHours => '6小时';

  @override
  String get publicShareExpiryTwelveHours => '12小时';

  @override
  String get publicShareExpiryOneDay => '1天';

  @override
  String get publicShareExpiryThreeDays => '3天';

  @override
  String get publicShareExpirySevenDays => '7天';

  @override
  String get publicShareExpiryThirtyDays => '30天';

  @override
  String get publicShareExpiryCustom => '自定义';

  @override
  String get publicShareExpiryCustomHours => '有效期（小时）';

  @override
  String get publicShareExpiryRangeError => '请输入 1–720 之间的整数小时';

  @override
  String publicShareEstimatedExpiry(String time) {
    return '预计失效：$time（本地时间）';
  }

  @override
  String get copyPublicShareLink => '复制链接';

  @override
  String get openPublicShare => '在浏览器打开';

  @override
  String get revokePublicShare => '撤销';

  @override
  String get publicShareLinkCopied => '公开链接已复制';

  @override
  String get publicShareNoActiveLinks => '当前没有有效的公开链接。创建后可将只读页面交给主控或远程查看者。';

  @override
  String get publicShareSecretUnavailable =>
      '已有有效公开链接，但其密钥只在创建时返回。若链接没有保存，请撤销旧链接并创建新链接。';

  @override
  String get publicShareLinksTitle => '公开链接记录';

  @override
  String get publicShareUnavailable => '已撤销或已过期';

  @override
  String get publicShareOpenFailed => '无法打开浏览器；你仍可复制链接后手动打开。';

  @override
  String publicShareExpiresAt(String time) {
    return '有效期至 $time';
  }

  @override
  String get refresh => '刷新';

  @override
  String get reuseDatabaseInformation => '一键复用数据库信息';

  @override
  String get collapseSidebar => '收起侧边栏';

  @override
  String get expandSidebar => '展开侧边栏';

  @override
  String get limitWorkbenchWidthSetting => '限制点名台内容宽度';

  @override
  String get limitWorkbenchWidthHint => '宽屏时将点名台内容居中并限制在 1520 像素内，避免字段过度拉伸。';

  @override
  String serverConnectionFailed(String detail) {
    return '连接失败：$detail';
  }

  @override
  String serverNetworkError(String url) {
    return '服务器 $url 没有响应。请检查地址和端口，并确认服务端或反向代理正在运行。';
  }

  @override
  String serverWebMixedContentError(String url) {
    return '当前 WebClient 使用 HTTPS，浏览器不允许连接 HTTP 服务器 $url。请为服务器启用 HTTPS。';
  }

  @override
  String serverWebCrossOriginError(String url, String origin) {
    return '浏览器无法访问服务器 $url。请确认服务器在线；若原生客户端能连接，请在服务端 CORS_ORIGINS 中加入 $origin，或使用同源反向代理。';
  }

  @override
  String serverNetworkTimeout(String url) {
    return '连接 $url 超时。请检查网络、防火墙和服务端状态。';
  }

  @override
  String serverInvalidResponse(String url) {
    return '已连接 $url，但它没有返回兼容的 OpenLogTool Server 响应。';
  }

  @override
  String get serverAddressRequired => '请先填写服务器地址。';

  @override
  String get serverAddressInvalid => '服务器地址必须是完整的 http(s) URL。';

  @override
  String get serverSettingsTitle => '服务器与账户';

  @override
  String get serverAddressLabel => '服务器地址';

  @override
  String get serverAddressHint => 'http://your-server:3000';

  @override
  String get serverSaveAndCheck => '保存并检测服务器';

  @override
  String serverCheckSucceeded(int min, int max) {
    return '连接成功 · 协议 v$min-$max';
  }

  @override
  String serverInstanceDetails(String instance, String features) {
    return '实例 $instance\n能力 $features';
  }

  @override
  String get serverConnected => '已连接';

  @override
  String get serverNotConnected => '未检测';

  @override
  String get serverSignedOutHint => '登录后可以参与协作，并管理当前账号自己的资料和登录设备。';

  @override
  String get tokenStoragePrivateFileWarning =>
      '系统钥匙环不可用；登录凭据已保存到仅当前 Linux 用户可读的私有文件。钥匙环恢复可用后会自动迁回安全存储。';

  @override
  String get tokenStorageMemoryOnlyWarning =>
      '安全凭据存储不可用；本次登录仅在应用运行期间有效，退出后需要重新登录。';

  @override
  String get serverLogin => '登录';

  @override
  String get serverRegister => '注册';

  @override
  String get serverLogout => '退出';

  @override
  String serverAccountId(String id) {
    return '账号 ID：$id';
  }

  @override
  String get serverLoginSucceeded => '已登录服务器';

  @override
  String get serverRegistrationSucceeded => '注册并登录成功';

  @override
  String serverLoginFailed(String error) {
    return '登录失败：$error';
  }

  @override
  String serverRegistrationFailed(String error) {
    return '注册失败：$error';
  }

  @override
  String serverLogoutFailed(String error) {
    return '退出失败：$error';
  }

  @override
  String get accountChangeUsername => '修改用户名';

  @override
  String get accountChangePassword => '修改密码';

  @override
  String get accountDeviceSessions => '登录设备';

  @override
  String get accountUsernameUpdated => '用户名已更新';

  @override
  String accountPasswordUpdated(int count) {
    return '密码已更新，已撤销 $count 个登录会话，请重新登录。';
  }

  @override
  String accountUpdateFailed(String error) {
    return '账户操作失败：$error';
  }

  @override
  String get usernameLabel => '用户名';

  @override
  String get usernameLengthHint => '用户名应为 3–64 个字符';

  @override
  String get passwordLabel => '密码';

  @override
  String get fieldRequired => '此项不能为空';

  @override
  String get currentPasswordLabel => '当前密码';

  @override
  String get newPasswordLabel => '新密码';

  @override
  String get confirmNewPasswordLabel => '确认新密码';

  @override
  String get passwordLengthHint => '密码至少需要 10 个字符';

  @override
  String get passwordMismatch => '两次输入的新密码不一致';

  @override
  String get passwordChangeRequiredTitle => '必须修改临时密码';

  @override
  String passwordChangeRequiredHint(String username) {
    return '账号 $username 使用了临时密码。设置新密码后才能继续。';
  }

  @override
  String passwordChangeCredentialExpires(int seconds) {
    return '本次改密凭据将在 $seconds 秒内过期。';
  }

  @override
  String get completePasswordChange => '设置新密码并登录';

  @override
  String get cancelLogin => '取消登录';

  @override
  String get passwordChangeCompleted => '密码已更新并完成登录';

  @override
  String get deviceSessionsTitle => '登录设备';

  @override
  String get deviceSessionsEmpty => '当前没有有效的登录设备';

  @override
  String get deviceUnknown => '未命名设备';

  @override
  String get deviceCurrent => '当前设备';

  @override
  String deviceIp(String ip) {
    return 'IP：$ip';
  }

  @override
  String deviceLastUsed(String time) {
    return '最近使用：$time';
  }

  @override
  String deviceExpires(String time) {
    return '到期：$time';
  }

  @override
  String get revokeDevice => '撤销设备';

  @override
  String get revokeCurrentDevice => '退出当前设备';

  @override
  String get revokeDeviceConfirmation => '撤销后，该设备将不能继续刷新登录状态。';

  @override
  String get revokeCurrentDeviceConfirmation => '退出当前设备后，需要重新输入用户名和密码才能连接服务器。';

  @override
  String get deviceRevoked => '登录设备已撤销';

  @override
  String get close => '关闭';

  @override
  String get retry => '重试';

  @override
  String get excelUseSessionTitleAsHeader => '抬头使用当前会话名';

  @override
  String get excelUseSessionTitleAsHeaderHint =>
      '开启后，Excel 抬头将直接使用当前会话名；会话名为空时继续使用抬头模板。';

  @override
  String get fileNameUseSessionTitle => '文件名使用当前会话名';

  @override
  String get fileNameUseSessionTitleHint =>
      '开启后，导出文件名将直接使用当前会话名；会话名为空时继续使用文件名模板。';

  @override
  String get themeColorPickerTitle => '选择主题颜色';

  @override
  String get themeColorPresets => '预设颜色';

  @override
  String get themeColorCustom => '自定义颜色';

  @override
  String get themeColorHex => 'HEX 颜色';

  @override
  String get themeColorHue => '色相';

  @override
  String get themeColorBlue => '蓝色';

  @override
  String get themeColorGreen => '绿色';

  @override
  String get themeColorRed => '红色';

  @override
  String get themeColorOrange => '橙色';

  @override
  String get themeColorPurple => '紫色';

  @override
  String get themeColorPink => '粉色';

  @override
  String get save => '保存';

  @override
  String get add => '添加';

  @override
  String get renameSession => '修改会话名';

  @override
  String get renameSessionTitle => '修改会话名';

  @override
  String get sessionTitleLabel => '会话名';

  @override
  String get renameCollaborationSessionHint => '只有会话所有者可以修改；保存后将同步给其他书记员和主控显示。';

  @override
  String get renameSessionSaved => '会话名已更新';

  @override
  String get renameCollaborationSessionSaved => '会话名已保存，正在同步给其他成员';

  @override
  String renameSessionFailed(String error) {
    return '修改会话名失败：$error';
  }

  @override
  String get renameSessionBlockedClosed => '已关闭的会话不能修改名称';

  @override
  String get renameSessionBlockedBusy => '协作操作进行中，暂时不能修改名称';

  @override
  String get renameSessionBlockedConflict => '请先解决会话冲突，再修改名称';

  @override
  String get renameSessionBlockedNotReady => '协作会话尚未就绪，暂时不能修改名称';

  @override
  String get renameSessionBlockedOwner => '只有会话所有者可以修改名称';

  @override
  String get dictionaryManagementTitle => '词库管理';

  @override
  String get dictionaryManagementHint => '管理点名时可搜索和一键复用的设备、天线、呼号与 QTH 内容。';

  @override
  String get deviceLibrary => '设备词库';

  @override
  String get antennaLibrary => '天线词库';

  @override
  String get callsignLibrary => '呼号词库';

  @override
  String get qthLibrary => 'QTH 词库';

  @override
  String libraryItemCount(int count) {
    return '共 $count 条';
  }

  @override
  String get importLibraryJson => '导入 JSON';

  @override
  String get expandAll => '展开全部';

  @override
  String get collapseAll => '折叠全部';

  @override
  String addLibraryItem(String name) {
    return '添加$name';
  }

  @override
  String searchLibrary(String name) {
    return '搜索$name';
  }

  @override
  String get libraryEmpty => '词库中还没有内容';

  @override
  String get noLibrarySearchResults => '没有匹配的词库内容';

  @override
  String libraryItemAdded(String value) {
    return '已添加：$value';
  }

  @override
  String libraryItemAlreadyExists(String value) {
    return '词库中已有“$value”';
  }

  @override
  String libraryItemAddFailed(String error) {
    return '添加失败：$error';
  }

  @override
  String get deleteLibraryItemTitle => '删除词库条目';

  @override
  String deleteLibraryItemConfirmation(String value, String name) {
    return '确定从$name中删除“$value”吗？';
  }

  @override
  String get deleteLibraryItemAction => '删除';

  @override
  String libraryItemDeleted(String value) {
    return '已删除：$value';
  }

  @override
  String libraryItemDeleteFailed(String error) {
    return '删除失败：$error';
  }

  @override
  String clearLibraryTitle(String name) {
    return '清空$name';
  }

  @override
  String clearLibraryConfirmation(String name, int count) {
    return '将删除$name中的全部 $count 条内容。此操作无法撤销，确定继续吗？';
  }

  @override
  String get clearLibraryAction => '全部清空';

  @override
  String libraryCleared(String name) {
    return '已清空$name';
  }

  @override
  String libraryClearFailed(String error) {
    return '清空失败：$error';
  }

  @override
  String get libraryImportEmpty => '文件中没有可导入的词库内容';

  @override
  String libraryImportCount(String name, int count) {
    return '$name $count 条';
  }

  @override
  String libraryImportSucceeded(String summary) {
    return '已导入：$summary';
  }

  @override
  String libraryImportFailed(String error) {
    return '导入词库失败：$error';
  }

  @override
  String get listSeparator => '，';

  @override
  String get fontPickerTitle => '选择字体';

  @override
  String get fontSearchHint => '搜索字体';

  @override
  String fontResultCount(int count) {
    return '共 $count 个字体';
  }

  @override
  String get fontSystemDefault => '系统默认';

  @override
  String get fontBuiltIn => '内置';

  @override
  String get fontPreview => '预览';

  @override
  String get fontPreviewSample => 'OpenLogTool · CQ CQ · 点名记录 123';

  @override
  String get aboutAppAction => '关于应用';

  @override
  String get aboutAppTitle => '关于 OpenLogTool';

  @override
  String get aboutAppTagline => '业余无线电点名记录与协作工具';

  @override
  String get aboutAppDescription =>
      '为现场和远程书记员提供完整点名记录、实时草稿协作与主控显示。OpenLogTool 专注于点名现场工作流，不以替代个人通联日志为目标。';

  @override
  String aboutVersionChip(String version) {
    return '版本 $version';
  }

  @override
  String get aboutVersionSection => '版本信息';

  @override
  String get aboutVersionLabel => '应用版本';

  @override
  String get aboutBuildLabel => '构建编号';

  @override
  String get aboutCommitLabel => 'Commit';

  @override
  String get aboutCopyVersionInfo => '复制版本信息';

  @override
  String get aboutVersionInfoCopied => '版本信息已复制';

  @override
  String get aboutCheckUpdates => '检查更新';

  @override
  String get aboutCheckingUpdates => '正在检查…';

  @override
  String aboutUpToDate(String version) {
    return '当前已是最新版本（$version）';
  }

  @override
  String get aboutUpdateAvailableTitle => '发现新版本';

  @override
  String aboutUpdateAvailableMessage(
      String currentVersion, String latestVersion) {
    return '当前版本：$currentVersion\n最新版本：$latestVersion';
  }

  @override
  String get aboutOpenRelease => '查看并下载';

  @override
  String get aboutUpdateLater => '稍后';

  @override
  String get aboutUpdateCheckFailed => '检查更新失败，请检查网络后重试';

  @override
  String get aboutProjectSection => '项目与许可';

  @override
  String get aboutRepository => '项目仓库';

  @override
  String get aboutRepositoryHint => '查看源代码与项目说明';

  @override
  String get aboutIssueTracker => '问题反馈';

  @override
  String get aboutIssueTrackerHint => '报告错误或提出建议';

  @override
  String get aboutOpenSourceLicenses => '开源组件许可';

  @override
  String get aboutOpenSourceLicensesHint => '查看应用使用的第三方组件许可';

  @override
  String get aboutLicenseName => 'GNU AGPL-3.0';

  @override
  String get aboutLicenseHint => 'OpenLogTool 是自由开源软件';

  @override
  String get aboutCopyright => '© 2026 Mazha0309 · BG5CRL';

  @override
  String aboutLinkOpenFailed(String error) {
    return '无法打开链接：$error';
  }

  @override
  String get restoreDefaultSettings => '恢复默认设置';

  @override
  String get settingsTitle => '应用设置';

  @override
  String get settingsSubtitle => '统一管理应用外观、点名台行为、主控显示、服务器账户和本机数据。';

  @override
  String get settingsAppearanceTitle => '外观与语言';

  @override
  String get settingsAppearanceHint => '选择主题、字体和界面语言；修改后立即应用。';

  @override
  String get themeColorSetting => '主题颜色';

  @override
  String get themeColorSettingHint => '设置应用按钮、选中状态与强调内容的主色调。';

  @override
  String get chooseThemeColor => '选择颜色';

  @override
  String get darkModeSetting => '深色模式';

  @override
  String get darkModeSettingHint => '切换应用的明暗配色。';

  @override
  String get appFontSetting => '应用字体';

  @override
  String get appFontSettingHint => '选择界面显示字体。';

  @override
  String get appLanguageSetting => '界面语言';

  @override
  String get appLanguageSettingHint => '可跟随系统，也可固定为简体中文或 English。';

  @override
  String get languageFollowSystem => '跟随系统';

  @override
  String get languageSimplifiedChinese => '简体中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get layoutSettingsTitle => '点名台与布局';

  @override
  String get layoutSettingsHint => '调整点名台宽度、分页和录入辅助行为。';

  @override
  String get paginationSetting => '分页显示记录';

  @override
  String get paginationSettingHint => '将记录分页显示，每页条数可配置。';

  @override
  String get tablePageSizeLabel => '每页记录数';

  @override
  String get tablePageSizeHint => '已保存记录表格每页显示的数量';

  @override
  String get recordEditorDialogSetting => '弹窗编辑记录';

  @override
  String get recordEditorDialogSettingHint =>
      '编辑记录时以弹窗打开完整表单，支持词库联想。关闭后改为在表格内联编辑。';

  @override
  String get controllerDisplaySettingsHint => '配置主控设备入口、独立窗口和默认显示内容。';

  @override
  String get serverSettingsHint => '配置协作服务器并管理当前账户和登录设备。';

  @override
  String get settingsSupportTitle => '应用信息与设置维护';

  @override
  String get settingsSupportHint => '查看版本与开源信息，或恢复界面和录入偏好。';

  @override
  String get restoreDefaultSettingsHint => '恢复外观、语言、布局和导出偏好，不影响记录与登录状态。';

  @override
  String get logsTitle => '日志';

  @override
  String get logsView => '查看持久化诊断日志、错误与应用内消息';

  @override
  String get logsEmpty => '（暂无日志）';

  @override
  String get logsCopy => '复制';

  @override
  String get logsClose => '关闭';

  @override
  String get logsCopied => '日志已复制';

  @override
  String logsCount(int count) {
    return '共 $count 条持久化日志';
  }

  @override
  String get logsSearchHint => '搜索消息、来源、错误或堆栈';

  @override
  String get logsLevelAll => '全部';

  @override
  String get logsLevelDebug => '调试';

  @override
  String get logsLevelInfo => '信息';

  @override
  String get logsLevelWarning => '警告';

  @override
  String get logsLevelError => '错误';

  @override
  String get logsClear => '清空';

  @override
  String get logsClearTitle => '清空诊断日志';

  @override
  String get logsClearConfirmation => '将删除本机保存的全部诊断日志。此操作不会影响点名记录，确定继续吗？';

  @override
  String get logsCleared => '诊断日志已清空';

  @override
  String get logsNoFilterResults => '没有符合当前筛选条件的日志';

  @override
  String get authSessionExpiredNotice => '服务器登录状态已失效，请重新登录。本机数据和服务器地址均已保留。';

  @override
  String get authStorageUnavailableNotice => '无法读取持久登录凭据，请检查系统凭据存储后重新登录。';

  @override
  String get resetSettingsTitle => '恢复默认设置';

  @override
  String get resetSettingsConfirmation =>
      '将外观、语言、布局和导出偏好恢复为默认值。本机记录、词库、服务器账户与登录状态不受影响。';

  @override
  String get resetSettingsConfirmAction => '恢复默认';

  @override
  String get resetSettingsSucceeded => '已恢复默认设置';

  @override
  String resetSettingsFailed(String error) {
    return '恢复默认设置失败：$error';
  }

  @override
  String get localDataOperationsTitle => '本机数据';

  @override
  String get localDataOperationsHint => '管理本机数据库的诊断、备份与重置；这些操作不会直接修改服务器数据。';

  @override
  String get databaseDiagnosticsSection => '诊断';

  @override
  String get databaseBackupSection => '备份与恢复';

  @override
  String get personalCloudTitle => '个人云同步';

  @override
  String get personalCloudHint =>
      '个人会话、点名记录和词库改动会在已登录设备间自动双向同步；协作会话仍使用独立的实时协作流程。';

  @override
  String get personalCloudSignedOut => '登录服务器后自动同步个人记录和词库改动';

  @override
  String get personalCloudUnsupported => '当前服务器版本不支持账户个人云快照，请先升级服务器';

  @override
  String get personalCloudChecking => '正在核对本机记录、词库与账户云快照…';

  @override
  String get personalCloudSyncing => '正在同步个人记录和词库改动…';

  @override
  String get personalCloudUpToDate => '个人记录和词库改动均已同步';

  @override
  String get personalCloudDecisionRequired => '首次配对或真实编辑冲突需要确认；互不冲突的改动已安全合并。';

  @override
  String personalCloudError(String error) {
    return '账户个人云快照同步失败：$error';
  }

  @override
  String personalCloudLocalSummary(int sessionCount, int logCount) {
    return '本机个人记录：$sessionCount 场、$logCount 条';
  }

  @override
  String personalCloudRemoteSummary(
      int sessionCount, int logCount, int revision) {
    return '账户云快照：$sessionCount 场、$logCount 条 · 修订 $revision';
  }

  @override
  String get personalCloudRemoteEmpty => '当前账户还没有个人云快照';

  @override
  String personalCloudDictionaryLocalSummary(int itemCount) {
    return '本机词库改动：$itemCount 项';
  }

  @override
  String personalCloudDictionaryRemoteSummary(int itemCount, int revision) {
    return '账户词库快照：$itemCount 项改动 · 修订 $revision';
  }

  @override
  String get personalCloudDictionaryRemoteEmpty => '当前账户还没有词库快照';

  @override
  String personalCloudConflictSummary(int count) {
    return '有 $count 个冲突字段需要选择';
  }

  @override
  String get personalCloudConfirmMerge => '确认安全合并';

  @override
  String get personalCloudKeepLocalConflicts => '冲突项保留本机值';

  @override
  String get personalCloudKeepRemoteConflicts => '冲突项保留云端值';

  @override
  String get personalCloudResolveOneByOne => '逐项处理';

  @override
  String get personalCloudConflictDialogTitle => '逐项处理冲突';

  @override
  String get personalCloudConflictPageTitle => '个人云同步冲突';

  @override
  String get personalCloudConflictPageHint =>
      '逐项比较本机、云端和共同基线。每个冲突都必须由你明确选择后才会合并；协作会话冲突仍在会话页处理。';

  @override
  String get personalCloudConflictSelectAllLocal => '全部选本机';

  @override
  String get personalCloudConflictSelectAllRemote => '全部选云端';

  @override
  String personalCloudConflictSelectionProgress(int selected, int total) {
    return '已选择 $selected/$total 项；全部选择后才能应用。';
  }

  @override
  String get personalCloudConflictApply => '应用选择';

  @override
  String get personalCloudConflictApplySucceeded => '冲突选择已应用并完成同步';

  @override
  String get personalCloudConflictNoneTitle => '当前没有同步冲突';

  @override
  String get personalCloudConflictNoneHint =>
      '个人记录和词库没有需要人工选择的冲突。同步状态与手动同步入口位于本地数据库页面。';

  @override
  String get personalCloudConflictConfirmationPendingTitle =>
      '没有字段冲突，但仍需确认首次合并';

  @override
  String get personalCloudConflictConfirmationPendingHint =>
      '返回本地数据库页面核对本机与云端数量，再确认安全合并。';

  @override
  String get personalCloudConflictRecordsDataset => '个人记录';

  @override
  String get personalCloudConflictDictionaryDataset => '个人词库';

  @override
  String personalCloudConflictEntityReference(String dataset, String id) {
    return '$dataset · 标识 $id';
  }

  @override
  String get personalCloudConflictBaseline => '共同基线';

  @override
  String get personalCloudConflictValueAbsent => '不存在（选择此侧将删除该项）';

  @override
  String get personalCloudConflictValueEmpty => '空值';

  @override
  String get personalCloudConflictLifecycleField => '会话状态';

  @override
  String get personalCloudConflictDeletionField => '删除状态';

  @override
  String get personalCloudConflictDictionaryStateField => '词库状态';

  @override
  String personalCloudFieldConflictTitle(String field) {
    return '字段 $field 双方都有值且不同';
  }

  @override
  String personalCloudEntityConflictTitle(String entity) {
    return '$entity 冲突';
  }

  @override
  String get personalCloudEntitySession => '会话';

  @override
  String get personalCloudEntityLog => '记录';

  @override
  String get personalCloudEntityDictionaryItem => '词库项';

  @override
  String get personalCloudKeepLocal => '保留本机';

  @override
  String get personalCloudKeepRemote => '保留云端';

  @override
  String get personalCloudSyncNow => '同步个人快照';

  @override
  String get personalCloudReplaceRemote => '以本机替换云快照';

  @override
  String get personalCloudRestoreLocal => '从云快照恢复本机';

  @override
  String get personalCloudReplaceTitle => '替换账户个人云快照';

  @override
  String personalCloudReplaceWarning(
      int localSessions, int localLogs, int remoteSessions, int remoteLogs) {
    return '将以本机 $localSessions 场、$localLogs 条个人记录完整替换账户云快照中的 $remoteSessions 场、$remoteLogs 条记录。不会写入或修改协作会话；此操作会同步到其他已登录设备。';
  }

  @override
  String get personalCloudReplacePhrase => '用本机记录替换账户云快照';

  @override
  String get personalCloudReplaceAction => '确认替换云快照';

  @override
  String get personalCloudRestoreTitle => '从账户个人云快照恢复';

  @override
  String personalCloudRestoreWarning(
      int remoteSessions, int remoteLogs, int localSessions, int localLogs) {
    return '将以账户云快照中的 $remoteSessions 场、$remoteLogs 条记录替换本机的 $localSessions 场、$localLogs 条个人记录。词库、设置和协作会话不受影响。';
  }

  @override
  String get personalCloudRestorePhrase => '用账户云快照替换本机记录';

  @override
  String get personalCloudRestoreAction => '确认恢复本机';

  @override
  String get personalCloudReplaceSucceeded => '账户云快照已保存本机个人记录';

  @override
  String get personalCloudRestoreSucceeded => '已从账户云快照恢复本机个人记录';

  @override
  String get databaseDangerZoneSection => '危险操作';

  @override
  String get databaseStatusTitle => '本机数据库状态';

  @override
  String get databaseStatusHint => '查看本机内容、协作待办和高级数据库诊断';

  @override
  String databaseStatusSchemaVersion(String version) {
    return '数据库结构版本：$version';
  }

  @override
  String databaseStatusBackupFormatVersion(String version) {
    return '备份格式版本：$version';
  }

  @override
  String get databaseStatusLocalContentSection => '本机内容';

  @override
  String get databaseStatusLocalContentHint => '仅统计本机数据库中的会话、点名记录和词库内容';

  @override
  String get databaseStatusSessionsLabel => '会话';

  @override
  String databaseStatusSessionsSummary(
      int active, int closed, int archived, int deleted) {
    return '进行中 $active · 已关闭 $closed · 已归档 $archived · 已删除 $deleted';
  }

  @override
  String get databaseStatusLogsLabel => '点名记录';

  @override
  String get databaseStatusDictionariesLabel => '词库条目';

  @override
  String databaseStatusLifecycleSummary(int active, int deleted) {
    return '可用 $active · 已删除 $deleted';
  }

  @override
  String databaseStatusDictionarySummary(
      String label, int active, int deleted) {
    return '$label $active（已删除 $deleted）';
  }

  @override
  String get databaseStatusDictionaryDevice => '设备';

  @override
  String get databaseStatusDictionaryAntenna => '天线';

  @override
  String get databaseStatusDictionaryQth => 'QTH';

  @override
  String get databaseStatusDictionaryCallsign => '呼号';

  @override
  String get databaseStatusCollaborationSection => '协作状态';

  @override
  String get databaseStatusCollaborationHint => '这些数字是本机协作副本和同步队列，不代表云端全部数据';

  @override
  String get databaseStatusCollaborationHealthy => '当前没有待上传记录、未解决冲突或离线记录';

  @override
  String get databaseStatusCollaborationPending => '本机仍有协作内容需要同步或处理';

  @override
  String get databaseStatusBindingsLabel => '协作会话副本';

  @override
  String get databaseStatusPendingOutboxLabel => '待上传操作';

  @override
  String get databaseStatusOpenConflictsLabel => '未解决冲突';

  @override
  String get databaseStatusOfflineRecordsLabel => '待处理离线记录';

  @override
  String get databaseStatusDraftCachesLabel => '点名草稿缓存';

  @override
  String get databaseStatusAdvancedTitle => '高级：原始表计数';

  @override
  String get databaseStatusAdvancedHint => '仅用于故障诊断；基础设施表为 0 通常是正常状态';

  @override
  String get databaseStatusUnknown => '未知';

  @override
  String databaseStatusLoadFailed(String error) {
    return '读取本机数据库状态失败：$error';
  }

  @override
  String get databaseExportTitle => '导出本机数据库';

  @override
  String get databaseExportHint => '备份会话、记录、词库以及本机协作副本和待同步状态';

  @override
  String get databaseExportDialogTitle => '保存 OpenLogTool 本机数据库备份';

  @override
  String get databaseExportSucceeded => '本机数据库备份已导出';

  @override
  String databaseExportFailed(String error) {
    return '导出本机数据库失败：$error';
  }

  @override
  String get databaseImportTitle => '导入本机数据库';

  @override
  String get databaseImportHint => '选择 JSON 备份并预览后，完整替换当前本机数据库';

  @override
  String get databaseImportPickerTitle => '选择 OpenLogTool 本机数据库备份';

  @override
  String get databaseImportNoFileSelected => '未选择备份文件，未执行导入';

  @override
  String get databaseImportPreviewTitle => '确认导入备份';

  @override
  String get databaseImportBackupVersion => '备份格式版本';

  @override
  String get databaseImportExportedAt => '导出时间';

  @override
  String get databaseImportUnknownTime => '未记录';

  @override
  String get databaseImportSessionCount => '会话';

  @override
  String get databaseImportLogCount => '点名记录';

  @override
  String get databaseImportDictionaryCount => '词库条目';

  @override
  String get databaseImportCollaborationCount => '协作副本';

  @override
  String get databaseImportPendingSyncCount => '待同步/待复核项';

  @override
  String get databaseImportPreviewWarning =>
      '导入会完整覆盖当前本机数据库，包括未同步更改。服务器上的会话、安全存储中的登录凭据和应用设置不受影响。内置词库将按当前版本补齐。此操作不可撤销。';

  @override
  String get databaseImportCollaborationWarning =>
      '此备份包含本机协作副本。当服务器地址和登录账户匹配时，导入后可能继续同步。';

  @override
  String get databaseImportConfirmAction => '覆盖并导入';

  @override
  String get databaseImportSucceeded => '本机数据库已导入，界面数据已刷新';

  @override
  String databaseImportSucceededSummary(int sessionCount, int logCount) {
    return '本机数据库已导入：$sessionCount 场会话、$logCount 条记录；可在会话页查看历史会话';
  }

  @override
  String databaseImportInvalid(String error) {
    return '所选文件不是有效的 OpenLogTool 数据库备份（$error）';
  }

  @override
  String databaseImportReadFailed(String error) {
    return '无法读取所选备份：$error';
  }

  @override
  String databaseImportFailed(String error) {
    return '导入本机数据库失败：$error';
  }

  @override
  String get databaseClearTitle => '清空本机数据';

  @override
  String get databaseClearHint => '清除本机记录、协作副本和自定义词条，并恢复内置词库默认内容';

  @override
  String get databaseClearWarning =>
      '此操作不可撤销。将清除本机的所有会话、点名记录、协作副本、待同步队列和自定义词条；不会删除或关闭服务器会话，也不会退出登录或重置外观。内置词库会恢复为默认内容。';

  @override
  String get databaseClearConfirmationPhrase => '清空全部数据';

  @override
  String databaseClearConfirmationInstruction(String phrase) {
    return '请输入“$phrase”以确认：';
  }

  @override
  String get databaseClearConfirmationLabel => '确认文本';

  @override
  String get databaseClearConfirmAction => '永久清空本机数据';

  @override
  String get databaseClearSucceeded => '本机数据已清空，内置词库已恢复为默认内容';

  @override
  String databaseClearFailed(String error) {
    return '清空本机数据失败：$error';
  }

  @override
  String get databaseReplacementRefreshFailed =>
      '操作已写入本机数据库，但界面刷新或内置词库恢复失败。请返回会话页后重试；如仍异常再重启应用。';

  @override
  String get databaseMaintenanceCollaborationBusy =>
      '当前正在发布、加入或处理其他协作操作，请等待操作结束后再管理本机数据库。';

  @override
  String get localCollaborationOperationBusy => '另一项协作操作仍在进行，请等待结束后重试。';

  @override
  String get localCollaborationRequired => '当前会话已不是本机协作副本，请刷新页面后重试。';

  @override
  String get dataTransferTitle => '数据导入与导出';

  @override
  String get dataTransferSubtitle => '备份、迁移或分享当前会话的点名记录，并配置 Excel 输出样式。';

  @override
  String get dataTransferActionsTitle => '记录文件';

  @override
  String get dataTransferActionsHint => 'JSON 适合完整数据迁移，Excel 适合查看、分享和打印。';

  @override
  String get exportDataTitle => '导出数据';

  @override
  String get exportDataHint => '将当前会话中的点名记录导出为文件';

  @override
  String get exportJson => '导出 JSON';

  @override
  String get exportExcel => '导出 Excel';

  @override
  String get importDataTitle => '导入数据';

  @override
  String get importDataHint => '从文件导入点名记录到当前会话';

  @override
  String get importJson => '导入 JSON';

  @override
  String get importExcel => '导入 Excel';

  @override
  String get excelConfigurationOverview => 'Excel 配置概览';

  @override
  String get excelConfigurationOverviewHint => '此处展示当前配置；交替行可直接切换，其他选项请打开编辑设置。';

  @override
  String get editSettings => '编辑设置';

  @override
  String get fileNameTemplate => '文件名模板';

  @override
  String get excelHeader => 'Excel 抬头';

  @override
  String get exportPath => '导出路径';

  @override
  String get systemDownloadsDirectory => '系统下载目录';

  @override
  String get headerBackground => '抬头背景';

  @override
  String get tableHeaderBackground => '表头背景';

  @override
  String get controllerRow => '主控行';

  @override
  String get alternatingRows => '交替行';

  @override
  String get fileFormatInformation => '文件格式说明';

  @override
  String get jsonFormatDescription => 'JSON：标准 JSON 数组，包含所有字段数据，适合备份与跨应用迁移。';

  @override
  String get excelFormatDescription =>
      'Excel：使用 .xlsx 格式，包含分组主控行、颜色样式和底部信息，适合分享与打印。';

  @override
  String get excelExportSettingsTitle => '编辑 Excel 导出设置';

  @override
  String get fileTab => '文件';

  @override
  String get tableStyleTab => '表格样式';

  @override
  String get templateVariablesTab => '模板变量';

  @override
  String get exportSettingsSaved => '导出设置已保存';

  @override
  String get select => '选择';

  @override
  String get exportPathDefaultHint => '留空时使用系统下载目录';

  @override
  String fileNameTemplateExample(String MM, String dd, String yyyy) {
    return '如：点名记录_$yyyy-$MM-$dd';
  }

  @override
  String get fileNameTemplateHint => '使用模板变量自动生成文件名';

  @override
  String get headerTemplate => '抬头模板';

  @override
  String headerTemplateExample(String MM, String dd, String yyyy) {
    return '如：$yyyy-$MM-$dd日点名记录';
  }

  @override
  String get headerTemplateHint => '未使用会话名或会话名为空时生效；支持模板变量';

  @override
  String get headerBackgroundColor => '抬头背景色';

  @override
  String get tableHeaderBackgroundColor => '表头背景色';

  @override
  String get controllerRowBackgroundColor => '主控栏背景色';

  @override
  String get tableBackgroundColor => '表格背景色';

  @override
  String get alternatingRowColor => '交替行颜色';

  @override
  String get alternatingRowColorHint => '使用交替行背景色';

  @override
  String get footerInformation => '底部说明';

  @override
  String get footerInformationHint => '显示 OpenLogTool 项目与许可信息';

  @override
  String get restoreDefaultColors => '恢复默认颜色';

  @override
  String get tableFont => '表格字体';

  @override
  String get templateVariablesTitle => '模板变量说明';

  @override
  String get templateYearDescription => '四位年份，如：2024';

  @override
  String get templateMonthDescription => '两位月份，如：01, 12';

  @override
  String get templateDayDescription => '两位日期，如：01, 31';

  @override
  String get templateHourDescription => '两位小时（24 小时制），如：14';

  @override
  String get templateMinuteDescription => '两位分钟，如：30';

  @override
  String get templateSecondDescription => '两位秒数，如：45';

  @override
  String get templateSessionDescription => '当前会话名称，如：2024年夏季点名';

  @override
  String get templateExamplesTitle => '使用示例';

  @override
  String templateFileNameExampleOne(String MM, String dd, String yyyy) {
    return '文件名：点名记录_$yyyy-$MM-$dd';
  }

  @override
  String get templateFileNameExampleOneResult => '点名记录_2024-03-28.xlsx';

  @override
  String templateFileNameExampleTwo(
      String HH, String MM, String dd, String mm, String ss, String yyyy) {
    return '文件名：通联_$yyyy-$MM-${dd}_$HH$mm$ss';
  }

  @override
  String get templateFileNameExampleTwoResult => '通联_2024-03-28_143045.xlsx';

  @override
  String templateHeaderExample(String MM, String dd, String yyyy) {
    return '抬头：$yyyy年$MM月$dd日点名记录';
  }

  @override
  String get templateHeaderExampleResult => '2024年03月28日点名记录';

  @override
  String get templateVariablesTip => '提示：使用模板变量可以让文件名和抬头自动包含当前日期时间，方便文件管理。';

  @override
  String chooseColor(String label) {
    return '选择$label';
  }

  @override
  String colorHexValue(String value) {
    return 'HEX：#$value';
  }

  @override
  String get colorOpacity => '透明度';

  @override
  String get noDataToExport => '没有数据可以导出';

  @override
  String saveExportFileDialog(String format) {
    return '保存 $format 导出文件';
  }

  @override
  String get downloadsDirectoryUnavailable => '无法访问下载目录';

  @override
  String exportSavedViaSystemPicker(String format) {
    return '$format 导出成功，已通过系统文件选择器保存';
  }

  @override
  String exportSucceeded(String format) {
    return '$format 导出成功';
  }

  @override
  String fileSavedTo(String path) {
    return '文件已保存到：\n$path';
  }

  @override
  String exportFailed(String error) {
    return '导出失败：$error';
  }

  @override
  String get excelGenerationFailed => '导出失败：无法生成 Excel 文件';

  @override
  String importSucceeded(int count) {
    return '导入成功：$count 条记录';
  }

  @override
  String importFailed(String error) {
    return '导入失败：$error';
  }

  @override
  String get excelImportComingSoon => 'Excel 导入功能开发中';

  @override
  String get excelImportLlmProcessing => '正在用 AI 解析 Excel 内容…';

  @override
  String get excelImportPreviewTitle => '导入预览';

  @override
  String excelImportPreviewCount(int count) {
    return '共识别 $count 条记录';
  }

  @override
  String get excelImportConfirm => '确认导入';

  @override
  String excelImportSuccess(int count) {
    return '已导入 $count 条记录';
  }

  @override
  String excelImportFailed(String error) {
    return '导入失败：$error';
  }

  @override
  String get pathCopied => '路径已复制';

  @override
  String get createSession => '新建会话';

  @override
  String get createSessionTitle => '新建点名会话';

  @override
  String get createSessionNameHint => '输入会话名称';

  @override
  String sessionCreated(String title) {
    return '已创建会话“$title”';
  }

  @override
  String createSessionFailed(String error) {
    return '创建会话失败：$error';
  }

  @override
  String get searchSessions => '搜索会话';

  @override
  String get allSessionStatuses => '全部状态';

  @override
  String get sessionArchived => '已归档';

  @override
  String sessionPage(int page, int total) {
    return '第 $page / $total 页';
  }

  @override
  String get moreSessionActions => '更多会话操作';

  @override
  String get openAndManageCollaboration => '打开并管理协作';

  @override
  String get exportLibraryJson => '导出词库 JSON';

  @override
  String get libraryExportDialogTitle => '导出词库';

  @override
  String get libraryExportSucceeded => '词库已导出';

  @override
  String libraryExportFailed(String error) {
    return '导出词库失败：$error';
  }

  @override
  String get editLibraryItem => '编辑';

  @override
  String editLibraryItemTitle(String name) {
    return '编辑“$name”';
  }

  @override
  String get editLibraryItemLabel => '词库内容';

  @override
  String libraryItemRenamed(String value) {
    return '已更新为“$value”';
  }

  @override
  String libraryItemRenameFailed(String error) {
    return '修改失败：$error';
  }

  @override
  String libraryPageStatus(int current, int total) {
    return '第 $current / $total 页';
  }

  @override
  String get previousPage => '上一页';

  @override
  String get nextPage => '下一页';

  @override
  String get settingsCategoryAppearance => '外观';

  @override
  String get settingsCategoryWorkbench => '工作台';

  @override
  String get settingsCategoryController => '主控屏';

  @override
  String get settingsCategoryServerAccount => '服务器与账户';

  @override
  String get settingsCategoryApplication => '应用';

  @override
  String get collaborationOverviewTab => '概览';

  @override
  String get collaborationSyncConflictsTab => '同步与冲突';

  @override
  String get collaborationAccessManagementTab => '访问管理';

  @override
  String get dataRecordsExportTab => '记录与导出';

  @override
  String get dataLookupLibrariesTab => '查询词库';

  @override
  String get dataLocalDatabaseTab => '本地数据库';

  @override
  String get dataSyncConflictsTab => '同步冲突';

  @override
  String get settingsCategoryAi => 'AI 辅助';

  @override
  String get aiSettingsTitle => 'AI 辅助识别';

  @override
  String get aiSettingsDescription => '配置可选的语音识别与字段提取服务。接口、模型与鉴权均由本机独立设置。';

  @override
  String get aiSettingsOptionalTitle => '可选且默认关闭';

  @override
  String get aiSettingsOptionalMessage =>
      '音频将直接发送到你配置的服务，不经过 OpenLogTool 协作服务器。识别结果只作为候选，不会自动覆盖书记员正在编辑的内容。';

  @override
  String get aiRecognitionEnabled => '启用 AI 辅助识别';

  @override
  String get aiRecognitionEnabledHint => '启用后可从点名工作台调用当前语音识别配置。';

  @override
  String get aiLocalReferenceContext => '结合本地词库与近期记录';

  @override
  String get aiLocalReferenceContextHint =>
      '默认开启。仅把与当前转写相近的少量词条和命中呼号的近期字段发送给文字模型，用于纠正呼号、设备、天线和 QTH；不会上传完整数据库。';

  @override
  String get aiRecognitionNeedsAsr => '请先添加并选择语音识别配置。';

  @override
  String get aiAsrStageTitle => '语音识别（ASR）';

  @override
  String get aiAsrStageDescription => '把音频转换为原始文本，三类接口格式可同时保存并随时切换。';

  @override
  String get aiExtractionStageTitle => '字段提取（可选）';

  @override
  String get aiExtractionStageDescription =>
      '把转写文本整理为呼号、RST、QTH 等候选字段；不配置时保留原始转写。';

  @override
  String get aiSupportedProtocols => '支持的接口格式';

  @override
  String get aiActiveProfile => '当前配置';

  @override
  String get aiNoProfileConfigured => '尚未添加配置';

  @override
  String get aiNoActiveProfile => '不使用';

  @override
  String get aiCredentialStatus => '密钥状态';

  @override
  String get aiCredentialNoProfile => '选择配置后显示本机密钥状态。';

  @override
  String get aiCredentialStoredLocally => 'API 密钥单独保存在系统安全存储中，不进入配置导出。';

  @override
  String get aiStatusNotConfigured => '未配置';

  @override
  String get aiStatusNoCredentialNeeded => '无需密钥';

  @override
  String get aiStatusCredentialReady => '密钥已保存';

  @override
  String get aiStatusCredentialMissing => '缺少密钥';

  @override
  String get aiAddProfile => '添加配置';

  @override
  String get aiEditProfile => '编辑配置';

  @override
  String get aiDeleteProfileTitle => '删除 AI 配置';

  @override
  String aiDeleteProfileMessage(String name) {
    return '确定删除“$name”及其本机密钥吗？';
  }

  @override
  String get aiProfileName => '配置名称';

  @override
  String get aiBaseUrl => 'API Base URL';

  @override
  String get aiModelName => '模型名称';

  @override
  String get aiProtocol => '接口格式';

  @override
  String get aiAuthentication => '鉴权方式';

  @override
  String get aiCredentialName => '请求头或查询参数名';

  @override
  String get aiCredentialPrefix => '密钥前缀（可留空）';

  @override
  String get aiApiKey => 'API 密钥';

  @override
  String get aiApiKeyNewHint => '可暂时留空，保存后将显示缺少密钥。';

  @override
  String get aiApiKeyExistingHint => '留空会保留当前密钥；更换接口目的地时需要重新填写。';

  @override
  String get aiRequestOptions => '高级请求选项（JSON）';

  @override
  String get aiRequestOptionsHint =>
      '通用 JSON 必须包含 requestTemplate；可设置 path、responsePath、body、fields、audioDataEncoding、includePrompt 等协议选项。这里的内容会随配置导出，请勿填写密钥。';

  @override
  String get aiRequiredField => '此项不能为空';

  @override
  String get aiRequestOptionsMustBeObject => '高级请求选项必须是 JSON 对象';

  @override
  String get aiJsonProtocolNeedsTemplate => '通用 JSON 格式必须包含 requestTemplate';

  @override
  String get aiInvalidJson => 'JSON 格式无效';

  @override
  String get aiInvalidBaseUrl => '请输入有效的 HTTP(S) API 地址';

  @override
  String aiSettingsFailed(String error) {
    return 'AI 设置操作失败：$error';
  }

  @override
  String get aiProtocolAudioTranscriptions => '音频转写 multipart';

  @override
  String get aiProtocolChatAudio => 'Chat input_audio';

  @override
  String get aiProtocolChatText => 'Chat 文本提取';

  @override
  String get aiProtocolGenericJson => '通用 JSON HTTP';

  @override
  String get aiAuthNone => '无需鉴权';

  @override
  String get aiAuthBearer => 'Authorization Bearer';

  @override
  String get aiAuthHeader => '自定义请求头';

  @override
  String get aiAuthQuery => '查询参数';

  @override
  String get aiWorkbenchTitle => 'AI 辅助识别';

  @override
  String get aiWorkbenchUnavailable => '当前记录为只读或正在处理，暂时不能识别。';

  @override
  String get aiReadyStatus => '点击麦克风录制一条点名内容。';

  @override
  String aiRecordingStatus(String elapsed) {
    return '正在录音 $elapsed';
  }

  @override
  String get aiLiveTranscriptTitle => '实时识别字段';

  @override
  String get aiLiveStructuredWaiting => '正在积累一段完整的点名内容，识别出的字段会显示在这里。';

  @override
  String get aiLiveStructuredUpdating => '正在根据目前的完整内容整理字段…';

  @override
  String aiLiveTranscriptionRetrying(String error) {
    return '实时识别暂时失败；停止录音后仍会用完整内容重试：$error';
  }

  @override
  String get aiRecognizingStatus => '正在识别并整理候选内容…';

  @override
  String get aiStartRecording => '录音';

  @override
  String get aiStopAndRecognize => '识别';

  @override
  String get aiMicrophonePermissionDenied => '未获得麦克风权限。';

  @override
  String aiRecordingFailed(String error) {
    return '录音失败：$error';
  }

  @override
  String aiRecognitionFailed(String error) {
    return '识别失败：$error';
  }

  @override
  String get aiReviewTitle => '确认 AI 候选内容';

  @override
  String get aiTranscriptTitle => '原始转写';

  @override
  String get aiCopyTranscript => '复制转写';

  @override
  String get aiTranscriptCopied => '已复制转写内容。';

  @override
  String get aiNoStructuredCandidates => '服务没有返回结构化字段，你仍可查看或复制上方转写。';

  @override
  String get aiCandidateRecord => '候选记录';

  @override
  String aiCandidateNumber(int number) {
    return '候选 $number';
  }

  @override
  String get aiCandidateHint => '空字段会默认勾选；替换已有内容必须由你手动勾选确认。';

  @override
  String get aiApplySelected => '应用所选字段';

  @override
  String aiCandidatesApplied(int count) {
    return '已应用 $count 个候选字段。';
  }

  @override
  String get aiCandidatesStale => '录音后记录内容已经变化，这些候选已不能安全应用。';

  @override
  String aiApplyFailed(String error) {
    return '无法应用 AI 候选：$error';
  }

  @override
  String aiWillReplaceValue(String value) {
    return '将替换：$value';
  }

  @override
  String get aiWillFillEmpty => '将填入空字段';

  @override
  String get aiReplacementNeedsConfirmation => '勾选后确认替换';

  @override
  String get aiCandidateUnchanged => '内容已经一致';

  @override
  String get aiCandidateStale => '录音后该字段已发生变化';

  @override
  String get aiCandidateBeingEdited => '该字段正在编辑或输入法组词';

  @override
  String get aiCandidateLocked => '另一位协作者正在编辑该字段';

  @override
  String get aiCandidateReadOnly => '当前记录为只读';

  @override
  String get aiCandidateBusy => '当前记录正在处理其他操作';

  @override
  String get aiCandidateInvalid => '不支持或无效的候选内容';

  @override
  String get textAssistantTitle => '文字助手';

  @override
  String get textAssistantDescription => '使用简单的文字模型配置完成字段整理、填写建议和词库维护。';

  @override
  String get textAssistantPrivacyTitle => '由你选择的模型服务处理';

  @override
  String get textAssistantPrivacyMessage =>
      '需要时会向所选服务发送当前字段文本或聚合后的历史词条，不会发送完整记录、备注或时间；API 密钥仅用于请求鉴权并安全保存在本机。';

  @override
  String get textAssistantEnabled => '启用文字助手';

  @override
  String get textAssistantNotConfigured => '尚未配置文字助手';

  @override
  String get textAssistantInlineSuggestions => '填写时显示 AI 规范建议';

  @override
  String get textAssistantInlineSuggestionsHint =>
      '设备、天线、QTH、高度和功率停止输入约 300 毫秒后，显示一条快速建议。';

  @override
  String get textAssistantTest => '测试连接';

  @override
  String get textAssistantConfigure => '配置文字助手';

  @override
  String get textAssistantEdit => '修改配置';

  @override
  String get textAssistantConfigureTitle => '配置文字助手';

  @override
  String get textAssistantProvider => '服务类型';

  @override
  String get textAssistantProviderOpenAi => 'OpenAI（Responses API）';

  @override
  String get textAssistantProviderAnthropic => 'Anthropic';

  @override
  String get textAssistantProviderCompatible =>
      'OpenAI 兼容（旧版 Chat Completions）';

  @override
  String get textAssistantTestSucceeded => '文字助手连接正常。';

  @override
  String get textAssistantSuggestionLabel => 'AI 规范建议';

  @override
  String get aiDictionaryRecognize => '从历史识别';

  @override
  String get aiDictionaryOptimize => 'AI 优化词库';

  @override
  String get aiDictionaryNeedsAssistant => '请先在设置中配置并启用文字助手。';

  @override
  String get aiDictionaryNoSuggestions => '没有发现需要处理的词条。';

  @override
  String aiDictionaryApplied(int count) {
    return '已应用 $count 条词库建议。';
  }

  @override
  String aiDictionaryFailed(String error) {
    return '词库 AI 操作失败：$error';
  }

  @override
  String get aiDictionaryOptimizing => '正在优化词库';

  @override
  String get aiDictionaryRecognizing => '正在识别历史词条';

  @override
  String get aiDictionaryPreparing => '正在整理本地数据…';

  @override
  String aiDictionaryProgress(int completed, int total) {
    return '已完成 $completed / $total';
  }

  @override
  String get aiDictionaryReviewTitle => '确认词库建议';

  @override
  String aiDictionaryReviewHint(int recordCount) {
    return '根据 $recordCount 条历史记录及当前词库生成。只有勾选的内容会写入。';
  }

  @override
  String get aiDictionaryActionAdd => '新增';

  @override
  String get aiDictionaryActionRename => '改名';

  @override
  String get aiDictionaryActionMerge => '合并';

  @override
  String aiDictionaryUsedCount(int count) {
    return '历史出现 $count 次';
  }

  @override
  String get aiDictionaryMergeWarning => '合并会从词库隐藏源词条，默认不勾选；不会改写历史记录。';

  @override
  String get aiDictionaryApplySelected => '应用所选建议';

  @override
  String get fieldFormatSuggestionLabel => '格式候选';

  @override
  String get logTableHorizontalScrollHint => 'Shift + 滚轮横向滚动';
}

/// The translations for Chinese, as used in China (`zh_CN`).
class AppLocalizationsZhCn extends AppLocalizationsZh {
  AppLocalizationsZhCn() : super('zh_CN');

  @override
  String get collaborationTechnicalDetails => '连接与诊断详情';

  @override
  String get collaborationOverviewOnline => '已连接，正在与参与者同步记录。';

  @override
  String get collaborationOverviewOffline => '连接暂时不可用，已有记录仍保留在本机。';

  @override
  String get collaborationOverviewAttention => '有待处理的记录或同步问题，请打开“同步”查看。';

  @override
  String collaborationOverviewPending(int count) {
    return '已保存到本机，$count 项修改等待同步。';
  }

  @override
  String get historySessionCollaborationCloseRequired =>
      '这是共同记录，请在“协作与成员”中结束共同记录或离开协作；不能把它作为本地会话结束。';

  @override
  String get collaborationLifecycleHint =>
      '切换页面或暂时断网不会退出协作。发起人可以结束共同记录，参与者可以离开协作；已有记录会保留。';

  @override
  String get hubLocalStart => '新建会话即可开始记录，无需服务器或账号。记录保存在本机，可随时查看和导出。';

  @override
  String get hubLocalHint => '本地记录可独立使用；同步与多人协作按需启用。';

  @override
  String get hubOptionalOnline => '同步与协作（可选）';

  @override
  String get hubOptionalOnlineHint => '需要多设备同步或与搭档共同记录时，再连接服务器。';

  @override
  String get hubConfigureServer => '设置可选服务器';

  @override
  String get hubOnlineConnected => '好友与协作使用当前服务器，本地记录仍可独立使用。';

  @override
  String get hubEnableCollaboration => '邀请搭档一起记录';

  @override
  String get hubConfirmUpload => '上传此会话并开启协作';

  @override
  String get hubUploadExplanation =>
      '这会把当前会话及其中已有的记录上传到下面的服务器，并开始协作同步。此操作只上传当前会话，不改变其他会话的同步设置。会话仍为私有，之后再选择要邀请的好友；此操作不会发布公开页面。';

  @override
  String get hubContextChanged => '服务器、账号或当前会话已切换，请关闭后重新操作。';

  @override
  String get hubAlreadyMember => '对方已经加入这个会话，可在参与者管理中查看。';

  @override
  String get hubInvitationHint => '对方接受后才能查看此会话的记录，不会开放你的其他会话。';

  @override
  String get hubContinueRecording => '继续记录';

  @override
  String get hubViewRecords => '查看记录';

  @override
  String get hubSessionDetails => '会话详细信息';

  @override
  String get hubHistoryHint => '查看本机已有记录。“已结束”只按会话状态筛选，不代表公开归档。';

  @override
  String get hubAllRecords => '全部';

  @override
  String get hubMyRecords => '我的记录';

  @override
  String get hubTogetherRecords => '共同记录';

  @override
  String get hubEndedRecords => '已结束';

  @override
  String get socialTitle => '好友与邀请';

  @override
  String get socialAddFriend => '添加好友';

  @override
  String get socialFriends => '好友';

  @override
  String get socialMessages => '消息';

  @override
  String get socialSessions => '会话';

  @override
  String get socialIntro => '添加搭档为好友，再邀请他们一起点名。好友关系不会自动开放个人记录。';

  @override
  String get socialUsername => '对方的用户名（注册时使用的呼号）';

  @override
  String get socialSend => '发送申请';

  @override
  String get socialInvite => '邀请参与';

  @override
  String get socialApply => '申请加入';

  @override
  String get socialAccept => '接受';

  @override
  String get socialReject => '拒绝';

  @override
  String get socialPending => '等待对方处理';

  @override
  String get socialAccepted => '已接受';

  @override
  String get socialView => '只能查看';

  @override
  String get socialEdit => '共同记录';

  @override
  String get socialOpen => '打开会话';

  @override
  String get socialPrivate => '仅邀请可加入';

  @override
  String get socialDiscoverable => '好友可见，可申请加入';

  @override
  String get socialVisibilityHint => '好友只能看到会话标题，获准加入后才能查看记录。';

  @override
  String get socialNoFriends => '还没有好友，输入搭档的用户名发送申请。';

  @override
  String get socialNoMessages => '暂无邀请或申请';

  @override
  String get socialNoSessions => '暂无好友开放的会话。你也可以把当前会话用于协作。';

  @override
  String get socialPublish => '开启当前会话协作';

  @override
  String get socialRemove => '删除好友';

  @override
  String get socialRemoveHint => '会取消彼此待处理的邀请和申请。已加入的会话成员由会话负责人单独管理。';

  @override
  String get socialBlock => '屏蔽';

  @override
  String get socialUnblock => '取消屏蔽';

  @override
  String get socialBlocked => '已屏蔽';

  @override
  String get socialDone => '操作已完成';

  @override
  String get socialFriendRequest => '好友申请';

  @override
  String get socialInvitation => '会话邀请';

  @override
  String get socialApplication => '加入申请';

  @override
  String get socialSent => '我发出的';

  @override
  String get socialReceived => '收到的';

  @override
  String get socialManage => '管理参与者';

  @override
  String get socialConnect => '连接服务器并登录后，即可添加好友。';

  @override
  String get socialUpgrade => '此服务器尚不支持好友功能，请更新服务器。';

  @override
  String get socialLoadFailed => '暂时无法刷新，请重试。';

  @override
  String get socialChooseFriend => '选择好友';

  @override
  String get socialErrorUser => '没有找到这个用户名。请确认对方已在同一服务器注册。';

  @override
  String get socialErrorFriends => '请先添加对方为好友。';

  @override
  String get socialErrorClosed => '这条申请已处理或已过期，请刷新。';

  @override
  String get socialErrorSelf => '不能添加自己为好友。';

  @override
  String get socialErrorBlocked => '目前无法向这个用户发送请求。';

  @override
  String get socialServerLink => '复制服务器连接信息';

  @override
  String get socialServerLinkHint => '可粘贴服务器地址或服务器网页链接，连接后再登录。';

  @override
  String get socialLegacy => '旧版共享';

  @override
  String get navWorkbench => '点名台';

  @override
  String get navSessions => '会话';

  @override
  String get navData => '数据';

  @override
  String get navSettings => '设置';

  @override
  String get workbenchNoSession => '尚未开始点名';

  @override
  String get workbenchLocalRecording => '单机记录';

  @override
  String get collaborationLocalOnly => '仅本地';

  @override
  String get collaborationPublishing => '发布中';

  @override
  String get collaborationJoining => '加入中';

  @override
  String get collaborationSnapshotting => '下载快照';

  @override
  String get collaborationCatchingUp => '追赶更新';

  @override
  String get collaborationReady => '已连接';

  @override
  String get collaborationResyncing => '重新同步';

  @override
  String get collaborationRevoked => '权限已撤销';

  @override
  String get collaborationFailed => '同步失败';

  @override
  String collaborationState(String state) {
    return '协作 $state';
  }

  @override
  String pendingSyncCount(int count) {
    return '待同步 $count';
  }

  @override
  String conflictCount(int count) {
    return '冲突 $count';
  }

  @override
  String get localSessionTooltip => '当前为本地会话';

  @override
  String collaborationStatusTooltip(String state, int count) {
    return '协作状态 $state，待同步 $count';
  }

  @override
  String get currentRecord => '当前记录';

  @override
  String get startNewRecord => '开始新记录';

  @override
  String get newRecordName => '新记录名称';

  @override
  String get newRecordNameHint => '输入本次记录名称（可留空）';

  @override
  String get automaticName => '自动命名';

  @override
  String newRecordStarted(String name) {
    return '已开始新记录：$name';
  }

  @override
  String createNewRecordFailed(String error) {
    return '创建新记录失败：$error';
  }

  @override
  String currentOrdinal(int ordinal) {
    return '当前第 $ordinal 位';
  }

  @override
  String get sessionsTitle => '会话';

  @override
  String get sessionsSubtitle => '管理本次点名、协作书记员和主控显示设备。';

  @override
  String get noCurrentSession => '当前没有点名会话';

  @override
  String get noCurrentSessionHint => '创建一个点名会话，或加入协作后即可开始记录。';

  @override
  String get workbenchNoSessionHint => '请先到会话页新建会话，或加入协作后再开始记录。';

  @override
  String get createOrJoinSessionFirst => '请先新建会话或加入协作';

  @override
  String get goCreateSession => '去新建会话';

  @override
  String get sessionActive => '进行中';

  @override
  String get sessionClosed => '已结束';

  @override
  String savedPositions(int count) {
    return '$count 位已保存';
  }

  @override
  String get localSession => '本地会话';

  @override
  String get manageCollaboration => '协作与成员';

  @override
  String get openLiveShare => 'Live Share 公开页面';

  @override
  String get enterControllerScreen => '进入主控屏';

  @override
  String get localControllerDisplay => '本机主控显示';

  @override
  String get localControllerDisplayHint => '书记员继续使用主窗口，主控内容在独立只读窗口显示。';

  @override
  String get openFloatingWindow => '打开悬浮窗';

  @override
  String get openSecondDisplayWindow => '打开第二屏窗口';

  @override
  String get historySessions => '历史会话';

  @override
  String get historySessionsHint => '查看和切换过去的点名会话；已关闭会话将以只读方式打开。';

  @override
  String get historySessionsEmpty => '暂无历史会话';

  @override
  String historySessionsLoadFailed(String error) {
    return '加载历史会话失败：$error';
  }

  @override
  String get historySessionOpen => '打开会话';

  @override
  String get historySessionCurrent => '当前会话';

  @override
  String historySessionSwitched(String title) {
    return '已打开会话：$title';
  }

  @override
  String historySessionOpenFailed(String error) {
    return '打开会话失败：$error';
  }

  @override
  String get historySessionCloseTitle => '结束记录';

  @override
  String historySessionCloseConfirmation(String title) {
    return '结束“$title”的记录吗？已有记录会保留，可随时查看或恢复记录。此操作不会删除数据。';
  }

  @override
  String get historySessionClosed => '记录已结束，已有记录已保留';

  @override
  String historySessionCloseFailed(String error) {
    return '结束记录失败：$error';
  }

  @override
  String get historySessionReopenAction => '重新激活';

  @override
  String get historySessionReopenTitle => '重新激活本地会话';

  @override
  String historySessionReopenConfirmation(String title) {
    return '恢复“$title”并切换过去继续记录吗？其他会话不受影响。协作会话请由发起人在“协作与成员”中恢复。';
  }

  @override
  String historySessionReopened(String title) {
    return '已重新激活并切换到会话：$title';
  }

  @override
  String historySessionReopenFailed(String error) {
    return '重新激活本地会话失败：$error';
  }

  @override
  String historySessionReopenedLogsUnavailable(String title) {
    return '会话“$title”已重新激活，但日志暂时加载失败。为安全起见当前保持只读，请重试加载。';
  }

  @override
  String get historySessionCollaborationReopenRequired =>
      '这是协作会话。请先打开该会话，再到“协作与成员”中重新打开。';

  @override
  String get historySessionDeleteTitle => '永久删除本机会话';

  @override
  String historySessionDeleteWarning(String title) {
    return '将永久删除本机“$title”的所有日志及本地协作副本。此操作不可撤销，但不会删除或关闭服务器上的共享会话。请输入完整会话名以确认：';
  }

  @override
  String get historySessionDeleteNameLabel => '完整会话名';

  @override
  String get historySessionDeleteAction => '永久删除本机数据';

  @override
  String get historySessionDeleted => '已永久删除本机会话';

  @override
  String historySessionDeleteFailed(String error) {
    return '永久删除本机会话失败：$error';
  }

  @override
  String get historySessionReadOnly => '当前为已关闭的历史会话，只能查看已有记录。';

  @override
  String controllerWindowOpenFailed(String error) {
    return '无法打开主控窗口：$error';
  }

  @override
  String get controllerDisplaySettingsTitle => '主控显示';

  @override
  String get enableControllerDeviceEntry => '启用主控设备入口';

  @override
  String get enableControllerDeviceEntryHint =>
      '开启后可从“会话”进入全屏只读主控屏，适用于安卓平板、手机或独立电脑。';

  @override
  String get defaultInformationDetail => '默认信息详细程度';

  @override
  String get desktopControllerDisplayHint => '本机桌面还可从会话页打开置顶悬浮窗或第二显示器窗口。';

  @override
  String get inAppControllerDisplayHint => '当前设备使用应用内全屏主控模式。';

  @override
  String get controllerScreenTitle => 'OpenLogTool 主控屏';

  @override
  String get controllerFloatingWindowTitle => 'OpenLogTool 主控悬浮窗';

  @override
  String get controllerScreenFallbackTitle => '点名主控屏';

  @override
  String savedPositionCount(int count) {
    return '已保存 $count 位';
  }

  @override
  String get notReceivedDraftUpdate => '尚未收到草稿更新';

  @override
  String updatedAt(String time) {
    return '更新 $time';
  }

  @override
  String editorEditing(String name) {
    return '$name 编辑';
  }

  @override
  String get connectionConnected => '实时连接';

  @override
  String get connectionReconnecting => '正在重连';

  @override
  String get connectionOffline => '连接中断';

  @override
  String get staleControllerDataWarning => '连接已中断，正在显示最后一次收到的内容，数据可能已过期。';

  @override
  String get previousSavedRecord => '上一位已保存记录';

  @override
  String get noPreviousRecord => '暂无上一位记录';

  @override
  String get waitingForCallsign => '等待来台呼号…';

  @override
  String get beingEdited => '正在编辑';

  @override
  String configureControllerDisplay(String detail) {
    return '显示内容（$detail）';
  }

  @override
  String get exitControllerScreen => '退出主控屏';

  @override
  String get controllerDisplayConfiguration => '主控屏显示内容';

  @override
  String get informationDetail => '信息详细程度';

  @override
  String get currentFields => '当前项字段';

  @override
  String get previousFields => '上一位字段';

  @override
  String get cancel => '取消';

  @override
  String get apply => '应用';

  @override
  String get detailMinimal => '极简';

  @override
  String get detailStandard => '标准';

  @override
  String get detailFull => '完整';

  @override
  String get detailCustom => '自定义';

  @override
  String get fieldController => '主控';

  @override
  String get fieldCallsign => '来台呼号';

  @override
  String get fieldTime => '时间';

  @override
  String get logTimeInvalid => '请输入有效时间（HH:mm）';

  @override
  String get fieldRstSent => 'RST 发';

  @override
  String get fieldRstRcvd => 'RST 收';

  @override
  String get fieldQth => 'QTH';

  @override
  String get fieldDevice => '设备';

  @override
  String get fieldPower => '功率';

  @override
  String get fieldAntenna => '天线';

  @override
  String get fieldHeight => '高度';

  @override
  String get fieldRemarks => '备注';

  @override
  String get saveRecord => '保存记录';

  @override
  String get recordAdded => '记录已添加';

  @override
  String get recordQueuedOffline => '网络不可用，记录已保存到本机待复核';

  @override
  String get sharedDraftReadOnly => '当前协作草稿只读';

  @override
  String fieldLockedBy(String name) {
    return '$name 正在编辑';
  }

  @override
  String get offlineReviewTitle => '离线记录待复核';

  @override
  String get resolutionDiscard => '丢弃';

  @override
  String get resolutionSubmitDuplicate => '作为重复记录提交';

  @override
  String get resolutionCopyCurrent => '带入当前草稿';

  @override
  String get callsignRequired => '请输入点名呼号';

  @override
  String get leaveSession => '离开协作';

  @override
  String get leaveSessionConfirmation =>
      '离开后你将不再收到此会话的更新，本机已有记录保留为只读，其他成员可继续记录。以后需要重新邀请或申请加入。此操作需要连接服务器；只是暂时离开页面，无需退出协作。';

  @override
  String get moreLocalCollaborationActions => '更多操作';

  @override
  String get createEditableLocalCopy => '另存独立会话';

  @override
  String get createEditableLocalCopyTitle => '另存独立会话？';

  @override
  String createEditableLocalCopyConfirmation(String title) {
    return '将“$title”当前表格中已保存的记录复制到一个新会话，并切换过去独立记录，无需服务器。原协作会话和你的成员身份不变，稍后仍可切回。未同步队列、冲突、离线待复核记录及未提交草稿保留在原会话，不会复制到新会话，也不会删除。';
  }

  @override
  String get editableLocalCopySucceeded => '已另存并切换到独立会话，原协作会话已保留';

  @override
  String get accountSharing => '跨账号共享';

  @override
  String get accountSharingHint => '先申请再接受。共享会话只读，加入协作仍需口令。';

  @override
  String get sharedSessionBadge => '共享';

  @override
  String sharedSessionFrom(String username) {
    return '来自 $username 的共享';
  }

  @override
  String get acceptShare => '接受';

  @override
  String get pendingInboundShares => '待处理申请';

  @override
  String get browseSharedSession => '浏览共享会话';

  @override
  String get joinSharedSession => '口令加入';

  @override
  String get readOnlyClosePending => '结束请求已保存，等待同步确认；确认前暂时只读。';

  @override
  String get readOnlySessionClosed => '共同记录已结束，已有记录可继续查看。';

  @override
  String get readOnlyResyncing => '正在恢复同步，已保存的修改会保留。';

  @override
  String get readOnlyCheckingAccess => '正在确认你的参与权限，暂时只能查看。';

  @override
  String get closeCollaborationSessionTitle => '结束共同记录';

  @override
  String get closeCollaborationSessionMessage =>
      '结束后，所有成员都不能继续添加或修改记录，已有记录和成员关系会保留。你可以稍后恢复记录。此操作需要同步到服务器；只是暂时离开，无需结束。';

  @override
  String get closeSharedSession => '结束共同记录';

  @override
  String get closeCollaborationDraftNotEmpty =>
      '当前点名草稿还有内容。请先提交这条完整记录，或明确丢弃草稿后再结束。';

  @override
  String get closeCollaborationDraftIncomplete =>
      '当前草稿缺少时间、主控呼号或点名呼号，不能提交；仍可明确丢弃后结束。';

  @override
  String closeCollaborationDraftLocked(int count) {
    return '其他成员或设备仍在编辑 $count 个草稿字段。请等待对方完成编辑并刷新后再结束。';
  }

  @override
  String get closeCollaborationDiscardAndClose => '丢弃草稿并结束';

  @override
  String get closeCollaborationSubmitAndClose => '提交并结束';

  @override
  String get closeCollaborationQueuedOffline =>
      '记录仅保存到离线队列，尚未提交到服务器；共同记录尚未结束。请恢复网络并处理该记录后重试。';

  @override
  String get closeSessionQueued => '结束共同记录的请求已保存，等待同步确认';

  @override
  String get confirm => '确认';

  @override
  String get duplicateCallsignWarningSetting => '重复呼号提醒';

  @override
  String get duplicateCallsignWarningHint => '同一场点名中再次录入相同呼号时先提醒，但仍允许保存。';

  @override
  String get duplicateCallsignTitle => '呼号已经记录过';

  @override
  String duplicateCallsignMessage(String callsign) {
    return '$callsign 已在本次点名中记录过，仍要保存吗？';
  }

  @override
  String get saveAnyway => '仍然保存';

  @override
  String get callsignHistoryFillSetting => '呼号历史一键复用';

  @override
  String get callsignHistoryFillHint => '匹配数据库中的既有呼号记录，并可一键带入设备、天线、QTH 等字段。';

  @override
  String get publicShareManagement => 'Live Share · 公开只读页面';

  @override
  String get publicShareManagementHint =>
      '为主控、远程书记员或观众生成只读网页；无需登录即可查看当前点名进度。链接密钥仅在创建时显示。';

  @override
  String get publicShareAccessRequired =>
      'Live Share 由当前协作会话的 Owner 管理。请先登录并发布此会话；如果你是协作成员，请联系 Owner 创建公开链接。';

  @override
  String get publicShareUnsupported =>
      '当前服务器未提供安全的 Live Share 公开页面。升级或启用服务端公开分享功能后即可创建。';

  @override
  String get publicShareCreatedTitle => '公开只读页面已创建';

  @override
  String get publicShareCreatedHint => '请立即保存此链接；出于安全考虑，刷新或重新登录后无法再次取回链接密钥。';

  @override
  String get createPublicShare => '创建公开链接';

  @override
  String get publicShareExpiryDialogTitle => '设置 Live Share 有效期';

  @override
  String get publicShareExpiryDialogHint => '公开链接将在所选时长后自动失效。';

  @override
  String get publicShareExpiryPresets => '快捷选择';

  @override
  String get publicShareExpiryOneHour => '1小时';

  @override
  String get publicShareExpirySixHours => '6小时';

  @override
  String get publicShareExpiryTwelveHours => '12小时';

  @override
  String get publicShareExpiryOneDay => '1天';

  @override
  String get publicShareExpiryThreeDays => '3天';

  @override
  String get publicShareExpirySevenDays => '7天';

  @override
  String get publicShareExpiryThirtyDays => '30天';

  @override
  String get publicShareExpiryCustom => '自定义';

  @override
  String get publicShareExpiryCustomHours => '有效期（小时）';

  @override
  String get publicShareExpiryRangeError => '请输入 1–720 之间的整数小时';

  @override
  String publicShareEstimatedExpiry(String time) {
    return '预计失效：$time（本地时间）';
  }

  @override
  String get copyPublicShareLink => '复制链接';

  @override
  String get openPublicShare => '在浏览器打开';

  @override
  String get revokePublicShare => '撤销';

  @override
  String get publicShareLinkCopied => '公开链接已复制';

  @override
  String get publicShareNoActiveLinks => '当前没有有效的公开链接。创建后可将只读页面交给主控或远程查看者。';

  @override
  String get publicShareSecretUnavailable =>
      '已有有效公开链接，但其密钥只在创建时返回。若链接没有保存，请撤销旧链接并创建新链接。';

  @override
  String get publicShareLinksTitle => '公开链接记录';

  @override
  String get publicShareUnavailable => '已撤销或已过期';

  @override
  String get publicShareOpenFailed => '无法打开浏览器；你仍可复制链接后手动打开。';

  @override
  String publicShareExpiresAt(String time) {
    return '有效期至 $time';
  }

  @override
  String get refresh => '刷新';

  @override
  String get reuseDatabaseInformation => '一键复用数据库信息';

  @override
  String get collapseSidebar => '收起侧边栏';

  @override
  String get expandSidebar => '展开侧边栏';

  @override
  String get limitWorkbenchWidthSetting => '限制点名台内容宽度';

  @override
  String get limitWorkbenchWidthHint => '宽屏时将点名台内容居中并限制在 1520 像素内，避免字段过度拉伸。';

  @override
  String serverConnectionFailed(String detail) {
    return '连接失败：$detail';
  }

  @override
  String serverNetworkError(String url) {
    return '服务器 $url 没有响应。请检查地址和端口，并确认服务端或反向代理正在运行。';
  }

  @override
  String serverWebMixedContentError(String url) {
    return '当前 WebClient 使用 HTTPS，浏览器不允许连接 HTTP 服务器 $url。请为服务器启用 HTTPS。';
  }

  @override
  String serverWebCrossOriginError(String url, String origin) {
    return '浏览器无法访问服务器 $url。请确认服务器在线；若原生客户端能连接，请在服务端 CORS_ORIGINS 中加入 $origin，或使用同源反向代理。';
  }

  @override
  String serverNetworkTimeout(String url) {
    return '连接 $url 超时。请检查网络、防火墙和服务端状态。';
  }

  @override
  String serverInvalidResponse(String url) {
    return '已连接 $url，但它没有返回兼容的 OpenLogTool Server 响应。';
  }

  @override
  String get serverAddressRequired => '请先填写服务器地址。';

  @override
  String get serverAddressInvalid => '服务器地址必须是完整的 http(s) URL。';

  @override
  String get serverSettingsTitle => '服务器与账户';

  @override
  String get serverAddressLabel => '服务器地址';

  @override
  String get serverAddressHint => 'http://your-server:3000';

  @override
  String get serverSaveAndCheck => '保存并检测服务器';

  @override
  String serverCheckSucceeded(int min, int max) {
    return '连接成功 · 协议 v$min-$max';
  }

  @override
  String serverInstanceDetails(String instance, String features) {
    return '实例 $instance\n能力 $features';
  }

  @override
  String get serverConnected => '已连接';

  @override
  String get serverNotConnected => '未检测';

  @override
  String get serverSignedOutHint => '登录后可以参与协作，并管理当前账号自己的资料和登录设备。';

  @override
  String get tokenStoragePrivateFileWarning =>
      '系统钥匙环不可用；登录凭据已保存到仅当前 Linux 用户可读的私有文件。钥匙环恢复可用后会自动迁回安全存储。';

  @override
  String get tokenStorageMemoryOnlyWarning =>
      '安全凭据存储不可用；本次登录仅在应用运行期间有效，退出后需要重新登录。';

  @override
  String get serverLogin => '登录';

  @override
  String get serverRegister => '注册';

  @override
  String get serverLogout => '退出';

  @override
  String serverAccountId(String id) {
    return '账号 ID：$id';
  }

  @override
  String get serverLoginSucceeded => '已登录服务器';

  @override
  String get serverRegistrationSucceeded => '注册并登录成功';

  @override
  String serverLoginFailed(String error) {
    return '登录失败：$error';
  }

  @override
  String serverRegistrationFailed(String error) {
    return '注册失败：$error';
  }

  @override
  String serverLogoutFailed(String error) {
    return '退出失败：$error';
  }

  @override
  String get accountChangeUsername => '修改用户名';

  @override
  String get accountChangePassword => '修改密码';

  @override
  String get accountDeviceSessions => '登录设备';

  @override
  String get accountUsernameUpdated => '用户名已更新';

  @override
  String accountPasswordUpdated(int count) {
    return '密码已更新，已撤销 $count 个登录会话，请重新登录。';
  }

  @override
  String accountUpdateFailed(String error) {
    return '账户操作失败：$error';
  }

  @override
  String get usernameLabel => '用户名';

  @override
  String get usernameLengthHint => '用户名应为 3–64 个字符';

  @override
  String get passwordLabel => '密码';

  @override
  String get fieldRequired => '此项不能为空';

  @override
  String get currentPasswordLabel => '当前密码';

  @override
  String get newPasswordLabel => '新密码';

  @override
  String get confirmNewPasswordLabel => '确认新密码';

  @override
  String get passwordLengthHint => '密码至少需要 10 个字符';

  @override
  String get passwordMismatch => '两次输入的新密码不一致';

  @override
  String get passwordChangeRequiredTitle => '必须修改临时密码';

  @override
  String passwordChangeRequiredHint(String username) {
    return '账号 $username 使用了临时密码。设置新密码后才能继续。';
  }

  @override
  String passwordChangeCredentialExpires(int seconds) {
    return '本次改密凭据将在 $seconds 秒内过期。';
  }

  @override
  String get completePasswordChange => '设置新密码并登录';

  @override
  String get cancelLogin => '取消登录';

  @override
  String get passwordChangeCompleted => '密码已更新并完成登录';

  @override
  String get deviceSessionsTitle => '登录设备';

  @override
  String get deviceSessionsEmpty => '当前没有有效的登录设备';

  @override
  String get deviceUnknown => '未命名设备';

  @override
  String get deviceCurrent => '当前设备';

  @override
  String deviceIp(String ip) {
    return 'IP：$ip';
  }

  @override
  String deviceLastUsed(String time) {
    return '最近使用：$time';
  }

  @override
  String deviceExpires(String time) {
    return '到期：$time';
  }

  @override
  String get revokeDevice => '撤销设备';

  @override
  String get revokeCurrentDevice => '退出当前设备';

  @override
  String get revokeDeviceConfirmation => '撤销后，该设备将不能继续刷新登录状态。';

  @override
  String get revokeCurrentDeviceConfirmation => '退出当前设备后，需要重新输入用户名和密码才能连接服务器。';

  @override
  String get deviceRevoked => '登录设备已撤销';

  @override
  String get close => '关闭';

  @override
  String get retry => '重试';

  @override
  String get excelUseSessionTitleAsHeader => '抬头使用当前会话名';

  @override
  String get excelUseSessionTitleAsHeaderHint =>
      '开启后，Excel 抬头将直接使用当前会话名；会话名为空时继续使用抬头模板。';

  @override
  String get fileNameUseSessionTitle => '文件名使用当前会话名';

  @override
  String get fileNameUseSessionTitleHint =>
      '开启后，导出文件名将直接使用当前会话名；会话名为空时继续使用文件名模板。';

  @override
  String get themeColorPickerTitle => '选择主题颜色';

  @override
  String get themeColorPresets => '预设颜色';

  @override
  String get themeColorCustom => '自定义颜色';

  @override
  String get themeColorHex => 'HEX 颜色';

  @override
  String get themeColorHue => '色相';

  @override
  String get themeColorBlue => '蓝色';

  @override
  String get themeColorGreen => '绿色';

  @override
  String get themeColorRed => '红色';

  @override
  String get themeColorOrange => '橙色';

  @override
  String get themeColorPurple => '紫色';

  @override
  String get themeColorPink => '粉色';

  @override
  String get save => '保存';

  @override
  String get add => '添加';

  @override
  String get renameSession => '修改会话名';

  @override
  String get renameSessionTitle => '修改会话名';

  @override
  String get sessionTitleLabel => '会话名';

  @override
  String get renameCollaborationSessionHint => '只有会话所有者可以修改；保存后将同步给其他书记员和主控显示。';

  @override
  String get renameSessionSaved => '会话名已更新';

  @override
  String get renameCollaborationSessionSaved => '会话名已保存，正在同步给其他成员';

  @override
  String renameSessionFailed(String error) {
    return '修改会话名失败：$error';
  }

  @override
  String get renameSessionBlockedClosed => '已关闭的会话不能修改名称';

  @override
  String get renameSessionBlockedBusy => '协作操作进行中，暂时不能修改名称';

  @override
  String get renameSessionBlockedConflict => '请先解决会话冲突，再修改名称';

  @override
  String get renameSessionBlockedNotReady => '协作会话尚未就绪，暂时不能修改名称';

  @override
  String get renameSessionBlockedOwner => '只有会话所有者可以修改名称';

  @override
  String get dictionaryManagementTitle => '词库管理';

  @override
  String get dictionaryManagementHint => '管理点名时可搜索和一键复用的设备、天线、呼号与 QTH 内容。';

  @override
  String get deviceLibrary => '设备词库';

  @override
  String get antennaLibrary => '天线词库';

  @override
  String get callsignLibrary => '呼号词库';

  @override
  String get qthLibrary => 'QTH 词库';

  @override
  String libraryItemCount(int count) {
    return '共 $count 条';
  }

  @override
  String get importLibraryJson => '导入 JSON';

  @override
  String get expandAll => '展开全部';

  @override
  String get collapseAll => '折叠全部';

  @override
  String addLibraryItem(String name) {
    return '添加$name';
  }

  @override
  String searchLibrary(String name) {
    return '搜索$name';
  }

  @override
  String get libraryEmpty => '词库中还没有内容';

  @override
  String get noLibrarySearchResults => '没有匹配的词库内容';

  @override
  String libraryItemAdded(String value) {
    return '已添加：$value';
  }

  @override
  String libraryItemAlreadyExists(String value) {
    return '词库中已有“$value”';
  }

  @override
  String libraryItemAddFailed(String error) {
    return '添加失败：$error';
  }

  @override
  String get deleteLibraryItemTitle => '删除词库条目';

  @override
  String deleteLibraryItemConfirmation(String value, String name) {
    return '确定从$name中删除“$value”吗？';
  }

  @override
  String get deleteLibraryItemAction => '删除';

  @override
  String libraryItemDeleted(String value) {
    return '已删除：$value';
  }

  @override
  String libraryItemDeleteFailed(String error) {
    return '删除失败：$error';
  }

  @override
  String clearLibraryTitle(String name) {
    return '清空$name';
  }

  @override
  String clearLibraryConfirmation(String name, int count) {
    return '将删除$name中的全部 $count 条内容。此操作无法撤销，确定继续吗？';
  }

  @override
  String get clearLibraryAction => '全部清空';

  @override
  String libraryCleared(String name) {
    return '已清空$name';
  }

  @override
  String libraryClearFailed(String error) {
    return '清空失败：$error';
  }

  @override
  String get libraryImportEmpty => '文件中没有可导入的词库内容';

  @override
  String libraryImportCount(String name, int count) {
    return '$name $count 条';
  }

  @override
  String libraryImportSucceeded(String summary) {
    return '已导入：$summary';
  }

  @override
  String libraryImportFailed(String error) {
    return '导入词库失败：$error';
  }

  @override
  String get listSeparator => '，';

  @override
  String get fontPickerTitle => '选择字体';

  @override
  String get fontSearchHint => '搜索字体';

  @override
  String fontResultCount(int count) {
    return '共 $count 个字体';
  }

  @override
  String get fontSystemDefault => '系统默认';

  @override
  String get fontBuiltIn => '内置';

  @override
  String get fontPreview => '预览';

  @override
  String get fontPreviewSample => 'OpenLogTool · CQ CQ · 点名记录 123';

  @override
  String get localCollaborationOperationBusy => '另一项协作操作仍在进行，请等待结束后重试。';

  @override
  String get localCollaborationRequired => '当前会话已不是本机协作副本，请刷新页面后重试。';

  @override
  String get settingsCategoryAi => 'AI 辅助';

  @override
  String get aiSettingsTitle => 'AI 辅助识别';

  @override
  String get aiSettingsDescription => '配置可选的语音识别与字段提取服务。接口、模型与鉴权均由本机独立设置。';

  @override
  String get aiSettingsOptionalTitle => '可选且默认关闭';

  @override
  String get aiSettingsOptionalMessage =>
      '音频将直接发送到你配置的服务，不经过 OpenLogTool 协作服务器。识别结果只作为候选，不会自动覆盖书记员正在编辑的内容。';

  @override
  String get aiRecognitionEnabled => '启用 AI 辅助识别';

  @override
  String get aiRecognitionEnabledHint => '启用后可从点名工作台调用当前语音识别配置。';

  @override
  String get aiLocalReferenceContext => '结合本地词库与近期记录';

  @override
  String get aiLocalReferenceContextHint =>
      '默认开启。仅把与当前转写相近的少量词条和命中呼号的近期字段发送给文字模型，用于纠正呼号、设备、天线和 QTH；不会上传完整数据库。';

  @override
  String get aiRecognitionNeedsAsr => '请先添加并选择语音识别配置。';

  @override
  String get aiAsrStageTitle => '语音识别（ASR）';

  @override
  String get aiAsrStageDescription => '把音频转换为原始文本，三类接口格式可同时保存并随时切换。';

  @override
  String get aiExtractionStageTitle => '字段提取（可选）';

  @override
  String get aiExtractionStageDescription =>
      '把转写文本整理为呼号、RST、QTH 等候选字段；不配置时保留原始转写。';

  @override
  String get aiSupportedProtocols => '支持的接口格式';

  @override
  String get aiActiveProfile => '当前配置';

  @override
  String get aiNoProfileConfigured => '尚未添加配置';

  @override
  String get aiNoActiveProfile => '不使用';

  @override
  String get aiCredentialStatus => '密钥状态';

  @override
  String get aiCredentialNoProfile => '选择配置后显示本机密钥状态。';

  @override
  String get aiCredentialStoredLocally => 'API 密钥单独保存在系统安全存储中，不进入配置导出。';

  @override
  String get aiStatusNotConfigured => '未配置';

  @override
  String get aiStatusNoCredentialNeeded => '无需密钥';

  @override
  String get aiStatusCredentialReady => '密钥已保存';

  @override
  String get aiStatusCredentialMissing => '缺少密钥';

  @override
  String get aiAddProfile => '添加配置';

  @override
  String get aiEditProfile => '编辑配置';

  @override
  String get aiDeleteProfileTitle => '删除 AI 配置';

  @override
  String aiDeleteProfileMessage(String name) {
    return '确定删除“$name”及其本机密钥吗？';
  }

  @override
  String get aiProfileName => '配置名称';

  @override
  String get aiBaseUrl => 'API Base URL';

  @override
  String get aiModelName => '模型名称';

  @override
  String get aiProtocol => '接口格式';

  @override
  String get aiAuthentication => '鉴权方式';

  @override
  String get aiCredentialName => '请求头或查询参数名';

  @override
  String get aiCredentialPrefix => '密钥前缀（可留空）';

  @override
  String get aiApiKey => 'API 密钥';

  @override
  String get aiApiKeyNewHint => '可暂时留空，保存后将显示缺少密钥。';

  @override
  String get aiApiKeyExistingHint => '留空会保留当前密钥；更换接口目的地时需要重新填写。';

  @override
  String get aiRequestOptions => '高级请求选项（JSON）';

  @override
  String get aiRequestOptionsHint =>
      '通用 JSON 必须包含 requestTemplate；可设置 path、responsePath、body、fields、audioDataEncoding、includePrompt 等协议选项。这里的内容会随配置导出，请勿填写密钥。';

  @override
  String get aiRequiredField => '此项不能为空';

  @override
  String get aiRequestOptionsMustBeObject => '高级请求选项必须是 JSON 对象';

  @override
  String get aiJsonProtocolNeedsTemplate => '通用 JSON 格式必须包含 requestTemplate';

  @override
  String get aiInvalidJson => 'JSON 格式无效';

  @override
  String get aiInvalidBaseUrl => '请输入有效的 HTTP(S) API 地址';

  @override
  String aiSettingsFailed(String error) {
    return 'AI 设置操作失败：$error';
  }

  @override
  String get aiProtocolAudioTranscriptions => '音频转写 multipart';

  @override
  String get aiProtocolChatAudio => 'Chat input_audio';

  @override
  String get aiProtocolChatText => 'Chat 文本提取';

  @override
  String get aiProtocolGenericJson => '通用 JSON HTTP';

  @override
  String get aiAuthNone => '无需鉴权';

  @override
  String get aiAuthBearer => 'Authorization Bearer';

  @override
  String get aiAuthHeader => '自定义请求头';

  @override
  String get aiAuthQuery => '查询参数';

  @override
  String get aiWorkbenchTitle => 'AI 辅助识别';

  @override
  String get aiWorkbenchUnavailable => '当前记录为只读或正在处理，暂时不能识别。';

  @override
  String get aiReadyStatus => '点击麦克风录制一条点名内容。';

  @override
  String aiRecordingStatus(String elapsed) {
    return '正在录音 $elapsed';
  }

  @override
  String get aiLiveTranscriptTitle => '实时识别字段';

  @override
  String get aiLiveStructuredWaiting => '正在积累一段完整的点名内容，识别出的字段会显示在这里。';

  @override
  String get aiLiveStructuredUpdating => '正在根据目前的完整内容整理字段…';

  @override
  String aiLiveTranscriptionRetrying(String error) {
    return '实时识别暂时失败；停止录音后仍会用完整内容重试：$error';
  }

  @override
  String get aiRecognizingStatus => '正在识别并整理候选内容…';

  @override
  String get aiStartRecording => '录音';

  @override
  String get aiStopAndRecognize => '识别';

  @override
  String get aiMicrophonePermissionDenied => '未获得麦克风权限。';

  @override
  String aiRecordingFailed(String error) {
    return '录音失败：$error';
  }

  @override
  String aiRecognitionFailed(String error) {
    return '识别失败：$error';
  }

  @override
  String get aiReviewTitle => '确认 AI 候选内容';

  @override
  String get aiTranscriptTitle => '原始转写';

  @override
  String get aiCopyTranscript => '复制转写';

  @override
  String get aiTranscriptCopied => '已复制转写内容。';

  @override
  String get aiNoStructuredCandidates => '服务没有返回结构化字段，你仍可查看或复制上方转写。';

  @override
  String get aiCandidateRecord => '候选记录';

  @override
  String aiCandidateNumber(int number) {
    return '候选 $number';
  }

  @override
  String get aiCandidateHint => '空字段会默认勾选；替换已有内容必须由你手动勾选确认。';

  @override
  String get aiApplySelected => '应用所选字段';

  @override
  String aiCandidatesApplied(int count) {
    return '已应用 $count 个候选字段。';
  }

  @override
  String get aiCandidatesStale => '录音后记录内容已经变化，这些候选已不能安全应用。';

  @override
  String aiApplyFailed(String error) {
    return '无法应用 AI 候选：$error';
  }

  @override
  String aiWillReplaceValue(String value) {
    return '将替换：$value';
  }

  @override
  String get aiWillFillEmpty => '将填入空字段';

  @override
  String get aiReplacementNeedsConfirmation => '勾选后确认替换';

  @override
  String get aiCandidateUnchanged => '内容已经一致';

  @override
  String get aiCandidateStale => '录音后该字段已发生变化';

  @override
  String get aiCandidateBeingEdited => '该字段正在编辑或输入法组词';

  @override
  String get aiCandidateLocked => '另一位协作者正在编辑该字段';

  @override
  String get aiCandidateReadOnly => '当前记录为只读';

  @override
  String get aiCandidateBusy => '当前记录正在处理其他操作';

  @override
  String get aiCandidateInvalid => '不支持或无效的候选内容';

  @override
  String get textAssistantTitle => '文字助手';

  @override
  String get textAssistantDescription => '使用简单的文字模型配置完成字段整理、填写建议和词库维护。';

  @override
  String get textAssistantPrivacyTitle => '由你选择的模型服务处理';

  @override
  String get textAssistantPrivacyMessage =>
      '需要时会向所选服务发送当前字段文本或聚合后的历史词条，不会发送完整记录、备注或时间；API 密钥仅用于请求鉴权并安全保存在本机。';

  @override
  String get textAssistantEnabled => '启用文字助手';

  @override
  String get textAssistantNotConfigured => '尚未配置文字助手';

  @override
  String get textAssistantInlineSuggestions => '填写时显示 AI 规范建议';

  @override
  String get textAssistantInlineSuggestionsHint =>
      '设备、天线、QTH、高度和功率停止输入约 300 毫秒后，显示一条快速建议。';

  @override
  String get textAssistantTest => '测试连接';

  @override
  String get textAssistantConfigure => '配置文字助手';

  @override
  String get textAssistantEdit => '修改配置';

  @override
  String get textAssistantConfigureTitle => '配置文字助手';

  @override
  String get textAssistantProvider => '服务类型';

  @override
  String get textAssistantProviderOpenAi => 'OpenAI（Responses API）';

  @override
  String get textAssistantProviderAnthropic => 'Anthropic';

  @override
  String get textAssistantProviderCompatible =>
      'OpenAI 兼容（旧版 Chat Completions）';

  @override
  String get textAssistantTestSucceeded => '文字助手连接正常。';

  @override
  String get textAssistantSuggestionLabel => 'AI 规范建议';

  @override
  String get aiDictionaryRecognize => '从历史识别';

  @override
  String get aiDictionaryOptimize => 'AI 优化词库';

  @override
  String get aiDictionaryNeedsAssistant => '请先在设置中配置并启用文字助手。';

  @override
  String get aiDictionaryNoSuggestions => '没有发现需要处理的词条。';

  @override
  String aiDictionaryApplied(int count) {
    return '已应用 $count 条词库建议。';
  }

  @override
  String aiDictionaryFailed(String error) {
    return '词库 AI 操作失败：$error';
  }

  @override
  String get aiDictionaryOptimizing => '正在优化词库';

  @override
  String get aiDictionaryRecognizing => '正在识别历史词条';

  @override
  String get aiDictionaryPreparing => '正在整理本地数据…';

  @override
  String aiDictionaryProgress(int completed, int total) {
    return '已完成 $completed / $total';
  }

  @override
  String get aiDictionaryReviewTitle => '确认词库建议';

  @override
  String aiDictionaryReviewHint(int recordCount) {
    return '根据 $recordCount 条历史记录及当前词库生成。只有勾选的内容会写入。';
  }

  @override
  String get aiDictionaryActionAdd => '新增';

  @override
  String get aiDictionaryActionRename => '改名';

  @override
  String get aiDictionaryActionMerge => '合并';

  @override
  String aiDictionaryUsedCount(int count) {
    return '历史出现 $count 次';
  }

  @override
  String get aiDictionaryMergeWarning => '合并会从词库隐藏源词条，默认不勾选；不会改写历史记录。';

  @override
  String get aiDictionaryApplySelected => '应用所选建议';
}

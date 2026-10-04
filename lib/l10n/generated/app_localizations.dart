import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('zh', 'CN'),
    Locale('en'),
    Locale('en', 'US'),
    Locale('zh')
  ];

  /// No description provided for @shareSessionsTitle.
  ///
  /// In zh, this message translates to:
  /// **'共享会话'**
  String get shareSessionsTitle;

  /// No description provided for @shareSelected.
  ///
  /// In zh, this message translates to:
  /// **'多选会话'**
  String get shareSelected;

  /// No description provided for @shareAll.
  ///
  /// In zh, this message translates to:
  /// **'持续共享全部'**
  String get shareAll;

  /// No description provided for @shareAllHint.
  ///
  /// In zh, this message translates to:
  /// **'包含当前和以后新建的所有本人会话。新建或离线修改的本地会话完成云同步后，对方即可看到。'**
  String get shareAllHint;

  /// No description provided for @shareSelectedHint.
  ///
  /// In zh, this message translates to:
  /// **'只共享勾选的本人会话；不会自动包含以后新建的会话，也不会转共享别人的记录。'**
  String get shareSelectedHint;

  /// No description provided for @shareViewOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅查看'**
  String get shareViewOnly;

  /// No description provided for @shareEditLogs.
  ///
  /// In zh, this message translates to:
  /// **'允许新增、修改记录'**
  String get shareEditLogs;

  /// No description provided for @shareDeleteLogs.
  ///
  /// In zh, this message translates to:
  /// **'另外允许删除记录'**
  String get shareDeleteLogs;

  /// No description provided for @sharePermissionHint.
  ///
  /// In zh, this message translates to:
  /// **'删除整个会话、结束会话和转授权仍由所有者控制；已结束的会话只能查看。'**
  String get sharePermissionHint;

  /// No description provided for @shareRecipientHint.
  ///
  /// In zh, this message translates to:
  /// **'选择好友，或输入同一服务器上的用户名'**
  String get shareRecipientHint;

  /// No description provided for @shareSend.
  ///
  /// In zh, this message translates to:
  /// **'发送共享邀请'**
  String get shareSend;

  /// No description provided for @shareManage.
  ///
  /// In zh, this message translates to:
  /// **'已发出的共享'**
  String get shareManage;

  /// No description provided for @shareRevoke.
  ///
  /// In zh, this message translates to:
  /// **'撤销共享'**
  String get shareRevoke;

  /// No description provided for @shareRevokeHint.
  ///
  /// In zh, this message translates to:
  /// **'撤销后，对方将无法继续通过这项授权查看或操作你的会话。已加入的独立协作不受影响。'**
  String get shareRevokeHint;

  /// No description provided for @shareSaved.
  ///
  /// In zh, this message translates to:
  /// **'共享设置已保存'**
  String get shareSaved;

  /// No description provided for @shareSyncFirst.
  ///
  /// In zh, this message translates to:
  /// **'请先在个人云同步中确认配对或解决冲突，再重试共享。不会自动覆盖云端数据。'**
  String get shareSyncFirst;

  /// No description provided for @shareSyncLocal.
  ///
  /// In zh, this message translates to:
  /// **'同步本机记录'**
  String get shareSyncLocal;

  /// No description provided for @shareNeedsSelection.
  ///
  /// In zh, this message translates to:
  /// **'请选择接收人，并至少勾选一个会话；也可以选择持续共享全部。'**
  String get shareNeedsSelection;

  /// No description provided for @shareAccessChanged.
  ///
  /// In zh, this message translates to:
  /// **'账号或共享权限已变化，请关闭后重新打开。'**
  String get shareAccessChanged;

  /// No description provided for @shareConflict.
  ///
  /// In zh, this message translates to:
  /// **'记录已被其他人修改，请刷新后重新编辑，避免覆盖对方的修改。'**
  String get shareConflict;

  /// No description provided for @shareLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'共享数据加载失败，请检查网络后重试。'**
  String get shareLoadFailed;

  /// No description provided for @shareOperationFailed.
  ///
  /// In zh, this message translates to:
  /// **'操作未完成，请检查连接和当前权限后重试。'**
  String get shareOperationFailed;

  /// No description provided for @shareExisting.
  ///
  /// In zh, this message translates to:
  /// **'已向该用户发出共享，请在下面的共享管理中修改。'**
  String get shareExisting;

  /// No description provided for @shareAddRecord.
  ///
  /// In zh, this message translates to:
  /// **'新增记录'**
  String get shareAddRecord;

  /// No description provided for @shareRecordsHint.
  ///
  /// In zh, this message translates to:
  /// **'正在浏览共享记录，不会切换你当前的记录会话。'**
  String get shareRecordsHint;

  /// No description provided for @shareUpgradeRequired.
  ///
  /// In zh, this message translates to:
  /// **'请先升级服务器以使用多选共享与操作授权。'**
  String get shareUpgradeRequired;

  /// No description provided for @shareSelectVisible.
  ///
  /// In zh, this message translates to:
  /// **'全选搜索结果'**
  String get shareSelectVisible;

  /// No description provided for @shareClearSelection.
  ///
  /// In zh, this message translates to:
  /// **'清空选择'**
  String get shareClearSelection;

  /// No description provided for @socialSearch.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get socialSearch;

  /// No description provided for @socialSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'输入用户名或注册呼号'**
  String get socialSearchHint;

  /// No description provided for @socialSearchScope.
  ///
  /// In zh, this message translates to:
  /// **'仅搜索当前服务器上的用户，不会搜索或公开个人记录。'**
  String get socialSearchScope;

  /// No description provided for @socialSearchStart.
  ///
  /// In zh, this message translates to:
  /// **'输入至少 2 个字符，搜索后选择要添加的人。'**
  String get socialSearchStart;

  /// No description provided for @socialSearchEmpty.
  ///
  /// In zh, this message translates to:
  /// **'没有找到匹配的用户，请确认对方在同一服务器注册。'**
  String get socialSearchEmpty;

  /// No description provided for @socialSearchMore.
  ///
  /// In zh, this message translates to:
  /// **'结果较多，请输入更完整的用户名。'**
  String get socialSearchMore;

  /// No description provided for @socialSearchFailed.
  ///
  /// In zh, this message translates to:
  /// **'搜索失败，请检查连接后重试。'**
  String get socialSearchFailed;

  /// No description provided for @socialSearchUpgrade.
  ///
  /// In zh, this message translates to:
  /// **'此服务器尚不支持用户搜索，请先升级服务端。'**
  String get socialSearchUpgrade;

  /// No description provided for @socialSearchRateLimited.
  ///
  /// In zh, this message translates to:
  /// **'搜索太频繁，请稍后再试。'**
  String get socialSearchRateLimited;

  /// No description provided for @socialAlreadyFriend.
  ///
  /// In zh, this message translates to:
  /// **'已是好友'**
  String get socialAlreadyFriend;

  /// No description provided for @socialRequestSent.
  ///
  /// In zh, this message translates to:
  /// **'申请已发送'**
  String get socialRequestSent;

  /// No description provided for @socialRequestIncoming.
  ///
  /// In zh, this message translates to:
  /// **'对方已申请加你为好友'**
  String get socialRequestIncoming;

  /// No description provided for @socialRequestClosed.
  ///
  /// In zh, this message translates to:
  /// **'申请已结束'**
  String get socialRequestClosed;

  /// No description provided for @socialJoinMode.
  ///
  /// In zh, this message translates to:
  /// **'加入方式'**
  String get socialJoinMode;

  /// No description provided for @socialJoinInviteOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅邀请'**
  String get socialJoinInviteOnly;

  /// No description provided for @socialJoinApproval.
  ///
  /// In zh, this message translates to:
  /// **'好友申请，审批后加入'**
  String get socialJoinApproval;

  /// No description provided for @socialJoinDirect.
  ///
  /// In zh, this message translates to:
  /// **'好友直接加入'**
  String get socialJoinDirect;

  /// No description provided for @socialDirectRole.
  ///
  /// In zh, this message translates to:
  /// **'直接加入的新成员权限'**
  String get socialDirectRole;

  /// No description provided for @socialDirectJoinWarning.
  ///
  /// In zh, this message translates to:
  /// **'开启后，同一服务器上的好友无需审批即可加入，并查看这个会话已有和新增的全部记录。仅影响此会话，其他会话仍然私有。'**
  String get socialDirectJoinWarning;

  /// No description provided for @socialDirectJoinExistingHint.
  ///
  /// In zh, this message translates to:
  /// **'此权限只适用于之后直接加入的成员，已有成员的权限不变。被移出的成员需要重新邀请或审批。'**
  String get socialDirectJoinExistingHint;

  /// No description provided for @socialDirectJoinConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确认开放'**
  String get socialDirectJoinConfirm;

  /// No description provided for @socialDirectJoin.
  ///
  /// In zh, this message translates to:
  /// **'直接加入'**
  String get socialDirectJoin;

  /// No description provided for @socialDirectJoinRemoved.
  ///
  /// In zh, this message translates to:
  /// **'你已被移出此会话，请联系负责人重新邀请。'**
  String get socialDirectJoinRemoved;

  /// No description provided for @detailsType.
  ///
  /// In zh, this message translates to:
  /// **'记录方式'**
  String get detailsType;

  /// No description provided for @detailsLocal.
  ///
  /// In zh, this message translates to:
  /// **'本地记录 · 无需服务器'**
  String get detailsLocal;

  /// No description provided for @detailsShared.
  ///
  /// In zh, this message translates to:
  /// **'共同记录 · 保留本机副本'**
  String get detailsShared;

  /// No description provided for @detailsStatus.
  ///
  /// In zh, this message translates to:
  /// **'会话状态'**
  String get detailsStatus;

  /// No description provided for @detailsRecords.
  ///
  /// In zh, this message translates to:
  /// **'本机已保存记录'**
  String get detailsRecords;

  /// No description provided for @detailsCreated.
  ///
  /// In zh, this message translates to:
  /// **'创建时间'**
  String get detailsCreated;

  /// No description provided for @detailsUpdated.
  ///
  /// In zh, this message translates to:
  /// **'更新时间'**
  String get detailsUpdated;

  /// No description provided for @detailsEnded.
  ///
  /// In zh, this message translates to:
  /// **'结束时间'**
  String get detailsEnded;

  /// No description provided for @detailsId.
  ///
  /// In zh, this message translates to:
  /// **'会话 ID'**
  String get detailsId;

  /// No description provided for @sessionPeopleTitle.
  ///
  /// In zh, this message translates to:
  /// **'参与者与邀请'**
  String get sessionPeopleTitle;

  /// No description provided for @sessionPeopleHint.
  ///
  /// In zh, this message translates to:
  /// **'在这里选择谁可以加入、处理邀请和申请。好友默认不开放记录；公开页面单独管理。'**
  String get sessionPeopleHint;

  /// No description provided for @sessionPendingRequests.
  ///
  /// In zh, this message translates to:
  /// **'本会话的邀请与申请'**
  String get sessionPendingRequests;

  /// No description provided for @legacyInviteCodes.
  ///
  /// In zh, this message translates to:
  /// **'邀请码（兼容旧版）'**
  String get legacyInviteCodes;

  /// No description provided for @collaborationTechnicalDetails.
  ///
  /// In zh, this message translates to:
  /// **'连接与诊断详情'**
  String get collaborationTechnicalDetails;

  /// No description provided for @collaborationOverviewOnline.
  ///
  /// In zh, this message translates to:
  /// **'已连接，正在与参与者同步记录。'**
  String get collaborationOverviewOnline;

  /// No description provided for @collaborationOverviewOffline.
  ///
  /// In zh, this message translates to:
  /// **'连接暂时不可用，已有记录仍保留在本机。'**
  String get collaborationOverviewOffline;

  /// No description provided for @collaborationOverviewAttention.
  ///
  /// In zh, this message translates to:
  /// **'有待处理的记录或同步问题，请打开“同步”查看。'**
  String get collaborationOverviewAttention;

  /// No description provided for @collaborationOverviewPending.
  ///
  /// In zh, this message translates to:
  /// **'已保存到本机，{count} 项修改等待同步。'**
  String collaborationOverviewPending(int count);

  /// No description provided for @historySessionCollaborationCloseRequired.
  ///
  /// In zh, this message translates to:
  /// **'这是共同记录，请在“协作与成员”中结束共同记录或离开协作；不能把它作为本地会话结束。'**
  String get historySessionCollaborationCloseRequired;

  /// No description provided for @collaborationLifecycleHint.
  ///
  /// In zh, this message translates to:
  /// **'切换页面或暂时断网不会退出协作。发起人可以结束共同记录，参与者可以离开协作；已有记录会保留。'**
  String get collaborationLifecycleHint;

  /// No description provided for @hubLocalStart.
  ///
  /// In zh, this message translates to:
  /// **'新建会话即可开始记录，无需服务器或账号。记录保存在本机，可随时查看和导出。'**
  String get hubLocalStart;

  /// No description provided for @hubLocalHint.
  ///
  /// In zh, this message translates to:
  /// **'本地记录可独立使用；同步与多人协作按需启用。'**
  String get hubLocalHint;

  /// No description provided for @hubOptionalOnline.
  ///
  /// In zh, this message translates to:
  /// **'同步与协作（可选）'**
  String get hubOptionalOnline;

  /// No description provided for @hubOptionalOnlineHint.
  ///
  /// In zh, this message translates to:
  /// **'需要多设备同步或与搭档共同记录时，再连接服务器。'**
  String get hubOptionalOnlineHint;

  /// No description provided for @hubConfigureServer.
  ///
  /// In zh, this message translates to:
  /// **'设置可选服务器'**
  String get hubConfigureServer;

  /// No description provided for @hubOnlineConnected.
  ///
  /// In zh, this message translates to:
  /// **'好友与协作使用当前服务器，本地记录仍可独立使用。'**
  String get hubOnlineConnected;

  /// No description provided for @hubEnableCollaboration.
  ///
  /// In zh, this message translates to:
  /// **'邀请搭档一起记录'**
  String get hubEnableCollaboration;

  /// No description provided for @hubConfirmUpload.
  ///
  /// In zh, this message translates to:
  /// **'上传此会话并开启协作'**
  String get hubConfirmUpload;

  /// No description provided for @hubUploadExplanation.
  ///
  /// In zh, this message translates to:
  /// **'这会把当前会话及其中已有的记录上传到下面的服务器，并开始协作同步。此操作只上传当前会话，不改变其他会话的同步设置。会话仍为私有，之后再选择要邀请的好友；此操作不会发布公开页面。'**
  String get hubUploadExplanation;

  /// No description provided for @hubContextChanged.
  ///
  /// In zh, this message translates to:
  /// **'服务器、账号或当前会话已切换，请关闭后重新操作。'**
  String get hubContextChanged;

  /// No description provided for @hubAlreadyMember.
  ///
  /// In zh, this message translates to:
  /// **'对方已经加入这个会话，可在参与者管理中查看。'**
  String get hubAlreadyMember;

  /// No description provided for @hubInvitationHint.
  ///
  /// In zh, this message translates to:
  /// **'对方接受后才能查看此会话的记录，不会开放你的其他会话。'**
  String get hubInvitationHint;

  /// No description provided for @hubContinueRecording.
  ///
  /// In zh, this message translates to:
  /// **'继续记录'**
  String get hubContinueRecording;

  /// No description provided for @hubViewRecords.
  ///
  /// In zh, this message translates to:
  /// **'查看记录'**
  String get hubViewRecords;

  /// No description provided for @hubSessionDetails.
  ///
  /// In zh, this message translates to:
  /// **'会话详细信息'**
  String get hubSessionDetails;

  /// No description provided for @hubHistoryHint.
  ///
  /// In zh, this message translates to:
  /// **'查看本机已有记录。“已结束”只按会话状态筛选，不代表公开归档。'**
  String get hubHistoryHint;

  /// No description provided for @hubAllRecords.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get hubAllRecords;

  /// No description provided for @hubMyRecords.
  ///
  /// In zh, this message translates to:
  /// **'我的记录'**
  String get hubMyRecords;

  /// No description provided for @hubTogetherRecords.
  ///
  /// In zh, this message translates to:
  /// **'共同记录'**
  String get hubTogetherRecords;

  /// No description provided for @hubEndedRecords.
  ///
  /// In zh, this message translates to:
  /// **'已结束'**
  String get hubEndedRecords;

  /// No description provided for @socialTitle.
  ///
  /// In zh, this message translates to:
  /// **'好友与邀请'**
  String get socialTitle;

  /// No description provided for @socialAddFriend.
  ///
  /// In zh, this message translates to:
  /// **'添加好友'**
  String get socialAddFriend;

  /// No description provided for @socialFriends.
  ///
  /// In zh, this message translates to:
  /// **'好友'**
  String get socialFriends;

  /// No description provided for @socialMessages.
  ///
  /// In zh, this message translates to:
  /// **'消息'**
  String get socialMessages;

  /// No description provided for @socialSessions.
  ///
  /// In zh, this message translates to:
  /// **'会话'**
  String get socialSessions;

  /// No description provided for @socialIntro.
  ///
  /// In zh, this message translates to:
  /// **'添加搭档为好友，再邀请他们一起点名。好友关系不会自动开放个人记录。'**
  String get socialIntro;

  /// No description provided for @socialUsername.
  ///
  /// In zh, this message translates to:
  /// **'对方的用户名（注册时使用的呼号）'**
  String get socialUsername;

  /// No description provided for @socialSend.
  ///
  /// In zh, this message translates to:
  /// **'发送申请'**
  String get socialSend;

  /// No description provided for @socialInvite.
  ///
  /// In zh, this message translates to:
  /// **'邀请参与'**
  String get socialInvite;

  /// No description provided for @socialApply.
  ///
  /// In zh, this message translates to:
  /// **'申请加入'**
  String get socialApply;

  /// No description provided for @socialAccept.
  ///
  /// In zh, this message translates to:
  /// **'接受'**
  String get socialAccept;

  /// No description provided for @socialReject.
  ///
  /// In zh, this message translates to:
  /// **'拒绝'**
  String get socialReject;

  /// No description provided for @socialPending.
  ///
  /// In zh, this message translates to:
  /// **'等待对方处理'**
  String get socialPending;

  /// No description provided for @socialAccepted.
  ///
  /// In zh, this message translates to:
  /// **'已接受'**
  String get socialAccepted;

  /// No description provided for @socialView.
  ///
  /// In zh, this message translates to:
  /// **'只能查看'**
  String get socialView;

  /// No description provided for @socialEdit.
  ///
  /// In zh, this message translates to:
  /// **'共同记录'**
  String get socialEdit;

  /// No description provided for @socialOpen.
  ///
  /// In zh, this message translates to:
  /// **'打开会话'**
  String get socialOpen;

  /// No description provided for @socialPrivate.
  ///
  /// In zh, this message translates to:
  /// **'仅邀请可加入'**
  String get socialPrivate;

  /// No description provided for @socialDiscoverable.
  ///
  /// In zh, this message translates to:
  /// **'好友可见，可申请加入'**
  String get socialDiscoverable;

  /// No description provided for @socialVisibilityHint.
  ///
  /// In zh, this message translates to:
  /// **'好友可见的会话会出现在这里。加入方式由负责人设置，成为成员后才能查看记录。'**
  String get socialVisibilityHint;

  /// No description provided for @socialNoFriends.
  ///
  /// In zh, this message translates to:
  /// **'还没有好友，搜索搭档的用户名或注册呼号来添加。'**
  String get socialNoFriends;

  /// No description provided for @socialNoMessages.
  ///
  /// In zh, this message translates to:
  /// **'暂无邀请或申请'**
  String get socialNoMessages;

  /// No description provided for @socialNoSessions.
  ///
  /// In zh, this message translates to:
  /// **'暂无好友开放的会话。你也可以把当前会话用于协作。'**
  String get socialNoSessions;

  /// No description provided for @socialPublish.
  ///
  /// In zh, this message translates to:
  /// **'开启当前会话协作'**
  String get socialPublish;

  /// No description provided for @socialRemove.
  ///
  /// In zh, this message translates to:
  /// **'删除好友'**
  String get socialRemove;

  /// No description provided for @socialRemoveHint.
  ///
  /// In zh, this message translates to:
  /// **'会取消彼此待处理的邀请和申请。已加入的会话成员由会话负责人单独管理。'**
  String get socialRemoveHint;

  /// No description provided for @socialBlock.
  ///
  /// In zh, this message translates to:
  /// **'屏蔽'**
  String get socialBlock;

  /// No description provided for @socialUnblock.
  ///
  /// In zh, this message translates to:
  /// **'取消屏蔽'**
  String get socialUnblock;

  /// No description provided for @socialBlocked.
  ///
  /// In zh, this message translates to:
  /// **'已屏蔽'**
  String get socialBlocked;

  /// No description provided for @socialDone.
  ///
  /// In zh, this message translates to:
  /// **'操作已完成'**
  String get socialDone;

  /// No description provided for @socialFriendRequest.
  ///
  /// In zh, this message translates to:
  /// **'好友申请'**
  String get socialFriendRequest;

  /// No description provided for @socialInvitation.
  ///
  /// In zh, this message translates to:
  /// **'会话邀请'**
  String get socialInvitation;

  /// No description provided for @socialApplication.
  ///
  /// In zh, this message translates to:
  /// **'加入申请'**
  String get socialApplication;

  /// No description provided for @socialSent.
  ///
  /// In zh, this message translates to:
  /// **'我发出的'**
  String get socialSent;

  /// No description provided for @socialReceived.
  ///
  /// In zh, this message translates to:
  /// **'收到的'**
  String get socialReceived;

  /// No description provided for @socialManage.
  ///
  /// In zh, this message translates to:
  /// **'管理参与者'**
  String get socialManage;

  /// No description provided for @socialConnect.
  ///
  /// In zh, this message translates to:
  /// **'连接服务器并登录后，即可添加好友。'**
  String get socialConnect;

  /// No description provided for @socialUpgrade.
  ///
  /// In zh, this message translates to:
  /// **'此服务器尚不支持好友功能，请更新服务器。'**
  String get socialUpgrade;

  /// No description provided for @socialLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'暂时无法刷新，请重试。'**
  String get socialLoadFailed;

  /// No description provided for @socialChooseFriend.
  ///
  /// In zh, this message translates to:
  /// **'选择好友'**
  String get socialChooseFriend;

  /// No description provided for @socialErrorUser.
  ///
  /// In zh, this message translates to:
  /// **'没有找到这个用户名。请确认对方已在同一服务器注册。'**
  String get socialErrorUser;

  /// No description provided for @socialErrorFriends.
  ///
  /// In zh, this message translates to:
  /// **'请先添加对方为好友。'**
  String get socialErrorFriends;

  /// No description provided for @socialErrorClosed.
  ///
  /// In zh, this message translates to:
  /// **'这条申请已处理或已过期，请刷新。'**
  String get socialErrorClosed;

  /// No description provided for @socialErrorSelf.
  ///
  /// In zh, this message translates to:
  /// **'不能添加自己为好友。'**
  String get socialErrorSelf;

  /// No description provided for @socialErrorBlocked.
  ///
  /// In zh, this message translates to:
  /// **'目前无法向这个用户发送请求。'**
  String get socialErrorBlocked;

  /// No description provided for @socialServerLink.
  ///
  /// In zh, this message translates to:
  /// **'复制服务器连接信息'**
  String get socialServerLink;

  /// No description provided for @socialServerLinkHint.
  ///
  /// In zh, this message translates to:
  /// **'可粘贴服务器地址或服务器网页链接，连接后再登录。'**
  String get socialServerLinkHint;

  /// No description provided for @socialLegacy.
  ///
  /// In zh, this message translates to:
  /// **'旧版共享'**
  String get socialLegacy;

  /// No description provided for @navWorkbench.
  ///
  /// In zh, this message translates to:
  /// **'点名台'**
  String get navWorkbench;

  /// No description provided for @navSessions.
  ///
  /// In zh, this message translates to:
  /// **'会话'**
  String get navSessions;

  /// No description provided for @navData.
  ///
  /// In zh, this message translates to:
  /// **'数据'**
  String get navData;

  /// No description provided for @navSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get navSettings;

  /// No description provided for @workbenchNoSession.
  ///
  /// In zh, this message translates to:
  /// **'尚未开始点名'**
  String get workbenchNoSession;

  /// No description provided for @workbenchLocalRecording.
  ///
  /// In zh, this message translates to:
  /// **'单机记录'**
  String get workbenchLocalRecording;

  /// No description provided for @collaborationLocalOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅本地'**
  String get collaborationLocalOnly;

  /// No description provided for @collaborationPublishing.
  ///
  /// In zh, this message translates to:
  /// **'发布中'**
  String get collaborationPublishing;

  /// No description provided for @collaborationJoining.
  ///
  /// In zh, this message translates to:
  /// **'加入中'**
  String get collaborationJoining;

  /// No description provided for @collaborationSnapshotting.
  ///
  /// In zh, this message translates to:
  /// **'下载快照'**
  String get collaborationSnapshotting;

  /// No description provided for @collaborationCatchingUp.
  ///
  /// In zh, this message translates to:
  /// **'追赶更新'**
  String get collaborationCatchingUp;

  /// No description provided for @collaborationReady.
  ///
  /// In zh, this message translates to:
  /// **'已连接'**
  String get collaborationReady;

  /// No description provided for @collaborationResyncing.
  ///
  /// In zh, this message translates to:
  /// **'重新同步'**
  String get collaborationResyncing;

  /// No description provided for @collaborationRevoked.
  ///
  /// In zh, this message translates to:
  /// **'权限已撤销'**
  String get collaborationRevoked;

  /// No description provided for @collaborationFailed.
  ///
  /// In zh, this message translates to:
  /// **'同步失败'**
  String get collaborationFailed;

  /// No description provided for @collaborationState.
  ///
  /// In zh, this message translates to:
  /// **'协作 {state}'**
  String collaborationState(String state);

  /// No description provided for @pendingSyncCount.
  ///
  /// In zh, this message translates to:
  /// **'待同步 {count}'**
  String pendingSyncCount(int count);

  /// No description provided for @conflictCount.
  ///
  /// In zh, this message translates to:
  /// **'冲突 {count}'**
  String conflictCount(int count);

  /// No description provided for @localSessionTooltip.
  ///
  /// In zh, this message translates to:
  /// **'当前为本地会话'**
  String get localSessionTooltip;

  /// No description provided for @collaborationStatusTooltip.
  ///
  /// In zh, this message translates to:
  /// **'协作状态 {state}，待同步 {count}'**
  String collaborationStatusTooltip(String state, int count);

  /// No description provided for @currentRecord.
  ///
  /// In zh, this message translates to:
  /// **'当前记录'**
  String get currentRecord;

  /// No description provided for @startNewRecord.
  ///
  /// In zh, this message translates to:
  /// **'开始新记录'**
  String get startNewRecord;

  /// No description provided for @newRecordName.
  ///
  /// In zh, this message translates to:
  /// **'新记录名称'**
  String get newRecordName;

  /// No description provided for @newRecordNameHint.
  ///
  /// In zh, this message translates to:
  /// **'输入本次记录名称（可留空）'**
  String get newRecordNameHint;

  /// No description provided for @automaticName.
  ///
  /// In zh, this message translates to:
  /// **'自动命名'**
  String get automaticName;

  /// No description provided for @newRecordStarted.
  ///
  /// In zh, this message translates to:
  /// **'已开始新记录：{name}'**
  String newRecordStarted(String name);

  /// No description provided for @createNewRecordFailed.
  ///
  /// In zh, this message translates to:
  /// **'创建新记录失败：{error}'**
  String createNewRecordFailed(String error);

  /// No description provided for @currentOrdinal.
  ///
  /// In zh, this message translates to:
  /// **'当前第 {ordinal} 位'**
  String currentOrdinal(int ordinal);

  /// No description provided for @sessionsTitle.
  ///
  /// In zh, this message translates to:
  /// **'会话'**
  String get sessionsTitle;

  /// No description provided for @sessionsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'管理本次点名、协作书记员和主控显示设备。'**
  String get sessionsSubtitle;

  /// No description provided for @noCurrentSession.
  ///
  /// In zh, this message translates to:
  /// **'当前没有点名会话'**
  String get noCurrentSession;

  /// No description provided for @noCurrentSessionHint.
  ///
  /// In zh, this message translates to:
  /// **'创建一个点名会话，或加入协作后即可开始记录。'**
  String get noCurrentSessionHint;

  /// No description provided for @workbenchNoSessionHint.
  ///
  /// In zh, this message translates to:
  /// **'请先到会话页新建会话，或加入协作后再开始记录。'**
  String get workbenchNoSessionHint;

  /// No description provided for @createOrJoinSessionFirst.
  ///
  /// In zh, this message translates to:
  /// **'请先新建会话或加入协作'**
  String get createOrJoinSessionFirst;

  /// No description provided for @goCreateSession.
  ///
  /// In zh, this message translates to:
  /// **'去新建会话'**
  String get goCreateSession;

  /// No description provided for @sessionActive.
  ///
  /// In zh, this message translates to:
  /// **'进行中'**
  String get sessionActive;

  /// No description provided for @sessionClosed.
  ///
  /// In zh, this message translates to:
  /// **'已结束'**
  String get sessionClosed;

  /// No description provided for @savedPositions.
  ///
  /// In zh, this message translates to:
  /// **'{count} 位已保存'**
  String savedPositions(int count);

  /// No description provided for @localSession.
  ///
  /// In zh, this message translates to:
  /// **'本地会话'**
  String get localSession;

  /// No description provided for @manageCollaboration.
  ///
  /// In zh, this message translates to:
  /// **'协作与成员'**
  String get manageCollaboration;

  /// No description provided for @openLiveShare.
  ///
  /// In zh, this message translates to:
  /// **'Live Share 公开页面'**
  String get openLiveShare;

  /// No description provided for @enterControllerScreen.
  ///
  /// In zh, this message translates to:
  /// **'进入主控屏'**
  String get enterControllerScreen;

  /// No description provided for @localControllerDisplay.
  ///
  /// In zh, this message translates to:
  /// **'本机主控显示'**
  String get localControllerDisplay;

  /// No description provided for @localControllerDisplayHint.
  ///
  /// In zh, this message translates to:
  /// **'书记员继续使用主窗口，主控内容在独立只读窗口显示。'**
  String get localControllerDisplayHint;

  /// No description provided for @openFloatingWindow.
  ///
  /// In zh, this message translates to:
  /// **'打开悬浮窗'**
  String get openFloatingWindow;

  /// No description provided for @openControllerTab.
  ///
  /// In zh, this message translates to:
  /// **'打开主控屏标签页'**
  String get openControllerTab;

  /// No description provided for @openControllerInApp.
  ///
  /// In zh, this message translates to:
  /// **'当前标签页打开主控屏'**
  String get openControllerInApp;

  /// No description provided for @openSecondDisplayWindow.
  ///
  /// In zh, this message translates to:
  /// **'打开第二屏窗口'**
  String get openSecondDisplayWindow;

  /// No description provided for @historySessions.
  ///
  /// In zh, this message translates to:
  /// **'历史会话'**
  String get historySessions;

  /// No description provided for @historySessionsHint.
  ///
  /// In zh, this message translates to:
  /// **'查看和切换过去的点名会话；已关闭会话将以只读方式打开。'**
  String get historySessionsHint;

  /// No description provided for @historySessionsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无历史会话'**
  String get historySessionsEmpty;

  /// No description provided for @historySessionsLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载历史会话失败：{error}'**
  String historySessionsLoadFailed(String error);

  /// No description provided for @historySessionOpen.
  ///
  /// In zh, this message translates to:
  /// **'打开会话'**
  String get historySessionOpen;

  /// No description provided for @historySessionCurrent.
  ///
  /// In zh, this message translates to:
  /// **'当前会话'**
  String get historySessionCurrent;

  /// No description provided for @historySessionSwitched.
  ///
  /// In zh, this message translates to:
  /// **'已打开会话：{title}'**
  String historySessionSwitched(String title);

  /// No description provided for @historySessionOpenFailed.
  ///
  /// In zh, this message translates to:
  /// **'打开会话失败：{error}'**
  String historySessionOpenFailed(String error);

  /// No description provided for @historySessionCloseTitle.
  ///
  /// In zh, this message translates to:
  /// **'结束记录'**
  String get historySessionCloseTitle;

  /// No description provided for @historySessionCloseConfirmation.
  ///
  /// In zh, this message translates to:
  /// **'结束“{title}”的记录吗？已有记录会保留，可随时查看或恢复记录。此操作不会删除数据。'**
  String historySessionCloseConfirmation(String title);

  /// No description provided for @historySessionClosed.
  ///
  /// In zh, this message translates to:
  /// **'记录已结束，已有记录已保留'**
  String get historySessionClosed;

  /// No description provided for @historySessionCloseFailed.
  ///
  /// In zh, this message translates to:
  /// **'结束记录失败：{error}'**
  String historySessionCloseFailed(String error);

  /// No description provided for @historySessionCollaborationCloseRequiresOpen.
  ///
  /// In zh, this message translates to:
  /// **'这是协作会话。请先打开该会话，再进入“协作与成员”关闭它。'**
  String get historySessionCollaborationCloseRequiresOpen;

  /// No description provided for @historySessionCollaborationCloseOwnerRequired.
  ///
  /// In zh, this message translates to:
  /// **'只有已完成同步的会话所有者才能关闭协作会话。请进入“协作与成员”刷新权限后重试。'**
  String get historySessionCollaborationCloseOwnerRequired;

  /// No description provided for @historySessionReopenAction.
  ///
  /// In zh, this message translates to:
  /// **'重新激活'**
  String get historySessionReopenAction;

  /// No description provided for @historySessionReopenTitle.
  ///
  /// In zh, this message translates to:
  /// **'重新激活本地会话'**
  String get historySessionReopenTitle;

  /// No description provided for @historySessionReopenConfirmation.
  ///
  /// In zh, this message translates to:
  /// **'恢复“{title}”并切换过去继续记录吗？其他会话不受影响。协作会话请由发起人在“协作与成员”中恢复。'**
  String historySessionReopenConfirmation(String title);

  /// No description provided for @historySessionReopened.
  ///
  /// In zh, this message translates to:
  /// **'已重新激活并切换到会话：{title}'**
  String historySessionReopened(String title);

  /// No description provided for @historySessionReopenFailed.
  ///
  /// In zh, this message translates to:
  /// **'重新激活本地会话失败：{error}'**
  String historySessionReopenFailed(String error);

  /// No description provided for @historySessionReopenedLogsUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'会话“{title}”已重新激活，但日志暂时加载失败。为安全起见当前保持只读，请重试加载。'**
  String historySessionReopenedLogsUnavailable(String title);

  /// No description provided for @historySessionCollaborationReopenRequired.
  ///
  /// In zh, this message translates to:
  /// **'这是协作会话。请先打开该会话，再到“协作与成员”中重新打开。'**
  String get historySessionCollaborationReopenRequired;

  /// No description provided for @historySessionDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'永久删除本机会话'**
  String get historySessionDeleteTitle;

  /// No description provided for @historySessionDeleteWarning.
  ///
  /// In zh, this message translates to:
  /// **'将永久删除本机“{title}”的所有日志及本地协作副本。此操作不可撤销，但不会删除或关闭服务器上的共享会话。请输入完整会话名以确认：'**
  String historySessionDeleteWarning(String title);

  /// No description provided for @historySessionDeleteNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'完整会话名'**
  String get historySessionDeleteNameLabel;

  /// No description provided for @historySessionDeleteExpectedName.
  ///
  /// In zh, this message translates to:
  /// **'期望输入：{title}'**
  String historySessionDeleteExpectedName(String title);

  /// No description provided for @historySessionDeleteNameMismatch.
  ///
  /// In zh, this message translates to:
  /// **'输入的会话名不匹配，请逐字核对。'**
  String get historySessionDeleteNameMismatch;

  /// No description provided for @historySessionDeleteAction.
  ///
  /// In zh, this message translates to:
  /// **'永久删除本机数据'**
  String get historySessionDeleteAction;

  /// No description provided for @historySessionDeleted.
  ///
  /// In zh, this message translates to:
  /// **'已永久删除本机会话'**
  String get historySessionDeleted;

  /// No description provided for @historySessionDeleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'永久删除本机会话失败：{error}'**
  String historySessionDeleteFailed(String error);

  /// No description provided for @historySessionReadOnly.
  ///
  /// In zh, this message translates to:
  /// **'当前为已关闭的历史会话，只能查看已有记录。'**
  String get historySessionReadOnly;

  /// No description provided for @controllerWindowOpenFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法打开主控窗口：{error}'**
  String controllerWindowOpenFailed(String error);

  /// No description provided for @controllerDisplaySettingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'主控显示'**
  String get controllerDisplaySettingsTitle;

  /// No description provided for @enableControllerDeviceEntry.
  ///
  /// In zh, this message translates to:
  /// **'启用主控设备入口'**
  String get enableControllerDeviceEntry;

  /// No description provided for @enableControllerDeviceEntryHint.
  ///
  /// In zh, this message translates to:
  /// **'开启后可从“会话”进入全屏只读主控屏，适用于安卓平板、手机或独立电脑。'**
  String get enableControllerDeviceEntryHint;

  /// No description provided for @defaultInformationDetail.
  ///
  /// In zh, this message translates to:
  /// **'默认信息详细程度'**
  String get defaultInformationDetail;

  /// No description provided for @desktopControllerDisplayHint.
  ///
  /// In zh, this message translates to:
  /// **'本机桌面还可从会话页打开置顶悬浮窗或第二显示器窗口。'**
  String get desktopControllerDisplayHint;

  /// No description provided for @inAppControllerDisplayHint.
  ///
  /// In zh, this message translates to:
  /// **'当前设备使用应用内全屏主控模式。'**
  String get inAppControllerDisplayHint;

  /// No description provided for @controllerScreenTitle.
  ///
  /// In zh, this message translates to:
  /// **'OpenLogTool 主控屏'**
  String get controllerScreenTitle;

  /// No description provided for @controllerFloatingWindowTitle.
  ///
  /// In zh, this message translates to:
  /// **'OpenLogTool 主控悬浮窗'**
  String get controllerFloatingWindowTitle;

  /// No description provided for @controllerScreenFallbackTitle.
  ///
  /// In zh, this message translates to:
  /// **'点名主控屏'**
  String get controllerScreenFallbackTitle;

  /// No description provided for @savedPositionCount.
  ///
  /// In zh, this message translates to:
  /// **'已保存 {count} 位'**
  String savedPositionCount(int count);

  /// No description provided for @notReceivedDraftUpdate.
  ///
  /// In zh, this message translates to:
  /// **'尚未收到草稿更新'**
  String get notReceivedDraftUpdate;

  /// No description provided for @updatedAt.
  ///
  /// In zh, this message translates to:
  /// **'更新 {time}'**
  String updatedAt(String time);

  /// No description provided for @editorEditing.
  ///
  /// In zh, this message translates to:
  /// **'{name} 编辑'**
  String editorEditing(String name);

  /// No description provided for @connectionConnected.
  ///
  /// In zh, this message translates to:
  /// **'实时连接'**
  String get connectionConnected;

  /// No description provided for @connectionReconnecting.
  ///
  /// In zh, this message translates to:
  /// **'正在重连'**
  String get connectionReconnecting;

  /// No description provided for @connectionOffline.
  ///
  /// In zh, this message translates to:
  /// **'连接中断'**
  String get connectionOffline;

  /// No description provided for @staleControllerDataWarning.
  ///
  /// In zh, this message translates to:
  /// **'连接已中断，正在显示最后一次收到的内容，数据可能已过期。'**
  String get staleControllerDataWarning;

  /// No description provided for @previousSavedRecord.
  ///
  /// In zh, this message translates to:
  /// **'上一位已保存记录'**
  String get previousSavedRecord;

  /// No description provided for @recordOrdinal.
  ///
  /// In zh, this message translates to:
  /// **'第 {ordinal} 位'**
  String recordOrdinal(int ordinal);

  /// No description provided for @noPreviousRecord.
  ///
  /// In zh, this message translates to:
  /// **'暂无上一位记录'**
  String get noPreviousRecord;

  /// No description provided for @waitingForCallsign.
  ///
  /// In zh, this message translates to:
  /// **'等待来台呼号…'**
  String get waitingForCallsign;

  /// No description provided for @beingEdited.
  ///
  /// In zh, this message translates to:
  /// **'正在编辑'**
  String get beingEdited;

  /// No description provided for @configureControllerDisplay.
  ///
  /// In zh, this message translates to:
  /// **'显示内容（{detail}）'**
  String configureControllerDisplay(String detail);

  /// No description provided for @exitControllerScreen.
  ///
  /// In zh, this message translates to:
  /// **'退出主控屏'**
  String get exitControllerScreen;

  /// No description provided for @controllerDisplayConfiguration.
  ///
  /// In zh, this message translates to:
  /// **'主控屏显示内容'**
  String get controllerDisplayConfiguration;

  /// No description provided for @informationDetail.
  ///
  /// In zh, this message translates to:
  /// **'信息详细程度'**
  String get informationDetail;

  /// No description provided for @controllerDisplayScale.
  ///
  /// In zh, this message translates to:
  /// **'主控屏缩放'**
  String get controllerDisplayScale;

  /// No description provided for @controllerDisplayScaleHint.
  ///
  /// In zh, this message translates to:
  /// **'仅调整主控屏的显示比例，不影响主应用界面。'**
  String get controllerDisplayScaleHint;

  /// No description provided for @currentFields.
  ///
  /// In zh, this message translates to:
  /// **'当前项字段'**
  String get currentFields;

  /// No description provided for @previousFields.
  ///
  /// In zh, this message translates to:
  /// **'上一位字段'**
  String get previousFields;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @apply.
  ///
  /// In zh, this message translates to:
  /// **'应用'**
  String get apply;

  /// No description provided for @detailMinimal.
  ///
  /// In zh, this message translates to:
  /// **'极简'**
  String get detailMinimal;

  /// No description provided for @detailStandard.
  ///
  /// In zh, this message translates to:
  /// **'标准'**
  String get detailStandard;

  /// No description provided for @detailFull.
  ///
  /// In zh, this message translates to:
  /// **'完整'**
  String get detailFull;

  /// No description provided for @detailCustom.
  ///
  /// In zh, this message translates to:
  /// **'自定义'**
  String get detailCustom;

  /// No description provided for @fieldController.
  ///
  /// In zh, this message translates to:
  /// **'主控'**
  String get fieldController;

  /// No description provided for @fieldControllerCallsign.
  ///
  /// In zh, this message translates to:
  /// **'主控呼号'**
  String get fieldControllerCallsign;

  /// No description provided for @fieldCallsign.
  ///
  /// In zh, this message translates to:
  /// **'来台呼号'**
  String get fieldCallsign;

  /// No description provided for @fieldTime.
  ///
  /// In zh, this message translates to:
  /// **'时间'**
  String get fieldTime;

  /// No description provided for @logTimeInvalid.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效时间（HH:mm）'**
  String get logTimeInvalid;

  /// No description provided for @fieldRstSent.
  ///
  /// In zh, this message translates to:
  /// **'RST 发'**
  String get fieldRstSent;

  /// No description provided for @fieldRstRcvd.
  ///
  /// In zh, this message translates to:
  /// **'RST 收'**
  String get fieldRstRcvd;

  /// No description provided for @fieldQth.
  ///
  /// In zh, this message translates to:
  /// **'QTH'**
  String get fieldQth;

  /// No description provided for @fieldDevice.
  ///
  /// In zh, this message translates to:
  /// **'设备'**
  String get fieldDevice;

  /// No description provided for @fieldPower.
  ///
  /// In zh, this message translates to:
  /// **'功率'**
  String get fieldPower;

  /// No description provided for @fieldAntenna.
  ///
  /// In zh, this message translates to:
  /// **'天线'**
  String get fieldAntenna;

  /// No description provided for @fieldHeight.
  ///
  /// In zh, this message translates to:
  /// **'高度'**
  String get fieldHeight;

  /// No description provided for @fieldRemarks.
  ///
  /// In zh, this message translates to:
  /// **'备注'**
  String get fieldRemarks;

  /// No description provided for @fieldActions.
  ///
  /// In zh, this message translates to:
  /// **'操作'**
  String get fieldActions;

  /// No description provided for @inputFieldHint.
  ///
  /// In zh, this message translates to:
  /// **'输入{field}'**
  String inputFieldHint(String field);

  /// No description provided for @optionalFieldHint.
  ///
  /// In zh, this message translates to:
  /// **'{field}（可选）'**
  String optionalFieldHint(String field);

  /// No description provided for @noSavedRecords.
  ///
  /// In zh, this message translates to:
  /// **'暂无已保存记录'**
  String get noSavedRecords;

  /// No description provided for @logTableSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索呼号 / QTH / 备注…'**
  String get logTableSearchHint;

  /// No description provided for @logTableSearchClear.
  ///
  /// In zh, this message translates to:
  /// **'清除搜索'**
  String get logTableSearchClear;

  /// No description provided for @logTableSearchNoMatches.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的记录'**
  String get logTableSearchNoMatches;

  /// No description provided for @addFirstRecordHint.
  ///
  /// In zh, this message translates to:
  /// **'在上方表单中添加第一条记录。'**
  String get addFirstRecordHint;

  /// No description provided for @editRecord.
  ///
  /// In zh, this message translates to:
  /// **'编辑记录'**
  String get editRecord;

  /// No description provided for @deleteRecord.
  ///
  /// In zh, this message translates to:
  /// **'删除记录'**
  String get deleteRecord;

  /// No description provided for @deleteRecordConfirmation.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除这条记录吗？'**
  String get deleteRecordConfirmation;

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// No description provided for @recordDeleted.
  ///
  /// In zh, this message translates to:
  /// **'记录已删除'**
  String get recordDeleted;

  /// No description provided for @savedRecords.
  ///
  /// In zh, this message translates to:
  /// **'已保存记录'**
  String get savedRecords;

  /// No description provided for @recordCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 条'**
  String recordCount(int count);

  /// No description provided for @restoreLastDeletedRecord.
  ///
  /// In zh, this message translates to:
  /// **'恢复最近删除'**
  String get restoreLastDeletedRecord;

  /// No description provided for @restoreLastDeletedRecordTitle.
  ///
  /// In zh, this message translates to:
  /// **'恢复最近删除的记录？'**
  String get restoreLastDeletedRecordTitle;

  /// No description provided for @restoreLastDeletedRecordConfirmation.
  ///
  /// In zh, this message translates to:
  /// **'将恢复最近一次删除的点名记录，不会影响其他记录。'**
  String get restoreLastDeletedRecordConfirmation;

  /// No description provided for @recordRestored.
  ///
  /// In zh, this message translates to:
  /// **'记录已恢复'**
  String get recordRestored;

  /// No description provided for @saveRecord.
  ///
  /// In zh, this message translates to:
  /// **'保存记录'**
  String get saveRecord;

  /// No description provided for @savingRecord.
  ///
  /// In zh, this message translates to:
  /// **'正在保存'**
  String get savingRecord;

  /// No description provided for @clearEnteredFields.
  ///
  /// In zh, this message translates to:
  /// **'清空已填内容'**
  String get clearEnteredFields;

  /// No description provided for @enteredFieldsCleared.
  ///
  /// In zh, this message translates to:
  /// **'已清空，主控呼号已保留'**
  String get enteredFieldsCleared;

  /// No description provided for @recordAdded.
  ///
  /// In zh, this message translates to:
  /// **'记录已添加'**
  String get recordAdded;

  /// No description provided for @recordQueuedOffline.
  ///
  /// In zh, this message translates to:
  /// **'网络不可用，记录已保存到本机待复核'**
  String get recordQueuedOffline;

  /// No description provided for @sharedDraftReadOnly.
  ///
  /// In zh, this message translates to:
  /// **'当前协作草稿只读'**
  String get sharedDraftReadOnly;

  /// No description provided for @fieldLockedBy.
  ///
  /// In zh, this message translates to:
  /// **'{name} 正在编辑'**
  String fieldLockedBy(String name);

  /// No description provided for @finishEditing.
  ///
  /// In zh, this message translates to:
  /// **'结束编辑'**
  String get finishEditing;

  /// No description provided for @offlineReviewTitle.
  ///
  /// In zh, this message translates to:
  /// **'离线记录待复核'**
  String get offlineReviewTitle;

  /// No description provided for @resolutionDiscard.
  ///
  /// In zh, this message translates to:
  /// **'丢弃'**
  String get resolutionDiscard;

  /// No description provided for @resolutionSubmitDuplicate.
  ///
  /// In zh, this message translates to:
  /// **'作为重复记录提交'**
  String get resolutionSubmitDuplicate;

  /// No description provided for @resolutionCopyCurrent.
  ///
  /// In zh, this message translates to:
  /// **'带入当前草稿'**
  String get resolutionCopyCurrent;

  /// No description provided for @callsignRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入点名呼号'**
  String get callsignRequired;

  /// No description provided for @leaveSession.
  ///
  /// In zh, this message translates to:
  /// **'离开协作'**
  String get leaveSession;

  /// No description provided for @leaveSessionConfirmation.
  ///
  /// In zh, this message translates to:
  /// **'离开后你将不再收到此会话的更新，本机已有记录保留为只读，其他成员可继续记录。以后需要重新邀请或申请加入。此操作需要连接服务器；只是暂时离开页面，无需退出协作。'**
  String get leaveSessionConfirmation;

  /// No description provided for @moreLocalCollaborationActions.
  ///
  /// In zh, this message translates to:
  /// **'更多操作'**
  String get moreLocalCollaborationActions;

  /// No description provided for @createEditableLocalCopy.
  ///
  /// In zh, this message translates to:
  /// **'另存独立会话'**
  String get createEditableLocalCopy;

  /// No description provided for @createEditableLocalCopyTitle.
  ///
  /// In zh, this message translates to:
  /// **'另存独立会话？'**
  String get createEditableLocalCopyTitle;

  /// No description provided for @createEditableLocalCopyConfirmation.
  ///
  /// In zh, this message translates to:
  /// **'将“{title}”当前表格中已保存的记录复制到一个新会话，并切换过去独立记录，无需服务器。原协作会话和你的成员身份不变，稍后仍可切回。未同步队列、冲突、离线待复核记录及未提交草稿保留在原会话，不会复制到新会话，也不会删除。'**
  String createEditableLocalCopyConfirmation(String title);

  /// No description provided for @editableLocalCopySessionTitle.
  ///
  /// In zh, this message translates to:
  /// **'{title}（本地副本）'**
  String editableLocalCopySessionTitle(String title);

  /// No description provided for @editableLocalCopySucceeded.
  ///
  /// In zh, this message translates to:
  /// **'已另存并切换到独立会话，原协作会话已保留'**
  String get editableLocalCopySucceeded;

  /// No description provided for @collaborationScreenTitle.
  ///
  /// In zh, this message translates to:
  /// **'协作与成员'**
  String get collaborationScreenTitle;

  /// No description provided for @collaborationConnectionSection.
  ///
  /// In zh, this message translates to:
  /// **'连接与会话'**
  String get collaborationConnectionSection;

  /// No description provided for @collaborationConnectionSectionHint.
  ///
  /// In zh, this message translates to:
  /// **'查看服务器账号、当前会话和同步入口。'**
  String get collaborationConnectionSectionHint;

  /// No description provided for @collaborationSyncSection.
  ///
  /// In zh, this message translates to:
  /// **'待处理同步'**
  String get collaborationSyncSection;

  /// No description provided for @collaborationSyncSectionHint.
  ///
  /// In zh, this message translates to:
  /// **'复核离线记录，并解决需要人工选择的冲突。'**
  String get collaborationSyncSectionHint;

  /// No description provided for @collaborationAccessSection.
  ///
  /// In zh, this message translates to:
  /// **'成员与共享'**
  String get collaborationAccessSection;

  /// No description provided for @collaborationAccessSectionHint.
  ///
  /// In zh, this message translates to:
  /// **'管理书记员权限、邀请码和只读公开页面。'**
  String get collaborationAccessSectionHint;

  /// No description provided for @serverLoggedIn.
  ///
  /// In zh, this message translates to:
  /// **'已登录'**
  String get serverLoggedIn;

  /// No description provided for @serverNotLoggedIn.
  ///
  /// In zh, this message translates to:
  /// **'尚未登录服务器'**
  String get serverNotLoggedIn;

  /// No description provided for @collaborationServerAccount.
  ///
  /// In zh, this message translates to:
  /// **'{url}\n账号 {id}'**
  String collaborationServerAccount(String url, String id);

  /// No description provided for @collaborationServerLoginHint.
  ///
  /// In zh, this message translates to:
  /// **'请先在“设置 → 服务器与账户”中检测服务器并登录。'**
  String get collaborationServerLoginHint;

  /// No description provided for @remoteCommitPendingLocalApplyHint.
  ///
  /// In zh, this message translates to:
  /// **'远端已经提交；客户端只会恢复本地确认，不会重复创建新修改。'**
  String get remoteCommitPendingLocalApplyHint;

  /// No description provided for @accountSharing.
  ///
  /// In zh, this message translates to:
  /// **'跨账号共享'**
  String get accountSharing;

  /// No description provided for @accountSharingHint.
  ///
  /// In zh, this message translates to:
  /// **'先申请再接受。共享会话只读，加入协作仍需口令。'**
  String get accountSharingHint;

  /// No description provided for @sharedSessionBadge.
  ///
  /// In zh, this message translates to:
  /// **'共享'**
  String get sharedSessionBadge;

  /// No description provided for @sharedSessionFrom.
  ///
  /// In zh, this message translates to:
  /// **'来自 {username} 的共享'**
  String sharedSessionFrom(String username);

  /// No description provided for @acceptShare.
  ///
  /// In zh, this message translates to:
  /// **'接受'**
  String get acceptShare;

  /// No description provided for @pendingInboundShares.
  ///
  /// In zh, this message translates to:
  /// **'待处理申请'**
  String get pendingInboundShares;

  /// No description provided for @browseSharedSession.
  ///
  /// In zh, this message translates to:
  /// **'浏览共享会话'**
  String get browseSharedSession;

  /// No description provided for @joinSharedSession.
  ///
  /// In zh, this message translates to:
  /// **'口令加入'**
  String get joinSharedSession;

  /// No description provided for @joinCollaborationTitle.
  ///
  /// In zh, this message translates to:
  /// **'加入协作'**
  String get joinCollaborationTitle;

  /// No description provided for @joinCollaborationHint.
  ///
  /// In zh, this message translates to:
  /// **'输入成员邀请码。成功后会以远端相同的 Session ID 安装完整本地副本。'**
  String get joinCollaborationHint;

  /// No description provided for @inviteCodeLabel.
  ///
  /// In zh, this message translates to:
  /// **'邀请码'**
  String get inviteCodeLabel;

  /// No description provided for @join.
  ///
  /// In zh, this message translates to:
  /// **'加入'**
  String get join;

  /// No description provided for @joinCollaborationSucceeded.
  ///
  /// In zh, this message translates to:
  /// **'已加入协作会话'**
  String get joinCollaborationSucceeded;

  /// No description provided for @localCollaborationSessionHint.
  ///
  /// In zh, this message translates to:
  /// **'本地会话尚未发布。发布时会锁定一致快照并分批上传全部记录。'**
  String get localCollaborationSessionHint;

  /// No description provided for @collaborationSessionSummary.
  ///
  /// In zh, this message translates to:
  /// **'状态 {state} · 角色 {role}'**
  String collaborationSessionSummary(String state, String role);

  /// No description provided for @collaborationSyncSummary.
  ///
  /// In zh, this message translates to:
  /// **'同步 {transport} · 游标 {applied}/{head}'**
  String collaborationSyncSummary(String transport, int applied, int head);

  /// No description provided for @collaborationQueueSummary.
  ///
  /// In zh, this message translates to:
  /// **'待同步 {pending} · 冲突 {conflicts} · 拒绝 {rejected}'**
  String collaborationQueueSummary(int pending, int conflicts, int rejected);

  /// No description provided for @collaborationReliableQueueHint.
  ///
  /// In zh, this message translates to:
  /// **'本地保存后会进入可靠队列，并由规范事件确认同步。'**
  String get collaborationReliableQueueHint;

  /// No description provided for @collaborationLastSync.
  ///
  /// In zh, this message translates to:
  /// **'最近同步 {time}'**
  String collaborationLastSync(String time);

  /// No description provided for @collaborationSessionConflictHint.
  ///
  /// In zh, this message translates to:
  /// **'会话存在未解决冲突。请先在冲突中心处理；重命名、关闭和重新打开暂时不可用。'**
  String get collaborationSessionConflictHint;

  /// No description provided for @publishSessionSucceeded.
  ///
  /// In zh, this message translates to:
  /// **'协作会话发布完成'**
  String get publishSessionSucceeded;

  /// No description provided for @publishCollaborationSession.
  ///
  /// In zh, this message translates to:
  /// **'发布为协作会话'**
  String get publishCollaborationSession;

  /// No description provided for @retryPublishSession.
  ///
  /// In zh, this message translates to:
  /// **'重试发布'**
  String get retryPublishSession;

  /// No description provided for @syncNowAndRefreshAccess.
  ///
  /// In zh, this message translates to:
  /// **'立即同步并刷新权限'**
  String get syncNowAndRefreshAccess;

  /// No description provided for @closeSession.
  ///
  /// In zh, this message translates to:
  /// **'关闭会话'**
  String get closeSession;

  /// No description provided for @reopenSession.
  ///
  /// In zh, this message translates to:
  /// **'重新打开'**
  String get reopenSession;

  /// No description provided for @transportStopped.
  ///
  /// In zh, this message translates to:
  /// **'已停止'**
  String get transportStopped;

  /// No description provided for @transportConnecting.
  ///
  /// In zh, this message translates to:
  /// **'连接中'**
  String get transportConnecting;

  /// No description provided for @transportOnline.
  ///
  /// In zh, this message translates to:
  /// **'在线'**
  String get transportOnline;

  /// No description provided for @transportBackingOff.
  ///
  /// In zh, this message translates to:
  /// **'等待重连'**
  String get transportBackingOff;

  /// No description provided for @transportAuthRequired.
  ///
  /// In zh, this message translates to:
  /// **'需要登录'**
  String get transportAuthRequired;

  /// No description provided for @transportIncompatible.
  ///
  /// In zh, this message translates to:
  /// **'协议异常'**
  String get transportIncompatible;

  /// No description provided for @readOnlyRevoked.
  ///
  /// In zh, this message translates to:
  /// **'成员权限已撤销，本地缓存保持只读。'**
  String get readOnlyRevoked;

  /// No description provided for @readOnlyClosePending.
  ///
  /// In zh, this message translates to:
  /// **'结束请求已保存，等待同步确认；确认前暂时只读。'**
  String get readOnlyClosePending;

  /// No description provided for @readOnlyReopenPending.
  ///
  /// In zh, this message translates to:
  /// **'重新打开请求已保存到本地，服务器确认前保持只读。'**
  String get readOnlyReopenPending;

  /// No description provided for @readOnlySessionClosed.
  ///
  /// In zh, this message translates to:
  /// **'共同记录已结束，已有记录可继续查看。'**
  String get readOnlySessionClosed;

  /// No description provided for @readOnlyViewer.
  ///
  /// In zh, this message translates to:
  /// **'当前账号是只读成员。'**
  String get readOnlyViewer;

  /// No description provided for @readOnlyResyncing.
  ///
  /// In zh, this message translates to:
  /// **'正在恢复同步，已保存的修改会保留。'**
  String get readOnlyResyncing;

  /// No description provided for @readOnlyCheckingAccess.
  ///
  /// In zh, this message translates to:
  /// **'正在确认你的参与权限，暂时只能查看。'**
  String get readOnlyCheckingAccess;

  /// No description provided for @logNotOwnedReadOnlyHint.
  ///
  /// In zh, this message translates to:
  /// **'只能修改或删除自己创建的记录。'**
  String get logNotOwnedReadOnlyHint;

  /// No description provided for @logAuthorUnknownReadOnlyHint.
  ///
  /// In zh, this message translates to:
  /// **'这条历史记录没有作者信息，普通成员只能查看。'**
  String get logAuthorUnknownReadOnlyHint;

  /// No description provided for @logSessionReadOnlyHint.
  ///
  /// In zh, this message translates to:
  /// **'当前成员角色、会话状态或同步状态不允许修改记录。'**
  String get logSessionReadOnlyHint;

  /// No description provided for @logConflictReadOnlyHint.
  ///
  /// In zh, this message translates to:
  /// **'请先在冲突中心解决这条记录。'**
  String get logConflictReadOnlyHint;

  /// No description provided for @renameCollaborationSession.
  ///
  /// In zh, this message translates to:
  /// **'重命名协作会话'**
  String get renameCollaborationSession;

  /// No description provided for @saveLocally.
  ///
  /// In zh, this message translates to:
  /// **'保存到本地'**
  String get saveLocally;

  /// No description provided for @sessionTitleQueued.
  ///
  /// In zh, this message translates to:
  /// **'标题已保存到本地，等待同步确认'**
  String get sessionTitleQueued;

  /// No description provided for @closeCollaborationSessionTitle.
  ///
  /// In zh, this message translates to:
  /// **'结束共同记录'**
  String get closeCollaborationSessionTitle;

  /// No description provided for @closeCollaborationSessionMessage.
  ///
  /// In zh, this message translates to:
  /// **'结束后，所有成员都不能继续添加或修改记录，已有记录和成员关系会保留。你可以稍后恢复记录。此操作需要同步到服务器；只是暂时离开，无需结束。'**
  String get closeCollaborationSessionMessage;

  /// No description provided for @closeSharedSession.
  ///
  /// In zh, this message translates to:
  /// **'结束共同记录'**
  String get closeSharedSession;

  /// No description provided for @closeCollaborationDraftNotEmpty.
  ///
  /// In zh, this message translates to:
  /// **'当前点名草稿还有内容。请先提交这条完整记录，或明确丢弃草稿后再结束。'**
  String get closeCollaborationDraftNotEmpty;

  /// No description provided for @closeCollaborationDraftIncomplete.
  ///
  /// In zh, this message translates to:
  /// **'当前草稿缺少时间、主控呼号或点名呼号，不能提交；仍可明确丢弃后结束。'**
  String get closeCollaborationDraftIncomplete;

  /// No description provided for @closeCollaborationDraftLocked.
  ///
  /// In zh, this message translates to:
  /// **'其他成员或设备仍在编辑 {count} 个草稿字段。请等待对方完成编辑并刷新后再结束。'**
  String closeCollaborationDraftLocked(int count);

  /// No description provided for @closeCollaborationDiscardAndClose.
  ///
  /// In zh, this message translates to:
  /// **'丢弃草稿并结束'**
  String get closeCollaborationDiscardAndClose;

  /// No description provided for @closeCollaborationSubmitAndClose.
  ///
  /// In zh, this message translates to:
  /// **'提交并结束'**
  String get closeCollaborationSubmitAndClose;

  /// No description provided for @closeCollaborationQueuedOffline.
  ///
  /// In zh, this message translates to:
  /// **'记录仅保存到离线队列，尚未提交到服务器；共同记录尚未结束。请恢复网络并处理该记录后重试。'**
  String get closeCollaborationQueuedOffline;

  /// No description provided for @closeSessionQueued.
  ///
  /// In zh, this message translates to:
  /// **'结束共同记录的请求已保存，等待同步确认'**
  String get closeSessionQueued;

  /// No description provided for @reopenCollaborationSessionTitle.
  ///
  /// In zh, this message translates to:
  /// **'重新打开协作会话'**
  String get reopenCollaborationSessionTitle;

  /// No description provided for @reopenCollaborationSessionMessage.
  ///
  /// In zh, this message translates to:
  /// **'重新打开会作为一项同步修改提交；服务器确认前仍保持只读。'**
  String get reopenCollaborationSessionMessage;

  /// No description provided for @reopenSessionQueued.
  ///
  /// In zh, this message translates to:
  /// **'重新打开请求已保存到本地，等待同步确认'**
  String get reopenSessionQueued;

  /// No description provided for @conflictUseRemoteTitle.
  ///
  /// In zh, this message translates to:
  /// **'采用远端版本'**
  String get conflictUseRemoteTitle;

  /// No description provided for @conflictKeepLocalTitle.
  ///
  /// In zh, this message translates to:
  /// **'保留本地版本'**
  String get conflictKeepLocalTitle;

  /// No description provided for @conflictCopyLocalTitle.
  ///
  /// In zh, this message translates to:
  /// **'复制为新日志'**
  String get conflictCopyLocalTitle;

  /// No description provided for @conflictUseRemoteMessage.
  ///
  /// In zh, this message translates to:
  /// **'本地未同步修改会被远端规范版本替换，此操作不会再次提交修改。'**
  String get conflictUseRemoteMessage;

  /// No description provided for @conflictKeepLocalMessage.
  ///
  /// In zh, this message translates to:
  /// **'将基于最新远端版本创建一项新修改。若远端再次变化，仍可能产生新冲突。'**
  String get conflictKeepLocalMessage;

  /// No description provided for @conflictCopyLocalMessage.
  ///
  /// In zh, this message translates to:
  /// **'远端原日志会保留，本地内容将使用新的日志 ID 创建副本并重新同步。'**
  String get conflictCopyLocalMessage;

  /// No description provided for @conflictUseRemoteSucceeded.
  ///
  /// In zh, this message translates to:
  /// **'已采用远端版本'**
  String get conflictUseRemoteSucceeded;

  /// No description provided for @conflictKeepLocalSucceeded.
  ///
  /// In zh, this message translates to:
  /// **'已保留本地版本并进入重试队列'**
  String get conflictKeepLocalSucceeded;

  /// No description provided for @conflictCopyLocalSucceeded.
  ///
  /// In zh, this message translates to:
  /// **'已复制为新日志并进入同步队列'**
  String get conflictCopyLocalSucceeded;

  /// No description provided for @conflictCenterTitle.
  ///
  /// In zh, this message translates to:
  /// **'冲突中心'**
  String get conflictCenterTitle;

  /// No description provided for @refreshConflicts.
  ///
  /// In zh, this message translates to:
  /// **'刷新冲突'**
  String get refreshConflicts;

  /// No description provided for @conflictCenterHint.
  ///
  /// In zh, this message translates to:
  /// **'可用操作由本地副本按最新权限和实体状态给出；保留或复制会生成新的同步修改。'**
  String get conflictCenterHint;

  /// No description provided for @noConflicts.
  ///
  /// In zh, this message translates to:
  /// **'没有待处理冲突。'**
  String get noConflicts;

  /// No description provided for @conflictSession.
  ///
  /// In zh, this message translates to:
  /// **'会话'**
  String get conflictSession;

  /// No description provided for @conflictLog.
  ///
  /// In zh, this message translates to:
  /// **'日志'**
  String get conflictLog;

  /// No description provided for @conflictNoOverlappingFields.
  ///
  /// In zh, this message translates to:
  /// **'无重叠字段（版本已变化）'**
  String get conflictNoOverlappingFields;

  /// No description provided for @conflictVersionSummary.
  ///
  /// In zh, this message translates to:
  /// **'字段 {fields} · 基线 v{base} → 远端 v{remote}'**
  String conflictVersionSummary(String fields, int base, int remote);

  /// No description provided for @conflictBase.
  ///
  /// In zh, this message translates to:
  /// **'基线'**
  String get conflictBase;

  /// No description provided for @conflictLocal.
  ///
  /// In zh, this message translates to:
  /// **'本地'**
  String get conflictLocal;

  /// No description provided for @conflictRemote.
  ///
  /// In zh, this message translates to:
  /// **'远端'**
  String get conflictRemote;

  /// No description provided for @conflictUseRemoteAction.
  ///
  /// In zh, this message translates to:
  /// **'采用远端'**
  String get conflictUseRemoteAction;

  /// No description provided for @conflictKeepLocalAction.
  ///
  /// In zh, this message translates to:
  /// **'保留本地重试'**
  String get conflictKeepLocalAction;

  /// No description provided for @conflictCopyLocalAction.
  ///
  /// In zh, this message translates to:
  /// **'复制为新日志'**
  String get conflictCopyLocalAction;

  /// No description provided for @memberInvitesTitle.
  ///
  /// In zh, this message translates to:
  /// **'成员邀请'**
  String get memberInvitesTitle;

  /// No description provided for @roleOwner.
  ///
  /// In zh, this message translates to:
  /// **'所有者'**
  String get roleOwner;

  /// No description provided for @roleEditor.
  ///
  /// In zh, this message translates to:
  /// **'编辑者'**
  String get roleEditor;

  /// No description provided for @roleViewer.
  ///
  /// In zh, this message translates to:
  /// **'只读成员'**
  String get roleViewer;

  /// No description provided for @inviteCreated.
  ///
  /// In zh, this message translates to:
  /// **'邀请码已生成'**
  String get inviteCreated;

  /// No description provided for @generate.
  ///
  /// In zh, this message translates to:
  /// **'生成'**
  String get generate;

  /// No description provided for @inviteCodeOneTimeHint.
  ///
  /// In zh, this message translates to:
  /// **'邀请码只在本次创建响应中显示：'**
  String get inviteCodeOneTimeHint;

  /// No description provided for @noInvites.
  ///
  /// In zh, this message translates to:
  /// **'暂无邀请'**
  String get noInvites;

  /// No description provided for @inviteSummary.
  ///
  /// In zh, this message translates to:
  /// **'{used}/{max} 次 · {status}'**
  String inviteSummary(int used, int max, String status);

  /// No description provided for @inviteExpiresAt.
  ///
  /// In zh, this message translates to:
  /// **'有效至 {time}'**
  String inviteExpiresAt(String time);

  /// No description provided for @inviteRevoked.
  ///
  /// In zh, this message translates to:
  /// **'已撤销'**
  String get inviteRevoked;

  /// No description provided for @membersTitle.
  ///
  /// In zh, this message translates to:
  /// **'成员'**
  String get membersTitle;

  /// No description provided for @currentAccount.
  ///
  /// In zh, this message translates to:
  /// **'当前账号'**
  String get currentAccount;

  /// No description provided for @memberSetEditor.
  ///
  /// In zh, this message translates to:
  /// **'成员已设为编辑者'**
  String get memberSetEditor;

  /// No description provided for @memberSetViewer.
  ///
  /// In zh, this message translates to:
  /// **'成员已设为只读'**
  String get memberSetViewer;

  /// No description provided for @setAsEditor.
  ///
  /// In zh, this message translates to:
  /// **'设为编辑者'**
  String get setAsEditor;

  /// No description provided for @setAsViewer.
  ///
  /// In zh, this message translates to:
  /// **'设为只读成员'**
  String get setAsViewer;

  /// No description provided for @transferOwnership.
  ///
  /// In zh, this message translates to:
  /// **'转移所有权'**
  String get transferOwnership;

  /// No description provided for @removeMember.
  ///
  /// In zh, this message translates to:
  /// **'移除成员'**
  String get removeMember;

  /// No description provided for @transferOwnershipConfirmation.
  ///
  /// In zh, this message translates to:
  /// **'转移给 {name} 后，你将变为编辑者。'**
  String transferOwnershipConfirmation(String name);

  /// No description provided for @ownershipTransferred.
  ///
  /// In zh, this message translates to:
  /// **'所有权已转移'**
  String get ownershipTransferred;

  /// No description provided for @removeMemberConfirmation.
  ///
  /// In zh, this message translates to:
  /// **'确定移除 {name}？权限会立即失效。'**
  String removeMemberConfirmation(String name);

  /// No description provided for @memberRemoved.
  ///
  /// In zh, this message translates to:
  /// **'成员已移除'**
  String get memberRemoved;

  /// No description provided for @operationFailed.
  ///
  /// In zh, this message translates to:
  /// **'操作失败：{error}'**
  String operationFailed(String error);

  /// No description provided for @unknown.
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get unknown;

  /// No description provided for @confirm.
  ///
  /// In zh, this message translates to:
  /// **'确认'**
  String get confirm;

  /// No description provided for @duplicateCallsignWarningSetting.
  ///
  /// In zh, this message translates to:
  /// **'重复呼号提醒'**
  String get duplicateCallsignWarningSetting;

  /// No description provided for @duplicateCallsignWarningHint.
  ///
  /// In zh, this message translates to:
  /// **'输入完呼号后立即检查同一场点名中的既有记录，弹窗询问是更新旧记录还是新增记录。'**
  String get duplicateCallsignWarningHint;

  /// No description provided for @autoAppendPowerWSetting.
  ///
  /// In zh, this message translates to:
  /// **'功率自动加 W'**
  String get autoAppendPowerWSetting;

  /// No description provided for @autoAppendPowerWHint.
  ///
  /// In zh, this message translates to:
  /// **'保存时若功率为纯数字（如 50、50.5）自动补上 W；已带单位或含中文的不动。'**
  String get autoAppendPowerWHint;

  /// No description provided for @duplicateCallsignTitle.
  ///
  /// In zh, this message translates to:
  /// **'呼号已经记录过'**
  String get duplicateCallsignTitle;

  /// No description provided for @duplicateCallsignMessage.
  ///
  /// In zh, this message translates to:
  /// **'{callsign} 已在本次点名中记录过，仍要保存吗？'**
  String duplicateCallsignMessage(String callsign);

  /// No description provided for @saveAnyway.
  ///
  /// In zh, this message translates to:
  /// **'仍然保存'**
  String get saveAnyway;

  /// No description provided for @duplicateUpdateOldRecord.
  ///
  /// In zh, this message translates to:
  /// **'更新旧记录'**
  String get duplicateUpdateOldRecord;

  /// No description provided for @duplicateAddNewRecord.
  ///
  /// In zh, this message translates to:
  /// **'添加新记录'**
  String get duplicateAddNewRecord;

  /// No description provided for @duplicateContinueDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'呼号已记录过'**
  String get duplicateContinueDialogTitle;

  /// No description provided for @duplicateContinueDialogMessage.
  ///
  /// In zh, this message translates to:
  /// **'{callsign} 已在第 {ordinal} 位记录过，继续添加吗？'**
  String duplicateContinueDialogMessage(String callsign, int ordinal);

  /// No description provided for @duplicateContinueAdd.
  ///
  /// In zh, this message translates to:
  /// **'继续添加'**
  String get duplicateContinueAdd;

  /// No description provided for @duplicateUpdateDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'呼号已记录过'**
  String get duplicateUpdateDialogTitle;

  /// No description provided for @duplicateUpdateDialogMessage.
  ///
  /// In zh, this message translates to:
  /// **'{callsign} 在本次点名中已有记录，选择处理方式：'**
  String duplicateUpdateDialogMessage(String callsign);

  /// No description provided for @duplicateOldRecordSummary.
  ///
  /// In zh, this message translates to:
  /// **'原记录（第 {ordinal} 位）：{time} {callsign} {rstSent}/{rstRcvd} {qth}'**
  String duplicateOldRecordSummary(int ordinal, String time, String callsign,
      String rstSent, String rstRcvd, String qth);

  /// No description provided for @recordUpdated.
  ///
  /// In zh, this message translates to:
  /// **'记录已更新'**
  String get recordUpdated;

  /// No description provided for @callsignHistoryFillSetting.
  ///
  /// In zh, this message translates to:
  /// **'呼号历史一键复用'**
  String get callsignHistoryFillSetting;

  /// No description provided for @callsignHistoryFillHint.
  ///
  /// In zh, this message translates to:
  /// **'匹配数据库中的既有呼号记录，并可一键带入设备、天线、QTH 等字段。'**
  String get callsignHistoryFillHint;

  /// No description provided for @publicShareManagement.
  ///
  /// In zh, this message translates to:
  /// **'Live Share · 公开只读页面'**
  String get publicShareManagement;

  /// No description provided for @publicShareManagementHint.
  ///
  /// In zh, this message translates to:
  /// **'为主控、远程书记员或观众生成只读网页；无需登录即可查看当前点名进度。链接密钥仅在创建时显示。'**
  String get publicShareManagementHint;

  /// No description provided for @publicShareAccessRequired.
  ///
  /// In zh, this message translates to:
  /// **'Live Share 由当前协作会话的 Owner 管理。请先登录并发布此会话；如果你是协作成员，请联系 Owner 创建公开链接。'**
  String get publicShareAccessRequired;

  /// No description provided for @publicShareUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'当前服务器未提供安全的 Live Share 公开页面。升级或启用服务端公开分享功能后即可创建。'**
  String get publicShareUnsupported;

  /// No description provided for @publicShareCreatedTitle.
  ///
  /// In zh, this message translates to:
  /// **'公开只读页面已创建'**
  String get publicShareCreatedTitle;

  /// No description provided for @publicShareCreatedHint.
  ///
  /// In zh, this message translates to:
  /// **'请立即保存此链接；出于安全考虑，刷新或重新登录后无法再次取回链接密钥。'**
  String get publicShareCreatedHint;

  /// No description provided for @createPublicShare.
  ///
  /// In zh, this message translates to:
  /// **'创建公开链接'**
  String get createPublicShare;

  /// No description provided for @publicShareExpiryDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置 Live Share 有效期'**
  String get publicShareExpiryDialogTitle;

  /// No description provided for @publicShareExpiryDialogHint.
  ///
  /// In zh, this message translates to:
  /// **'公开链接将在所选时长后自动失效。'**
  String get publicShareExpiryDialogHint;

  /// No description provided for @publicShareExpiryPresets.
  ///
  /// In zh, this message translates to:
  /// **'快捷选择'**
  String get publicShareExpiryPresets;

  /// No description provided for @publicShareExpiryOneHour.
  ///
  /// In zh, this message translates to:
  /// **'1小时'**
  String get publicShareExpiryOneHour;

  /// No description provided for @publicShareExpirySixHours.
  ///
  /// In zh, this message translates to:
  /// **'6小时'**
  String get publicShareExpirySixHours;

  /// No description provided for @publicShareExpiryTwelveHours.
  ///
  /// In zh, this message translates to:
  /// **'12小时'**
  String get publicShareExpiryTwelveHours;

  /// No description provided for @publicShareExpiryOneDay.
  ///
  /// In zh, this message translates to:
  /// **'1天'**
  String get publicShareExpiryOneDay;

  /// No description provided for @publicShareExpiryThreeDays.
  ///
  /// In zh, this message translates to:
  /// **'3天'**
  String get publicShareExpiryThreeDays;

  /// No description provided for @publicShareExpirySevenDays.
  ///
  /// In zh, this message translates to:
  /// **'7天'**
  String get publicShareExpirySevenDays;

  /// No description provided for @publicShareExpiryThirtyDays.
  ///
  /// In zh, this message translates to:
  /// **'30天'**
  String get publicShareExpiryThirtyDays;

  /// No description provided for @publicShareExpiryCustom.
  ///
  /// In zh, this message translates to:
  /// **'自定义'**
  String get publicShareExpiryCustom;

  /// No description provided for @publicShareExpiryCustomHours.
  ///
  /// In zh, this message translates to:
  /// **'有效期（小时）'**
  String get publicShareExpiryCustomHours;

  /// No description provided for @publicShareExpiryRangeError.
  ///
  /// In zh, this message translates to:
  /// **'请输入 1–720 之间的整数小时'**
  String get publicShareExpiryRangeError;

  /// No description provided for @publicShareEstimatedExpiry.
  ///
  /// In zh, this message translates to:
  /// **'预计失效：{time}（本地时间）'**
  String publicShareEstimatedExpiry(String time);

  /// No description provided for @copyPublicShareLink.
  ///
  /// In zh, this message translates to:
  /// **'复制链接'**
  String get copyPublicShareLink;

  /// No description provided for @openPublicShare.
  ///
  /// In zh, this message translates to:
  /// **'在浏览器打开'**
  String get openPublicShare;

  /// No description provided for @revokePublicShare.
  ///
  /// In zh, this message translates to:
  /// **'撤销'**
  String get revokePublicShare;

  /// No description provided for @publicShareLinkCopied.
  ///
  /// In zh, this message translates to:
  /// **'公开链接已复制'**
  String get publicShareLinkCopied;

  /// No description provided for @publicShareNoActiveLinks.
  ///
  /// In zh, this message translates to:
  /// **'当前没有有效的公开链接。创建后可将只读页面交给主控或远程查看者。'**
  String get publicShareNoActiveLinks;

  /// No description provided for @publicShareSecretUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'已有有效公开链接，但其密钥只在创建时返回。若链接没有保存，请撤销旧链接并创建新链接。'**
  String get publicShareSecretUnavailable;

  /// No description provided for @publicShareLinksTitle.
  ///
  /// In zh, this message translates to:
  /// **'公开链接记录'**
  String get publicShareLinksTitle;

  /// No description provided for @publicShareUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'已撤销或已过期'**
  String get publicShareUnavailable;

  /// No description provided for @publicShareOpenFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法打开浏览器；你仍可复制链接后手动打开。'**
  String get publicShareOpenFailed;

  /// No description provided for @publicShareExpiresAt.
  ///
  /// In zh, this message translates to:
  /// **'有效期至 {time}'**
  String publicShareExpiresAt(String time);

  /// No description provided for @refresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get refresh;

  /// No description provided for @reuseDatabaseInformation.
  ///
  /// In zh, this message translates to:
  /// **'一键复用数据库信息'**
  String get reuseDatabaseInformation;

  /// No description provided for @collapseSidebar.
  ///
  /// In zh, this message translates to:
  /// **'收起侧边栏'**
  String get collapseSidebar;

  /// No description provided for @expandSidebar.
  ///
  /// In zh, this message translates to:
  /// **'展开侧边栏'**
  String get expandSidebar;

  /// No description provided for @limitWorkbenchWidthSetting.
  ///
  /// In zh, this message translates to:
  /// **'限制点名台内容宽度'**
  String get limitWorkbenchWidthSetting;

  /// No description provided for @limitWorkbenchWidthHint.
  ///
  /// In zh, this message translates to:
  /// **'宽屏时将点名台内容居中并限制在 1520 像素内，避免字段过度拉伸。'**
  String get limitWorkbenchWidthHint;

  /// No description provided for @serverConnectionFailed.
  ///
  /// In zh, this message translates to:
  /// **'连接失败：{detail}'**
  String serverConnectionFailed(String detail);

  /// No description provided for @serverNetworkError.
  ///
  /// In zh, this message translates to:
  /// **'服务器 {url} 没有响应。请检查地址和端口，并确认服务端或反向代理正在运行。'**
  String serverNetworkError(String url);

  /// No description provided for @serverWebMixedContentError.
  ///
  /// In zh, this message translates to:
  /// **'当前 WebClient 使用 HTTPS，浏览器不允许连接 HTTP 服务器 {url}。请为服务器启用 HTTPS。'**
  String serverWebMixedContentError(String url);

  /// No description provided for @serverWebCrossOriginError.
  ///
  /// In zh, this message translates to:
  /// **'浏览器无法访问服务器 {url}。请确认服务器在线；若原生客户端能连接，请在服务端 CORS_ORIGINS 中加入 {origin}，或使用同源反向代理。'**
  String serverWebCrossOriginError(String url, String origin);

  /// No description provided for @serverNetworkTimeout.
  ///
  /// In zh, this message translates to:
  /// **'连接 {url} 超时。请检查网络、防火墙和服务端状态。'**
  String serverNetworkTimeout(String url);

  /// No description provided for @serverInvalidResponse.
  ///
  /// In zh, this message translates to:
  /// **'已连接 {url}，但它没有返回兼容的 OpenLogTool Server 响应。'**
  String serverInvalidResponse(String url);

  /// No description provided for @serverAddressRequired.
  ///
  /// In zh, this message translates to:
  /// **'请先填写服务器地址。'**
  String get serverAddressRequired;

  /// No description provided for @serverAddressInvalid.
  ///
  /// In zh, this message translates to:
  /// **'服务器地址必须是完整的 http(s) URL。'**
  String get serverAddressInvalid;

  /// No description provided for @serverSettingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'服务器与账户'**
  String get serverSettingsTitle;

  /// No description provided for @serverAddressLabel.
  ///
  /// In zh, this message translates to:
  /// **'服务器地址'**
  String get serverAddressLabel;

  /// No description provided for @serverAddressHint.
  ///
  /// In zh, this message translates to:
  /// **'http://your-server:3000'**
  String get serverAddressHint;

  /// No description provided for @serverSaveAndCheck.
  ///
  /// In zh, this message translates to:
  /// **'保存并检测服务器'**
  String get serverSaveAndCheck;

  /// No description provided for @serverCheckSucceeded.
  ///
  /// In zh, this message translates to:
  /// **'连接成功 · 协议 v{min}-{max}'**
  String serverCheckSucceeded(int min, int max);

  /// No description provided for @serverInstanceDetails.
  ///
  /// In zh, this message translates to:
  /// **'实例 {instance}\n能力 {features}'**
  String serverInstanceDetails(String instance, String features);

  /// No description provided for @serverConnected.
  ///
  /// In zh, this message translates to:
  /// **'已连接'**
  String get serverConnected;

  /// No description provided for @serverNotConnected.
  ///
  /// In zh, this message translates to:
  /// **'未检测'**
  String get serverNotConnected;

  /// No description provided for @serverSignedOutHint.
  ///
  /// In zh, this message translates to:
  /// **'登录后可以参与协作，并管理当前账号自己的资料和登录设备。'**
  String get serverSignedOutHint;

  /// No description provided for @tokenStoragePrivateFileWarning.
  ///
  /// In zh, this message translates to:
  /// **'系统钥匙环不可用；登录凭据已保存到仅当前 Linux 用户可读的私有文件。钥匙环恢复可用后会自动迁回安全存储。'**
  String get tokenStoragePrivateFileWarning;

  /// No description provided for @tokenStorageMemoryOnlyWarning.
  ///
  /// In zh, this message translates to:
  /// **'安全凭据存储不可用；本次登录仅在应用运行期间有效，退出后需要重新登录。'**
  String get tokenStorageMemoryOnlyWarning;

  /// No description provided for @serverLogin.
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get serverLogin;

  /// No description provided for @serverRegister.
  ///
  /// In zh, this message translates to:
  /// **'注册'**
  String get serverRegister;

  /// No description provided for @serverLogout.
  ///
  /// In zh, this message translates to:
  /// **'退出'**
  String get serverLogout;

  /// No description provided for @serverAccountId.
  ///
  /// In zh, this message translates to:
  /// **'账号 ID：{id}'**
  String serverAccountId(String id);

  /// No description provided for @serverLoginSucceeded.
  ///
  /// In zh, this message translates to:
  /// **'已登录服务器'**
  String get serverLoginSucceeded;

  /// No description provided for @serverRegistrationSucceeded.
  ///
  /// In zh, this message translates to:
  /// **'注册并登录成功'**
  String get serverRegistrationSucceeded;

  /// No description provided for @serverLoginFailed.
  ///
  /// In zh, this message translates to:
  /// **'登录失败：{error}'**
  String serverLoginFailed(String error);

  /// No description provided for @serverRegistrationFailed.
  ///
  /// In zh, this message translates to:
  /// **'注册失败：{error}'**
  String serverRegistrationFailed(String error);

  /// No description provided for @serverLogoutFailed.
  ///
  /// In zh, this message translates to:
  /// **'退出失败：{error}'**
  String serverLogoutFailed(String error);

  /// No description provided for @accountChangeUsername.
  ///
  /// In zh, this message translates to:
  /// **'修改用户名'**
  String get accountChangeUsername;

  /// No description provided for @accountChangePassword.
  ///
  /// In zh, this message translates to:
  /// **'修改密码'**
  String get accountChangePassword;

  /// No description provided for @accountDeviceSessions.
  ///
  /// In zh, this message translates to:
  /// **'登录设备'**
  String get accountDeviceSessions;

  /// No description provided for @accountUsernameUpdated.
  ///
  /// In zh, this message translates to:
  /// **'用户名已更新'**
  String get accountUsernameUpdated;

  /// No description provided for @accountPasswordUpdated.
  ///
  /// In zh, this message translates to:
  /// **'密码已更新，已撤销 {count} 个登录会话，请重新登录。'**
  String accountPasswordUpdated(int count);

  /// No description provided for @accountUpdateFailed.
  ///
  /// In zh, this message translates to:
  /// **'账户操作失败：{error}'**
  String accountUpdateFailed(String error);

  /// No description provided for @usernameLabel.
  ///
  /// In zh, this message translates to:
  /// **'用户名'**
  String get usernameLabel;

  /// No description provided for @usernameLengthHint.
  ///
  /// In zh, this message translates to:
  /// **'用户名应为 3–64 个字符'**
  String get usernameLengthHint;

  /// No description provided for @passwordLabel.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get passwordLabel;

  /// No description provided for @fieldRequired.
  ///
  /// In zh, this message translates to:
  /// **'此项不能为空'**
  String get fieldRequired;

  /// No description provided for @currentPasswordLabel.
  ///
  /// In zh, this message translates to:
  /// **'当前密码'**
  String get currentPasswordLabel;

  /// No description provided for @newPasswordLabel.
  ///
  /// In zh, this message translates to:
  /// **'新密码'**
  String get newPasswordLabel;

  /// No description provided for @confirmNewPasswordLabel.
  ///
  /// In zh, this message translates to:
  /// **'确认新密码'**
  String get confirmNewPasswordLabel;

  /// No description provided for @passwordLengthHint.
  ///
  /// In zh, this message translates to:
  /// **'密码至少需要 10 个字符'**
  String get passwordLengthHint;

  /// No description provided for @passwordMismatch.
  ///
  /// In zh, this message translates to:
  /// **'两次输入的新密码不一致'**
  String get passwordMismatch;

  /// No description provided for @passwordChangeRequiredTitle.
  ///
  /// In zh, this message translates to:
  /// **'必须修改临时密码'**
  String get passwordChangeRequiredTitle;

  /// No description provided for @passwordChangeRequiredHint.
  ///
  /// In zh, this message translates to:
  /// **'账号 {username} 使用了临时密码。设置新密码后才能继续。'**
  String passwordChangeRequiredHint(String username);

  /// No description provided for @passwordChangeCredentialExpires.
  ///
  /// In zh, this message translates to:
  /// **'本次改密凭据将在 {seconds} 秒内过期。'**
  String passwordChangeCredentialExpires(int seconds);

  /// No description provided for @completePasswordChange.
  ///
  /// In zh, this message translates to:
  /// **'设置新密码并登录'**
  String get completePasswordChange;

  /// No description provided for @cancelLogin.
  ///
  /// In zh, this message translates to:
  /// **'取消登录'**
  String get cancelLogin;

  /// No description provided for @passwordChangeCompleted.
  ///
  /// In zh, this message translates to:
  /// **'密码已更新并完成登录'**
  String get passwordChangeCompleted;

  /// No description provided for @deviceSessionsTitle.
  ///
  /// In zh, this message translates to:
  /// **'登录设备'**
  String get deviceSessionsTitle;

  /// No description provided for @deviceSessionsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'当前没有有效的登录设备'**
  String get deviceSessionsEmpty;

  /// No description provided for @deviceUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未命名设备'**
  String get deviceUnknown;

  /// No description provided for @deviceCurrent.
  ///
  /// In zh, this message translates to:
  /// **'当前设备'**
  String get deviceCurrent;

  /// No description provided for @deviceIp.
  ///
  /// In zh, this message translates to:
  /// **'IP：{ip}'**
  String deviceIp(String ip);

  /// No description provided for @deviceLastUsed.
  ///
  /// In zh, this message translates to:
  /// **'最近使用：{time}'**
  String deviceLastUsed(String time);

  /// No description provided for @deviceExpires.
  ///
  /// In zh, this message translates to:
  /// **'到期：{time}'**
  String deviceExpires(String time);

  /// No description provided for @revokeDevice.
  ///
  /// In zh, this message translates to:
  /// **'撤销设备'**
  String get revokeDevice;

  /// No description provided for @revokeCurrentDevice.
  ///
  /// In zh, this message translates to:
  /// **'退出当前设备'**
  String get revokeCurrentDevice;

  /// No description provided for @revokeDeviceConfirmation.
  ///
  /// In zh, this message translates to:
  /// **'撤销后，该设备将不能继续刷新登录状态。'**
  String get revokeDeviceConfirmation;

  /// No description provided for @revokeCurrentDeviceConfirmation.
  ///
  /// In zh, this message translates to:
  /// **'退出当前设备后，需要重新输入用户名和密码才能连接服务器。'**
  String get revokeCurrentDeviceConfirmation;

  /// No description provided for @deviceRevoked.
  ///
  /// In zh, this message translates to:
  /// **'登录设备已撤销'**
  String get deviceRevoked;

  /// No description provided for @close.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get close;

  /// No description provided for @retry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retry;

  /// No description provided for @excelUseSessionTitleAsHeader.
  ///
  /// In zh, this message translates to:
  /// **'抬头使用当前会话名'**
  String get excelUseSessionTitleAsHeader;

  /// No description provided for @excelUseSessionTitleAsHeaderHint.
  ///
  /// In zh, this message translates to:
  /// **'开启后，Excel 抬头将直接使用当前会话名；会话名为空时继续使用抬头模板。'**
  String get excelUseSessionTitleAsHeaderHint;

  /// No description provided for @fileNameUseSessionTitle.
  ///
  /// In zh, this message translates to:
  /// **'文件名使用当前会话名'**
  String get fileNameUseSessionTitle;

  /// No description provided for @fileNameUseSessionTitleHint.
  ///
  /// In zh, this message translates to:
  /// **'开启后，导出文件名将直接使用当前会话名；会话名为空时继续使用文件名模板。'**
  String get fileNameUseSessionTitleHint;

  /// No description provided for @themeColorPickerTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择主题颜色'**
  String get themeColorPickerTitle;

  /// No description provided for @themeColorPresets.
  ///
  /// In zh, this message translates to:
  /// **'预设颜色'**
  String get themeColorPresets;

  /// No description provided for @themeColorCustom.
  ///
  /// In zh, this message translates to:
  /// **'自定义颜色'**
  String get themeColorCustom;

  /// No description provided for @themeColorHex.
  ///
  /// In zh, this message translates to:
  /// **'HEX 颜色'**
  String get themeColorHex;

  /// No description provided for @themeColorHue.
  ///
  /// In zh, this message translates to:
  /// **'色相'**
  String get themeColorHue;

  /// No description provided for @themeColorBlue.
  ///
  /// In zh, this message translates to:
  /// **'蓝色'**
  String get themeColorBlue;

  /// No description provided for @themeColorGreen.
  ///
  /// In zh, this message translates to:
  /// **'绿色'**
  String get themeColorGreen;

  /// No description provided for @themeColorRed.
  ///
  /// In zh, this message translates to:
  /// **'红色'**
  String get themeColorRed;

  /// No description provided for @themeColorOrange.
  ///
  /// In zh, this message translates to:
  /// **'橙色'**
  String get themeColorOrange;

  /// No description provided for @themeColorPurple.
  ///
  /// In zh, this message translates to:
  /// **'紫色'**
  String get themeColorPurple;

  /// No description provided for @themeColorPink.
  ///
  /// In zh, this message translates to:
  /// **'粉色'**
  String get themeColorPink;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @add.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get add;

  /// No description provided for @renameSession.
  ///
  /// In zh, this message translates to:
  /// **'修改会话名'**
  String get renameSession;

  /// No description provided for @renameSessionTitle.
  ///
  /// In zh, this message translates to:
  /// **'修改会话名'**
  String get renameSessionTitle;

  /// No description provided for @sessionTitleLabel.
  ///
  /// In zh, this message translates to:
  /// **'会话名'**
  String get sessionTitleLabel;

  /// No description provided for @renameCollaborationSessionHint.
  ///
  /// In zh, this message translates to:
  /// **'只有会话所有者可以修改；保存后将同步给其他书记员和主控显示。'**
  String get renameCollaborationSessionHint;

  /// No description provided for @renameSessionSaved.
  ///
  /// In zh, this message translates to:
  /// **'会话名已更新'**
  String get renameSessionSaved;

  /// No description provided for @renameCollaborationSessionSaved.
  ///
  /// In zh, this message translates to:
  /// **'会话名已保存，正在同步给其他成员'**
  String get renameCollaborationSessionSaved;

  /// No description provided for @renameSessionFailed.
  ///
  /// In zh, this message translates to:
  /// **'修改会话名失败：{error}'**
  String renameSessionFailed(String error);

  /// No description provided for @renameSessionBlockedClosed.
  ///
  /// In zh, this message translates to:
  /// **'已关闭的会话不能修改名称'**
  String get renameSessionBlockedClosed;

  /// No description provided for @renameSessionBlockedBusy.
  ///
  /// In zh, this message translates to:
  /// **'协作操作进行中，暂时不能修改名称'**
  String get renameSessionBlockedBusy;

  /// No description provided for @renameSessionBlockedConflict.
  ///
  /// In zh, this message translates to:
  /// **'请先解决会话冲突，再修改名称'**
  String get renameSessionBlockedConflict;

  /// No description provided for @renameSessionBlockedNotReady.
  ///
  /// In zh, this message translates to:
  /// **'协作会话尚未就绪，暂时不能修改名称'**
  String get renameSessionBlockedNotReady;

  /// No description provided for @renameSessionBlockedOwner.
  ///
  /// In zh, this message translates to:
  /// **'只有会话所有者可以修改名称'**
  String get renameSessionBlockedOwner;

  /// No description provided for @dictionaryManagementTitle.
  ///
  /// In zh, this message translates to:
  /// **'词库管理'**
  String get dictionaryManagementTitle;

  /// No description provided for @dictionaryManagementHint.
  ///
  /// In zh, this message translates to:
  /// **'管理点名时可搜索和一键复用的设备、天线、呼号与 QTH 内容。'**
  String get dictionaryManagementHint;

  /// No description provided for @deviceLibrary.
  ///
  /// In zh, this message translates to:
  /// **'设备词库'**
  String get deviceLibrary;

  /// No description provided for @antennaLibrary.
  ///
  /// In zh, this message translates to:
  /// **'天线词库'**
  String get antennaLibrary;

  /// No description provided for @callsignLibrary.
  ///
  /// In zh, this message translates to:
  /// **'呼号词库'**
  String get callsignLibrary;

  /// No description provided for @qthLibrary.
  ///
  /// In zh, this message translates to:
  /// **'QTH 词库'**
  String get qthLibrary;

  /// No description provided for @libraryItemCount.
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 条'**
  String libraryItemCount(int count);

  /// No description provided for @importLibraryJson.
  ///
  /// In zh, this message translates to:
  /// **'导入 JSON'**
  String get importLibraryJson;

  /// No description provided for @expandAll.
  ///
  /// In zh, this message translates to:
  /// **'展开全部'**
  String get expandAll;

  /// No description provided for @collapseAll.
  ///
  /// In zh, this message translates to:
  /// **'折叠全部'**
  String get collapseAll;

  /// No description provided for @addLibraryItem.
  ///
  /// In zh, this message translates to:
  /// **'添加{name}'**
  String addLibraryItem(String name);

  /// No description provided for @searchLibrary.
  ///
  /// In zh, this message translates to:
  /// **'搜索{name}'**
  String searchLibrary(String name);

  /// No description provided for @libraryEmpty.
  ///
  /// In zh, this message translates to:
  /// **'词库中还没有内容'**
  String get libraryEmpty;

  /// No description provided for @noLibrarySearchResults.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的词库内容'**
  String get noLibrarySearchResults;

  /// No description provided for @libraryItemAdded.
  ///
  /// In zh, this message translates to:
  /// **'已添加：{value}'**
  String libraryItemAdded(String value);

  /// No description provided for @libraryItemAlreadyExists.
  ///
  /// In zh, this message translates to:
  /// **'词库中已有“{value}”'**
  String libraryItemAlreadyExists(String value);

  /// No description provided for @libraryItemAddFailed.
  ///
  /// In zh, this message translates to:
  /// **'添加失败：{error}'**
  String libraryItemAddFailed(String error);

  /// No description provided for @deleteLibraryItemTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除词库条目'**
  String get deleteLibraryItemTitle;

  /// No description provided for @deleteLibraryItemConfirmation.
  ///
  /// In zh, this message translates to:
  /// **'确定从{name}中删除“{value}”吗？'**
  String deleteLibraryItemConfirmation(String value, String name);

  /// No description provided for @deleteLibraryItemAction.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get deleteLibraryItemAction;

  /// No description provided for @libraryItemDeleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除：{value}'**
  String libraryItemDeleted(String value);

  /// No description provided for @libraryItemDeleteFailed.
  ///
  /// In zh, this message translates to:
  /// **'删除失败：{error}'**
  String libraryItemDeleteFailed(String error);

  /// No description provided for @clearLibraryTitle.
  ///
  /// In zh, this message translates to:
  /// **'清空{name}'**
  String clearLibraryTitle(String name);

  /// No description provided for @clearLibraryConfirmation.
  ///
  /// In zh, this message translates to:
  /// **'将删除{name}中的全部 {count} 条内容。此操作无法撤销，确定继续吗？'**
  String clearLibraryConfirmation(String name, int count);

  /// No description provided for @clearLibraryAction.
  ///
  /// In zh, this message translates to:
  /// **'全部清空'**
  String get clearLibraryAction;

  /// No description provided for @libraryCleared.
  ///
  /// In zh, this message translates to:
  /// **'已清空{name}'**
  String libraryCleared(String name);

  /// No description provided for @libraryClearFailed.
  ///
  /// In zh, this message translates to:
  /// **'清空失败：{error}'**
  String libraryClearFailed(String error);

  /// No description provided for @libraryImportEmpty.
  ///
  /// In zh, this message translates to:
  /// **'文件中没有可导入的词库内容'**
  String get libraryImportEmpty;

  /// No description provided for @libraryImportCount.
  ///
  /// In zh, this message translates to:
  /// **'{name} {count} 条'**
  String libraryImportCount(String name, int count);

  /// No description provided for @libraryImportSucceeded.
  ///
  /// In zh, this message translates to:
  /// **'已导入：{summary}'**
  String libraryImportSucceeded(String summary);

  /// No description provided for @libraryImportFailed.
  ///
  /// In zh, this message translates to:
  /// **'导入词库失败：{error}'**
  String libraryImportFailed(String error);

  /// No description provided for @listSeparator.
  ///
  /// In zh, this message translates to:
  /// **'，'**
  String get listSeparator;

  /// No description provided for @fontPickerTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择字体'**
  String get fontPickerTitle;

  /// No description provided for @fontSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索字体'**
  String get fontSearchHint;

  /// No description provided for @fontResultCount.
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 个字体'**
  String fontResultCount(int count);

  /// No description provided for @fontSystemDefault.
  ///
  /// In zh, this message translates to:
  /// **'系统默认'**
  String get fontSystemDefault;

  /// No description provided for @fontBuiltIn.
  ///
  /// In zh, this message translates to:
  /// **'内置'**
  String get fontBuiltIn;

  /// No description provided for @fontPreview.
  ///
  /// In zh, this message translates to:
  /// **'预览'**
  String get fontPreview;

  /// No description provided for @fontPreviewSample.
  ///
  /// In zh, this message translates to:
  /// **'OpenLogTool · CQ CQ · 点名记录 123'**
  String get fontPreviewSample;

  /// No description provided for @aboutAppAction.
  ///
  /// In zh, this message translates to:
  /// **'关于应用'**
  String get aboutAppAction;

  /// No description provided for @aboutAppTitle.
  ///
  /// In zh, this message translates to:
  /// **'关于 OpenLogTool'**
  String get aboutAppTitle;

  /// No description provided for @aboutAppTagline.
  ///
  /// In zh, this message translates to:
  /// **'业余无线电点名记录与协作工具'**
  String get aboutAppTagline;

  /// No description provided for @aboutAppDescription.
  ///
  /// In zh, this message translates to:
  /// **'为现场和远程书记员提供完整点名记录、实时草稿协作与主控显示。OpenLogTool 专注于点名现场工作流，不以替代个人通联日志为目标。'**
  String get aboutAppDescription;

  /// No description provided for @aboutVersionChip.
  ///
  /// In zh, this message translates to:
  /// **'版本 {version}'**
  String aboutVersionChip(String version);

  /// No description provided for @aboutVersionSection.
  ///
  /// In zh, this message translates to:
  /// **'版本信息'**
  String get aboutVersionSection;

  /// No description provided for @aboutVersionLabel.
  ///
  /// In zh, this message translates to:
  /// **'应用版本'**
  String get aboutVersionLabel;

  /// No description provided for @aboutBuildLabel.
  ///
  /// In zh, this message translates to:
  /// **'构建编号'**
  String get aboutBuildLabel;

  /// No description provided for @aboutCommitLabel.
  ///
  /// In zh, this message translates to:
  /// **'Commit'**
  String get aboutCommitLabel;

  /// No description provided for @aboutCopyVersionInfo.
  ///
  /// In zh, this message translates to:
  /// **'复制版本信息'**
  String get aboutCopyVersionInfo;

  /// No description provided for @aboutVersionInfoCopied.
  ///
  /// In zh, this message translates to:
  /// **'版本信息已复制'**
  String get aboutVersionInfoCopied;

  /// No description provided for @aboutCheckUpdates.
  ///
  /// In zh, this message translates to:
  /// **'检查更新'**
  String get aboutCheckUpdates;

  /// No description provided for @aboutCheckingUpdates.
  ///
  /// In zh, this message translates to:
  /// **'正在检查…'**
  String get aboutCheckingUpdates;

  /// No description provided for @aboutUpToDate.
  ///
  /// In zh, this message translates to:
  /// **'当前已是最新版本（{version}）'**
  String aboutUpToDate(String version);

  /// No description provided for @aboutUpdateAvailableTitle.
  ///
  /// In zh, this message translates to:
  /// **'发现新版本'**
  String get aboutUpdateAvailableTitle;

  /// No description provided for @aboutUpdateAvailableMessage.
  ///
  /// In zh, this message translates to:
  /// **'当前版本：{currentVersion}\n最新版本：{latestVersion}'**
  String aboutUpdateAvailableMessage(
      String currentVersion, String latestVersion);

  /// No description provided for @aboutOpenRelease.
  ///
  /// In zh, this message translates to:
  /// **'查看并下载'**
  String get aboutOpenRelease;

  /// No description provided for @aboutUpdateLater.
  ///
  /// In zh, this message translates to:
  /// **'稍后'**
  String get aboutUpdateLater;

  /// No description provided for @aboutUpdateCheckFailed.
  ///
  /// In zh, this message translates to:
  /// **'检查更新失败，请检查网络后重试'**
  String get aboutUpdateCheckFailed;

  /// No description provided for @aboutProjectSection.
  ///
  /// In zh, this message translates to:
  /// **'项目与许可'**
  String get aboutProjectSection;

  /// No description provided for @aboutRepository.
  ///
  /// In zh, this message translates to:
  /// **'项目仓库'**
  String get aboutRepository;

  /// No description provided for @aboutRepositoryHint.
  ///
  /// In zh, this message translates to:
  /// **'查看源代码与项目说明'**
  String get aboutRepositoryHint;

  /// No description provided for @aboutIssueTracker.
  ///
  /// In zh, this message translates to:
  /// **'问题反馈'**
  String get aboutIssueTracker;

  /// No description provided for @aboutIssueTrackerHint.
  ///
  /// In zh, this message translates to:
  /// **'报告错误或提出建议'**
  String get aboutIssueTrackerHint;

  /// No description provided for @aboutOpenSourceLicenses.
  ///
  /// In zh, this message translates to:
  /// **'开源组件许可'**
  String get aboutOpenSourceLicenses;

  /// No description provided for @aboutOpenSourceLicensesHint.
  ///
  /// In zh, this message translates to:
  /// **'查看应用使用的第三方组件许可'**
  String get aboutOpenSourceLicensesHint;

  /// No description provided for @aboutLicenseName.
  ///
  /// In zh, this message translates to:
  /// **'GNU AGPL-3.0'**
  String get aboutLicenseName;

  /// No description provided for @aboutLicenseHint.
  ///
  /// In zh, this message translates to:
  /// **'OpenLogTool 是自由开源软件'**
  String get aboutLicenseHint;

  /// No description provided for @aboutCopyright.
  ///
  /// In zh, this message translates to:
  /// **'© 2026 Mazha0309 · BG5CRL'**
  String get aboutCopyright;

  /// No description provided for @aboutLinkOpenFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法打开链接：{error}'**
  String aboutLinkOpenFailed(String error);

  /// No description provided for @restoreDefaultSettings.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认设置'**
  String get restoreDefaultSettings;

  /// No description provided for @settingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'应用设置'**
  String get settingsTitle;

  /// No description provided for @settingsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'统一管理应用外观、点名台行为、主控显示、服务器账户和本机数据。'**
  String get settingsSubtitle;

  /// No description provided for @settingsAppearanceTitle.
  ///
  /// In zh, this message translates to:
  /// **'外观与语言'**
  String get settingsAppearanceTitle;

  /// No description provided for @settingsAppearanceHint.
  ///
  /// In zh, this message translates to:
  /// **'选择主题、字体和界面语言；修改后立即应用。'**
  String get settingsAppearanceHint;

  /// No description provided for @themeColorSetting.
  ///
  /// In zh, this message translates to:
  /// **'主题颜色'**
  String get themeColorSetting;

  /// No description provided for @themeColorSettingHint.
  ///
  /// In zh, this message translates to:
  /// **'设置应用按钮、选中状态与强调内容的主色调。'**
  String get themeColorSettingHint;

  /// No description provided for @chooseThemeColor.
  ///
  /// In zh, this message translates to:
  /// **'选择颜色'**
  String get chooseThemeColor;

  /// No description provided for @darkModeSetting.
  ///
  /// In zh, this message translates to:
  /// **'深色模式'**
  String get darkModeSetting;

  /// No description provided for @darkModeSettingHint.
  ///
  /// In zh, this message translates to:
  /// **'切换应用的明暗配色。'**
  String get darkModeSettingHint;

  /// No description provided for @appFontSetting.
  ///
  /// In zh, this message translates to:
  /// **'应用字体'**
  String get appFontSetting;

  /// No description provided for @appFontSettingHint.
  ///
  /// In zh, this message translates to:
  /// **'选择界面显示字体。'**
  String get appFontSettingHint;

  /// No description provided for @appLanguageSetting.
  ///
  /// In zh, this message translates to:
  /// **'界面语言'**
  String get appLanguageSetting;

  /// No description provided for @appLanguageSettingHint.
  ///
  /// In zh, this message translates to:
  /// **'可跟随系统，也可固定为简体中文或 English。'**
  String get appLanguageSettingHint;

  /// No description provided for @languageFollowSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get languageFollowSystem;

  /// No description provided for @languageSimplifiedChinese.
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get languageSimplifiedChinese;

  /// No description provided for @languageEnglish.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @layoutSettingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'点名台与布局'**
  String get layoutSettingsTitle;

  /// No description provided for @layoutSettingsHint.
  ///
  /// In zh, this message translates to:
  /// **'调整点名台宽度、分页和录入辅助行为。'**
  String get layoutSettingsHint;

  /// No description provided for @paginationSetting.
  ///
  /// In zh, this message translates to:
  /// **'分页显示记录'**
  String get paginationSetting;

  /// No description provided for @paginationSettingHint.
  ///
  /// In zh, this message translates to:
  /// **'将记录分页显示，每页条数可配置。'**
  String get paginationSettingHint;

  /// No description provided for @tablePageSizeLabel.
  ///
  /// In zh, this message translates to:
  /// **'每页记录数'**
  String get tablePageSizeLabel;

  /// No description provided for @tablePageSizeHint.
  ///
  /// In zh, this message translates to:
  /// **'已保存记录表格每页显示的数量'**
  String get tablePageSizeHint;

  /// No description provided for @recordEditorDialogSetting.
  ///
  /// In zh, this message translates to:
  /// **'弹窗编辑记录'**
  String get recordEditorDialogSetting;

  /// No description provided for @recordEditorDialogSettingHint.
  ///
  /// In zh, this message translates to:
  /// **'编辑记录时以弹窗打开完整表单，支持词库联想。关闭后改为在表格内联编辑。'**
  String get recordEditorDialogSettingHint;

  /// No description provided for @controllerDisplaySettingsHint.
  ///
  /// In zh, this message translates to:
  /// **'配置主控设备入口、独立窗口和默认显示内容。'**
  String get controllerDisplaySettingsHint;

  /// No description provided for @serverSettingsHint.
  ///
  /// In zh, this message translates to:
  /// **'配置协作服务器并管理当前账户和登录设备。'**
  String get serverSettingsHint;

  /// No description provided for @settingsSupportTitle.
  ///
  /// In zh, this message translates to:
  /// **'应用信息与设置维护'**
  String get settingsSupportTitle;

  /// No description provided for @settingsSupportHint.
  ///
  /// In zh, this message translates to:
  /// **'查看版本与开源信息，或恢复界面和录入偏好。'**
  String get settingsSupportHint;

  /// No description provided for @restoreDefaultSettingsHint.
  ///
  /// In zh, this message translates to:
  /// **'恢复外观、语言、布局和导出偏好，不影响记录与登录状态。'**
  String get restoreDefaultSettingsHint;

  /// No description provided for @logsTitle.
  ///
  /// In zh, this message translates to:
  /// **'日志'**
  String get logsTitle;

  /// No description provided for @logsView.
  ///
  /// In zh, this message translates to:
  /// **'查看持久化诊断日志、错误与应用内消息'**
  String get logsView;

  /// No description provided for @logsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'（暂无日志）'**
  String get logsEmpty;

  /// No description provided for @logsCopy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get logsCopy;

  /// No description provided for @logsClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get logsClose;

  /// No description provided for @logsCopied.
  ///
  /// In zh, this message translates to:
  /// **'日志已复制'**
  String get logsCopied;

  /// No description provided for @logsCount.
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 条持久化日志'**
  String logsCount(int count);

  /// No description provided for @logsSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索消息、来源、错误或堆栈'**
  String get logsSearchHint;

  /// No description provided for @logsLevelAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get logsLevelAll;

  /// No description provided for @logsLevelDebug.
  ///
  /// In zh, this message translates to:
  /// **'调试'**
  String get logsLevelDebug;

  /// No description provided for @logsLevelInfo.
  ///
  /// In zh, this message translates to:
  /// **'信息'**
  String get logsLevelInfo;

  /// No description provided for @logsLevelWarning.
  ///
  /// In zh, this message translates to:
  /// **'警告'**
  String get logsLevelWarning;

  /// No description provided for @logsLevelError.
  ///
  /// In zh, this message translates to:
  /// **'错误'**
  String get logsLevelError;

  /// No description provided for @logsClear.
  ///
  /// In zh, this message translates to:
  /// **'清空'**
  String get logsClear;

  /// No description provided for @logsClearTitle.
  ///
  /// In zh, this message translates to:
  /// **'清空诊断日志'**
  String get logsClearTitle;

  /// No description provided for @logsClearConfirmation.
  ///
  /// In zh, this message translates to:
  /// **'将删除本机保存的全部诊断日志。此操作不会影响点名记录，确定继续吗？'**
  String get logsClearConfirmation;

  /// No description provided for @logsCleared.
  ///
  /// In zh, this message translates to:
  /// **'诊断日志已清空'**
  String get logsCleared;

  /// No description provided for @logsNoFilterResults.
  ///
  /// In zh, this message translates to:
  /// **'没有符合当前筛选条件的日志'**
  String get logsNoFilterResults;

  /// No description provided for @authSessionExpiredNotice.
  ///
  /// In zh, this message translates to:
  /// **'服务器登录状态已失效，请重新登录。本机数据和服务器地址均已保留。'**
  String get authSessionExpiredNotice;

  /// No description provided for @authStorageUnavailableNotice.
  ///
  /// In zh, this message translates to:
  /// **'无法读取持久登录凭据，请检查系统凭据存储后重新登录。'**
  String get authStorageUnavailableNotice;

  /// No description provided for @resetSettingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认设置'**
  String get resetSettingsTitle;

  /// No description provided for @resetSettingsConfirmation.
  ///
  /// In zh, this message translates to:
  /// **'将外观、语言、布局和导出偏好恢复为默认值。本机记录、词库、服务器账户与登录状态不受影响。'**
  String get resetSettingsConfirmation;

  /// No description provided for @resetSettingsConfirmAction.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认'**
  String get resetSettingsConfirmAction;

  /// No description provided for @resetSettingsSucceeded.
  ///
  /// In zh, this message translates to:
  /// **'已恢复默认设置'**
  String get resetSettingsSucceeded;

  /// No description provided for @resetSettingsFailed.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认设置失败：{error}'**
  String resetSettingsFailed(String error);

  /// No description provided for @localDataOperationsTitle.
  ///
  /// In zh, this message translates to:
  /// **'本机数据'**
  String get localDataOperationsTitle;

  /// No description provided for @localDataOperationsHint.
  ///
  /// In zh, this message translates to:
  /// **'管理本机数据库的诊断、备份与重置；这些操作不会直接修改服务器数据。'**
  String get localDataOperationsHint;

  /// No description provided for @databaseDiagnosticsSection.
  ///
  /// In zh, this message translates to:
  /// **'诊断'**
  String get databaseDiagnosticsSection;

  /// No description provided for @databaseBackupSection.
  ///
  /// In zh, this message translates to:
  /// **'备份与恢复'**
  String get databaseBackupSection;

  /// No description provided for @personalCloudTitle.
  ///
  /// In zh, this message translates to:
  /// **'个人云同步'**
  String get personalCloudTitle;

  /// No description provided for @personalCloudHint.
  ///
  /// In zh, this message translates to:
  /// **'个人会话、点名记录和词库改动会在已登录设备间自动双向同步；协作会话仍使用独立的实时协作流程。'**
  String get personalCloudHint;

  /// No description provided for @personalCloudSignedOut.
  ///
  /// In zh, this message translates to:
  /// **'登录服务器后自动同步个人记录和词库改动'**
  String get personalCloudSignedOut;

  /// No description provided for @personalCloudUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'当前服务器版本不支持账户个人云快照，请先升级服务器'**
  String get personalCloudUnsupported;

  /// No description provided for @personalCloudChecking.
  ///
  /// In zh, this message translates to:
  /// **'正在核对本机记录、词库与账户云快照…'**
  String get personalCloudChecking;

  /// No description provided for @personalCloudSyncing.
  ///
  /// In zh, this message translates to:
  /// **'正在同步个人记录和词库改动…'**
  String get personalCloudSyncing;

  /// No description provided for @personalCloudUpToDate.
  ///
  /// In zh, this message translates to:
  /// **'个人记录和词库改动均已同步'**
  String get personalCloudUpToDate;

  /// No description provided for @personalCloudDecisionRequired.
  ///
  /// In zh, this message translates to:
  /// **'首次配对或真实编辑冲突需要确认；互不冲突的改动已安全合并。'**
  String get personalCloudDecisionRequired;

  /// No description provided for @personalCloudError.
  ///
  /// In zh, this message translates to:
  /// **'账户个人云快照同步失败：{error}'**
  String personalCloudError(String error);

  /// No description provided for @personalCloudLocalSummary.
  ///
  /// In zh, this message translates to:
  /// **'本机个人记录：{sessionCount} 场、{logCount} 条'**
  String personalCloudLocalSummary(int sessionCount, int logCount);

  /// No description provided for @personalCloudRemoteSummary.
  ///
  /// In zh, this message translates to:
  /// **'账户云快照：{sessionCount} 场、{logCount} 条 · 修订 {revision}'**
  String personalCloudRemoteSummary(
      int sessionCount, int logCount, int revision);

  /// No description provided for @personalCloudRemoteEmpty.
  ///
  /// In zh, this message translates to:
  /// **'当前账户还没有个人云快照'**
  String get personalCloudRemoteEmpty;

  /// No description provided for @personalCloudDictionaryLocalSummary.
  ///
  /// In zh, this message translates to:
  /// **'本机词库改动：{itemCount} 项'**
  String personalCloudDictionaryLocalSummary(int itemCount);

  /// No description provided for @personalCloudDictionaryRemoteSummary.
  ///
  /// In zh, this message translates to:
  /// **'账户词库快照：{itemCount} 项改动 · 修订 {revision}'**
  String personalCloudDictionaryRemoteSummary(int itemCount, int revision);

  /// No description provided for @personalCloudDictionaryRemoteEmpty.
  ///
  /// In zh, this message translates to:
  /// **'当前账户还没有词库快照'**
  String get personalCloudDictionaryRemoteEmpty;

  /// No description provided for @personalCloudConflictSummary.
  ///
  /// In zh, this message translates to:
  /// **'有 {count} 个冲突字段需要选择'**
  String personalCloudConflictSummary(int count);

  /// No description provided for @personalCloudConfirmMerge.
  ///
  /// In zh, this message translates to:
  /// **'确认安全合并'**
  String get personalCloudConfirmMerge;

  /// No description provided for @personalCloudKeepLocalConflicts.
  ///
  /// In zh, this message translates to:
  /// **'冲突项保留本机值'**
  String get personalCloudKeepLocalConflicts;

  /// No description provided for @personalCloudKeepRemoteConflicts.
  ///
  /// In zh, this message translates to:
  /// **'冲突项保留云端值'**
  String get personalCloudKeepRemoteConflicts;

  /// No description provided for @personalCloudResolveOneByOne.
  ///
  /// In zh, this message translates to:
  /// **'逐项处理'**
  String get personalCloudResolveOneByOne;

  /// No description provided for @personalCloudConflictDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'逐项处理冲突'**
  String get personalCloudConflictDialogTitle;

  /// No description provided for @personalCloudConflictPageTitle.
  ///
  /// In zh, this message translates to:
  /// **'个人云同步冲突'**
  String get personalCloudConflictPageTitle;

  /// No description provided for @personalCloudConflictPageHint.
  ///
  /// In zh, this message translates to:
  /// **'逐项比较本机、云端和共同基线。每个冲突都必须由你明确选择后才会合并；协作会话冲突仍在会话页处理。'**
  String get personalCloudConflictPageHint;

  /// No description provided for @personalCloudConflictSelectAllLocal.
  ///
  /// In zh, this message translates to:
  /// **'全部选本机'**
  String get personalCloudConflictSelectAllLocal;

  /// No description provided for @personalCloudConflictSelectAllRemote.
  ///
  /// In zh, this message translates to:
  /// **'全部选云端'**
  String get personalCloudConflictSelectAllRemote;

  /// No description provided for @personalCloudConflictSelectionProgress.
  ///
  /// In zh, this message translates to:
  /// **'已选择 {selected}/{total} 项；全部选择后才能应用。'**
  String personalCloudConflictSelectionProgress(int selected, int total);

  /// No description provided for @personalCloudConflictApply.
  ///
  /// In zh, this message translates to:
  /// **'应用选择'**
  String get personalCloudConflictApply;

  /// No description provided for @personalCloudConflictApplySucceeded.
  ///
  /// In zh, this message translates to:
  /// **'冲突选择已应用并完成同步'**
  String get personalCloudConflictApplySucceeded;

  /// No description provided for @personalCloudConflictNoneTitle.
  ///
  /// In zh, this message translates to:
  /// **'当前没有同步冲突'**
  String get personalCloudConflictNoneTitle;

  /// No description provided for @personalCloudConflictNoneHint.
  ///
  /// In zh, this message translates to:
  /// **'个人记录和词库没有需要人工选择的冲突。同步状态与手动同步入口位于本地数据库页面。'**
  String get personalCloudConflictNoneHint;

  /// No description provided for @personalCloudConflictConfirmationPendingTitle.
  ///
  /// In zh, this message translates to:
  /// **'没有字段冲突，但仍需确认首次合并'**
  String get personalCloudConflictConfirmationPendingTitle;

  /// No description provided for @personalCloudConflictConfirmationPendingHint.
  ///
  /// In zh, this message translates to:
  /// **'返回本地数据库页面核对本机与云端数量，再确认安全合并。'**
  String get personalCloudConflictConfirmationPendingHint;

  /// No description provided for @personalCloudConflictRecordsDataset.
  ///
  /// In zh, this message translates to:
  /// **'个人记录'**
  String get personalCloudConflictRecordsDataset;

  /// No description provided for @personalCloudConflictDictionaryDataset.
  ///
  /// In zh, this message translates to:
  /// **'个人词库'**
  String get personalCloudConflictDictionaryDataset;

  /// No description provided for @personalCloudConflictEntityReference.
  ///
  /// In zh, this message translates to:
  /// **'{dataset} · 标识 {id}'**
  String personalCloudConflictEntityReference(String dataset, String id);

  /// No description provided for @personalCloudConflictBaseline.
  ///
  /// In zh, this message translates to:
  /// **'共同基线'**
  String get personalCloudConflictBaseline;

  /// No description provided for @personalCloudConflictValueAbsent.
  ///
  /// In zh, this message translates to:
  /// **'不存在（选择此侧将删除该项）'**
  String get personalCloudConflictValueAbsent;

  /// No description provided for @personalCloudConflictValueEmpty.
  ///
  /// In zh, this message translates to:
  /// **'空值'**
  String get personalCloudConflictValueEmpty;

  /// No description provided for @personalCloudConflictLifecycleField.
  ///
  /// In zh, this message translates to:
  /// **'会话状态'**
  String get personalCloudConflictLifecycleField;

  /// No description provided for @personalCloudConflictDeletionField.
  ///
  /// In zh, this message translates to:
  /// **'删除状态'**
  String get personalCloudConflictDeletionField;

  /// No description provided for @personalCloudConflictDictionaryStateField.
  ///
  /// In zh, this message translates to:
  /// **'词库状态'**
  String get personalCloudConflictDictionaryStateField;

  /// No description provided for @personalCloudFieldConflictTitle.
  ///
  /// In zh, this message translates to:
  /// **'字段 {field} 双方都有值且不同'**
  String personalCloudFieldConflictTitle(String field);

  /// No description provided for @personalCloudEntityConflictTitle.
  ///
  /// In zh, this message translates to:
  /// **'{entity} 冲突'**
  String personalCloudEntityConflictTitle(String entity);

  /// No description provided for @personalCloudEntitySession.
  ///
  /// In zh, this message translates to:
  /// **'会话'**
  String get personalCloudEntitySession;

  /// No description provided for @personalCloudEntityLog.
  ///
  /// In zh, this message translates to:
  /// **'记录'**
  String get personalCloudEntityLog;

  /// No description provided for @personalCloudEntityDictionaryItem.
  ///
  /// In zh, this message translates to:
  /// **'词库项'**
  String get personalCloudEntityDictionaryItem;

  /// No description provided for @personalCloudKeepLocal.
  ///
  /// In zh, this message translates to:
  /// **'保留本机'**
  String get personalCloudKeepLocal;

  /// No description provided for @personalCloudKeepRemote.
  ///
  /// In zh, this message translates to:
  /// **'保留云端'**
  String get personalCloudKeepRemote;

  /// No description provided for @personalCloudSyncNow.
  ///
  /// In zh, this message translates to:
  /// **'同步个人快照'**
  String get personalCloudSyncNow;

  /// No description provided for @personalCloudReplaceRemote.
  ///
  /// In zh, this message translates to:
  /// **'以本机替换云快照'**
  String get personalCloudReplaceRemote;

  /// No description provided for @personalCloudRestoreLocal.
  ///
  /// In zh, this message translates to:
  /// **'从云快照恢复本机'**
  String get personalCloudRestoreLocal;

  /// No description provided for @personalCloudReplaceTitle.
  ///
  /// In zh, this message translates to:
  /// **'替换账户个人云快照'**
  String get personalCloudReplaceTitle;

  /// No description provided for @personalCloudReplaceWarning.
  ///
  /// In zh, this message translates to:
  /// **'将以本机 {localSessions} 场、{localLogs} 条个人记录完整替换账户云快照中的 {remoteSessions} 场、{remoteLogs} 条记录。不会写入或修改协作会话；此操作会同步到其他已登录设备。'**
  String personalCloudReplaceWarning(
      int localSessions, int localLogs, int remoteSessions, int remoteLogs);

  /// No description provided for @personalCloudReplacePhrase.
  ///
  /// In zh, this message translates to:
  /// **'用本机记录替换账户云快照'**
  String get personalCloudReplacePhrase;

  /// No description provided for @personalCloudReplaceAction.
  ///
  /// In zh, this message translates to:
  /// **'确认替换云快照'**
  String get personalCloudReplaceAction;

  /// No description provided for @personalCloudRestoreTitle.
  ///
  /// In zh, this message translates to:
  /// **'从账户个人云快照恢复'**
  String get personalCloudRestoreTitle;

  /// No description provided for @personalCloudRestoreWarning.
  ///
  /// In zh, this message translates to:
  /// **'将以账户云快照中的 {remoteSessions} 场、{remoteLogs} 条记录替换本机的 {localSessions} 场、{localLogs} 条个人记录。词库、设置和协作会话不受影响。'**
  String personalCloudRestoreWarning(
      int remoteSessions, int remoteLogs, int localSessions, int localLogs);

  /// No description provided for @personalCloudRestorePhrase.
  ///
  /// In zh, this message translates to:
  /// **'用账户云快照替换本机记录'**
  String get personalCloudRestorePhrase;

  /// No description provided for @personalCloudRestoreAction.
  ///
  /// In zh, this message translates to:
  /// **'确认恢复本机'**
  String get personalCloudRestoreAction;

  /// No description provided for @personalCloudReplaceSucceeded.
  ///
  /// In zh, this message translates to:
  /// **'账户云快照已保存本机个人记录'**
  String get personalCloudReplaceSucceeded;

  /// No description provided for @personalCloudRestoreSucceeded.
  ///
  /// In zh, this message translates to:
  /// **'已从账户云快照恢复本机个人记录'**
  String get personalCloudRestoreSucceeded;

  /// No description provided for @databaseDangerZoneSection.
  ///
  /// In zh, this message translates to:
  /// **'危险操作'**
  String get databaseDangerZoneSection;

  /// No description provided for @databaseStatusTitle.
  ///
  /// In zh, this message translates to:
  /// **'本机数据库状态'**
  String get databaseStatusTitle;

  /// No description provided for @databaseStatusHint.
  ///
  /// In zh, this message translates to:
  /// **'查看本机内容、协作待办和高级数据库诊断'**
  String get databaseStatusHint;

  /// No description provided for @databaseStatusSchemaVersion.
  ///
  /// In zh, this message translates to:
  /// **'数据库结构版本：{version}'**
  String databaseStatusSchemaVersion(String version);

  /// No description provided for @databaseStatusBackupFormatVersion.
  ///
  /// In zh, this message translates to:
  /// **'备份格式版本：{version}'**
  String databaseStatusBackupFormatVersion(String version);

  /// No description provided for @databaseStatusLocalContentSection.
  ///
  /// In zh, this message translates to:
  /// **'本机内容'**
  String get databaseStatusLocalContentSection;

  /// No description provided for @databaseStatusLocalContentHint.
  ///
  /// In zh, this message translates to:
  /// **'仅统计本机数据库中的会话、点名记录和词库内容'**
  String get databaseStatusLocalContentHint;

  /// No description provided for @databaseStatusSessionsLabel.
  ///
  /// In zh, this message translates to:
  /// **'会话'**
  String get databaseStatusSessionsLabel;

  /// No description provided for @databaseStatusSessionsSummary.
  ///
  /// In zh, this message translates to:
  /// **'进行中 {active} · 已关闭 {closed} · 已归档 {archived} · 已删除 {deleted}'**
  String databaseStatusSessionsSummary(
      int active, int closed, int archived, int deleted);

  /// No description provided for @databaseStatusLogsLabel.
  ///
  /// In zh, this message translates to:
  /// **'点名记录'**
  String get databaseStatusLogsLabel;

  /// No description provided for @databaseStatusDictionariesLabel.
  ///
  /// In zh, this message translates to:
  /// **'词库条目'**
  String get databaseStatusDictionariesLabel;

  /// No description provided for @databaseStatusLifecycleSummary.
  ///
  /// In zh, this message translates to:
  /// **'可用 {active} · 已删除 {deleted}'**
  String databaseStatusLifecycleSummary(int active, int deleted);

  /// No description provided for @databaseStatusDictionarySummary.
  ///
  /// In zh, this message translates to:
  /// **'{label} {active}（已删除 {deleted}）'**
  String databaseStatusDictionarySummary(String label, int active, int deleted);

  /// No description provided for @databaseStatusDictionaryDevice.
  ///
  /// In zh, this message translates to:
  /// **'设备'**
  String get databaseStatusDictionaryDevice;

  /// No description provided for @databaseStatusDictionaryAntenna.
  ///
  /// In zh, this message translates to:
  /// **'天线'**
  String get databaseStatusDictionaryAntenna;

  /// No description provided for @databaseStatusDictionaryQth.
  ///
  /// In zh, this message translates to:
  /// **'QTH'**
  String get databaseStatusDictionaryQth;

  /// No description provided for @databaseStatusDictionaryCallsign.
  ///
  /// In zh, this message translates to:
  /// **'呼号'**
  String get databaseStatusDictionaryCallsign;

  /// No description provided for @databaseStatusCollaborationSection.
  ///
  /// In zh, this message translates to:
  /// **'协作状态'**
  String get databaseStatusCollaborationSection;

  /// No description provided for @databaseStatusCollaborationHint.
  ///
  /// In zh, this message translates to:
  /// **'这些数字是本机协作副本和同步队列，不代表云端全部数据'**
  String get databaseStatusCollaborationHint;

  /// No description provided for @databaseStatusCollaborationHealthy.
  ///
  /// In zh, this message translates to:
  /// **'当前没有待上传记录、未解决冲突或离线记录'**
  String get databaseStatusCollaborationHealthy;

  /// No description provided for @databaseStatusCollaborationPending.
  ///
  /// In zh, this message translates to:
  /// **'本机仍有协作内容需要同步或处理'**
  String get databaseStatusCollaborationPending;

  /// No description provided for @databaseStatusBindingsLabel.
  ///
  /// In zh, this message translates to:
  /// **'协作会话副本'**
  String get databaseStatusBindingsLabel;

  /// No description provided for @databaseStatusPendingOutboxLabel.
  ///
  /// In zh, this message translates to:
  /// **'待上传操作'**
  String get databaseStatusPendingOutboxLabel;

  /// No description provided for @databaseStatusOpenConflictsLabel.
  ///
  /// In zh, this message translates to:
  /// **'未解决冲突'**
  String get databaseStatusOpenConflictsLabel;

  /// No description provided for @databaseStatusOfflineRecordsLabel.
  ///
  /// In zh, this message translates to:
  /// **'待处理离线记录'**
  String get databaseStatusOfflineRecordsLabel;

  /// No description provided for @databaseStatusDraftCachesLabel.
  ///
  /// In zh, this message translates to:
  /// **'点名草稿缓存'**
  String get databaseStatusDraftCachesLabel;

  /// No description provided for @databaseStatusAdvancedTitle.
  ///
  /// In zh, this message translates to:
  /// **'高级：原始表计数'**
  String get databaseStatusAdvancedTitle;

  /// No description provided for @databaseStatusAdvancedHint.
  ///
  /// In zh, this message translates to:
  /// **'仅用于故障诊断；基础设施表为 0 通常是正常状态'**
  String get databaseStatusAdvancedHint;

  /// No description provided for @databaseStatusUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get databaseStatusUnknown;

  /// No description provided for @databaseStatusLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'读取本机数据库状态失败：{error}'**
  String databaseStatusLoadFailed(String error);

  /// No description provided for @databaseExportTitle.
  ///
  /// In zh, this message translates to:
  /// **'导出本机数据库'**
  String get databaseExportTitle;

  /// No description provided for @databaseExportHint.
  ///
  /// In zh, this message translates to:
  /// **'备份会话、记录、词库以及本机协作副本和待同步状态'**
  String get databaseExportHint;

  /// No description provided for @databaseExportDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'保存 OpenLogTool 本机数据库备份'**
  String get databaseExportDialogTitle;

  /// No description provided for @databaseExportSucceeded.
  ///
  /// In zh, this message translates to:
  /// **'本机数据库备份已导出'**
  String get databaseExportSucceeded;

  /// No description provided for @databaseExportFailed.
  ///
  /// In zh, this message translates to:
  /// **'导出本机数据库失败：{error}'**
  String databaseExportFailed(String error);

  /// No description provided for @databaseImportTitle.
  ///
  /// In zh, this message translates to:
  /// **'导入本机数据库'**
  String get databaseImportTitle;

  /// No description provided for @databaseImportHint.
  ///
  /// In zh, this message translates to:
  /// **'选择 JSON 备份并预览后，完整替换当前本机数据库'**
  String get databaseImportHint;

  /// No description provided for @databaseImportPickerTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择 OpenLogTool 本机数据库备份'**
  String get databaseImportPickerTitle;

  /// No description provided for @databaseImportNoFileSelected.
  ///
  /// In zh, this message translates to:
  /// **'未选择备份文件，未执行导入'**
  String get databaseImportNoFileSelected;

  /// No description provided for @databaseImportPreviewTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认导入备份'**
  String get databaseImportPreviewTitle;

  /// No description provided for @databaseImportBackupVersion.
  ///
  /// In zh, this message translates to:
  /// **'备份格式版本'**
  String get databaseImportBackupVersion;

  /// No description provided for @databaseImportExportedAt.
  ///
  /// In zh, this message translates to:
  /// **'导出时间'**
  String get databaseImportExportedAt;

  /// No description provided for @databaseImportUnknownTime.
  ///
  /// In zh, this message translates to:
  /// **'未记录'**
  String get databaseImportUnknownTime;

  /// No description provided for @databaseImportSessionCount.
  ///
  /// In zh, this message translates to:
  /// **'会话'**
  String get databaseImportSessionCount;

  /// No description provided for @databaseImportLogCount.
  ///
  /// In zh, this message translates to:
  /// **'点名记录'**
  String get databaseImportLogCount;

  /// No description provided for @databaseImportDictionaryCount.
  ///
  /// In zh, this message translates to:
  /// **'词库条目'**
  String get databaseImportDictionaryCount;

  /// No description provided for @databaseImportCollaborationCount.
  ///
  /// In zh, this message translates to:
  /// **'协作副本'**
  String get databaseImportCollaborationCount;

  /// No description provided for @databaseImportPendingSyncCount.
  ///
  /// In zh, this message translates to:
  /// **'待同步/待复核项'**
  String get databaseImportPendingSyncCount;

  /// No description provided for @databaseImportPreviewWarning.
  ///
  /// In zh, this message translates to:
  /// **'导入会完整覆盖当前本机数据库，包括未同步更改。服务器上的会话、安全存储中的登录凭据和应用设置不受影响。内置词库将按当前版本补齐。此操作不可撤销。'**
  String get databaseImportPreviewWarning;

  /// No description provided for @databaseImportCollaborationWarning.
  ///
  /// In zh, this message translates to:
  /// **'此备份包含本机协作副本。当服务器地址和登录账户匹配时，导入后可能继续同步。'**
  String get databaseImportCollaborationWarning;

  /// No description provided for @databaseImportConfirmAction.
  ///
  /// In zh, this message translates to:
  /// **'覆盖并导入'**
  String get databaseImportConfirmAction;

  /// No description provided for @databaseImportSucceeded.
  ///
  /// In zh, this message translates to:
  /// **'本机数据库已导入，界面数据已刷新'**
  String get databaseImportSucceeded;

  /// No description provided for @databaseImportSucceededSummary.
  ///
  /// In zh, this message translates to:
  /// **'本机数据库已导入：{sessionCount} 场会话、{logCount} 条记录；可在会话页查看历史会话'**
  String databaseImportSucceededSummary(int sessionCount, int logCount);

  /// No description provided for @databaseImportInvalid.
  ///
  /// In zh, this message translates to:
  /// **'所选文件不是有效的 OpenLogTool 数据库备份（{error}）'**
  String databaseImportInvalid(String error);

  /// No description provided for @databaseImportReadFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法读取所选备份：{error}'**
  String databaseImportReadFailed(String error);

  /// No description provided for @databaseImportFailed.
  ///
  /// In zh, this message translates to:
  /// **'导入本机数据库失败：{error}'**
  String databaseImportFailed(String error);

  /// No description provided for @databaseClearTitle.
  ///
  /// In zh, this message translates to:
  /// **'清空本机数据'**
  String get databaseClearTitle;

  /// No description provided for @databaseClearHint.
  ///
  /// In zh, this message translates to:
  /// **'清除本机记录、协作副本和自定义词条，并恢复内置词库默认内容'**
  String get databaseClearHint;

  /// No description provided for @databaseClearWarning.
  ///
  /// In zh, this message translates to:
  /// **'此操作不可撤销。将清除本机的所有会话、点名记录、协作副本、待同步队列和自定义词条；不会删除或关闭服务器会话，也不会退出登录或重置外观。内置词库会恢复为默认内容。'**
  String get databaseClearWarning;

  /// No description provided for @databaseClearConfirmationPhrase.
  ///
  /// In zh, this message translates to:
  /// **'清空全部数据'**
  String get databaseClearConfirmationPhrase;

  /// No description provided for @databaseClearConfirmationInstruction.
  ///
  /// In zh, this message translates to:
  /// **'请输入“{phrase}”以确认：'**
  String databaseClearConfirmationInstruction(String phrase);

  /// No description provided for @databaseClearConfirmationLabel.
  ///
  /// In zh, this message translates to:
  /// **'确认文本'**
  String get databaseClearConfirmationLabel;

  /// No description provided for @databaseClearConfirmAction.
  ///
  /// In zh, this message translates to:
  /// **'永久清空本机数据'**
  String get databaseClearConfirmAction;

  /// No description provided for @databaseClearSucceeded.
  ///
  /// In zh, this message translates to:
  /// **'本机数据已清空，内置词库已恢复为默认内容'**
  String get databaseClearSucceeded;

  /// No description provided for @databaseClearFailed.
  ///
  /// In zh, this message translates to:
  /// **'清空本机数据失败：{error}'**
  String databaseClearFailed(String error);

  /// No description provided for @databaseReplacementRefreshFailed.
  ///
  /// In zh, this message translates to:
  /// **'操作已写入本机数据库，但界面刷新或内置词库恢复失败。请返回会话页后重试；如仍异常再重启应用。'**
  String get databaseReplacementRefreshFailed;

  /// No description provided for @databaseMaintenanceCollaborationBusy.
  ///
  /// In zh, this message translates to:
  /// **'当前正在发布、加入或处理其他协作操作，请等待操作结束后再管理本机数据库。'**
  String get databaseMaintenanceCollaborationBusy;

  /// No description provided for @localCollaborationOperationBusy.
  ///
  /// In zh, this message translates to:
  /// **'另一项协作操作仍在进行，请等待结束后重试。'**
  String get localCollaborationOperationBusy;

  /// No description provided for @localCollaborationRequired.
  ///
  /// In zh, this message translates to:
  /// **'当前会话已不是本机协作副本，请刷新页面后重试。'**
  String get localCollaborationRequired;

  /// No description provided for @dataTransferTitle.
  ///
  /// In zh, this message translates to:
  /// **'数据导入与导出'**
  String get dataTransferTitle;

  /// No description provided for @dataTransferSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'备份、迁移或分享当前会话的点名记录，并配置 Excel 输出样式。'**
  String get dataTransferSubtitle;

  /// No description provided for @dataTransferActionsTitle.
  ///
  /// In zh, this message translates to:
  /// **'记录文件'**
  String get dataTransferActionsTitle;

  /// No description provided for @dataTransferActionsHint.
  ///
  /// In zh, this message translates to:
  /// **'JSON 适合完整数据迁移，Excel 适合查看、分享和打印。'**
  String get dataTransferActionsHint;

  /// No description provided for @exportDataTitle.
  ///
  /// In zh, this message translates to:
  /// **'导出数据'**
  String get exportDataTitle;

  /// No description provided for @exportDataHint.
  ///
  /// In zh, this message translates to:
  /// **'将当前会话中的点名记录导出为文件'**
  String get exportDataHint;

  /// No description provided for @exportJson.
  ///
  /// In zh, this message translates to:
  /// **'导出 JSON'**
  String get exportJson;

  /// No description provided for @exportExcel.
  ///
  /// In zh, this message translates to:
  /// **'导出 Excel'**
  String get exportExcel;

  /// No description provided for @importDataTitle.
  ///
  /// In zh, this message translates to:
  /// **'导入数据'**
  String get importDataTitle;

  /// No description provided for @importDataHint.
  ///
  /// In zh, this message translates to:
  /// **'从文件导入点名记录到当前会话'**
  String get importDataHint;

  /// No description provided for @importJson.
  ///
  /// In zh, this message translates to:
  /// **'导入 JSON'**
  String get importJson;

  /// No description provided for @importExcel.
  ///
  /// In zh, this message translates to:
  /// **'导入 Excel'**
  String get importExcel;

  /// No description provided for @excelConfigurationOverview.
  ///
  /// In zh, this message translates to:
  /// **'Excel 配置概览'**
  String get excelConfigurationOverview;

  /// No description provided for @excelConfigurationOverviewHint.
  ///
  /// In zh, this message translates to:
  /// **'此处展示当前配置；交替行可直接切换，其他选项请打开编辑设置。'**
  String get excelConfigurationOverviewHint;

  /// No description provided for @editSettings.
  ///
  /// In zh, this message translates to:
  /// **'编辑设置'**
  String get editSettings;

  /// No description provided for @fileNameTemplate.
  ///
  /// In zh, this message translates to:
  /// **'文件名模板'**
  String get fileNameTemplate;

  /// No description provided for @excelHeader.
  ///
  /// In zh, this message translates to:
  /// **'Excel 抬头'**
  String get excelHeader;

  /// No description provided for @exportPath.
  ///
  /// In zh, this message translates to:
  /// **'导出路径'**
  String get exportPath;

  /// No description provided for @systemDownloadsDirectory.
  ///
  /// In zh, this message translates to:
  /// **'系统下载目录'**
  String get systemDownloadsDirectory;

  /// No description provided for @headerBackground.
  ///
  /// In zh, this message translates to:
  /// **'抬头背景'**
  String get headerBackground;

  /// No description provided for @tableHeaderBackground.
  ///
  /// In zh, this message translates to:
  /// **'表头背景'**
  String get tableHeaderBackground;

  /// No description provided for @controllerRow.
  ///
  /// In zh, this message translates to:
  /// **'主控行'**
  String get controllerRow;

  /// No description provided for @alternatingRows.
  ///
  /// In zh, this message translates to:
  /// **'交替行'**
  String get alternatingRows;

  /// No description provided for @fileFormatInformation.
  ///
  /// In zh, this message translates to:
  /// **'文件格式说明'**
  String get fileFormatInformation;

  /// No description provided for @jsonFormatDescription.
  ///
  /// In zh, this message translates to:
  /// **'JSON：标准 JSON 数组，包含所有字段数据，适合备份与跨应用迁移。'**
  String get jsonFormatDescription;

  /// No description provided for @excelFormatDescription.
  ///
  /// In zh, this message translates to:
  /// **'Excel：使用 .xlsx 格式，包含分组主控行、颜色样式和底部信息，适合分享与打印。'**
  String get excelFormatDescription;

  /// No description provided for @excelExportSettingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑 Excel 导出设置'**
  String get excelExportSettingsTitle;

  /// No description provided for @fileTab.
  ///
  /// In zh, this message translates to:
  /// **'文件'**
  String get fileTab;

  /// No description provided for @tableStyleTab.
  ///
  /// In zh, this message translates to:
  /// **'表格样式'**
  String get tableStyleTab;

  /// No description provided for @templateVariablesTab.
  ///
  /// In zh, this message translates to:
  /// **'模板变量'**
  String get templateVariablesTab;

  /// No description provided for @exportSettingsSaved.
  ///
  /// In zh, this message translates to:
  /// **'导出设置已保存'**
  String get exportSettingsSaved;

  /// No description provided for @select.
  ///
  /// In zh, this message translates to:
  /// **'选择'**
  String get select;

  /// No description provided for @exportPathDefaultHint.
  ///
  /// In zh, this message translates to:
  /// **'留空时使用系统下载目录'**
  String get exportPathDefaultHint;

  /// No description provided for @fileNameTemplateExample.
  ///
  /// In zh, this message translates to:
  /// **'如：点名记录_{yyyy}-{MM}-{dd}'**
  String fileNameTemplateExample(String MM, String dd, String yyyy);

  /// No description provided for @fileNameTemplateHint.
  ///
  /// In zh, this message translates to:
  /// **'使用模板变量自动生成文件名'**
  String get fileNameTemplateHint;

  /// No description provided for @headerTemplate.
  ///
  /// In zh, this message translates to:
  /// **'抬头模板'**
  String get headerTemplate;

  /// No description provided for @headerTemplateExample.
  ///
  /// In zh, this message translates to:
  /// **'如：{yyyy}-{MM}-{dd}日点名记录'**
  String headerTemplateExample(String MM, String dd, String yyyy);

  /// No description provided for @headerTemplateHint.
  ///
  /// In zh, this message translates to:
  /// **'未使用会话名或会话名为空时生效；支持模板变量'**
  String get headerTemplateHint;

  /// No description provided for @headerBackgroundColor.
  ///
  /// In zh, this message translates to:
  /// **'抬头背景色'**
  String get headerBackgroundColor;

  /// No description provided for @tableHeaderBackgroundColor.
  ///
  /// In zh, this message translates to:
  /// **'表头背景色'**
  String get tableHeaderBackgroundColor;

  /// No description provided for @controllerRowBackgroundColor.
  ///
  /// In zh, this message translates to:
  /// **'主控栏背景色'**
  String get controllerRowBackgroundColor;

  /// No description provided for @tableBackgroundColor.
  ///
  /// In zh, this message translates to:
  /// **'表格背景色'**
  String get tableBackgroundColor;

  /// No description provided for @alternatingRowColor.
  ///
  /// In zh, this message translates to:
  /// **'交替行颜色'**
  String get alternatingRowColor;

  /// No description provided for @alternatingRowColorHint.
  ///
  /// In zh, this message translates to:
  /// **'使用交替行背景色'**
  String get alternatingRowColorHint;

  /// No description provided for @footerInformation.
  ///
  /// In zh, this message translates to:
  /// **'底部说明'**
  String get footerInformation;

  /// No description provided for @footerInformationHint.
  ///
  /// In zh, this message translates to:
  /// **'显示 OpenLogTool 项目与许可信息'**
  String get footerInformationHint;

  /// No description provided for @restoreDefaultColors.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认颜色'**
  String get restoreDefaultColors;

  /// No description provided for @tableFont.
  ///
  /// In zh, this message translates to:
  /// **'表格字体'**
  String get tableFont;

  /// No description provided for @templateVariablesTitle.
  ///
  /// In zh, this message translates to:
  /// **'模板变量说明'**
  String get templateVariablesTitle;

  /// No description provided for @templateYearDescription.
  ///
  /// In zh, this message translates to:
  /// **'四位年份，如：2024'**
  String get templateYearDescription;

  /// No description provided for @templateMonthDescription.
  ///
  /// In zh, this message translates to:
  /// **'两位月份，如：01, 12'**
  String get templateMonthDescription;

  /// No description provided for @templateDayDescription.
  ///
  /// In zh, this message translates to:
  /// **'两位日期，如：01, 31'**
  String get templateDayDescription;

  /// No description provided for @templateHourDescription.
  ///
  /// In zh, this message translates to:
  /// **'两位小时（24 小时制），如：14'**
  String get templateHourDescription;

  /// No description provided for @templateMinuteDescription.
  ///
  /// In zh, this message translates to:
  /// **'两位分钟，如：30'**
  String get templateMinuteDescription;

  /// No description provided for @templateSecondDescription.
  ///
  /// In zh, this message translates to:
  /// **'两位秒数，如：45'**
  String get templateSecondDescription;

  /// No description provided for @templateSessionDescription.
  ///
  /// In zh, this message translates to:
  /// **'当前会话名称，如：2024年夏季点名'**
  String get templateSessionDescription;

  /// No description provided for @templateExamplesTitle.
  ///
  /// In zh, this message translates to:
  /// **'使用示例'**
  String get templateExamplesTitle;

  /// No description provided for @templateFileNameExampleOne.
  ///
  /// In zh, this message translates to:
  /// **'文件名：点名记录_{yyyy}-{MM}-{dd}'**
  String templateFileNameExampleOne(String MM, String dd, String yyyy);

  /// No description provided for @templateFileNameExampleOneResult.
  ///
  /// In zh, this message translates to:
  /// **'点名记录_2024-03-28.xlsx'**
  String get templateFileNameExampleOneResult;

  /// No description provided for @templateFileNameExampleTwo.
  ///
  /// In zh, this message translates to:
  /// **'文件名：通联_{yyyy}-{MM}-{dd}_{HH}{mm}{ss}'**
  String templateFileNameExampleTwo(
      String HH, String MM, String dd, String mm, String ss, String yyyy);

  /// No description provided for @templateFileNameExampleTwoResult.
  ///
  /// In zh, this message translates to:
  /// **'通联_2024-03-28_143045.xlsx'**
  String get templateFileNameExampleTwoResult;

  /// No description provided for @templateHeaderExample.
  ///
  /// In zh, this message translates to:
  /// **'抬头：{yyyy}年{MM}月{dd}日点名记录'**
  String templateHeaderExample(String MM, String dd, String yyyy);

  /// No description provided for @templateHeaderExampleResult.
  ///
  /// In zh, this message translates to:
  /// **'2024年03月28日点名记录'**
  String get templateHeaderExampleResult;

  /// No description provided for @templateVariablesTip.
  ///
  /// In zh, this message translates to:
  /// **'提示：使用模板变量可以让文件名和抬头自动包含当前日期时间，方便文件管理。'**
  String get templateVariablesTip;

  /// No description provided for @chooseColor.
  ///
  /// In zh, this message translates to:
  /// **'选择{label}'**
  String chooseColor(String label);

  /// No description provided for @colorHexValue.
  ///
  /// In zh, this message translates to:
  /// **'HEX：#{value}'**
  String colorHexValue(String value);

  /// No description provided for @colorOpacity.
  ///
  /// In zh, this message translates to:
  /// **'透明度'**
  String get colorOpacity;

  /// No description provided for @noDataToExport.
  ///
  /// In zh, this message translates to:
  /// **'没有数据可以导出'**
  String get noDataToExport;

  /// No description provided for @saveExportFileDialog.
  ///
  /// In zh, this message translates to:
  /// **'保存 {format} 导出文件'**
  String saveExportFileDialog(String format);

  /// No description provided for @downloadsDirectoryUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'无法访问下载目录'**
  String get downloadsDirectoryUnavailable;

  /// No description provided for @exportSavedViaSystemPicker.
  ///
  /// In zh, this message translates to:
  /// **'{format} 导出成功，已通过系统文件选择器保存'**
  String exportSavedViaSystemPicker(String format);

  /// No description provided for @exportSucceeded.
  ///
  /// In zh, this message translates to:
  /// **'{format} 导出成功'**
  String exportSucceeded(String format);

  /// No description provided for @fileSavedTo.
  ///
  /// In zh, this message translates to:
  /// **'文件已保存到：\n{path}'**
  String fileSavedTo(String path);

  /// No description provided for @exportFailed.
  ///
  /// In zh, this message translates to:
  /// **'导出失败：{error}'**
  String exportFailed(String error);

  /// No description provided for @excelGenerationFailed.
  ///
  /// In zh, this message translates to:
  /// **'导出失败：无法生成 Excel 文件'**
  String get excelGenerationFailed;

  /// No description provided for @importSucceeded.
  ///
  /// In zh, this message translates to:
  /// **'导入成功：{count} 条记录'**
  String importSucceeded(int count);

  /// No description provided for @importFailed.
  ///
  /// In zh, this message translates to:
  /// **'导入失败：{error}'**
  String importFailed(String error);

  /// No description provided for @excelImportComingSoon.
  ///
  /// In zh, this message translates to:
  /// **'Excel 导入功能开发中'**
  String get excelImportComingSoon;

  /// No description provided for @excelImportLlmProcessing.
  ///
  /// In zh, this message translates to:
  /// **'正在用 AI 解析 Excel 内容…'**
  String get excelImportLlmProcessing;

  /// No description provided for @excelImportPreviewTitle.
  ///
  /// In zh, this message translates to:
  /// **'导入预览'**
  String get excelImportPreviewTitle;

  /// No description provided for @excelImportPreviewCount.
  ///
  /// In zh, this message translates to:
  /// **'共识别 {count} 条记录'**
  String excelImportPreviewCount(int count);

  /// No description provided for @excelImportConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确认导入'**
  String get excelImportConfirm;

  /// No description provided for @excelImportSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已导入 {count} 条记录'**
  String excelImportSuccess(int count);

  /// No description provided for @excelImportFailed.
  ///
  /// In zh, this message translates to:
  /// **'导入失败：{error}'**
  String excelImportFailed(String error);

  /// No description provided for @pathCopied.
  ///
  /// In zh, this message translates to:
  /// **'路径已复制'**
  String get pathCopied;

  /// No description provided for @createSession.
  ///
  /// In zh, this message translates to:
  /// **'新建会话'**
  String get createSession;

  /// No description provided for @createSessionTitle.
  ///
  /// In zh, this message translates to:
  /// **'新建点名会话'**
  String get createSessionTitle;

  /// No description provided for @createSessionNameHint.
  ///
  /// In zh, this message translates to:
  /// **'输入会话名称'**
  String get createSessionNameHint;

  /// No description provided for @sessionCreated.
  ///
  /// In zh, this message translates to:
  /// **'已创建会话“{title}”'**
  String sessionCreated(String title);

  /// No description provided for @createSessionFailed.
  ///
  /// In zh, this message translates to:
  /// **'创建会话失败：{error}'**
  String createSessionFailed(String error);

  /// No description provided for @searchSessions.
  ///
  /// In zh, this message translates to:
  /// **'搜索会话'**
  String get searchSessions;

  /// No description provided for @allSessionStatuses.
  ///
  /// In zh, this message translates to:
  /// **'全部状态'**
  String get allSessionStatuses;

  /// No description provided for @sessionArchived.
  ///
  /// In zh, this message translates to:
  /// **'已归档'**
  String get sessionArchived;

  /// No description provided for @sessionPage.
  ///
  /// In zh, this message translates to:
  /// **'第 {page} / {total} 页'**
  String sessionPage(int page, int total);

  /// No description provided for @moreSessionActions.
  ///
  /// In zh, this message translates to:
  /// **'更多会话操作'**
  String get moreSessionActions;

  /// No description provided for @openAndManageCollaboration.
  ///
  /// In zh, this message translates to:
  /// **'打开并管理协作'**
  String get openAndManageCollaboration;

  /// No description provided for @exportLibraryJson.
  ///
  /// In zh, this message translates to:
  /// **'导出词库 JSON'**
  String get exportLibraryJson;

  /// No description provided for @libraryExportDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'导出词库'**
  String get libraryExportDialogTitle;

  /// No description provided for @libraryExportSucceeded.
  ///
  /// In zh, this message translates to:
  /// **'词库已导出'**
  String get libraryExportSucceeded;

  /// No description provided for @libraryExportFailed.
  ///
  /// In zh, this message translates to:
  /// **'导出词库失败：{error}'**
  String libraryExportFailed(String error);

  /// No description provided for @editLibraryItem.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get editLibraryItem;

  /// No description provided for @editLibraryItemTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑“{name}”'**
  String editLibraryItemTitle(String name);

  /// No description provided for @editLibraryItemLabel.
  ///
  /// In zh, this message translates to:
  /// **'词库内容'**
  String get editLibraryItemLabel;

  /// No description provided for @libraryItemRenamed.
  ///
  /// In zh, this message translates to:
  /// **'已更新为“{value}”'**
  String libraryItemRenamed(String value);

  /// No description provided for @libraryItemRenameFailed.
  ///
  /// In zh, this message translates to:
  /// **'修改失败：{error}'**
  String libraryItemRenameFailed(String error);

  /// No description provided for @libraryPageStatus.
  ///
  /// In zh, this message translates to:
  /// **'第 {current} / {total} 页'**
  String libraryPageStatus(int current, int total);

  /// No description provided for @previousPage.
  ///
  /// In zh, this message translates to:
  /// **'上一页'**
  String get previousPage;

  /// No description provided for @nextPage.
  ///
  /// In zh, this message translates to:
  /// **'下一页'**
  String get nextPage;

  /// No description provided for @settingsCategoryAppearance.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get settingsCategoryAppearance;

  /// No description provided for @settingsCategoryWorkbench.
  ///
  /// In zh, this message translates to:
  /// **'工作台'**
  String get settingsCategoryWorkbench;

  /// No description provided for @settingsCategoryController.
  ///
  /// In zh, this message translates to:
  /// **'主控屏'**
  String get settingsCategoryController;

  /// No description provided for @settingsCategoryServerAccount.
  ///
  /// In zh, this message translates to:
  /// **'服务器与账户'**
  String get settingsCategoryServerAccount;

  /// No description provided for @settingsCategoryApplication.
  ///
  /// In zh, this message translates to:
  /// **'应用'**
  String get settingsCategoryApplication;

  /// No description provided for @collaborationOverviewTab.
  ///
  /// In zh, this message translates to:
  /// **'概览'**
  String get collaborationOverviewTab;

  /// No description provided for @collaborationSyncConflictsTab.
  ///
  /// In zh, this message translates to:
  /// **'同步与冲突'**
  String get collaborationSyncConflictsTab;

  /// No description provided for @collaborationAccessManagementTab.
  ///
  /// In zh, this message translates to:
  /// **'访问管理'**
  String get collaborationAccessManagementTab;

  /// No description provided for @dataRecordsExportTab.
  ///
  /// In zh, this message translates to:
  /// **'记录与导出'**
  String get dataRecordsExportTab;

  /// No description provided for @dataLookupLibrariesTab.
  ///
  /// In zh, this message translates to:
  /// **'查询词库'**
  String get dataLookupLibrariesTab;

  /// No description provided for @dataLocalDatabaseTab.
  ///
  /// In zh, this message translates to:
  /// **'本地数据库'**
  String get dataLocalDatabaseTab;

  /// No description provided for @dataSyncConflictsTab.
  ///
  /// In zh, this message translates to:
  /// **'同步冲突'**
  String get dataSyncConflictsTab;

  /// No description provided for @settingsCategoryAi.
  ///
  /// In zh, this message translates to:
  /// **'AI 辅助'**
  String get settingsCategoryAi;

  /// No description provided for @aiSettingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'AI 辅助识别'**
  String get aiSettingsTitle;

  /// No description provided for @aiSettingsDescription.
  ///
  /// In zh, this message translates to:
  /// **'配置可选的语音识别与字段提取服务。接口、模型与鉴权均由本机独立设置。'**
  String get aiSettingsDescription;

  /// No description provided for @aiSettingsOptionalTitle.
  ///
  /// In zh, this message translates to:
  /// **'可选且默认关闭'**
  String get aiSettingsOptionalTitle;

  /// No description provided for @aiSettingsOptionalMessage.
  ///
  /// In zh, this message translates to:
  /// **'音频将直接发送到你配置的服务，不经过 OpenLogTool 协作服务器。识别结果只作为候选，不会自动覆盖书记员正在编辑的内容。'**
  String get aiSettingsOptionalMessage;

  /// No description provided for @aiRecognitionEnabled.
  ///
  /// In zh, this message translates to:
  /// **'启用 AI 辅助识别'**
  String get aiRecognitionEnabled;

  /// No description provided for @aiRecognitionEnabledHint.
  ///
  /// In zh, this message translates to:
  /// **'启用后可从点名工作台调用当前语音识别配置。'**
  String get aiRecognitionEnabledHint;

  /// No description provided for @aiLocalReferenceContext.
  ///
  /// In zh, this message translates to:
  /// **'结合本地词库与近期记录'**
  String get aiLocalReferenceContext;

  /// No description provided for @aiLocalReferenceContextHint.
  ///
  /// In zh, this message translates to:
  /// **'默认开启。仅把与当前转写相近的少量词条和命中呼号的近期字段发送给文字模型，用于纠正呼号、设备、天线和 QTH；不会上传完整数据库。'**
  String get aiLocalReferenceContextHint;

  /// No description provided for @aiRecognitionNeedsAsr.
  ///
  /// In zh, this message translates to:
  /// **'请先添加并选择语音识别配置。'**
  String get aiRecognitionNeedsAsr;

  /// No description provided for @aiAsrStageTitle.
  ///
  /// In zh, this message translates to:
  /// **'语音识别（ASR）'**
  String get aiAsrStageTitle;

  /// No description provided for @aiAsrStageDescription.
  ///
  /// In zh, this message translates to:
  /// **'把音频转换为原始文本，三类接口格式可同时保存并随时切换。'**
  String get aiAsrStageDescription;

  /// No description provided for @aiExtractionStageTitle.
  ///
  /// In zh, this message translates to:
  /// **'字段提取（可选）'**
  String get aiExtractionStageTitle;

  /// No description provided for @aiExtractionStageDescription.
  ///
  /// In zh, this message translates to:
  /// **'把转写文本整理为呼号、RST、QTH 等候选字段；不配置时保留原始转写。'**
  String get aiExtractionStageDescription;

  /// No description provided for @aiSupportedProtocols.
  ///
  /// In zh, this message translates to:
  /// **'支持的接口格式'**
  String get aiSupportedProtocols;

  /// No description provided for @aiActiveProfile.
  ///
  /// In zh, this message translates to:
  /// **'当前配置'**
  String get aiActiveProfile;

  /// No description provided for @aiNoProfileConfigured.
  ///
  /// In zh, this message translates to:
  /// **'尚未添加配置'**
  String get aiNoProfileConfigured;

  /// No description provided for @aiNoActiveProfile.
  ///
  /// In zh, this message translates to:
  /// **'不使用'**
  String get aiNoActiveProfile;

  /// No description provided for @aiCredentialStatus.
  ///
  /// In zh, this message translates to:
  /// **'密钥状态'**
  String get aiCredentialStatus;

  /// No description provided for @aiCredentialNoProfile.
  ///
  /// In zh, this message translates to:
  /// **'选择配置后显示本机密钥状态。'**
  String get aiCredentialNoProfile;

  /// No description provided for @aiCredentialStoredLocally.
  ///
  /// In zh, this message translates to:
  /// **'API 密钥单独保存在系统安全存储中，不进入配置导出。'**
  String get aiCredentialStoredLocally;

  /// No description provided for @aiStatusNotConfigured.
  ///
  /// In zh, this message translates to:
  /// **'未配置'**
  String get aiStatusNotConfigured;

  /// No description provided for @aiStatusNoCredentialNeeded.
  ///
  /// In zh, this message translates to:
  /// **'无需密钥'**
  String get aiStatusNoCredentialNeeded;

  /// No description provided for @aiStatusCredentialReady.
  ///
  /// In zh, this message translates to:
  /// **'密钥已保存'**
  String get aiStatusCredentialReady;

  /// No description provided for @aiStatusCredentialMissing.
  ///
  /// In zh, this message translates to:
  /// **'缺少密钥'**
  String get aiStatusCredentialMissing;

  /// No description provided for @aiAddProfile.
  ///
  /// In zh, this message translates to:
  /// **'添加配置'**
  String get aiAddProfile;

  /// No description provided for @aiEditProfile.
  ///
  /// In zh, this message translates to:
  /// **'编辑配置'**
  String get aiEditProfile;

  /// No description provided for @aiDeleteProfileTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除 AI 配置'**
  String get aiDeleteProfileTitle;

  /// No description provided for @aiDeleteProfileMessage.
  ///
  /// In zh, this message translates to:
  /// **'确定删除“{name}”及其本机密钥吗？'**
  String aiDeleteProfileMessage(String name);

  /// No description provided for @aiProfileName.
  ///
  /// In zh, this message translates to:
  /// **'配置名称'**
  String get aiProfileName;

  /// No description provided for @aiBaseUrl.
  ///
  /// In zh, this message translates to:
  /// **'API Base URL'**
  String get aiBaseUrl;

  /// No description provided for @aiModelName.
  ///
  /// In zh, this message translates to:
  /// **'模型名称'**
  String get aiModelName;

  /// No description provided for @aiProtocol.
  ///
  /// In zh, this message translates to:
  /// **'接口格式'**
  String get aiProtocol;

  /// No description provided for @aiAuthentication.
  ///
  /// In zh, this message translates to:
  /// **'鉴权方式'**
  String get aiAuthentication;

  /// No description provided for @aiCredentialName.
  ///
  /// In zh, this message translates to:
  /// **'请求头或查询参数名'**
  String get aiCredentialName;

  /// No description provided for @aiCredentialPrefix.
  ///
  /// In zh, this message translates to:
  /// **'密钥前缀（可留空）'**
  String get aiCredentialPrefix;

  /// No description provided for @aiApiKey.
  ///
  /// In zh, this message translates to:
  /// **'API 密钥'**
  String get aiApiKey;

  /// No description provided for @aiApiKeyNewHint.
  ///
  /// In zh, this message translates to:
  /// **'可暂时留空，保存后将显示缺少密钥。'**
  String get aiApiKeyNewHint;

  /// No description provided for @aiApiKeyExistingHint.
  ///
  /// In zh, this message translates to:
  /// **'留空会保留当前密钥；更换接口目的地时需要重新填写。'**
  String get aiApiKeyExistingHint;

  /// No description provided for @aiRequestOptions.
  ///
  /// In zh, this message translates to:
  /// **'高级请求选项（JSON）'**
  String get aiRequestOptions;

  /// No description provided for @aiRequestOptionsHint.
  ///
  /// In zh, this message translates to:
  /// **'通用 JSON 必须包含 requestTemplate；可设置 path、responsePath、body、fields、audioDataEncoding、includePrompt 等协议选项。这里的内容会随配置导出，请勿填写密钥。'**
  String get aiRequestOptionsHint;

  /// No description provided for @aiRequiredField.
  ///
  /// In zh, this message translates to:
  /// **'此项不能为空'**
  String get aiRequiredField;

  /// No description provided for @aiRequestOptionsMustBeObject.
  ///
  /// In zh, this message translates to:
  /// **'高级请求选项必须是 JSON 对象'**
  String get aiRequestOptionsMustBeObject;

  /// No description provided for @aiJsonProtocolNeedsTemplate.
  ///
  /// In zh, this message translates to:
  /// **'通用 JSON 格式必须包含 requestTemplate'**
  String get aiJsonProtocolNeedsTemplate;

  /// No description provided for @aiInvalidJson.
  ///
  /// In zh, this message translates to:
  /// **'JSON 格式无效'**
  String get aiInvalidJson;

  /// No description provided for @aiInvalidBaseUrl.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效的 HTTP(S) API 地址'**
  String get aiInvalidBaseUrl;

  /// No description provided for @aiSettingsFailed.
  ///
  /// In zh, this message translates to:
  /// **'AI 设置操作失败：{error}'**
  String aiSettingsFailed(String error);

  /// No description provided for @aiProtocolAudioTranscriptions.
  ///
  /// In zh, this message translates to:
  /// **'音频转写 multipart'**
  String get aiProtocolAudioTranscriptions;

  /// No description provided for @aiProtocolChatAudio.
  ///
  /// In zh, this message translates to:
  /// **'Chat input_audio'**
  String get aiProtocolChatAudio;

  /// No description provided for @aiProtocolChatText.
  ///
  /// In zh, this message translates to:
  /// **'Chat 文本提取'**
  String get aiProtocolChatText;

  /// No description provided for @aiProtocolGenericJson.
  ///
  /// In zh, this message translates to:
  /// **'通用 JSON HTTP'**
  String get aiProtocolGenericJson;

  /// No description provided for @aiAuthNone.
  ///
  /// In zh, this message translates to:
  /// **'无需鉴权'**
  String get aiAuthNone;

  /// No description provided for @aiAuthBearer.
  ///
  /// In zh, this message translates to:
  /// **'Authorization Bearer'**
  String get aiAuthBearer;

  /// No description provided for @aiAuthHeader.
  ///
  /// In zh, this message translates to:
  /// **'自定义请求头'**
  String get aiAuthHeader;

  /// No description provided for @aiAuthQuery.
  ///
  /// In zh, this message translates to:
  /// **'查询参数'**
  String get aiAuthQuery;

  /// No description provided for @aiWorkbenchTitle.
  ///
  /// In zh, this message translates to:
  /// **'AI 辅助识别'**
  String get aiWorkbenchTitle;

  /// No description provided for @aiWorkbenchUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'当前记录为只读或正在处理，暂时不能识别。'**
  String get aiWorkbenchUnavailable;

  /// No description provided for @aiReadyStatus.
  ///
  /// In zh, this message translates to:
  /// **'点击麦克风录制一条点名内容。'**
  String get aiReadyStatus;

  /// No description provided for @aiRecordingStatus.
  ///
  /// In zh, this message translates to:
  /// **'正在录音 {elapsed}'**
  String aiRecordingStatus(String elapsed);

  /// No description provided for @aiLiveTranscriptTitle.
  ///
  /// In zh, this message translates to:
  /// **'实时识别字段'**
  String get aiLiveTranscriptTitle;

  /// No description provided for @aiLiveStructuredWaiting.
  ///
  /// In zh, this message translates to:
  /// **'正在积累一段完整的点名内容，识别出的字段会显示在这里。'**
  String get aiLiveStructuredWaiting;

  /// No description provided for @aiLiveStructuredUpdating.
  ///
  /// In zh, this message translates to:
  /// **'正在根据目前的完整内容整理字段…'**
  String get aiLiveStructuredUpdating;

  /// No description provided for @aiLiveTranscriptionRetrying.
  ///
  /// In zh, this message translates to:
  /// **'实时识别暂时失败；停止录音后仍会用完整内容重试：{error}'**
  String aiLiveTranscriptionRetrying(String error);

  /// No description provided for @aiRecognizingStatus.
  ///
  /// In zh, this message translates to:
  /// **'正在识别并整理候选内容…'**
  String get aiRecognizingStatus;

  /// No description provided for @aiStartRecording.
  ///
  /// In zh, this message translates to:
  /// **'录音'**
  String get aiStartRecording;

  /// No description provided for @aiStopAndRecognize.
  ///
  /// In zh, this message translates to:
  /// **'识别'**
  String get aiStopAndRecognize;

  /// No description provided for @aiMicrophonePermissionDenied.
  ///
  /// In zh, this message translates to:
  /// **'未获得麦克风权限。'**
  String get aiMicrophonePermissionDenied;

  /// No description provided for @aiRecordingFailed.
  ///
  /// In zh, this message translates to:
  /// **'录音失败：{error}'**
  String aiRecordingFailed(String error);

  /// No description provided for @aiRecognitionFailed.
  ///
  /// In zh, this message translates to:
  /// **'识别失败：{error}'**
  String aiRecognitionFailed(String error);

  /// No description provided for @aiReviewTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认 AI 候选内容'**
  String get aiReviewTitle;

  /// No description provided for @aiTranscriptTitle.
  ///
  /// In zh, this message translates to:
  /// **'原始转写'**
  String get aiTranscriptTitle;

  /// No description provided for @aiCopyTranscript.
  ///
  /// In zh, this message translates to:
  /// **'复制转写'**
  String get aiCopyTranscript;

  /// No description provided for @aiTranscriptCopied.
  ///
  /// In zh, this message translates to:
  /// **'已复制转写内容。'**
  String get aiTranscriptCopied;

  /// No description provided for @aiNoStructuredCandidates.
  ///
  /// In zh, this message translates to:
  /// **'服务没有返回结构化字段，你仍可查看或复制上方转写。'**
  String get aiNoStructuredCandidates;

  /// No description provided for @aiCandidateRecord.
  ///
  /// In zh, this message translates to:
  /// **'候选记录'**
  String get aiCandidateRecord;

  /// No description provided for @aiCandidateNumber.
  ///
  /// In zh, this message translates to:
  /// **'候选 {number}'**
  String aiCandidateNumber(int number);

  /// No description provided for @aiCandidateHint.
  ///
  /// In zh, this message translates to:
  /// **'空字段会默认勾选；替换已有内容必须由你手动勾选确认。'**
  String get aiCandidateHint;

  /// No description provided for @aiApplySelected.
  ///
  /// In zh, this message translates to:
  /// **'应用所选字段'**
  String get aiApplySelected;

  /// No description provided for @aiCandidatesApplied.
  ///
  /// In zh, this message translates to:
  /// **'已应用 {count} 个候选字段。'**
  String aiCandidatesApplied(int count);

  /// No description provided for @aiCandidatesStale.
  ///
  /// In zh, this message translates to:
  /// **'录音后记录内容已经变化，这些候选已不能安全应用。'**
  String get aiCandidatesStale;

  /// No description provided for @aiApplyFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法应用 AI 候选：{error}'**
  String aiApplyFailed(String error);

  /// No description provided for @aiWillReplaceValue.
  ///
  /// In zh, this message translates to:
  /// **'将替换：{value}'**
  String aiWillReplaceValue(String value);

  /// No description provided for @aiWillFillEmpty.
  ///
  /// In zh, this message translates to:
  /// **'将填入空字段'**
  String get aiWillFillEmpty;

  /// No description provided for @aiReplacementNeedsConfirmation.
  ///
  /// In zh, this message translates to:
  /// **'勾选后确认替换'**
  String get aiReplacementNeedsConfirmation;

  /// No description provided for @aiCandidateUnchanged.
  ///
  /// In zh, this message translates to:
  /// **'内容已经一致'**
  String get aiCandidateUnchanged;

  /// No description provided for @aiCandidateStale.
  ///
  /// In zh, this message translates to:
  /// **'录音后该字段已发生变化'**
  String get aiCandidateStale;

  /// No description provided for @aiCandidateBeingEdited.
  ///
  /// In zh, this message translates to:
  /// **'该字段正在编辑或输入法组词'**
  String get aiCandidateBeingEdited;

  /// No description provided for @aiCandidateLocked.
  ///
  /// In zh, this message translates to:
  /// **'另一位协作者正在编辑该字段'**
  String get aiCandidateLocked;

  /// No description provided for @aiCandidateReadOnly.
  ///
  /// In zh, this message translates to:
  /// **'当前记录为只读'**
  String get aiCandidateReadOnly;

  /// No description provided for @aiCandidateBusy.
  ///
  /// In zh, this message translates to:
  /// **'当前记录正在处理其他操作'**
  String get aiCandidateBusy;

  /// No description provided for @aiCandidateInvalid.
  ///
  /// In zh, this message translates to:
  /// **'不支持或无效的候选内容'**
  String get aiCandidateInvalid;

  /// No description provided for @textAssistantTitle.
  ///
  /// In zh, this message translates to:
  /// **'文字助手'**
  String get textAssistantTitle;

  /// No description provided for @textAssistantDescription.
  ///
  /// In zh, this message translates to:
  /// **'使用简单的文字模型配置完成字段整理、填写建议和词库维护。'**
  String get textAssistantDescription;

  /// No description provided for @textAssistantPrivacyTitle.
  ///
  /// In zh, this message translates to:
  /// **'由你选择的模型服务处理'**
  String get textAssistantPrivacyTitle;

  /// No description provided for @textAssistantPrivacyMessage.
  ///
  /// In zh, this message translates to:
  /// **'需要时会向所选服务发送当前字段文本或聚合后的历史词条，不会发送完整记录、备注或时间；API 密钥仅用于请求鉴权并安全保存在本机。'**
  String get textAssistantPrivacyMessage;

  /// No description provided for @textAssistantEnabled.
  ///
  /// In zh, this message translates to:
  /// **'启用文字助手'**
  String get textAssistantEnabled;

  /// No description provided for @textAssistantNotConfigured.
  ///
  /// In zh, this message translates to:
  /// **'尚未配置文字助手'**
  String get textAssistantNotConfigured;

  /// No description provided for @textAssistantInlineSuggestions.
  ///
  /// In zh, this message translates to:
  /// **'填写时显示 AI 规范建议'**
  String get textAssistantInlineSuggestions;

  /// No description provided for @textAssistantInlineSuggestionsHint.
  ///
  /// In zh, this message translates to:
  /// **'设备、天线、QTH、高度和功率停止输入约 300 毫秒后，显示一条快速建议。'**
  String get textAssistantInlineSuggestionsHint;

  /// No description provided for @textAssistantTest.
  ///
  /// In zh, this message translates to:
  /// **'测试连接'**
  String get textAssistantTest;

  /// No description provided for @textAssistantConfigure.
  ///
  /// In zh, this message translates to:
  /// **'配置文字助手'**
  String get textAssistantConfigure;

  /// No description provided for @textAssistantEdit.
  ///
  /// In zh, this message translates to:
  /// **'修改配置'**
  String get textAssistantEdit;

  /// No description provided for @textAssistantConfigureTitle.
  ///
  /// In zh, this message translates to:
  /// **'配置文字助手'**
  String get textAssistantConfigureTitle;

  /// No description provided for @textAssistantProvider.
  ///
  /// In zh, this message translates to:
  /// **'服务类型'**
  String get textAssistantProvider;

  /// No description provided for @textAssistantProviderOpenAi.
  ///
  /// In zh, this message translates to:
  /// **'OpenAI（Responses API）'**
  String get textAssistantProviderOpenAi;

  /// No description provided for @textAssistantProviderAnthropic.
  ///
  /// In zh, this message translates to:
  /// **'Anthropic'**
  String get textAssistantProviderAnthropic;

  /// No description provided for @textAssistantProviderCompatible.
  ///
  /// In zh, this message translates to:
  /// **'OpenAI 兼容（旧版 Chat Completions）'**
  String get textAssistantProviderCompatible;

  /// No description provided for @textAssistantTestSucceeded.
  ///
  /// In zh, this message translates to:
  /// **'文字助手连接正常。'**
  String get textAssistantTestSucceeded;

  /// No description provided for @textAssistantSuggestionLabel.
  ///
  /// In zh, this message translates to:
  /// **'AI 规范建议'**
  String get textAssistantSuggestionLabel;

  /// No description provided for @aiDictionaryRecognize.
  ///
  /// In zh, this message translates to:
  /// **'从历史识别'**
  String get aiDictionaryRecognize;

  /// No description provided for @aiDictionaryOptimize.
  ///
  /// In zh, this message translates to:
  /// **'AI 优化词库'**
  String get aiDictionaryOptimize;

  /// No description provided for @aiDictionaryNeedsAssistant.
  ///
  /// In zh, this message translates to:
  /// **'请先在设置中配置并启用文字助手。'**
  String get aiDictionaryNeedsAssistant;

  /// No description provided for @aiDictionaryNoSuggestions.
  ///
  /// In zh, this message translates to:
  /// **'没有发现需要处理的词条。'**
  String get aiDictionaryNoSuggestions;

  /// No description provided for @aiDictionaryApplied.
  ///
  /// In zh, this message translates to:
  /// **'已应用 {count} 条词库建议。'**
  String aiDictionaryApplied(int count);

  /// No description provided for @aiDictionaryFailed.
  ///
  /// In zh, this message translates to:
  /// **'词库 AI 操作失败：{error}'**
  String aiDictionaryFailed(String error);

  /// No description provided for @aiDictionaryOptimizing.
  ///
  /// In zh, this message translates to:
  /// **'正在优化词库'**
  String get aiDictionaryOptimizing;

  /// No description provided for @aiDictionaryRecognizing.
  ///
  /// In zh, this message translates to:
  /// **'正在识别历史词条'**
  String get aiDictionaryRecognizing;

  /// No description provided for @aiDictionaryPreparing.
  ///
  /// In zh, this message translates to:
  /// **'正在整理本地数据…'**
  String get aiDictionaryPreparing;

  /// No description provided for @aiDictionaryProgress.
  ///
  /// In zh, this message translates to:
  /// **'已完成 {completed} / {total}'**
  String aiDictionaryProgress(int completed, int total);

  /// No description provided for @aiDictionaryReviewTitle.
  ///
  /// In zh, this message translates to:
  /// **'确认词库建议'**
  String get aiDictionaryReviewTitle;

  /// No description provided for @aiDictionaryReviewHint.
  ///
  /// In zh, this message translates to:
  /// **'根据 {recordCount} 条历史记录及当前词库生成。只有勾选的内容会写入。'**
  String aiDictionaryReviewHint(int recordCount);

  /// No description provided for @aiDictionaryActionAdd.
  ///
  /// In zh, this message translates to:
  /// **'新增'**
  String get aiDictionaryActionAdd;

  /// No description provided for @aiDictionaryActionRename.
  ///
  /// In zh, this message translates to:
  /// **'改名'**
  String get aiDictionaryActionRename;

  /// No description provided for @aiDictionaryActionMerge.
  ///
  /// In zh, this message translates to:
  /// **'合并'**
  String get aiDictionaryActionMerge;

  /// No description provided for @aiDictionaryUsedCount.
  ///
  /// In zh, this message translates to:
  /// **'历史出现 {count} 次'**
  String aiDictionaryUsedCount(int count);

  /// No description provided for @aiDictionaryMergeWarning.
  ///
  /// In zh, this message translates to:
  /// **'合并会从词库隐藏源词条，默认不勾选；不会改写历史记录。'**
  String get aiDictionaryMergeWarning;

  /// No description provided for @aiDictionaryApplySelected.
  ///
  /// In zh, this message translates to:
  /// **'应用所选建议'**
  String get aiDictionaryApplySelected;

  /// No description provided for @fieldFormatSuggestionLabel.
  ///
  /// In zh, this message translates to:
  /// **'格式候选'**
  String get fieldFormatSuggestionLabel;

  /// No description provided for @logTableHorizontalScrollHint.
  ///
  /// In zh, this message translates to:
  /// **'Shift + 滚轮横向滚动'**
  String get logTableHorizontalScrollHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'en':
      {
        switch (locale.countryCode) {
          case 'US':
            return AppLocalizationsEnUs();
        }
        break;
      }
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'CN':
            return AppLocalizationsZhCn();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}

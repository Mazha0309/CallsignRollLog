// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get collaborationTechnicalDetails => 'Connection & diagnostics';

  @override
  String get collaborationOverviewOnline =>
      'Connected. Record updates are being shared with participants.';

  @override
  String get collaborationOverviewOffline =>
      'The connection is unavailable. Existing records are still on this device.';

  @override
  String get collaborationOverviewAttention =>
      'Some records or sync issues need attention. Open Sync to review them.';

  @override
  String collaborationOverviewPending(int count) {
    return 'Saved on this device. $count changes are waiting to sync.';
  }

  @override
  String get historySessionCollaborationCloseRequired =>
      'This is a collaborative session. Use Collaboration & members to end shared recording or leave; it cannot be ended as a local session.';

  @override
  String get collaborationLifecycleHint =>
      'Switching pages or temporarily going offline does not leave the collaboration. The owner can end shared recording; participants can leave. Existing records are kept.';

  @override
  String get hubLocalStart =>
      'Create a session to start recording. No server or account is required; records are saved on this device and can be viewed or exported.';

  @override
  String get hubLocalHint =>
      'Local recording works on its own. Sync and collaboration are optional.';

  @override
  String get hubOptionalOnline => 'Sync and collaboration (optional)';

  @override
  String get hubOptionalOnlineHint =>
      'Connect a server when you want multi-device sync or to record with others.';

  @override
  String get hubConfigureServer => 'Set up an optional server';

  @override
  String get hubOnlineConnected =>
      'Friends and collaboration use your connected server. Local recording remains independent.';

  @override
  String get hubEnableCollaboration => 'Record with a friend';

  @override
  String get hubConfirmUpload => 'Upload this session and enable collaboration';

  @override
  String get hubUploadExplanation =>
      'This uploads the current session and its existing records to the server below and starts collaboration sync. Other local sessions are not uploaded by this action. The session stays private; choose friends to invite afterwards. No public page is created.';

  @override
  String get hubContextChanged =>
      'The server, account or current session changed. Close this dialog and try again.';

  @override
  String get hubAlreadyMember =>
      'This person has already joined. You can find them in participant management.';

  @override
  String get hubInvitationHint =>
      'They can view this session\'s records after accepting. Your other sessions are not shared.';

  @override
  String get hubContinueRecording => 'Continue recording';

  @override
  String get hubViewRecords => 'View records';

  @override
  String get hubSessionDetails => 'Session details';

  @override
  String get hubHistoryHint =>
      'Browse existing records on this device. Ended sessions are a status filter, not public archives.';

  @override
  String get hubAllRecords => 'All';

  @override
  String get hubMyRecords => 'My records';

  @override
  String get hubTogetherRecords => 'Shared records';

  @override
  String get hubEndedRecords => 'Ended';

  @override
  String get socialTitle => 'Friends & invitations';

  @override
  String get socialAddFriend => 'Add friend';

  @override
  String get socialFriends => 'Friends';

  @override
  String get socialMessages => 'Messages';

  @override
  String get socialSessions => 'Sessions';

  @override
  String get socialIntro =>
      'Add your partners as friends, then invite them to a session. Personal records remain private.';

  @override
  String get socialUsername => 'Username (callsign used at registration)';

  @override
  String get socialSend => 'Send request';

  @override
  String get socialInvite => 'Invite';

  @override
  String get socialApply => 'Request to join';

  @override
  String get socialAccept => 'Accept';

  @override
  String get socialReject => 'Decline';

  @override
  String get socialPending => 'Awaiting response';

  @override
  String get socialAccepted => 'Accepted';

  @override
  String get socialView => 'View only';

  @override
  String get socialEdit => 'Record together';

  @override
  String get socialOpen => 'Open session';

  @override
  String get socialPrivate => 'Invite only';

  @override
  String get socialDiscoverable => 'Friends can discover and request to join';

  @override
  String get socialVisibilityHint =>
      'Friends see the session title. Records are available only after approval.';

  @override
  String get socialNoFriends =>
      'No friends yet. Send a request using your partner\'s username.';

  @override
  String get socialNoMessages => 'No invitations or requests';

  @override
  String get socialNoSessions =>
      'No sessions available. You can also enable collaboration for your current session.';

  @override
  String get socialPublish => 'Enable collaboration for current session';

  @override
  String get socialRemove => 'Remove friend';

  @override
  String get socialRemoveHint =>
      'Pending requests between you will be cancelled. Existing session memberships are managed separately by the session owner.';

  @override
  String get socialBlock => 'Block';

  @override
  String get socialUnblock => 'Unblock';

  @override
  String get socialBlocked => 'Blocked';

  @override
  String get socialDone => 'Done';

  @override
  String get socialFriendRequest => 'Friend request';

  @override
  String get socialInvitation => 'Session invitation';

  @override
  String get socialApplication => 'Join request';

  @override
  String get socialSent => 'Sent by me';

  @override
  String get socialReceived => 'Received';

  @override
  String get socialManage => 'Manage participants';

  @override
  String get socialConnect => 'Connect to a server and sign in to add friends.';

  @override
  String get socialUpgrade => 'Update this server to enable friends.';

  @override
  String get socialLoadFailed => 'Could not refresh. Please retry.';

  @override
  String get socialChooseFriend => 'Choose a friend';

  @override
  String get socialErrorUser =>
      'Username not found. Check that your partner registered on the same server.';

  @override
  String get socialErrorFriends => 'Please add each other as friends first.';

  @override
  String get socialErrorClosed =>
      'This request is closed or expired. Please refresh.';

  @override
  String get socialErrorSelf => 'You cannot add yourself.';

  @override
  String get socialErrorBlocked => 'Requests to this user are unavailable.';

  @override
  String get socialServerLink => 'Copy server connection';

  @override
  String get socialServerLinkHint =>
      'Paste a server address or a server portal link, then sign in.';

  @override
  String get socialLegacy => 'Legacy sharing';

  @override
  String get navWorkbench => 'Net Desk';

  @override
  String get navSessions => 'Sessions';

  @override
  String get navData => 'Data';

  @override
  String get navSettings => 'Settings';

  @override
  String get workbenchNoSession => 'No net in progress';

  @override
  String get workbenchLocalRecording => 'Local recording';

  @override
  String get collaborationLocalOnly => 'Local only';

  @override
  String get collaborationPublishing => 'Publishing';

  @override
  String get collaborationJoining => 'Joining';

  @override
  String get collaborationSnapshotting => 'Loading snapshot';

  @override
  String get collaborationCatchingUp => 'Catching up';

  @override
  String get collaborationReady => 'Connected';

  @override
  String get collaborationResyncing => 'Resyncing';

  @override
  String get collaborationRevoked => 'Access revoked';

  @override
  String get collaborationFailed => 'Sync failed';

  @override
  String collaborationState(String state) {
    return 'Collaboration: $state';
  }

  @override
  String pendingSyncCount(int count) {
    return 'Pending $count';
  }

  @override
  String conflictCount(int count) {
    return 'Conflicts $count';
  }

  @override
  String get localSessionTooltip => 'This is a local session';

  @override
  String collaborationStatusTooltip(String state, int count) {
    return 'Collaboration $state, $count pending';
  }

  @override
  String get currentRecord => 'Current record';

  @override
  String get startNewRecord => 'Start new record';

  @override
  String get newRecordName => 'New record name';

  @override
  String get newRecordNameHint => 'Enter a name for this record (optional)';

  @override
  String get automaticName => 'automatic name';

  @override
  String newRecordStarted(String name) {
    return 'Started new record: $name';
  }

  @override
  String createNewRecordFailed(String error) {
    return 'Could not create a new record: $error';
  }

  @override
  String currentOrdinal(int ordinal) {
    return 'Current #$ordinal';
  }

  @override
  String get sessionsTitle => 'Sessions';

  @override
  String get sessionsSubtitle =>
      'Manage this net, collaborating scribes, and controller displays.';

  @override
  String get noCurrentSession => 'No current net session';

  @override
  String get noCurrentSessionHint =>
      'Create a net session, or join a collaboration, to start logging.';

  @override
  String get workbenchNoSessionHint =>
      'Create a session on the Sessions page, or join a collaboration, before logging.';

  @override
  String get createOrJoinSessionFirst =>
      'Create a session or join a collaboration first';

  @override
  String get goCreateSession => 'Create a session';

  @override
  String get sessionActive => 'Active';

  @override
  String get sessionClosed => 'Ended';

  @override
  String savedPositions(int count) {
    return '$count saved';
  }

  @override
  String get localSession => 'Local session';

  @override
  String get manageCollaboration => 'Collaboration & members';

  @override
  String get openLiveShare => 'Live Share';

  @override
  String get enterControllerScreen => 'Enter controller display';

  @override
  String get localControllerDisplay => 'Local controller display';

  @override
  String get localControllerDisplayHint =>
      'Keep logging in the main window while a separate read-only window serves the controller.';

  @override
  String get openFloatingWindow => 'Open floating window';

  @override
  String get openControllerTab => 'Open controller in a new tab';

  @override
  String get openControllerInApp => 'Open controller in this tab';

  @override
  String get openSecondDisplayWindow => 'Open second-display window';

  @override
  String get historySessions => 'Session history';

  @override
  String get historySessionsHint =>
      'View and switch to past net sessions. Closed sessions open read-only.';

  @override
  String get historySessionsEmpty => 'There are no past sessions';

  @override
  String historySessionsLoadFailed(String error) {
    return 'Could not load session history: $error';
  }

  @override
  String get historySessionOpen => 'Open session';

  @override
  String get historySessionCurrent => 'Current session';

  @override
  String historySessionSwitched(String title) {
    return 'Opened session: $title';
  }

  @override
  String historySessionOpenFailed(String error) {
    return 'Could not open session: $error';
  }

  @override
  String get historySessionCloseTitle => 'End recording';

  @override
  String historySessionCloseConfirmation(String title) {
    return 'End recording in “$title”? Existing records will be kept. You can view them or resume recording later. No data will be deleted.';
  }

  @override
  String get historySessionClosed =>
      'Recording ended. Existing records were kept.';

  @override
  String historySessionCloseFailed(String error) {
    return 'Failed to end recording: $error';
  }

  @override
  String get historySessionCollaborationCloseRequiresOpen =>
      'This is a collaboration session. Open it first, then close it from Collaboration & members.';

  @override
  String get historySessionCollaborationCloseOwnerRequired =>
      'Only a fully synchronized session owner can close a collaboration session. Refresh access in Collaboration & members and try again.';

  @override
  String get historySessionReopenAction => 'Reactivate';

  @override
  String get historySessionReopenTitle => 'Reactivate local session';

  @override
  String historySessionReopenConfirmation(String title) {
    return 'Resume recording in “$title” and switch to it? Other sessions stay unchanged. Collaborative sessions must be resumed by their owner in Collaboration & members.';
  }

  @override
  String historySessionReopened(String title) {
    return 'Reactivated and switched to session: $title';
  }

  @override
  String historySessionReopenFailed(String error) {
    return 'Could not reactivate local session: $error';
  }

  @override
  String historySessionReopenedLogsUnavailable(String title) {
    return 'Session “$title” was reactivated, but its logs could not be loaded. It is temporarily read-only; retry loading.';
  }

  @override
  String get historySessionCollaborationReopenRequired =>
      'This is a collaboration session. Open it first, then reopen it from Collaboration & members.';

  @override
  String get historySessionDeleteTitle => 'Permanently delete local session';

  @override
  String historySessionDeleteWarning(String title) {
    return 'This permanently deletes all local logs and the local collaboration replica for “$title”. This cannot be undone, but it will not delete or close the shared session on the server. Enter the full session name to confirm:';
  }

  @override
  String get historySessionDeleteNameLabel => 'Full session name';

  @override
  String historySessionDeleteExpectedName(String title) {
    return 'Expected: $title';
  }

  @override
  String get historySessionDeleteNameMismatch =>
      'The session name does not match. Check every character.';

  @override
  String get historySessionDeleteAction => 'Delete local data permanently';

  @override
  String get historySessionDeleted => 'Local session permanently deleted';

  @override
  String historySessionDeleteFailed(String error) {
    return 'Could not permanently delete local session: $error';
  }

  @override
  String get historySessionReadOnly =>
      'This is a closed historical session. Existing records are read-only.';

  @override
  String controllerWindowOpenFailed(String error) {
    return 'Could not open controller window: $error';
  }

  @override
  String get controllerDisplaySettingsTitle => 'Controller display';

  @override
  String get enableControllerDeviceEntry => 'Enable controller-device entry';

  @override
  String get enableControllerDeviceEntryHint =>
      'When enabled, Sessions can open a full-screen read-only display on an Android tablet, phone, or separate computer.';

  @override
  String get defaultInformationDetail => 'Default information detail';

  @override
  String get desktopControllerDisplayHint =>
      'This desktop can also open an always-on-top window or a second-display window from Sessions.';

  @override
  String get inAppControllerDisplayHint =>
      'This device uses the in-app full-screen controller display.';

  @override
  String get controllerScreenTitle => 'OpenLogTool Controller Display';

  @override
  String get controllerFloatingWindowTitle =>
      'OpenLogTool Controller Floating Window';

  @override
  String get controllerScreenFallbackTitle => 'Net Controller Display';

  @override
  String savedPositionCount(int count) {
    return '$count saved';
  }

  @override
  String get notReceivedDraftUpdate => 'No draft update received';

  @override
  String updatedAt(String time) {
    return 'Updated $time';
  }

  @override
  String editorEditing(String name) {
    return 'Editing by $name';
  }

  @override
  String get connectionConnected => 'Live';

  @override
  String get connectionReconnecting => 'Reconnecting';

  @override
  String get connectionOffline => 'Offline';

  @override
  String get staleControllerDataWarning =>
      'Connection lost. The last received content is shown and may be out of date.';

  @override
  String get previousSavedRecord => 'Previous saved record';

  @override
  String recordOrdinal(int ordinal) {
    return 'Position #$ordinal';
  }

  @override
  String get noPreviousRecord => 'No previous record';

  @override
  String get waitingForCallsign => 'Waiting for a callsign…';

  @override
  String get beingEdited => 'Editing';

  @override
  String configureControllerDisplay(String detail) {
    return 'Display content ($detail)';
  }

  @override
  String get exitControllerScreen => 'Exit controller display';

  @override
  String get controllerDisplayConfiguration => 'Controller display content';

  @override
  String get informationDetail => 'Information detail';

  @override
  String get controllerDisplayScale => 'Controller display zoom';

  @override
  String get controllerDisplayScaleHint =>
      'Adjusts only the controller display, not the main application interface.';

  @override
  String get currentFields => 'Current fields';

  @override
  String get previousFields => 'Previous fields';

  @override
  String get cancel => 'Cancel';

  @override
  String get apply => 'Apply';

  @override
  String get detailMinimal => 'Minimal';

  @override
  String get detailStandard => 'Standard';

  @override
  String get detailFull => 'Full';

  @override
  String get detailCustom => 'Custom';

  @override
  String get fieldController => 'Controller';

  @override
  String get fieldControllerCallsign => 'Controller callsign';

  @override
  String get fieldCallsign => 'Callsign';

  @override
  String get fieldTime => 'Time';

  @override
  String get logTimeInvalid => 'Enter a valid time (HH:mm)';

  @override
  String get fieldRstSent => 'RST sent';

  @override
  String get fieldRstRcvd => 'RST received';

  @override
  String get fieldQth => 'QTH';

  @override
  String get fieldDevice => 'Radio';

  @override
  String get fieldPower => 'Power';

  @override
  String get fieldAntenna => 'Antenna';

  @override
  String get fieldHeight => 'Height';

  @override
  String get fieldRemarks => 'Remarks';

  @override
  String get fieldActions => 'Actions';

  @override
  String inputFieldHint(String field) {
    return 'Enter $field';
  }

  @override
  String optionalFieldHint(String field) {
    return '$field (optional)';
  }

  @override
  String get noSavedRecords => 'No saved records';

  @override
  String get logTableSearchHint => 'Search callsign / QTH / remarks…';

  @override
  String get logTableSearchClear => 'Clear search';

  @override
  String get logTableSearchNoMatches => 'No matching records';

  @override
  String get addFirstRecordHint => 'Add the first record using the form above.';

  @override
  String get editRecord => 'Edit record';

  @override
  String get deleteRecord => 'Delete record';

  @override
  String get deleteRecordConfirmation => 'Delete this record?';

  @override
  String get delete => 'Delete';

  @override
  String get recordDeleted => 'Record deleted';

  @override
  String get savedRecords => 'Saved records';

  @override
  String recordCount(int count) {
    return '$count records';
  }

  @override
  String get restoreLastDeletedRecord => 'Restore last deleted';

  @override
  String get restoreLastDeletedRecordTitle =>
      'Restore the last deleted record?';

  @override
  String get restoreLastDeletedRecordConfirmation =>
      'This restores the most recently deleted net record without changing any other records.';

  @override
  String get recordRestored => 'Record restored';

  @override
  String get saveRecord => 'Save record';

  @override
  String get savingRecord => 'Saving';

  @override
  String get clearEnteredFields => 'Clear fields';

  @override
  String get enteredFieldsCleared =>
      'Fields cleared; controller callsign retained';

  @override
  String get recordAdded => 'Record saved';

  @override
  String get recordQueuedOffline => 'Saved offline; review after reconnecting';

  @override
  String get sharedDraftReadOnly => 'This shared draft is read-only';

  @override
  String fieldLockedBy(String name) {
    return 'Editing by $name';
  }

  @override
  String get finishEditing => 'Finish editing';

  @override
  String get offlineReviewTitle => 'Offline records need review';

  @override
  String get resolutionDiscard => 'Discard';

  @override
  String get resolutionSubmitDuplicate => 'Submit as duplicate';

  @override
  String get resolutionCopyCurrent => 'Copy to current draft';

  @override
  String get callsignRequired => 'Enter a callsign';

  @override
  String get leaveSession => 'Leave collaboration';

  @override
  String get leaveSessionConfirmation =>
      'You will stop receiving updates for this session. Records already on this device will remain read-only, and other members can continue. To join again, you will need a new invitation or approved application. A server connection is required. You do not need to leave just to close this page.';

  @override
  String get moreLocalCollaborationActions => 'More actions';

  @override
  String get createEditableLocalCopy => 'Save independent copy';

  @override
  String get createEditableLocalCopyTitle => 'Save an independent session?';

  @override
  String createEditableLocalCopyConfirmation(String title) {
    return 'Copy the saved table records from “$title” into a new session and switch to it for independent recording, without a server. Your original collaborative session and membership stay unchanged; you can switch back later. Pending sync operations, conflicts, offline records awaiting review and unsubmitted drafts stay in the original session. They are neither copied nor deleted.';
  }

  @override
  String editableLocalCopySessionTitle(String title) {
    return '$title (local copy)';
  }

  @override
  String get editableLocalCopySucceeded =>
      'Switched to the independent copy. The original collaboration was kept.';

  @override
  String get collaborationScreenTitle => 'Collaboration and members';

  @override
  String get collaborationConnectionSection => 'Connection and session';

  @override
  String get collaborationConnectionSectionHint =>
      'Review the server account, current session, and synchronization entry points.';

  @override
  String get collaborationSyncSection => 'Synchronization review';

  @override
  String get collaborationSyncSectionHint =>
      'Review offline records and resolve conflicts that require a decision.';

  @override
  String get collaborationAccessSection => 'Members and sharing';

  @override
  String get collaborationAccessSectionHint =>
      'Manage scribe access, invitation codes, and read-only public pages.';

  @override
  String get serverLoggedIn => 'Signed in';

  @override
  String get serverNotLoggedIn => 'Not signed in to a server';

  @override
  String collaborationServerAccount(String url, String id) {
    return '$url\nAccount $id';
  }

  @override
  String get collaborationServerLoginHint =>
      'Check the server and sign in from Settings → Server and account.';

  @override
  String get remoteCommitPendingLocalApplyHint =>
      'The remote commit succeeded. The client will restore only the local acknowledgement and will not create another mutation.';

  @override
  String get accountSharing => 'Account sharing';

  @override
  String get accountSharingHint =>
      'Request then accept. Shared sessions are read-only until you join with the passphrase.';

  @override
  String get sharedSessionBadge => 'Shared';

  @override
  String sharedSessionFrom(String username) {
    return 'Shared from $username';
  }

  @override
  String get acceptShare => 'Accept';

  @override
  String get pendingInboundShares => 'Pending requests';

  @override
  String get browseSharedSession => 'Browse shared session';

  @override
  String get joinSharedSession => 'Join with passphrase';

  @override
  String get joinCollaborationTitle => 'Join collaboration';

  @override
  String get joinCollaborationHint =>
      'Enter a member invitation code. A complete local replica is installed with the same remote Session ID.';

  @override
  String get inviteCodeLabel => 'Invitation code';

  @override
  String get join => 'Join';

  @override
  String get joinCollaborationSucceeded => 'Joined the collaboration session';

  @override
  String get localCollaborationSessionHint =>
      'This local session is not published. Publishing locks a consistent snapshot and uploads all records in batches.';

  @override
  String collaborationSessionSummary(String state, String role) {
    return 'Status $state · Role $role';
  }

  @override
  String collaborationSyncSummary(String transport, int applied, int head) {
    return 'Sync $transport · Cursor $applied/$head';
  }

  @override
  String collaborationQueueSummary(int pending, int conflicts, int rejected) {
    return 'Pending $pending · Conflicts $conflicts · Rejected $rejected';
  }

  @override
  String get collaborationReliableQueueHint =>
      'Local saves enter the reliable queue and are confirmed by canonical events.';

  @override
  String collaborationLastSync(String time) {
    return 'Last synchronized $time';
  }

  @override
  String get collaborationSessionConflictHint =>
      'The session has an unresolved conflict. Resolve it first; rename, close, and reopen actions are temporarily unavailable.';

  @override
  String get publishSessionSucceeded => 'Collaboration session published';

  @override
  String get publishCollaborationSession => 'Publish for collaboration';

  @override
  String get retryPublishSession => 'Retry publishing';

  @override
  String get syncNowAndRefreshAccess => 'Sync now and refresh access';

  @override
  String get closeSession => 'Close session';

  @override
  String get reopenSession => 'Reopen';

  @override
  String get transportStopped => 'Stopped';

  @override
  String get transportConnecting => 'Connecting';

  @override
  String get transportOnline => 'Online';

  @override
  String get transportBackingOff => 'Waiting to reconnect';

  @override
  String get transportAuthRequired => 'Sign-in required';

  @override
  String get transportIncompatible => 'Protocol error';

  @override
  String get readOnlyRevoked =>
      'Membership has been revoked. The local cache is read-only.';

  @override
  String get readOnlyClosePending =>
      'The end request is awaiting sync confirmation. Records are temporarily read-only.';

  @override
  String get readOnlyReopenPending =>
      'The reopen request is saved locally. The session remains read-only until the server confirms it.';

  @override
  String get readOnlySessionClosed =>
      'Shared recording has ended. Existing records remain available to view.';

  @override
  String get readOnlyViewer => 'This account is a read-only member.';

  @override
  String get readOnlyResyncing =>
      'Restoring synchronization. Saved changes will be kept.';

  @override
  String get readOnlyCheckingAccess =>
      'Checking your participation permissions. Viewing only for now.';

  @override
  String get logNotOwnedReadOnlyHint =>
      'You can change or delete only records that you created.';

  @override
  String get logAuthorUnknownReadOnlyHint =>
      'This historical record has no author information and is read-only for members.';

  @override
  String get logSessionReadOnlyHint =>
      'The current member role, session state, or synchronization state does not allow record changes.';

  @override
  String get logConflictReadOnlyHint =>
      'Resolve this record in the conflict center first.';

  @override
  String get renameCollaborationSession => 'Rename collaboration session';

  @override
  String get saveLocally => 'Save locally';

  @override
  String get sessionTitleQueued =>
      'Title saved locally and awaiting synchronization';

  @override
  String get closeCollaborationSessionTitle => 'End shared recording';

  @override
  String get closeCollaborationSessionMessage =>
      'All members will stop adding or editing records. Existing records and membership will be kept, and you can resume recording later. This change must sync to the server. You do not need to end recording just to leave this page.';

  @override
  String get closeSharedSession => 'End shared recording';

  @override
  String get closeCollaborationDraftNotEmpty =>
      'The current check-in draft has content. Submit the complete record or explicitly discard the draft before ending recording.';

  @override
  String get closeCollaborationDraftIncomplete =>
      'The draft is missing the time, controller callsign or check-in callsign. It cannot be submitted, but can be explicitly discarded before ending recording.';

  @override
  String closeCollaborationDraftLocked(int count) {
    return 'Other members or devices are editing $count draft fields. Wait for them to finish and refresh before ending recording.';
  }

  @override
  String get closeCollaborationDiscardAndClose => 'Discard draft and end';

  @override
  String get closeCollaborationSubmitAndClose => 'Submit and end';

  @override
  String get closeCollaborationQueuedOffline =>
      'The record is only saved in the offline queue and has not reached the server. Shared recording has not ended. Reconnect and resolve the record before trying again.';

  @override
  String get closeSessionQueued =>
      'The request to end shared recording was saved and is awaiting sync confirmation.';

  @override
  String get reopenCollaborationSessionTitle => 'Reopen collaboration session';

  @override
  String get reopenCollaborationSessionMessage =>
      'Reopening is submitted as a synchronized change. The session remains read-only until confirmed.';

  @override
  String get reopenSessionQueued =>
      'Reopen request saved locally and awaiting synchronization';

  @override
  String get conflictUseRemoteTitle => 'Use remote version';

  @override
  String get conflictKeepLocalTitle => 'Keep local version';

  @override
  String get conflictCopyLocalTitle => 'Copy as a new log';

  @override
  String get conflictUseRemoteMessage =>
      'Unsynchronized local changes are replaced by the canonical remote version. No new mutation is submitted.';

  @override
  String get conflictKeepLocalMessage =>
      'A new mutation is based on the latest remote version. Another remote change can still produce a new conflict.';

  @override
  String get conflictCopyLocalMessage =>
      'The remote log is preserved, while the local content is copied under a new log ID and synchronized again.';

  @override
  String get conflictUseRemoteSucceeded => 'Remote version applied';

  @override
  String get conflictKeepLocalSucceeded =>
      'Local version kept and queued for retry';

  @override
  String get conflictCopyLocalSucceeded =>
      'Copied as a new log and queued for synchronization';

  @override
  String get conflictCenterTitle => 'Conflict center';

  @override
  String get refreshConflicts => 'Refresh conflicts';

  @override
  String get conflictCenterHint =>
      'Available actions reflect the latest access and entity state in the local replica. Keeping or copying creates a new synchronized mutation.';

  @override
  String get noConflicts => 'No conflicts need attention.';

  @override
  String get conflictSession => 'Session';

  @override
  String get conflictLog => 'Log';

  @override
  String get conflictNoOverlappingFields =>
      'No overlapping fields (the version changed)';

  @override
  String conflictVersionSummary(String fields, int base, int remote) {
    return 'Fields $fields · Base v$base → remote v$remote';
  }

  @override
  String get conflictBase => 'Base';

  @override
  String get conflictLocal => 'Local';

  @override
  String get conflictRemote => 'Remote';

  @override
  String get conflictUseRemoteAction => 'Use remote';

  @override
  String get conflictKeepLocalAction => 'Keep local and retry';

  @override
  String get conflictCopyLocalAction => 'Copy as a new log';

  @override
  String get memberInvitesTitle => 'Member invitations';

  @override
  String get roleOwner => 'Owner';

  @override
  String get roleEditor => 'Editor';

  @override
  String get roleViewer => 'Read-only member';

  @override
  String get inviteCreated => 'Invitation code created';

  @override
  String get generate => 'Generate';

  @override
  String get inviteCodeOneTimeHint =>
      'The invitation code is shown only in this creation response:';

  @override
  String get noInvites => 'No invitations';

  @override
  String inviteSummary(int used, int max, String status) {
    return '$used/$max uses · $status';
  }

  @override
  String inviteExpiresAt(String time) {
    return 'Expires $time';
  }

  @override
  String get inviteRevoked => 'Revoked';

  @override
  String get membersTitle => 'Members';

  @override
  String get currentAccount => 'Current account';

  @override
  String get memberSetEditor => 'Member changed to editor';

  @override
  String get memberSetViewer => 'Member changed to read-only';

  @override
  String get setAsEditor => 'Make editor';

  @override
  String get setAsViewer => 'Make read-only';

  @override
  String get transferOwnership => 'Transfer ownership';

  @override
  String get removeMember => 'Remove member';

  @override
  String transferOwnershipConfirmation(String name) {
    return 'After transferring to $name, you become an editor.';
  }

  @override
  String get ownershipTransferred => 'Ownership transferred';

  @override
  String removeMemberConfirmation(String name) {
    return 'Remove $name? Their access is revoked immediately.';
  }

  @override
  String get memberRemoved => 'Member removed';

  @override
  String operationFailed(String error) {
    return 'Action failed: $error';
  }

  @override
  String get unknown => 'Unknown';

  @override
  String get confirm => 'Confirm';

  @override
  String get duplicateCallsignWarningSetting => 'Duplicate callsign warning';

  @override
  String get duplicateCallsignWarningHint =>
      'Check immediately after entering a callsign for an existing record in this net, and ask whether to update the old record or add a new one.';

  @override
  String get autoAppendPowerWSetting => 'Auto-append W to power';

  @override
  String get autoAppendPowerWHint =>
      'Append W to a plain numeric power (e.g. 50, 50.5) when saving; leave values that already carry a unit or contain Chinese untouched.';

  @override
  String get duplicateCallsignTitle => 'Callsign already recorded';

  @override
  String duplicateCallsignMessage(String callsign) {
    return '$callsign is already recorded in this net. Save it again?';
  }

  @override
  String get saveAnyway => 'Save anyway';

  @override
  String get duplicateUpdateOldRecord => 'Update old record';

  @override
  String get duplicateAddNewRecord => 'Add new record';

  @override
  String get duplicateContinueDialogTitle => 'Callsign already recorded';

  @override
  String duplicateContinueDialogMessage(String callsign, int ordinal) {
    return '$callsign was already logged at position $ordinal. Continue adding it?';
  }

  @override
  String get duplicateContinueAdd => 'Continue adding';

  @override
  String get duplicateUpdateDialogTitle => 'Callsign already recorded';

  @override
  String duplicateUpdateDialogMessage(String callsign) {
    return '$callsign already has a record in this net. Choose how to proceed:';
  }

  @override
  String duplicateOldRecordSummary(int ordinal, String time, String callsign,
      String rstSent, String rstRcvd, String qth) {
    return 'Existing (#$ordinal): $time $callsign $rstSent/$rstRcvd $qth';
  }

  @override
  String get recordUpdated => 'Record updated';

  @override
  String get callsignHistoryFillSetting => 'Reuse callsign history';

  @override
  String get callsignHistoryFillHint =>
      'Match existing callsign records and fill the radio, antenna, QTH, and related fields in one tap.';

  @override
  String get publicShareManagement => 'Live Share · public read-only page';

  @override
  String get publicShareManagementHint =>
      'Create a read-only web page for controllers, remote scribes, or observers. It can be viewed without signing in; the link secret is shown only when created.';

  @override
  String get publicShareAccessRequired =>
      'Live Share is managed by the collaboration session owner. Sign in and publish this session first, or ask the owner to create the public link.';

  @override
  String get publicShareUnsupported =>
      'This server does not provide the secure Live Share page. Upgrade or enable public sharing on the server to create one.';

  @override
  String get publicShareCreatedTitle => 'Public read-only page created';

  @override
  String get publicShareCreatedHint =>
      'Save this link now. For security, its secret cannot be retrieved again after a refresh or sign-in.';

  @override
  String get createPublicShare => 'Create public link';

  @override
  String get publicShareExpiryDialogTitle => 'Set Live Share expiration';

  @override
  String get publicShareExpiryDialogHint =>
      'The public link will expire automatically after the selected duration.';

  @override
  String get publicShareExpiryPresets => 'Presets';

  @override
  String get publicShareExpiryOneHour => '1 hour';

  @override
  String get publicShareExpirySixHours => '6 hours';

  @override
  String get publicShareExpiryTwelveHours => '12 hours';

  @override
  String get publicShareExpiryOneDay => '1 day';

  @override
  String get publicShareExpiryThreeDays => '3 days';

  @override
  String get publicShareExpirySevenDays => '7 days';

  @override
  String get publicShareExpiryThirtyDays => '30 days';

  @override
  String get publicShareExpiryCustom => 'Custom';

  @override
  String get publicShareExpiryCustomHours => 'Validity (hours)';

  @override
  String get publicShareExpiryRangeError =>
      'Enter a whole number from 1 to 720.';

  @override
  String publicShareEstimatedExpiry(String time) {
    return 'Estimated expiry: $time (local time)';
  }

  @override
  String get copyPublicShareLink => 'Copy link';

  @override
  String get openPublicShare => 'Open in browser';

  @override
  String get revokePublicShare => 'Revoke';

  @override
  String get publicShareLinkCopied => 'Public link copied';

  @override
  String get publicShareNoActiveLinks =>
      'There are no active public links. Create one for a controller or remote observer.';

  @override
  String get publicShareSecretUnavailable =>
      'An active public link exists, but its secret was returned only when created. If it was not saved, revoke it and create a new link.';

  @override
  String get publicShareLinksTitle => 'Public link history';

  @override
  String get publicShareUnavailable => 'Revoked or expired';

  @override
  String get publicShareOpenFailed =>
      'Could not open the browser. You can still copy the link and open it manually.';

  @override
  String publicShareExpiresAt(String time) {
    return 'Expires $time';
  }

  @override
  String get refresh => 'Refresh';

  @override
  String get reuseDatabaseInformation => 'Reuse database information';

  @override
  String get collapseSidebar => 'Collapse sidebar';

  @override
  String get expandSidebar => 'Expand sidebar';

  @override
  String get limitWorkbenchWidthSetting => 'Limit Net Desk content width';

  @override
  String get limitWorkbenchWidthHint =>
      'Center Net Desk content and limit it to 1520 pixels on wide screens to keep fields from stretching too far.';

  @override
  String serverConnectionFailed(String detail) {
    return 'Connection failed: $detail';
  }

  @override
  String serverNetworkError(String url) {
    return 'The server at $url did not respond. Check the address and port, and make sure the server or reverse proxy is running.';
  }

  @override
  String serverWebMixedContentError(String url) {
    return 'This WebClient uses HTTPS, so the browser cannot connect to the HTTP server at $url. Enable HTTPS for the server.';
  }

  @override
  String serverWebCrossOriginError(String url, String origin) {
    return 'The browser could not access $url. Confirm the server is online. If native clients can connect, add $origin to the server\'s CORS_ORIGINS or use a same-origin reverse proxy.';
  }

  @override
  String serverNetworkTimeout(String url) {
    return 'The connection to $url timed out. Check the network, firewall, and server status.';
  }

  @override
  String serverInvalidResponse(String url) {
    return 'Connected to $url, but it did not return a compatible OpenLogTool Server response.';
  }

  @override
  String get serverAddressRequired => 'Enter a server address first.';

  @override
  String get serverAddressInvalid =>
      'The server address must be a complete http(s) URL.';

  @override
  String get serverSettingsTitle => 'Server and account';

  @override
  String get serverAddressLabel => 'Server address';

  @override
  String get serverAddressHint => 'http://your-server:3000';

  @override
  String get serverSaveAndCheck => 'Save and check server';

  @override
  String serverCheckSucceeded(int min, int max) {
    return 'Connected · protocol v$min-$max';
  }

  @override
  String serverInstanceDetails(String instance, String features) {
    return 'Instance $instance\nCapabilities $features';
  }

  @override
  String get serverConnected => 'Connected';

  @override
  String get serverNotConnected => 'Not checked';

  @override
  String get serverSignedOutHint =>
      'Sign in to collaborate and manage only your own account and sign-in devices.';

  @override
  String get tokenStoragePrivateFileWarning =>
      'The system keyring is unavailable. Your sign-in is stored in a private file readable only by your Linux user and will move back to secure storage when a keyring becomes available.';

  @override
  String get tokenStorageMemoryOnlyWarning =>
      'Secure credential storage is unavailable. This sign-in lasts only while the app is running; you will need to sign in again after exiting.';

  @override
  String get serverLogin => 'Sign in';

  @override
  String get serverRegister => 'Register';

  @override
  String get serverLogout => 'Sign out';

  @override
  String serverAccountId(String id) {
    return 'Account ID: $id';
  }

  @override
  String get serverLoginSucceeded => 'Signed in to the server';

  @override
  String get serverRegistrationSucceeded => 'Registered and signed in';

  @override
  String serverLoginFailed(String error) {
    return 'Sign-in failed: $error';
  }

  @override
  String serverRegistrationFailed(String error) {
    return 'Registration failed: $error';
  }

  @override
  String serverLogoutFailed(String error) {
    return 'Sign-out failed: $error';
  }

  @override
  String get accountChangeUsername => 'Change username';

  @override
  String get accountChangePassword => 'Change password';

  @override
  String get accountDeviceSessions => 'Sign-in devices';

  @override
  String get accountUsernameUpdated => 'Username updated';

  @override
  String accountPasswordUpdated(int count) {
    return 'Password updated. $count sign-in sessions were revoked; sign in again.';
  }

  @override
  String accountUpdateFailed(String error) {
    return 'Account action failed: $error';
  }

  @override
  String get usernameLabel => 'Username';

  @override
  String get usernameLengthHint => 'Username must be 3–64 characters';

  @override
  String get passwordLabel => 'Password';

  @override
  String get fieldRequired => 'This field is required';

  @override
  String get currentPasswordLabel => 'Current password';

  @override
  String get newPasswordLabel => 'New password';

  @override
  String get confirmNewPasswordLabel => 'Confirm new password';

  @override
  String get passwordLengthHint => 'Password must be at least 10 characters';

  @override
  String get passwordMismatch => 'The new passwords do not match';

  @override
  String get passwordChangeRequiredTitle =>
      'Temporary password must be changed';

  @override
  String passwordChangeRequiredHint(String username) {
    return 'Account $username signed in with a temporary password. Set a new password to continue.';
  }

  @override
  String passwordChangeCredentialExpires(int seconds) {
    return 'This password-change credential expires in $seconds seconds.';
  }

  @override
  String get completePasswordChange => 'Set password and sign in';

  @override
  String get cancelLogin => 'Cancel sign-in';

  @override
  String get passwordChangeCompleted =>
      'Password updated and sign-in completed';

  @override
  String get deviceSessionsTitle => 'Sign-in devices';

  @override
  String get deviceSessionsEmpty => 'There are no active sign-in devices';

  @override
  String get deviceUnknown => 'Unnamed device';

  @override
  String get deviceCurrent => 'Current device';

  @override
  String deviceIp(String ip) {
    return 'IP: $ip';
  }

  @override
  String deviceLastUsed(String time) {
    return 'Last used: $time';
  }

  @override
  String deviceExpires(String time) {
    return 'Expires: $time';
  }

  @override
  String get revokeDevice => 'Revoke device';

  @override
  String get revokeCurrentDevice => 'Sign out this device';

  @override
  String get revokeDeviceConfirmation =>
      'After revocation, this device can no longer refresh its sign-in session.';

  @override
  String get revokeCurrentDeviceConfirmation =>
      'After signing out this device, enter your username and password again to reconnect.';

  @override
  String get deviceRevoked => 'Sign-in device revoked';

  @override
  String get close => 'Close';

  @override
  String get retry => 'Retry';

  @override
  String get excelUseSessionTitleAsHeader =>
      'Use current session name as header';

  @override
  String get excelUseSessionTitleAsHeaderHint =>
      'Use the current session name directly as the Excel header. If it is blank, the header template is used instead.';

  @override
  String get fileNameUseSessionTitle => 'Use current session name as file name';

  @override
  String get fileNameUseSessionTitleHint =>
      'Use the current session name directly as the export file name. If it is blank, the file name template is used instead.';

  @override
  String get themeColorPickerTitle => 'Choose theme color';

  @override
  String get themeColorPresets => 'Preset colors';

  @override
  String get themeColorCustom => 'Custom color';

  @override
  String get themeColorHex => 'HEX color';

  @override
  String get themeColorHue => 'Hue';

  @override
  String get themeColorBlue => 'Blue';

  @override
  String get themeColorGreen => 'Green';

  @override
  String get themeColorRed => 'Red';

  @override
  String get themeColorOrange => 'Orange';

  @override
  String get themeColorPurple => 'Purple';

  @override
  String get themeColorPink => 'Pink';

  @override
  String get save => 'Save';

  @override
  String get add => 'Add';

  @override
  String get renameSession => 'Rename session';

  @override
  String get renameSessionTitle => 'Rename session';

  @override
  String get sessionTitleLabel => 'Session name';

  @override
  String get renameCollaborationSessionHint =>
      'Only the session owner can rename it. The new name will sync to other scribes and controller displays.';

  @override
  String get renameSessionSaved => 'Session name updated';

  @override
  String get renameCollaborationSessionSaved =>
      'Session name saved and syncing to other members';

  @override
  String renameSessionFailed(String error) {
    return 'Could not rename session: $error';
  }

  @override
  String get renameSessionBlockedClosed => 'A closed session cannot be renamed';

  @override
  String get renameSessionBlockedBusy =>
      'Wait for the current collaboration operation to finish';

  @override
  String get renameSessionBlockedConflict =>
      'Resolve the session conflict before renaming';

  @override
  String get renameSessionBlockedNotReady =>
      'The collaboration session is not ready to be renamed';

  @override
  String get renameSessionBlockedOwner =>
      'Only the session owner can rename it';

  @override
  String get dictionaryManagementTitle => 'Lookup libraries';

  @override
  String get dictionaryManagementHint =>
      'Manage radios, antennas, callsigns, and QTH values that can be searched and reused while logging.';

  @override
  String get deviceLibrary => 'Radio library';

  @override
  String get antennaLibrary => 'Antenna library';

  @override
  String get callsignLibrary => 'Callsign library';

  @override
  String get qthLibrary => 'QTH library';

  @override
  String libraryItemCount(int count) {
    return '$count entries';
  }

  @override
  String get importLibraryJson => 'Import JSON';

  @override
  String get expandAll => 'Expand all';

  @override
  String get collapseAll => 'Collapse all';

  @override
  String addLibraryItem(String name) {
    return 'Add to $name';
  }

  @override
  String searchLibrary(String name) {
    return 'Search $name';
  }

  @override
  String get libraryEmpty => 'This library is empty';

  @override
  String get noLibrarySearchResults => 'No matching library entries';

  @override
  String libraryItemAdded(String value) {
    return 'Added: $value';
  }

  @override
  String libraryItemAlreadyExists(String value) {
    return '“$value” is already in the library';
  }

  @override
  String libraryItemAddFailed(String error) {
    return 'Could not add entry: $error';
  }

  @override
  String get deleteLibraryItemTitle => 'Delete library entry';

  @override
  String deleteLibraryItemConfirmation(String value, String name) {
    return 'Delete “$value” from $name?';
  }

  @override
  String get deleteLibraryItemAction => 'Delete';

  @override
  String libraryItemDeleted(String value) {
    return 'Deleted: $value';
  }

  @override
  String libraryItemDeleteFailed(String error) {
    return 'Could not delete entry: $error';
  }

  @override
  String clearLibraryTitle(String name) {
    return 'Clear $name';
  }

  @override
  String clearLibraryConfirmation(String name, int count) {
    return 'This will delete all $count entries from $name. This cannot be undone. Continue?';
  }

  @override
  String get clearLibraryAction => 'Clear all';

  @override
  String libraryCleared(String name) {
    return 'Cleared $name';
  }

  @override
  String libraryClearFailed(String error) {
    return 'Could not clear library: $error';
  }

  @override
  String get libraryImportEmpty => 'The file has no library entries to import';

  @override
  String libraryImportCount(String name, int count) {
    return '$name: $count';
  }

  @override
  String libraryImportSucceeded(String summary) {
    return 'Imported: $summary';
  }

  @override
  String libraryImportFailed(String error) {
    return 'Could not import libraries: $error';
  }

  @override
  String get listSeparator => ', ';

  @override
  String get fontPickerTitle => 'Choose font';

  @override
  String get fontSearchHint => 'Search fonts';

  @override
  String fontResultCount(int count) {
    return '$count fonts';
  }

  @override
  String get fontSystemDefault => 'System default';

  @override
  String get fontBuiltIn => 'Built in';

  @override
  String get fontPreview => 'Preview';

  @override
  String get fontPreviewSample => 'OpenLogTool · CQ CQ · Net log 123';

  @override
  String get aboutAppAction => 'About';

  @override
  String get aboutAppTitle => 'About OpenLogTool';

  @override
  String get aboutAppTagline => 'Amateur-radio net logging and collaboration';

  @override
  String get aboutAppDescription =>
      'Complete net logging, live-draft collaboration, and controller displays for on-site and remote scribes. OpenLogTool focuses on net-control workflows rather than replacing a personal contact log.';

  @override
  String aboutVersionChip(String version) {
    return 'Version $version';
  }

  @override
  String get aboutVersionSection => 'Version information';

  @override
  String get aboutVersionLabel => 'App version';

  @override
  String get aboutBuildLabel => 'Build number';

  @override
  String get aboutCommitLabel => 'Commit';

  @override
  String get aboutCopyVersionInfo => 'Copy version information';

  @override
  String get aboutVersionInfoCopied => 'Version information copied';

  @override
  String get aboutCheckUpdates => 'Check for updates';

  @override
  String get aboutCheckingUpdates => 'Checking…';

  @override
  String aboutUpToDate(String version) {
    return 'You’re up to date ($version)';
  }

  @override
  String get aboutUpdateAvailableTitle => 'Update available';

  @override
  String aboutUpdateAvailableMessage(
      String currentVersion, String latestVersion) {
    return 'Current version: $currentVersion\nLatest version: $latestVersion';
  }

  @override
  String get aboutOpenRelease => 'View release';

  @override
  String get aboutUpdateLater => 'Not now';

  @override
  String get aboutUpdateCheckFailed =>
      'Couldn’t check for updates. Check your connection and try again.';

  @override
  String get aboutProjectSection => 'Project & licenses';

  @override
  String get aboutRepository => 'Project repository';

  @override
  String get aboutRepositoryHint =>
      'View source code and project documentation';

  @override
  String get aboutIssueTracker => 'Report an issue';

  @override
  String get aboutIssueTrackerHint => 'Report a bug or suggest an improvement';

  @override
  String get aboutOpenSourceLicenses => 'Open-source licenses';

  @override
  String get aboutOpenSourceLicensesHint =>
      'Review licenses for third-party components';

  @override
  String get aboutLicenseName => 'GNU AGPL-3.0';

  @override
  String get aboutLicenseHint => 'OpenLogTool is free and open-source software';

  @override
  String get aboutCopyright => '© 2026 Mazha0309 · BG5CRL';

  @override
  String aboutLinkOpenFailed(String error) {
    return 'Could not open the link: $error';
  }

  @override
  String get restoreDefaultSettings => 'Restore default settings';

  @override
  String get settingsTitle => 'App settings';

  @override
  String get settingsSubtitle =>
      'Manage appearance, Net Desk behavior, controller displays, server accounts, and on-device data in one place.';

  @override
  String get settingsAppearanceTitle => 'Appearance & language';

  @override
  String get settingsAppearanceHint =>
      'Choose the theme, font, and interface language. Changes apply immediately.';

  @override
  String get themeColorSetting => 'Theme color';

  @override
  String get themeColorSettingHint =>
      'Set the accent color used for actions, selections, and highlights.';

  @override
  String get chooseThemeColor => 'Choose color';

  @override
  String get darkModeSetting => 'Dark mode';

  @override
  String get darkModeSettingHint =>
      'Switch between the light and dark color schemes.';

  @override
  String get appFontSetting => 'App font';

  @override
  String get appFontSettingHint =>
      'Choose the font used throughout the interface.';

  @override
  String get appLanguageSetting => 'Interface language';

  @override
  String get appLanguageSettingHint =>
      'Follow the system or use Simplified Chinese or English.';

  @override
  String get languageFollowSystem => 'Follow system';

  @override
  String get languageSimplifiedChinese => '简体中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get layoutSettingsTitle => 'Net Desk & layout';

  @override
  String get layoutSettingsHint =>
      'Adjust Net Desk width, pagination, and logging assistance.';

  @override
  String get paginationSetting => 'Paginate records';

  @override
  String get paginationSettingHint =>
      'Split records into pages with a configurable size.';

  @override
  String get tablePageSizeLabel => 'Records per page';

  @override
  String get tablePageSizeHint => 'How many saved records each page shows';

  @override
  String get recordEditorDialogSetting => 'Edit records in a dialog';

  @override
  String get recordEditorDialogSettingHint =>
      'Open the full form in a dialog when editing a record, with dictionary suggestions. Turn off to edit inline in the table.';

  @override
  String get controllerDisplaySettingsHint =>
      'Configure controller-device access, separate windows, and default display content.';

  @override
  String get serverSettingsHint =>
      'Configure the collaboration server and manage the current account and sign-in devices.';

  @override
  String get settingsSupportTitle => 'App information & settings maintenance';

  @override
  String get settingsSupportHint =>
      'Review version and open-source information, or restore interface and logging preferences.';

  @override
  String get restoreDefaultSettingsHint =>
      'Restore appearance, language, layout, and export preferences without affecting records or sign-in state.';

  @override
  String get logsTitle => 'Logs';

  @override
  String get logsView =>
      'Review persistent diagnostics, errors, and in-app messages';

  @override
  String get logsEmpty => 'No logs yet';

  @override
  String get logsCopy => 'Copy';

  @override
  String get logsClose => 'Close';

  @override
  String get logsCopied => 'Logs copied';

  @override
  String logsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count persistent logs',
      one: '1 persistent log',
      zero: 'No persistent logs',
    );
    return '$_temp0';
  }

  @override
  String get logsSearchHint => 'Search messages, sources, errors, or stacks';

  @override
  String get logsLevelAll => 'All';

  @override
  String get logsLevelDebug => 'Debug';

  @override
  String get logsLevelInfo => 'Info';

  @override
  String get logsLevelWarning => 'Warning';

  @override
  String get logsLevelError => 'Error';

  @override
  String get logsClear => 'Clear';

  @override
  String get logsClearTitle => 'Clear diagnostic logs';

  @override
  String get logsClearConfirmation =>
      'Delete all diagnostic logs saved on this device? Check-in records will not be affected.';

  @override
  String get logsCleared => 'Diagnostic logs cleared';

  @override
  String get logsNoFilterResults => 'No logs match the current filters';

  @override
  String get authSessionExpiredNotice =>
      'Your server sign-in has expired. Sign in again; local data and the server address were preserved.';

  @override
  String get authStorageUnavailableNotice =>
      'Persistent sign-in credentials could not be read. Check the system credential store and sign in again.';

  @override
  String get resetSettingsTitle => 'Restore default settings';

  @override
  String get resetSettingsConfirmation =>
      'Restore appearance, language, layout, and export preferences to their defaults. Local records, lookup libraries, server accounts, and sign-in state are not affected.';

  @override
  String get resetSettingsConfirmAction => 'Restore defaults';

  @override
  String get resetSettingsSucceeded => 'Default settings restored';

  @override
  String resetSettingsFailed(String error) {
    return 'Could not restore default settings: $error';
  }

  @override
  String get localDataOperationsTitle => 'On-device data';

  @override
  String get localDataOperationsHint =>
      'Diagnose, back up, restore, or reset this device\'s database. These actions do not directly change server data.';

  @override
  String get databaseDiagnosticsSection => 'Diagnostics';

  @override
  String get databaseBackupSection => 'Backup & restore';

  @override
  String get personalCloudTitle => 'Personal cloud sync';

  @override
  String get personalCloudHint =>
      'Personal sessions, net records, and your dictionary changes synchronize automatically between signed-in devices. Collaboration sessions keep using their separate realtime workflow.';

  @override
  String get personalCloudSignedOut =>
      'Sign in to automatically synchronize personal records and dictionary changes';

  @override
  String get personalCloudUnsupported =>
      'This server version does not support account personal snapshots; upgrade the server first';

  @override
  String get personalCloudChecking =>
      'Comparing on-device records and dictionaries with the account snapshots…';

  @override
  String get personalCloudSyncing =>
      'Synchronizing personal records and dictionary changes…';

  @override
  String get personalCloudUpToDate =>
      'Personal records and dictionary changes are up to date';

  @override
  String get personalCloudDecisionRequired =>
      'A first-time pairing or real edit conflict needs your confirmation. Unrelated changes have already been merged safely.';

  @override
  String personalCloudError(String error) {
    return 'Account personal snapshot sync failed: $error';
  }

  @override
  String personalCloudLocalSummary(int sessionCount, int logCount) {
    return 'Personal records on device: $sessionCount sessions and $logCount records';
  }

  @override
  String personalCloudRemoteSummary(
      int sessionCount, int logCount, int revision) {
    return 'Account snapshot: $sessionCount sessions and $logCount records · revision $revision';
  }

  @override
  String get personalCloudRemoteEmpty =>
      'This account does not have a personal records snapshot yet';

  @override
  String personalCloudDictionaryLocalSummary(int itemCount) {
    return 'Dictionary changes on device: $itemCount';
  }

  @override
  String personalCloudDictionaryRemoteSummary(int itemCount, int revision) {
    return 'Account dictionary snapshot: $itemCount changes · revision $revision';
  }

  @override
  String get personalCloudDictionaryRemoteEmpty =>
      'This account does not have a dictionary snapshot yet';

  @override
  String personalCloudConflictSummary(int count) {
    return '$count conflicting field(s) need a choice';
  }

  @override
  String get personalCloudConfirmMerge => 'Confirm safe merge';

  @override
  String get personalCloudKeepLocalConflicts => 'Keep device values';

  @override
  String get personalCloudKeepRemoteConflicts => 'Keep cloud values';

  @override
  String get personalCloudResolveOneByOne => 'Resolve one by one';

  @override
  String get personalCloudConflictDialogTitle => 'Resolve conflicts';

  @override
  String get personalCloudConflictPageTitle => 'Personal cloud conflicts';

  @override
  String get personalCloudConflictPageHint =>
      'Compare the device, cloud, and common baseline one item at a time. Every conflict requires your explicit choice before merging. Collaboration conflicts remain in Sessions.';

  @override
  String get personalCloudConflictSelectAllLocal => 'Select all device';

  @override
  String get personalCloudConflictSelectAllRemote => 'Select all cloud';

  @override
  String personalCloudConflictSelectionProgress(int selected, int total) {
    return 'Selected $selected of $total; choose every item before applying.';
  }

  @override
  String get personalCloudConflictApply => 'Apply choices';

  @override
  String get personalCloudConflictApplySucceeded =>
      'Conflict choices applied and synchronized';

  @override
  String get personalCloudConflictNoneTitle => 'No synchronization conflicts';

  @override
  String get personalCloudConflictNoneHint =>
      'No personal record or dictionary conflict needs a decision. Synchronization status and manual sync are available under Local database.';

  @override
  String get personalCloudConflictConfirmationPendingTitle =>
      'No field conflicts, but first-merge confirmation is pending';

  @override
  String get personalCloudConflictConfirmationPendingHint =>
      'Return to Local database, review the device and cloud counts, then confirm the safe merge.';

  @override
  String get personalCloudConflictRecordsDataset => 'Personal records';

  @override
  String get personalCloudConflictDictionaryDataset => 'Personal dictionary';

  @override
  String personalCloudConflictEntityReference(String dataset, String id) {
    return '$dataset · ID $id';
  }

  @override
  String get personalCloudConflictBaseline => 'Common baseline';

  @override
  String get personalCloudConflictValueAbsent =>
      'Does not exist (choosing this side deletes the item)';

  @override
  String get personalCloudConflictValueEmpty => 'Empty value';

  @override
  String get personalCloudConflictLifecycleField => 'Session state';

  @override
  String get personalCloudConflictDeletionField => 'Deletion state';

  @override
  String get personalCloudConflictDictionaryStateField => 'Dictionary state';

  @override
  String personalCloudFieldConflictTitle(String field) {
    return 'Field $field differs on both sides';
  }

  @override
  String personalCloudEntityConflictTitle(String entity) {
    return '$entity conflict';
  }

  @override
  String get personalCloudEntitySession => 'Session';

  @override
  String get personalCloudEntityLog => 'Record';

  @override
  String get personalCloudEntityDictionaryItem => 'Dictionary item';

  @override
  String get personalCloudKeepLocal => 'Keep device';

  @override
  String get personalCloudKeepRemote => 'Keep cloud';

  @override
  String get personalCloudSyncNow => 'Sync personal snapshot';

  @override
  String get personalCloudReplaceRemote => 'Replace snapshot with device';

  @override
  String get personalCloudRestoreLocal => 'Restore device from snapshot';

  @override
  String get personalCloudReplaceTitle => 'Replace account personal snapshot';

  @override
  String personalCloudReplaceWarning(
      int localSessions, int localLogs, int remoteSessions, int remoteLogs) {
    return 'The $localSessions personal sessions and $localLogs records on this device will completely replace the $remoteSessions sessions and $remoteLogs records in the account snapshot. This does not create or modify collaboration sessions. The change will synchronize to other signed-in devices.';
  }

  @override
  String get personalCloudReplacePhrase =>
      'REPLACE ACCOUNT SNAPSHOT WITH DEVICE';

  @override
  String get personalCloudReplaceAction => 'Replace snapshot';

  @override
  String get personalCloudRestoreTitle =>
      'Restore from account personal snapshot';

  @override
  String personalCloudRestoreWarning(
      int remoteSessions, int remoteLogs, int localSessions, int localLogs) {
    return 'The $remoteSessions sessions and $remoteLogs records in the account snapshot will replace the $localSessions sessions and $localLogs personal records on this device. Libraries, settings, and collaboration sessions are unaffected.';
  }

  @override
  String get personalCloudRestorePhrase =>
      'RESTORE DEVICE FROM ACCOUNT SNAPSHOT';

  @override
  String get personalCloudRestoreAction => 'Restore this device';

  @override
  String get personalCloudReplaceSucceeded =>
      'The account snapshot now contains this device\'s personal records';

  @override
  String get personalCloudRestoreSucceeded =>
      'Personal records were restored from the account snapshot';

  @override
  String get databaseDangerZoneSection => 'Danger zone';

  @override
  String get databaseStatusTitle => 'On-device database status';

  @override
  String get databaseStatusHint =>
      'Review local content, collaboration work, and advanced diagnostics';

  @override
  String databaseStatusSchemaVersion(String version) {
    return 'Database schema version: $version';
  }

  @override
  String databaseStatusBackupFormatVersion(String version) {
    return 'Backup format version: $version';
  }

  @override
  String get databaseStatusLocalContentSection => 'On-device content';

  @override
  String get databaseStatusLocalContentHint =>
      'Sessions, net-control records, and library items stored in this device database';

  @override
  String get databaseStatusSessionsLabel => 'Sessions';

  @override
  String databaseStatusSessionsSummary(
      int active, int closed, int archived, int deleted) {
    return '$active active · $closed closed · $archived archived · $deleted deleted';
  }

  @override
  String get databaseStatusLogsLabel => 'Net-control records';

  @override
  String get databaseStatusDictionariesLabel => 'Library items';

  @override
  String databaseStatusLifecycleSummary(int active, int deleted) {
    return '$active available · $deleted deleted';
  }

  @override
  String databaseStatusDictionarySummary(
      String label, int active, int deleted) {
    return '$label $active ($deleted deleted)';
  }

  @override
  String get databaseStatusDictionaryDevice => 'Devices';

  @override
  String get databaseStatusDictionaryAntenna => 'Antennas';

  @override
  String get databaseStatusDictionaryQth => 'QTH';

  @override
  String get databaseStatusDictionaryCallsign => 'Call signs';

  @override
  String get databaseStatusCollaborationSection => 'Collaboration state';

  @override
  String get databaseStatusCollaborationHint =>
      'These are local replicas and sync queues, not a count of all server data';

  @override
  String get databaseStatusCollaborationHealthy =>
      'There are no pending uploads, unresolved conflicts, or offline records';

  @override
  String get databaseStatusCollaborationPending =>
      'This device still has collaboration work to synchronize or resolve';

  @override
  String get databaseStatusBindingsLabel => 'Session replicas';

  @override
  String get databaseStatusPendingOutboxLabel => 'Pending uploads';

  @override
  String get databaseStatusOpenConflictsLabel => 'Open conflicts';

  @override
  String get databaseStatusOfflineRecordsLabel => 'Offline records';

  @override
  String get databaseStatusDraftCachesLabel => 'Live-draft caches';

  @override
  String get databaseStatusAdvancedTitle => 'Advanced: raw table counts';

  @override
  String get databaseStatusAdvancedHint =>
      'For troubleshooting only; an infrastructure table at zero is usually healthy';

  @override
  String get databaseStatusUnknown => 'unknown';

  @override
  String databaseStatusLoadFailed(String error) {
    return 'Could not read the on-device database status: $error';
  }

  @override
  String get databaseExportTitle => 'Export on-device database';

  @override
  String get databaseExportHint =>
      'Back up sessions, records, libraries, local collaboration replicas, and pending-sync state';

  @override
  String get databaseExportDialogTitle =>
      'Save OpenLogTool on-device database backup';

  @override
  String get databaseExportSucceeded => 'On-device database backup exported';

  @override
  String databaseExportFailed(String error) {
    return 'Could not export the on-device database: $error';
  }

  @override
  String get databaseImportTitle => 'Import on-device database';

  @override
  String get databaseImportHint =>
      'Select and preview a JSON backup, then replace the complete on-device database';

  @override
  String get databaseImportPickerTitle =>
      'Select an OpenLogTool on-device database backup';

  @override
  String get databaseImportNoFileSelected =>
      'No backup file was selected; nothing was imported';

  @override
  String get databaseImportPreviewTitle => 'Confirm backup import';

  @override
  String get databaseImportBackupVersion => 'Backup format version';

  @override
  String get databaseImportExportedAt => 'Exported';

  @override
  String get databaseImportUnknownTime => 'Not recorded';

  @override
  String get databaseImportSessionCount => 'Sessions';

  @override
  String get databaseImportLogCount => 'Net records';

  @override
  String get databaseImportDictionaryCount => 'Library entries';

  @override
  String get databaseImportCollaborationCount => 'Collaboration replicas';

  @override
  String get databaseImportPendingSyncCount => 'Pending sync/review items';

  @override
  String get databaseImportPreviewWarning =>
      'Import completely replaces the current on-device database, including unsynchronized changes. Server sessions, sign-in credentials in secure storage, and app settings are not affected. Built-in library content is completed for this app version. This cannot be undone.';

  @override
  String get databaseImportCollaborationWarning =>
      'This backup contains local collaboration replicas. Synchronization may resume after import when the configured server and signed-in account match.';

  @override
  String get databaseImportConfirmAction => 'Replace and import';

  @override
  String get databaseImportSucceeded =>
      'On-device database imported and the interface has been refreshed';

  @override
  String databaseImportSucceededSummary(int sessionCount, int logCount) {
    return 'On-device database imported: $sessionCount sessions and $logCount records. Historical sessions are available on the Sessions page';
  }

  @override
  String databaseImportInvalid(String error) {
    return 'The selected file is not a valid OpenLogTool database backup ($error)';
  }

  @override
  String databaseImportReadFailed(String error) {
    return 'Could not read the selected backup: $error';
  }

  @override
  String databaseImportFailed(String error) {
    return 'Could not import the on-device database: $error';
  }

  @override
  String get databaseClearTitle => 'Clear on-device data';

  @override
  String get databaseClearHint =>
      'Remove local records, collaboration replicas, and custom library entries, then restore built-in library defaults';

  @override
  String get databaseClearWarning =>
      'This cannot be undone. It removes every on-device session, net record, collaboration replica, pending-sync queue, and custom library entry. It does not delete or close server sessions, sign you out, or reset appearance. Built-in libraries are restored to their defaults.';

  @override
  String get databaseClearConfirmationPhrase => 'DELETE ALL DATA';

  @override
  String databaseClearConfirmationInstruction(String phrase) {
    return 'Enter “$phrase” to confirm:';
  }

  @override
  String get databaseClearConfirmationLabel => 'Confirmation text';

  @override
  String get databaseClearConfirmAction => 'Permanently clear on-device data';

  @override
  String get databaseClearSucceeded =>
      'On-device data cleared and built-in libraries restored to their defaults';

  @override
  String databaseClearFailed(String error) {
    return 'Could not clear on-device data: $error';
  }

  @override
  String get databaseReplacementRefreshFailed =>
      'The on-device database was changed, but the interface refresh or built-in library restore failed. Return to Sessions and try again; restart the app only if it remains inconsistent.';

  @override
  String get databaseMaintenanceCollaborationBusy =>
      'A collaboration publish, join, or other operation is in progress. Wait for it to end before managing the on-device database.';

  @override
  String get localCollaborationOperationBusy =>
      'Another collaboration operation is still in progress. Wait for it to end and try again.';

  @override
  String get localCollaborationRequired =>
      'The current session is no longer an on-device collaboration replica. Refresh the page and try again.';

  @override
  String get dataTransferTitle => 'Import and export';

  @override
  String get dataTransferSubtitle =>
      'Back up, migrate, or share the current session\'s net records, and configure the Excel output style.';

  @override
  String get dataTransferActionsTitle => 'Record files';

  @override
  String get dataTransferActionsHint =>
      'Use JSON for complete data migration and Excel for viewing, sharing, and printing.';

  @override
  String get exportDataTitle => 'Export data';

  @override
  String get exportDataHint =>
      'Export the current session\'s net records to a file';

  @override
  String get exportJson => 'Export JSON';

  @override
  String get exportExcel => 'Export Excel';

  @override
  String get importDataTitle => 'Import data';

  @override
  String get importDataHint =>
      'Import net records from a file into the current session';

  @override
  String get importJson => 'Import JSON';

  @override
  String get importExcel => 'Import Excel';

  @override
  String get excelConfigurationOverview => 'Excel configuration';

  @override
  String get excelConfigurationOverviewHint =>
      'This is the current configuration. Alternating rows can be toggled here; open the editor for all other options.';

  @override
  String get editSettings => 'Edit settings';

  @override
  String get fileNameTemplate => 'Filename template';

  @override
  String get excelHeader => 'Excel header';

  @override
  String get exportPath => 'Export location';

  @override
  String get systemDownloadsDirectory => 'System Downloads folder';

  @override
  String get headerBackground => 'Header background';

  @override
  String get tableHeaderBackground => 'Column header background';

  @override
  String get controllerRow => 'Controller row';

  @override
  String get alternatingRows => 'Alternating rows';

  @override
  String get fileFormatInformation => 'File formats';

  @override
  String get jsonFormatDescription =>
      'JSON: A standard JSON array containing every field, suitable for backup and migration between apps.';

  @override
  String get excelFormatDescription =>
      'Excel: An .xlsx workbook with grouped controller rows, color styling, and footer information, suitable for sharing and printing.';

  @override
  String get excelExportSettingsTitle => 'Edit Excel export settings';

  @override
  String get fileTab => 'File';

  @override
  String get tableStyleTab => 'Table style';

  @override
  String get templateVariablesTab => 'Template variables';

  @override
  String get exportSettingsSaved => 'Export settings saved';

  @override
  String get select => 'Choose';

  @override
  String get exportPathDefaultHint =>
      'Leave blank to use the system Downloads folder';

  @override
  String fileNameTemplateExample(String MM, String dd, String yyyy) {
    return 'Example: Net_Log_$yyyy-$MM-$dd';
  }

  @override
  String get fileNameTemplateHint =>
      'Use template variables to generate filenames automatically';

  @override
  String get headerTemplate => 'Header template';

  @override
  String headerTemplateExample(String MM, String dd, String yyyy) {
    return 'Example: Net log for $yyyy-$MM-$dd';
  }

  @override
  String get headerTemplateHint =>
      'Used when the session name option is off or the session name is blank; template variables are supported';

  @override
  String get headerBackgroundColor => 'Header background color';

  @override
  String get tableHeaderBackgroundColor => 'Column header background color';

  @override
  String get controllerRowBackgroundColor => 'Controller row background color';

  @override
  String get tableBackgroundColor => 'Table background color';

  @override
  String get alternatingRowColor => 'Alternating row color';

  @override
  String get alternatingRowColorHint => 'Use alternating row background colors';

  @override
  String get footerInformation => 'Footer information';

  @override
  String get footerInformationHint =>
      'Show OpenLogTool project and license information';

  @override
  String get restoreDefaultColors => 'Restore default colors';

  @override
  String get tableFont => 'Table font';

  @override
  String get templateVariablesTitle => 'Template variable reference';

  @override
  String get templateYearDescription => 'Four-digit year, for example 2024';

  @override
  String get templateMonthDescription =>
      'Two-digit month, for example 01 or 12';

  @override
  String get templateDayDescription => 'Two-digit day, for example 01 or 31';

  @override
  String get templateHourDescription =>
      'Two-digit hour (24-hour clock), for example 14';

  @override
  String get templateMinuteDescription => 'Two-digit minute, for example 30';

  @override
  String get templateSecondDescription => 'Two-digit second, for example 45';

  @override
  String get templateSessionDescription =>
      'Current session name, for example 2024 Summer Net';

  @override
  String get templateExamplesTitle => 'Examples';

  @override
  String templateFileNameExampleOne(String MM, String dd, String yyyy) {
    return 'Filename: Net_Log_$yyyy-$MM-$dd';
  }

  @override
  String get templateFileNameExampleOneResult => 'Net_Log_2024-03-28.xlsx';

  @override
  String templateFileNameExampleTwo(
      String HH, String MM, String dd, String mm, String ss, String yyyy) {
    return 'Filename: Contact_$yyyy-$MM-${dd}_$HH$mm$ss';
  }

  @override
  String get templateFileNameExampleTwoResult =>
      'Contact_2024-03-28_143045.xlsx';

  @override
  String templateHeaderExample(String MM, String dd, String yyyy) {
    return 'Header: Net log for $yyyy-$MM-$dd';
  }

  @override
  String get templateHeaderExampleResult => 'Net log for 2024-03-28';

  @override
  String get templateVariablesTip =>
      'Tip: Template variables add the current date and time to filenames and headers automatically, making files easier to organize.';

  @override
  String chooseColor(String label) {
    return 'Choose $label';
  }

  @override
  String colorHexValue(String value) {
    return 'HEX: #$value';
  }

  @override
  String get colorOpacity => 'Opacity';

  @override
  String get noDataToExport => 'There is no data to export';

  @override
  String saveExportFileDialog(String format) {
    return 'Save $format export file';
  }

  @override
  String get downloadsDirectoryUnavailable =>
      'The Downloads folder is unavailable';

  @override
  String exportSavedViaSystemPicker(String format) {
    return '$format export completed and was saved with the system file picker';
  }

  @override
  String exportSucceeded(String format) {
    return '$format export completed';
  }

  @override
  String fileSavedTo(String path) {
    return 'File saved to:\n$path';
  }

  @override
  String exportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get excelGenerationFailed =>
      'Export failed: Could not generate the Excel file';

  @override
  String importSucceeded(int count) {
    return 'Imported $count records';
  }

  @override
  String importFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get excelImportComingSoon => 'Excel import is not available yet';

  @override
  String get excelImportLlmProcessing => 'Parsing Excel with AI…';

  @override
  String get excelImportPreviewTitle => 'Import preview';

  @override
  String excelImportPreviewCount(int count) {
    return '$count records recognized';
  }

  @override
  String get excelImportConfirm => 'Import';

  @override
  String excelImportSuccess(int count) {
    return 'Imported $count records';
  }

  @override
  String excelImportFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get pathCopied => 'Path copied';

  @override
  String get createSession => 'New session';

  @override
  String get createSessionTitle => 'Create a net session';

  @override
  String get createSessionNameHint => 'Enter a session name';

  @override
  String sessionCreated(String title) {
    return 'Created session \"$title\"';
  }

  @override
  String createSessionFailed(String error) {
    return 'Could not create session: $error';
  }

  @override
  String get searchSessions => 'Search sessions';

  @override
  String get allSessionStatuses => 'All statuses';

  @override
  String get sessionArchived => 'Archived';

  @override
  String sessionPage(int page, int total) {
    return 'Page $page of $total';
  }

  @override
  String get moreSessionActions => 'More session actions';

  @override
  String get openAndManageCollaboration => 'Open and manage collaboration';

  @override
  String get exportLibraryJson => 'Export library JSON';

  @override
  String get libraryExportDialogTitle => 'Export lookup libraries';

  @override
  String get libraryExportSucceeded => 'Lookup libraries exported';

  @override
  String libraryExportFailed(String error) {
    return 'Could not export lookup libraries: $error';
  }

  @override
  String get editLibraryItem => 'Edit';

  @override
  String editLibraryItemTitle(String name) {
    return 'Edit \"$name\"';
  }

  @override
  String get editLibraryItemLabel => 'Library entry';

  @override
  String libraryItemRenamed(String value) {
    return 'Updated to \"$value\"';
  }

  @override
  String libraryItemRenameFailed(String error) {
    return 'Could not update entry: $error';
  }

  @override
  String libraryPageStatus(int current, int total) {
    return 'Page $current of $total';
  }

  @override
  String get previousPage => 'Previous page';

  @override
  String get nextPage => 'Next page';

  @override
  String get settingsCategoryAppearance => 'Appearance';

  @override
  String get settingsCategoryWorkbench => 'Workbench';

  @override
  String get settingsCategoryController => 'Controller display';

  @override
  String get settingsCategoryServerAccount => 'Server & account';

  @override
  String get settingsCategoryApplication => 'Application';

  @override
  String get collaborationOverviewTab => 'Overview';

  @override
  String get collaborationSyncConflictsTab => 'Sync & conflicts';

  @override
  String get collaborationAccessManagementTab => 'Access management';

  @override
  String get dataRecordsExportTab => 'Records & export';

  @override
  String get dataLookupLibrariesTab => 'Lookup libraries';

  @override
  String get dataLocalDatabaseTab => 'Local database';

  @override
  String get dataSyncConflictsTab => 'Sync conflicts';

  @override
  String get settingsCategoryAi => 'AI assistance';

  @override
  String get aiSettingsTitle => 'AI-assisted recognition';

  @override
  String get aiSettingsDescription =>
      'Configure optional speech recognition and field extraction services. Endpoints, models, and authentication stay device-specific.';

  @override
  String get aiSettingsOptionalTitle => 'Optional and off by default';

  @override
  String get aiSettingsOptionalMessage =>
      'Audio is sent directly to the service you configure, not through the OpenLogTool collaboration server. Results are suggestions and never overwrite a scribe\'s active edits automatically.';

  @override
  String get aiRecognitionEnabled => 'Enable AI-assisted recognition';

  @override
  String get aiRecognitionEnabledHint =>
      'Makes the selected speech recognition profile available from the Net Desk.';

  @override
  String get aiLocalReferenceContext =>
      'Use local dictionaries and recent records';

  @override
  String get aiLocalReferenceContextHint =>
      'On by default. Sends only a few terms similar to the current transcript and recent fields for a matched callsign to the text model. The complete database is never uploaded.';

  @override
  String get aiRecognitionNeedsAsr =>
      'Add and select a speech recognition profile first.';

  @override
  String get aiAsrStageTitle => 'Speech recognition (ASR)';

  @override
  String get aiAsrStageDescription =>
      'Turns audio into raw text. All three endpoint formats can be saved and switched at any time.';

  @override
  String get aiExtractionStageTitle => 'Field extraction (optional)';

  @override
  String get aiExtractionStageDescription =>
      'Turns a transcript into suggested callsign, RST, QTH, and other fields. Without it, the raw transcript remains available.';

  @override
  String get aiSupportedProtocols => 'Supported endpoint formats';

  @override
  String get aiActiveProfile => 'Active profile';

  @override
  String get aiNoProfileConfigured => 'No profiles have been added';

  @override
  String get aiNoActiveProfile => 'Do not use';

  @override
  String get aiCredentialStatus => 'Credential status';

  @override
  String get aiCredentialNoProfile =>
      'Select a profile to see its on-device credential status.';

  @override
  String get aiCredentialStoredLocally =>
      'API keys are stored separately in secure system storage and are excluded from profile exports.';

  @override
  String get aiStatusNotConfigured => 'Not configured';

  @override
  String get aiStatusNoCredentialNeeded => 'No key required';

  @override
  String get aiStatusCredentialReady => 'Key stored';

  @override
  String get aiStatusCredentialMissing => 'Key missing';

  @override
  String get aiAddProfile => 'Add profile';

  @override
  String get aiEditProfile => 'Edit profile';

  @override
  String get aiDeleteProfileTitle => 'Delete AI profile';

  @override
  String aiDeleteProfileMessage(String name) {
    return 'Delete “$name” and its on-device credential?';
  }

  @override
  String get aiProfileName => 'Profile name';

  @override
  String get aiBaseUrl => 'API base URL';

  @override
  String get aiModelName => 'Model name';

  @override
  String get aiProtocol => 'Endpoint format';

  @override
  String get aiAuthentication => 'Authentication';

  @override
  String get aiCredentialName => 'Header or query parameter name';

  @override
  String get aiCredentialPrefix => 'Credential prefix (optional)';

  @override
  String get aiApiKey => 'API key';

  @override
  String get aiApiKeyNewHint =>
      'You may leave this empty and add the key later.';

  @override
  String get aiApiKeyExistingHint =>
      'Leave empty to keep the current key. A changed destination requires a new key.';

  @override
  String get aiRequestOptions => 'Advanced request options (JSON)';

  @override
  String get aiRequestOptionsHint =>
      'Generic JSON requires requestTemplate. Protocol options include path, responsePath, body, fields, audioDataEncoding, and includePrompt. This metadata is exported with the profile; never place a key here.';

  @override
  String get aiRequiredField => 'This field is required';

  @override
  String get aiRequestOptionsMustBeObject =>
      'Advanced request options must be a JSON object';

  @override
  String get aiJsonProtocolNeedsTemplate =>
      'Generic JSON requires requestTemplate';

  @override
  String get aiInvalidJson => 'Invalid JSON';

  @override
  String get aiInvalidBaseUrl => 'Enter a valid HTTP(S) API address';

  @override
  String aiSettingsFailed(String error) {
    return 'AI settings operation failed: $error';
  }

  @override
  String get aiProtocolAudioTranscriptions => 'Audio transcription multipart';

  @override
  String get aiProtocolChatAudio => 'Chat input_audio';

  @override
  String get aiProtocolChatText => 'Chat text extraction';

  @override
  String get aiProtocolGenericJson => 'Generic JSON HTTP';

  @override
  String get aiAuthNone => 'No authentication';

  @override
  String get aiAuthBearer => 'Authorization Bearer';

  @override
  String get aiAuthHeader => 'Custom header';

  @override
  String get aiAuthQuery => 'Query parameter';

  @override
  String get aiWorkbenchTitle => 'AI-assisted recognition';

  @override
  String get aiWorkbenchUnavailable =>
      'Recognition is unavailable while this record is read-only or busy.';

  @override
  String get aiReadyStatus => 'Tap the microphone to capture one check-in.';

  @override
  String aiRecordingStatus(String elapsed) {
    return 'Recording $elapsed';
  }

  @override
  String get aiLiveTranscriptTitle => 'Live recognized fields';

  @override
  String get aiLiveStructuredWaiting =>
      'Building enough context for a complete check-in. Recognized fields will appear here.';

  @override
  String get aiLiveStructuredUpdating =>
      'Organizing fields from everything recognized so far…';

  @override
  String aiLiveTranscriptionRetrying(String error) {
    return 'Live recognition temporarily failed. The complete content will still be retried after recording stops: $error';
  }

  @override
  String get aiRecognizingStatus => 'Recognizing and preparing suggestions…';

  @override
  String get aiStartRecording => 'Record';

  @override
  String get aiStopAndRecognize => 'Recognize';

  @override
  String get aiMicrophonePermissionDenied =>
      'Microphone permission was not granted.';

  @override
  String aiRecordingFailed(String error) {
    return 'Recording failed: $error';
  }

  @override
  String aiRecognitionFailed(String error) {
    return 'Recognition failed: $error';
  }

  @override
  String get aiReviewTitle => 'Review AI suggestions';

  @override
  String get aiTranscriptTitle => 'Transcript';

  @override
  String get aiCopyTranscript => 'Copy transcript';

  @override
  String get aiTranscriptCopied => 'Transcript copied.';

  @override
  String get aiNoStructuredCandidates =>
      'No structured fields were returned. The transcript is still available above.';

  @override
  String get aiCandidateRecord => 'Suggested record';

  @override
  String aiCandidateNumber(int number) {
    return 'Candidate $number';
  }

  @override
  String get aiCandidateHint =>
      'Empty fields are selected automatically. Replacing existing text always requires your explicit selection.';

  @override
  String get aiApplySelected => 'Apply selected';

  @override
  String aiCandidatesApplied(int count) {
    return 'Applied $count suggested field(s).';
  }

  @override
  String get aiCandidatesStale =>
      'These suggestions are no longer safe to apply because the record changed.';

  @override
  String aiApplyFailed(String error) {
    return 'Could not apply AI suggestions: $error';
  }

  @override
  String aiWillReplaceValue(String value) {
    return 'Will replace: $value';
  }

  @override
  String get aiWillFillEmpty => 'Will fill an empty field';

  @override
  String get aiReplacementNeedsConfirmation => 'Select to confirm replacement';

  @override
  String get aiCandidateUnchanged => 'Already matches';

  @override
  String get aiCandidateStale => 'The field changed after recording began';

  @override
  String get aiCandidateBeingEdited => 'The field is currently being edited';

  @override
  String get aiCandidateLocked => 'Another collaborator is editing this field';

  @override
  String get aiCandidateReadOnly => 'This record is read-only';

  @override
  String get aiCandidateBusy => 'The record is busy';

  @override
  String get aiCandidateInvalid => 'Unsupported or invalid suggestion';

  @override
  String get textAssistantTitle => 'Text assistant';

  @override
  String get textAssistantDescription =>
      'Use a simple text-model setup for structured fields, inline suggestions, and dictionary maintenance.';

  @override
  String get textAssistantPrivacyTitle =>
      'Processed by your selected model service';

  @override
  String get textAssistantPrivacyMessage =>
      'When needed, current field text or aggregated historical terms are sent to the selected service. Complete records, remarks, and times are not sent. The API key is used only for request authentication and stored securely on this device.';

  @override
  String get textAssistantEnabled => 'Enable text assistant';

  @override
  String get textAssistantNotConfigured => 'Text assistant is not configured';

  @override
  String get textAssistantInlineSuggestions =>
      'Show AI formatting suggestions while typing';

  @override
  String get textAssistantInlineSuggestionsHint =>
      'Shows one fast suggestion for device, antenna, QTH, height, and power after typing pauses for about 300 ms.';

  @override
  String get textAssistantTest => 'Test connection';

  @override
  String get textAssistantConfigure => 'Configure text assistant';

  @override
  String get textAssistantEdit => 'Edit configuration';

  @override
  String get textAssistantConfigureTitle => 'Configure text assistant';

  @override
  String get textAssistantProvider => 'Provider type';

  @override
  String get textAssistantProviderOpenAi => 'OpenAI (Responses API)';

  @override
  String get textAssistantProviderAnthropic => 'Anthropic';

  @override
  String get textAssistantProviderCompatible =>
      'OpenAI-compatible (legacy Chat Completions)';

  @override
  String get textAssistantTestSucceeded =>
      'The text assistant connection works.';

  @override
  String get textAssistantSuggestionLabel => 'AI formatting suggestion';

  @override
  String get aiDictionaryRecognize => 'Recognize from history';

  @override
  String get aiDictionaryOptimize => 'Optimize dictionaries with AI';

  @override
  String get aiDictionaryNeedsAssistant =>
      'Configure and enable the text assistant in Settings first.';

  @override
  String get aiDictionaryNoSuggestions =>
      'No dictionary changes were suggested.';

  @override
  String aiDictionaryApplied(int count) {
    return 'Applied $count dictionary suggestion(s).';
  }

  @override
  String aiDictionaryFailed(String error) {
    return 'Dictionary AI operation failed: $error';
  }

  @override
  String get aiDictionaryOptimizing => 'Optimizing dictionaries';

  @override
  String get aiDictionaryRecognizing => 'Recognizing historical terms';

  @override
  String get aiDictionaryPreparing => 'Preparing local data…';

  @override
  String aiDictionaryProgress(int completed, int total) {
    return 'Completed $completed / $total';
  }

  @override
  String get aiDictionaryReviewTitle => 'Review dictionary suggestions';

  @override
  String aiDictionaryReviewHint(int recordCount) {
    return 'Generated from $recordCount historical record(s) and the current dictionaries. Only selected changes will be written.';
  }

  @override
  String get aiDictionaryActionAdd => 'Add';

  @override
  String get aiDictionaryActionRename => 'Rename';

  @override
  String get aiDictionaryActionMerge => 'Merge';

  @override
  String aiDictionaryUsedCount(int count) {
    return 'Used $count time(s) in history';
  }

  @override
  String get aiDictionaryMergeWarning =>
      'Merging hides the source term and is not selected by default. Historical records are unchanged.';

  @override
  String get aiDictionaryApplySelected => 'Apply selected suggestions';

  @override
  String get fieldFormatSuggestionLabel => 'Format option';

  @override
  String get logTableHorizontalScrollHint =>
      'Shift + wheel to scroll horizontally';
}

/// The translations for English, as used in the United States (`en_US`).
class AppLocalizationsEnUs extends AppLocalizationsEn {
  AppLocalizationsEnUs() : super('en_US');

  @override
  String get collaborationTechnicalDetails => 'Connection & diagnostics';

  @override
  String get collaborationOverviewOnline =>
      'Connected. Record updates are being shared with participants.';

  @override
  String get collaborationOverviewOffline =>
      'The connection is unavailable. Existing records are still on this device.';

  @override
  String get collaborationOverviewAttention =>
      'Some records or sync issues need attention. Open Sync to review them.';

  @override
  String collaborationOverviewPending(int count) {
    return 'Saved on this device. $count changes are waiting to sync.';
  }

  @override
  String get historySessionCollaborationCloseRequired =>
      'This is a collaborative session. Use Collaboration & members to end shared recording or leave; it cannot be ended as a local session.';

  @override
  String get collaborationLifecycleHint =>
      'Switching pages or temporarily going offline does not leave the collaboration. The owner can end shared recording; participants can leave. Existing records are kept.';

  @override
  String get hubLocalStart =>
      'Create a session to start recording. No server or account is required; records are saved on this device and can be viewed or exported.';

  @override
  String get hubLocalHint =>
      'Local recording works on its own. Sync and collaboration are optional.';

  @override
  String get hubOptionalOnline => 'Sync and collaboration (optional)';

  @override
  String get hubOptionalOnlineHint =>
      'Connect a server when you want multi-device sync or to record with others.';

  @override
  String get hubConfigureServer => 'Set up an optional server';

  @override
  String get hubOnlineConnected =>
      'Friends and collaboration use your connected server. Local recording remains independent.';

  @override
  String get hubEnableCollaboration => 'Record with a friend';

  @override
  String get hubConfirmUpload => 'Upload this session and enable collaboration';

  @override
  String get hubUploadExplanation =>
      'This uploads the current session and its existing records to the server below and starts collaboration sync. Other local sessions are not uploaded by this action. The session stays private; choose friends to invite afterwards. No public page is created.';

  @override
  String get hubContextChanged =>
      'The server, account or current session changed. Close this dialog and try again.';

  @override
  String get hubAlreadyMember =>
      'This person has already joined. You can find them in participant management.';

  @override
  String get hubInvitationHint =>
      'They can view this session\'s records after accepting. Your other sessions are not shared.';

  @override
  String get hubContinueRecording => 'Continue recording';

  @override
  String get hubViewRecords => 'View records';

  @override
  String get hubSessionDetails => 'Session details';

  @override
  String get hubHistoryHint =>
      'Browse existing records on this device. Ended sessions are a status filter, not public archives.';

  @override
  String get hubAllRecords => 'All';

  @override
  String get hubMyRecords => 'My records';

  @override
  String get hubTogetherRecords => 'Shared records';

  @override
  String get hubEndedRecords => 'Ended';

  @override
  String get socialTitle => 'Friends & invitations';

  @override
  String get socialAddFriend => 'Add friend';

  @override
  String get socialFriends => 'Friends';

  @override
  String get socialMessages => 'Messages';

  @override
  String get socialSessions => 'Sessions';

  @override
  String get socialIntro =>
      'Add your partners as friends, then invite them to a session. Personal records remain private.';

  @override
  String get socialUsername => 'Username (callsign used at registration)';

  @override
  String get socialSend => 'Send request';

  @override
  String get socialInvite => 'Invite';

  @override
  String get socialApply => 'Request to join';

  @override
  String get socialAccept => 'Accept';

  @override
  String get socialReject => 'Decline';

  @override
  String get socialPending => 'Awaiting response';

  @override
  String get socialAccepted => 'Accepted';

  @override
  String get socialView => 'View only';

  @override
  String get socialEdit => 'Record together';

  @override
  String get socialOpen => 'Open session';

  @override
  String get socialPrivate => 'Invite only';

  @override
  String get socialDiscoverable => 'Friends can discover and request to join';

  @override
  String get socialVisibilityHint =>
      'Friends see the session title. Records are available only after approval.';

  @override
  String get socialNoFriends =>
      'No friends yet. Send a request using your partner\'s username.';

  @override
  String get socialNoMessages => 'No invitations or requests';

  @override
  String get socialNoSessions =>
      'No sessions available. You can also enable collaboration for your current session.';

  @override
  String get socialPublish => 'Enable collaboration for current session';

  @override
  String get socialRemove => 'Remove friend';

  @override
  String get socialRemoveHint =>
      'Pending requests between you will be cancelled. Existing session memberships are managed separately by the session owner.';

  @override
  String get socialBlock => 'Block';

  @override
  String get socialUnblock => 'Unblock';

  @override
  String get socialBlocked => 'Blocked';

  @override
  String get socialDone => 'Done';

  @override
  String get socialFriendRequest => 'Friend request';

  @override
  String get socialInvitation => 'Session invitation';

  @override
  String get socialApplication => 'Join request';

  @override
  String get socialSent => 'Sent by me';

  @override
  String get socialReceived => 'Received';

  @override
  String get socialManage => 'Manage participants';

  @override
  String get socialConnect => 'Connect to a server and sign in to add friends.';

  @override
  String get socialUpgrade => 'Update this server to enable friends.';

  @override
  String get socialLoadFailed => 'Could not refresh. Please retry.';

  @override
  String get socialChooseFriend => 'Choose a friend';

  @override
  String get socialErrorUser =>
      'Username not found. Check that your partner registered on the same server.';

  @override
  String get socialErrorFriends => 'Please add each other as friends first.';

  @override
  String get socialErrorClosed =>
      'This request is closed or expired. Please refresh.';

  @override
  String get socialErrorSelf => 'You cannot add yourself.';

  @override
  String get socialErrorBlocked => 'Requests to this user are unavailable.';

  @override
  String get socialServerLink => 'Copy server connection';

  @override
  String get socialServerLinkHint =>
      'Paste a server address or a server portal link, then sign in.';

  @override
  String get socialLegacy => 'Legacy sharing';

  @override
  String get navWorkbench => 'Net Desk';

  @override
  String get navSessions => 'Sessions';

  @override
  String get navData => 'Data';

  @override
  String get navSettings => 'Settings';

  @override
  String get workbenchNoSession => 'No net in progress';

  @override
  String get workbenchLocalRecording => 'Local recording';

  @override
  String get collaborationLocalOnly => 'Local only';

  @override
  String get collaborationPublishing => 'Publishing';

  @override
  String get collaborationJoining => 'Joining';

  @override
  String get collaborationSnapshotting => 'Loading snapshot';

  @override
  String get collaborationCatchingUp => 'Catching up';

  @override
  String get collaborationReady => 'Connected';

  @override
  String get collaborationResyncing => 'Resyncing';

  @override
  String get collaborationRevoked => 'Access revoked';

  @override
  String get collaborationFailed => 'Sync failed';

  @override
  String collaborationState(String state) {
    return 'Collaboration: $state';
  }

  @override
  String pendingSyncCount(int count) {
    return 'Pending $count';
  }

  @override
  String conflictCount(int count) {
    return 'Conflicts $count';
  }

  @override
  String get localSessionTooltip => 'This is a local session';

  @override
  String collaborationStatusTooltip(String state, int count) {
    return 'Collaboration $state, $count pending';
  }

  @override
  String get currentRecord => 'Current record';

  @override
  String get startNewRecord => 'Start new record';

  @override
  String get newRecordName => 'New record name';

  @override
  String get newRecordNameHint => 'Enter a name for this record (optional)';

  @override
  String get automaticName => 'automatic name';

  @override
  String newRecordStarted(String name) {
    return 'Started new record: $name';
  }

  @override
  String createNewRecordFailed(String error) {
    return 'Could not create a new record: $error';
  }

  @override
  String currentOrdinal(int ordinal) {
    return 'Current #$ordinal';
  }

  @override
  String get sessionsTitle => 'Sessions';

  @override
  String get sessionsSubtitle =>
      'Manage this net, collaborating scribes, and controller displays.';

  @override
  String get noCurrentSession => 'No current net session';

  @override
  String get noCurrentSessionHint =>
      'Create a net session, or join a collaboration, to start logging.';

  @override
  String get workbenchNoSessionHint =>
      'Create a session on the Sessions page, or join a collaboration, before logging.';

  @override
  String get createOrJoinSessionFirst =>
      'Create a session or join a collaboration first';

  @override
  String get goCreateSession => 'Create a session';

  @override
  String get sessionActive => 'Active';

  @override
  String get sessionClosed => 'Ended';

  @override
  String savedPositions(int count) {
    return '$count saved';
  }

  @override
  String get localSession => 'Local session';

  @override
  String get manageCollaboration => 'Collaboration & members';

  @override
  String get openLiveShare => 'Live Share';

  @override
  String get enterControllerScreen => 'Enter controller display';

  @override
  String get localControllerDisplay => 'Local controller display';

  @override
  String get localControllerDisplayHint =>
      'Keep logging in the main window while a separate read-only window serves the controller.';

  @override
  String get openFloatingWindow => 'Open floating window';

  @override
  String get openSecondDisplayWindow => 'Open second-display window';

  @override
  String get historySessions => 'Session history';

  @override
  String get historySessionsHint =>
      'View and switch to past net sessions. Closed sessions open read-only.';

  @override
  String get historySessionsEmpty => 'There are no past sessions';

  @override
  String historySessionsLoadFailed(String error) {
    return 'Could not load session history: $error';
  }

  @override
  String get historySessionOpen => 'Open session';

  @override
  String get historySessionCurrent => 'Current session';

  @override
  String historySessionSwitched(String title) {
    return 'Opened session: $title';
  }

  @override
  String historySessionOpenFailed(String error) {
    return 'Could not open session: $error';
  }

  @override
  String get historySessionCloseTitle => 'End recording';

  @override
  String historySessionCloseConfirmation(String title) {
    return 'End recording in “$title”? Existing records will be kept. You can view them or resume recording later. No data will be deleted.';
  }

  @override
  String get historySessionClosed =>
      'Recording ended. Existing records were kept.';

  @override
  String historySessionCloseFailed(String error) {
    return 'Failed to end recording: $error';
  }

  @override
  String get historySessionReopenAction => 'Reactivate';

  @override
  String get historySessionReopenTitle => 'Reactivate local session';

  @override
  String historySessionReopenConfirmation(String title) {
    return 'Resume recording in “$title” and switch to it? Other sessions stay unchanged. Collaborative sessions must be resumed by their owner in Collaboration & members.';
  }

  @override
  String historySessionReopened(String title) {
    return 'Reactivated and switched to session: $title';
  }

  @override
  String historySessionReopenFailed(String error) {
    return 'Could not reactivate local session: $error';
  }

  @override
  String historySessionReopenedLogsUnavailable(String title) {
    return 'Session “$title” was reactivated, but its logs could not be loaded. It is temporarily read-only; retry loading.';
  }

  @override
  String get historySessionCollaborationReopenRequired =>
      'This is a collaboration session. Open it first, then reopen it from Collaboration & members.';

  @override
  String get historySessionDeleteTitle => 'Permanently delete local session';

  @override
  String historySessionDeleteWarning(String title) {
    return 'This permanently deletes all local logs and the local collaboration replica for “$title”. This cannot be undone, but it will not delete or close the shared session on the server. Enter the full session name to confirm:';
  }

  @override
  String get historySessionDeleteNameLabel => 'Full session name';

  @override
  String get historySessionDeleteAction => 'Delete local data permanently';

  @override
  String get historySessionDeleted => 'Local session permanently deleted';

  @override
  String historySessionDeleteFailed(String error) {
    return 'Could not permanently delete local session: $error';
  }

  @override
  String get historySessionReadOnly =>
      'This is a closed historical session. Existing records are read-only.';

  @override
  String controllerWindowOpenFailed(String error) {
    return 'Could not open controller window: $error';
  }

  @override
  String get controllerDisplaySettingsTitle => 'Controller display';

  @override
  String get enableControllerDeviceEntry => 'Enable controller-device entry';

  @override
  String get enableControllerDeviceEntryHint =>
      'When enabled, Sessions can open a full-screen read-only display on an Android tablet, phone, or separate computer.';

  @override
  String get defaultInformationDetail => 'Default information detail';

  @override
  String get desktopControllerDisplayHint =>
      'This desktop can also open an always-on-top window or a second-display window from Sessions.';

  @override
  String get inAppControllerDisplayHint =>
      'This device uses the in-app full-screen controller display.';

  @override
  String get controllerScreenTitle => 'OpenLogTool Controller Display';

  @override
  String get controllerFloatingWindowTitle =>
      'OpenLogTool Controller Floating Window';

  @override
  String get controllerScreenFallbackTitle => 'Net Controller Display';

  @override
  String savedPositionCount(int count) {
    return '$count saved';
  }

  @override
  String get notReceivedDraftUpdate => 'No draft update received';

  @override
  String updatedAt(String time) {
    return 'Updated $time';
  }

  @override
  String editorEditing(String name) {
    return 'Editing by $name';
  }

  @override
  String get connectionConnected => 'Live';

  @override
  String get connectionReconnecting => 'Reconnecting';

  @override
  String get connectionOffline => 'Offline';

  @override
  String get staleControllerDataWarning =>
      'Connection lost. The last received content is shown and may be out of date.';

  @override
  String get previousSavedRecord => 'Previous saved record';

  @override
  String get noPreviousRecord => 'No previous record';

  @override
  String get waitingForCallsign => 'Waiting for a callsign…';

  @override
  String get beingEdited => 'Editing';

  @override
  String configureControllerDisplay(String detail) {
    return 'Display content ($detail)';
  }

  @override
  String get exitControllerScreen => 'Exit controller display';

  @override
  String get controllerDisplayConfiguration => 'Controller display content';

  @override
  String get informationDetail => 'Information detail';

  @override
  String get currentFields => 'Current fields';

  @override
  String get previousFields => 'Previous fields';

  @override
  String get cancel => 'Cancel';

  @override
  String get apply => 'Apply';

  @override
  String get detailMinimal => 'Minimal';

  @override
  String get detailStandard => 'Standard';

  @override
  String get detailFull => 'Full';

  @override
  String get detailCustom => 'Custom';

  @override
  String get fieldController => 'Controller';

  @override
  String get fieldCallsign => 'Callsign';

  @override
  String get fieldTime => 'Time';

  @override
  String get logTimeInvalid => 'Enter a valid time (HH:mm)';

  @override
  String get fieldRstSent => 'RST sent';

  @override
  String get fieldRstRcvd => 'RST received';

  @override
  String get fieldQth => 'QTH';

  @override
  String get fieldDevice => 'Radio';

  @override
  String get fieldPower => 'Power';

  @override
  String get fieldAntenna => 'Antenna';

  @override
  String get fieldHeight => 'Height';

  @override
  String get fieldRemarks => 'Remarks';

  @override
  String get saveRecord => 'Save record';

  @override
  String get recordAdded => 'Record saved';

  @override
  String get recordQueuedOffline => 'Saved offline; review after reconnecting';

  @override
  String get sharedDraftReadOnly => 'This shared draft is read-only';

  @override
  String fieldLockedBy(String name) {
    return 'Editing by $name';
  }

  @override
  String get offlineReviewTitle => 'Offline records need review';

  @override
  String get resolutionDiscard => 'Discard';

  @override
  String get resolutionSubmitDuplicate => 'Submit as duplicate';

  @override
  String get resolutionCopyCurrent => 'Copy to current draft';

  @override
  String get callsignRequired => 'Enter a callsign';

  @override
  String get leaveSession => 'Leave collaboration';

  @override
  String get leaveSessionConfirmation =>
      'You will stop receiving updates for this session. Records already on this device will remain read-only, and other members can continue. To join again, you will need a new invitation or approved application. A server connection is required. You do not need to leave just to close this page.';

  @override
  String get moreLocalCollaborationActions => 'More actions';

  @override
  String get createEditableLocalCopy => 'Save independent copy';

  @override
  String get createEditableLocalCopyTitle => 'Save an independent session?';

  @override
  String createEditableLocalCopyConfirmation(String title) {
    return 'Copy the saved table records from “$title” into a new session and switch to it for independent recording, without a server. Your original collaborative session and membership stay unchanged; you can switch back later. Pending sync operations, conflicts, offline records awaiting review and unsubmitted drafts stay in the original session. They are neither copied nor deleted.';
  }

  @override
  String get editableLocalCopySucceeded =>
      'Switched to the independent copy. The original collaboration was kept.';

  @override
  String get accountSharing => 'Account sharing';

  @override
  String get accountSharingHint =>
      'Request then accept. Shared sessions are read-only until you join with the passphrase.';

  @override
  String get sharedSessionBadge => 'Shared';

  @override
  String sharedSessionFrom(String username) {
    return 'Shared from $username';
  }

  @override
  String get acceptShare => 'Accept';

  @override
  String get pendingInboundShares => 'Pending requests';

  @override
  String get browseSharedSession => 'Browse shared session';

  @override
  String get joinSharedSession => 'Join with passphrase';

  @override
  String get readOnlyClosePending =>
      'The end request is awaiting sync confirmation. Records are temporarily read-only.';

  @override
  String get readOnlySessionClosed =>
      'Shared recording has ended. Existing records remain available to view.';

  @override
  String get readOnlyResyncing =>
      'Restoring synchronization. Saved changes will be kept.';

  @override
  String get readOnlyCheckingAccess =>
      'Checking your participation permissions. Viewing only for now.';

  @override
  String get closeCollaborationSessionTitle => 'End shared recording';

  @override
  String get closeCollaborationSessionMessage =>
      'All members will stop adding or editing records. Existing records and membership will be kept, and you can resume recording later. This change must sync to the server. You do not need to end recording just to leave this page.';

  @override
  String get closeSharedSession => 'End shared recording';

  @override
  String get closeCollaborationDraftNotEmpty =>
      'The current check-in draft has content. Submit the complete record or explicitly discard the draft before ending recording.';

  @override
  String get closeCollaborationDraftIncomplete =>
      'The draft is missing the time, controller callsign or check-in callsign. It cannot be submitted, but can be explicitly discarded before ending recording.';

  @override
  String closeCollaborationDraftLocked(int count) {
    return 'Other members or devices are editing $count draft fields. Wait for them to finish and refresh before ending recording.';
  }

  @override
  String get closeCollaborationDiscardAndClose => 'Discard draft and end';

  @override
  String get closeCollaborationSubmitAndClose => 'Submit and end';

  @override
  String get closeCollaborationQueuedOffline =>
      'The record is only saved in the offline queue and has not reached the server. Shared recording has not ended. Reconnect and resolve the record before trying again.';

  @override
  String get closeSessionQueued =>
      'The request to end shared recording was saved and is awaiting sync confirmation.';

  @override
  String get confirm => 'Confirm';

  @override
  String get duplicateCallsignWarningSetting => 'Duplicate callsign warning';

  @override
  String get duplicateCallsignWarningHint =>
      'Warn before saving the same callsign again in this net, while still allowing it.';

  @override
  String get duplicateCallsignTitle => 'Callsign already recorded';

  @override
  String duplicateCallsignMessage(String callsign) {
    return '$callsign is already recorded in this net. Save it again?';
  }

  @override
  String get saveAnyway => 'Save anyway';

  @override
  String get callsignHistoryFillSetting => 'Reuse callsign history';

  @override
  String get callsignHistoryFillHint =>
      'Match existing callsign records and fill the radio, antenna, QTH, and related fields in one tap.';

  @override
  String get publicShareManagement => 'Live Share · public read-only page';

  @override
  String get publicShareManagementHint =>
      'Create a read-only web page for controllers, remote scribes, or observers. It can be viewed without signing in; the link secret is shown only when created.';

  @override
  String get publicShareAccessRequired =>
      'Live Share is managed by the collaboration session owner. Sign in and publish this session first, or ask the owner to create the public link.';

  @override
  String get publicShareUnsupported =>
      'This server does not provide the secure Live Share page. Upgrade or enable public sharing on the server to create one.';

  @override
  String get publicShareCreatedTitle => 'Public read-only page created';

  @override
  String get publicShareCreatedHint =>
      'Save this link now. For security, its secret cannot be retrieved again after a refresh or sign-in.';

  @override
  String get createPublicShare => 'Create public link';

  @override
  String get publicShareExpiryDialogTitle => 'Set Live Share expiration';

  @override
  String get publicShareExpiryDialogHint =>
      'The public link will expire automatically after the selected duration.';

  @override
  String get publicShareExpiryPresets => 'Presets';

  @override
  String get publicShareExpiryOneHour => '1 hour';

  @override
  String get publicShareExpirySixHours => '6 hours';

  @override
  String get publicShareExpiryTwelveHours => '12 hours';

  @override
  String get publicShareExpiryOneDay => '1 day';

  @override
  String get publicShareExpiryThreeDays => '3 days';

  @override
  String get publicShareExpirySevenDays => '7 days';

  @override
  String get publicShareExpiryThirtyDays => '30 days';

  @override
  String get publicShareExpiryCustom => 'Custom';

  @override
  String get publicShareExpiryCustomHours => 'Validity (hours)';

  @override
  String get publicShareExpiryRangeError =>
      'Enter a whole number from 1 to 720.';

  @override
  String publicShareEstimatedExpiry(String time) {
    return 'Estimated expiry: $time (local time)';
  }

  @override
  String get copyPublicShareLink => 'Copy link';

  @override
  String get openPublicShare => 'Open in browser';

  @override
  String get revokePublicShare => 'Revoke';

  @override
  String get publicShareLinkCopied => 'Public link copied';

  @override
  String get publicShareNoActiveLinks =>
      'There are no active public links. Create one for a controller or remote observer.';

  @override
  String get publicShareSecretUnavailable =>
      'An active public link exists, but its secret was returned only when created. If it was not saved, revoke it and create a new link.';

  @override
  String get publicShareLinksTitle => 'Public link history';

  @override
  String get publicShareUnavailable => 'Revoked or expired';

  @override
  String get publicShareOpenFailed =>
      'Could not open the browser. You can still copy the link and open it manually.';

  @override
  String publicShareExpiresAt(String time) {
    return 'Expires $time';
  }

  @override
  String get refresh => 'Refresh';

  @override
  String get reuseDatabaseInformation => 'Reuse database information';

  @override
  String get collapseSidebar => 'Collapse sidebar';

  @override
  String get expandSidebar => 'Expand sidebar';

  @override
  String get limitWorkbenchWidthSetting => 'Limit Net Desk content width';

  @override
  String get limitWorkbenchWidthHint =>
      'Center Net Desk content and limit it to 1520 pixels on wide screens to keep fields from stretching too far.';

  @override
  String serverConnectionFailed(String detail) {
    return 'Connection failed: $detail';
  }

  @override
  String serverNetworkError(String url) {
    return 'The server at $url did not respond. Check the address and port, and make sure the server or reverse proxy is running.';
  }

  @override
  String serverWebMixedContentError(String url) {
    return 'This WebClient uses HTTPS, so the browser cannot connect to the HTTP server at $url. Enable HTTPS for the server.';
  }

  @override
  String serverWebCrossOriginError(String url, String origin) {
    return 'The browser could not access $url. Confirm the server is online. If native clients can connect, add $origin to the server\'s CORS_ORIGINS or use a same-origin reverse proxy.';
  }

  @override
  String serverNetworkTimeout(String url) {
    return 'The connection to $url timed out. Check the network, firewall, and server status.';
  }

  @override
  String serverInvalidResponse(String url) {
    return 'Connected to $url, but it did not return a compatible OpenLogTool Server response.';
  }

  @override
  String get serverAddressRequired => 'Enter a server address first.';

  @override
  String get serverAddressInvalid =>
      'The server address must be a complete http(s) URL.';

  @override
  String get serverSettingsTitle => 'Server and account';

  @override
  String get serverAddressLabel => 'Server address';

  @override
  String get serverAddressHint => 'http://your-server:3000';

  @override
  String get serverSaveAndCheck => 'Save and check server';

  @override
  String serverCheckSucceeded(int min, int max) {
    return 'Connected · protocol v$min-$max';
  }

  @override
  String serverInstanceDetails(String instance, String features) {
    return 'Instance $instance\nCapabilities $features';
  }

  @override
  String get serverConnected => 'Connected';

  @override
  String get serverNotConnected => 'Not checked';

  @override
  String get serverSignedOutHint =>
      'Sign in to collaborate and manage only your own account and sign-in devices.';

  @override
  String get tokenStoragePrivateFileWarning =>
      'The system keyring is unavailable. Your sign-in is stored in a private file readable only by your Linux user and will move back to secure storage when a keyring becomes available.';

  @override
  String get tokenStorageMemoryOnlyWarning =>
      'Secure credential storage is unavailable. This sign-in lasts only while the app is running; you will need to sign in again after exiting.';

  @override
  String get serverLogin => 'Sign in';

  @override
  String get serverRegister => 'Register';

  @override
  String get serverLogout => 'Sign out';

  @override
  String serverAccountId(String id) {
    return 'Account ID: $id';
  }

  @override
  String get serverLoginSucceeded => 'Signed in to the server';

  @override
  String get serverRegistrationSucceeded => 'Registered and signed in';

  @override
  String serverLoginFailed(String error) {
    return 'Sign-in failed: $error';
  }

  @override
  String serverRegistrationFailed(String error) {
    return 'Registration failed: $error';
  }

  @override
  String serverLogoutFailed(String error) {
    return 'Sign-out failed: $error';
  }

  @override
  String get accountChangeUsername => 'Change username';

  @override
  String get accountChangePassword => 'Change password';

  @override
  String get accountDeviceSessions => 'Sign-in devices';

  @override
  String get accountUsernameUpdated => 'Username updated';

  @override
  String accountPasswordUpdated(int count) {
    return 'Password updated. $count sign-in sessions were revoked; sign in again.';
  }

  @override
  String accountUpdateFailed(String error) {
    return 'Account action failed: $error';
  }

  @override
  String get usernameLabel => 'Username';

  @override
  String get usernameLengthHint => 'Username must be 3–64 characters';

  @override
  String get passwordLabel => 'Password';

  @override
  String get fieldRequired => 'This field is required';

  @override
  String get currentPasswordLabel => 'Current password';

  @override
  String get newPasswordLabel => 'New password';

  @override
  String get confirmNewPasswordLabel => 'Confirm new password';

  @override
  String get passwordLengthHint => 'Password must be at least 10 characters';

  @override
  String get passwordMismatch => 'The new passwords do not match';

  @override
  String get passwordChangeRequiredTitle =>
      'Temporary password must be changed';

  @override
  String passwordChangeRequiredHint(String username) {
    return 'Account $username signed in with a temporary password. Set a new password to continue.';
  }

  @override
  String passwordChangeCredentialExpires(int seconds) {
    return 'This password-change credential expires in $seconds seconds.';
  }

  @override
  String get completePasswordChange => 'Set password and sign in';

  @override
  String get cancelLogin => 'Cancel sign-in';

  @override
  String get passwordChangeCompleted =>
      'Password updated and sign-in completed';

  @override
  String get deviceSessionsTitle => 'Sign-in devices';

  @override
  String get deviceSessionsEmpty => 'There are no active sign-in devices';

  @override
  String get deviceUnknown => 'Unnamed device';

  @override
  String get deviceCurrent => 'Current device';

  @override
  String deviceIp(String ip) {
    return 'IP: $ip';
  }

  @override
  String deviceLastUsed(String time) {
    return 'Last used: $time';
  }

  @override
  String deviceExpires(String time) {
    return 'Expires: $time';
  }

  @override
  String get revokeDevice => 'Revoke device';

  @override
  String get revokeCurrentDevice => 'Sign out this device';

  @override
  String get revokeDeviceConfirmation =>
      'After revocation, this device can no longer refresh its sign-in session.';

  @override
  String get revokeCurrentDeviceConfirmation =>
      'After signing out this device, enter your username and password again to reconnect.';

  @override
  String get deviceRevoked => 'Sign-in device revoked';

  @override
  String get close => 'Close';

  @override
  String get retry => 'Retry';

  @override
  String get excelUseSessionTitleAsHeader =>
      'Use current session name as header';

  @override
  String get excelUseSessionTitleAsHeaderHint =>
      'Use the current session name directly as the Excel header. If it is blank, the header template is used instead.';

  @override
  String get fileNameUseSessionTitle => 'Use current session name as file name';

  @override
  String get fileNameUseSessionTitleHint =>
      'Use the current session name directly as the export file name. If it is blank, the file name template is used instead.';

  @override
  String get themeColorPickerTitle => 'Choose theme color';

  @override
  String get themeColorPresets => 'Preset colors';

  @override
  String get themeColorCustom => 'Custom color';

  @override
  String get themeColorHex => 'HEX color';

  @override
  String get themeColorHue => 'Hue';

  @override
  String get themeColorBlue => 'Blue';

  @override
  String get themeColorGreen => 'Green';

  @override
  String get themeColorRed => 'Red';

  @override
  String get themeColorOrange => 'Orange';

  @override
  String get themeColorPurple => 'Purple';

  @override
  String get themeColorPink => 'Pink';

  @override
  String get save => 'Save';

  @override
  String get add => 'Add';

  @override
  String get renameSession => 'Rename session';

  @override
  String get renameSessionTitle => 'Rename session';

  @override
  String get sessionTitleLabel => 'Session name';

  @override
  String get renameCollaborationSessionHint =>
      'Only the session owner can rename it. The new name will sync to other scribes and controller displays.';

  @override
  String get renameSessionSaved => 'Session name updated';

  @override
  String get renameCollaborationSessionSaved =>
      'Session name saved and syncing to other members';

  @override
  String renameSessionFailed(String error) {
    return 'Could not rename session: $error';
  }

  @override
  String get renameSessionBlockedClosed => 'A closed session cannot be renamed';

  @override
  String get renameSessionBlockedBusy =>
      'Wait for the current collaboration operation to finish';

  @override
  String get renameSessionBlockedConflict =>
      'Resolve the session conflict before renaming';

  @override
  String get renameSessionBlockedNotReady =>
      'The collaboration session is not ready to be renamed';

  @override
  String get renameSessionBlockedOwner =>
      'Only the session owner can rename it';

  @override
  String get dictionaryManagementTitle => 'Lookup libraries';

  @override
  String get dictionaryManagementHint =>
      'Manage radios, antennas, callsigns, and QTH values that can be searched and reused while logging.';

  @override
  String get deviceLibrary => 'Radio library';

  @override
  String get antennaLibrary => 'Antenna library';

  @override
  String get callsignLibrary => 'Callsign library';

  @override
  String get qthLibrary => 'QTH library';

  @override
  String libraryItemCount(int count) {
    return '$count entries';
  }

  @override
  String get importLibraryJson => 'Import JSON';

  @override
  String get expandAll => 'Expand all';

  @override
  String get collapseAll => 'Collapse all';

  @override
  String addLibraryItem(String name) {
    return 'Add to $name';
  }

  @override
  String searchLibrary(String name) {
    return 'Search $name';
  }

  @override
  String get libraryEmpty => 'This library is empty';

  @override
  String get noLibrarySearchResults => 'No matching library entries';

  @override
  String libraryItemAdded(String value) {
    return 'Added: $value';
  }

  @override
  String libraryItemAlreadyExists(String value) {
    return '“$value” is already in the library';
  }

  @override
  String libraryItemAddFailed(String error) {
    return 'Could not add entry: $error';
  }

  @override
  String get deleteLibraryItemTitle => 'Delete library entry';

  @override
  String deleteLibraryItemConfirmation(String value, String name) {
    return 'Delete “$value” from $name?';
  }

  @override
  String get deleteLibraryItemAction => 'Delete';

  @override
  String libraryItemDeleted(String value) {
    return 'Deleted: $value';
  }

  @override
  String libraryItemDeleteFailed(String error) {
    return 'Could not delete entry: $error';
  }

  @override
  String clearLibraryTitle(String name) {
    return 'Clear $name';
  }

  @override
  String clearLibraryConfirmation(String name, int count) {
    return 'This will delete all $count entries from $name. This cannot be undone. Continue?';
  }

  @override
  String get clearLibraryAction => 'Clear all';

  @override
  String libraryCleared(String name) {
    return 'Cleared $name';
  }

  @override
  String libraryClearFailed(String error) {
    return 'Could not clear library: $error';
  }

  @override
  String get libraryImportEmpty => 'The file has no library entries to import';

  @override
  String libraryImportCount(String name, int count) {
    return '$name: $count';
  }

  @override
  String libraryImportSucceeded(String summary) {
    return 'Imported: $summary';
  }

  @override
  String libraryImportFailed(String error) {
    return 'Could not import libraries: $error';
  }

  @override
  String get listSeparator => ', ';

  @override
  String get fontPickerTitle => 'Choose font';

  @override
  String get fontSearchHint => 'Search fonts';

  @override
  String fontResultCount(int count) {
    return '$count fonts';
  }

  @override
  String get fontSystemDefault => 'System default';

  @override
  String get fontBuiltIn => 'Built in';

  @override
  String get fontPreview => 'Preview';

  @override
  String get fontPreviewSample => 'OpenLogTool · CQ CQ · Net log 123';

  @override
  String get localCollaborationOperationBusy =>
      'Another collaboration operation is still in progress. Wait for it to end and try again.';

  @override
  String get localCollaborationRequired =>
      'The current session is no longer an on-device collaboration replica. Refresh the page and try again.';

  @override
  String get settingsCategoryAi => 'AI assistance';

  @override
  String get aiSettingsTitle => 'AI-assisted recognition';

  @override
  String get aiSettingsDescription =>
      'Configure optional speech recognition and field extraction services. Endpoints, models, and authentication stay device-specific.';

  @override
  String get aiSettingsOptionalTitle => 'Optional and off by default';

  @override
  String get aiSettingsOptionalMessage =>
      'Audio is sent directly to the service you configure, not through the OpenLogTool collaboration server. Results are suggestions and never overwrite a scribe\'s active edits automatically.';

  @override
  String get aiRecognitionEnabled => 'Enable AI-assisted recognition';

  @override
  String get aiRecognitionEnabledHint =>
      'Makes the selected speech recognition profile available from the Net Desk.';

  @override
  String get aiLocalReferenceContext =>
      'Use local dictionaries and recent records';

  @override
  String get aiLocalReferenceContextHint =>
      'On by default. Sends only a few terms similar to the current transcript and recent fields for a matched callsign to the text model. The complete database is never uploaded.';

  @override
  String get aiRecognitionNeedsAsr =>
      'Add and select a speech recognition profile first.';

  @override
  String get aiAsrStageTitle => 'Speech recognition (ASR)';

  @override
  String get aiAsrStageDescription =>
      'Turns audio into raw text. All three endpoint formats can be saved and switched at any time.';

  @override
  String get aiExtractionStageTitle => 'Field extraction (optional)';

  @override
  String get aiExtractionStageDescription =>
      'Turns a transcript into suggested callsign, RST, QTH, and other fields. Without it, the raw transcript remains available.';

  @override
  String get aiSupportedProtocols => 'Supported endpoint formats';

  @override
  String get aiActiveProfile => 'Active profile';

  @override
  String get aiNoProfileConfigured => 'No profiles have been added';

  @override
  String get aiNoActiveProfile => 'Do not use';

  @override
  String get aiCredentialStatus => 'Credential status';

  @override
  String get aiCredentialNoProfile =>
      'Select a profile to see its on-device credential status.';

  @override
  String get aiCredentialStoredLocally =>
      'API keys are stored separately in secure system storage and are excluded from profile exports.';

  @override
  String get aiStatusNotConfigured => 'Not configured';

  @override
  String get aiStatusNoCredentialNeeded => 'No key required';

  @override
  String get aiStatusCredentialReady => 'Key stored';

  @override
  String get aiStatusCredentialMissing => 'Key missing';

  @override
  String get aiAddProfile => 'Add profile';

  @override
  String get aiEditProfile => 'Edit profile';

  @override
  String get aiDeleteProfileTitle => 'Delete AI profile';

  @override
  String aiDeleteProfileMessage(String name) {
    return 'Delete “$name” and its on-device credential?';
  }

  @override
  String get aiProfileName => 'Profile name';

  @override
  String get aiBaseUrl => 'API base URL';

  @override
  String get aiModelName => 'Model name';

  @override
  String get aiProtocol => 'Endpoint format';

  @override
  String get aiAuthentication => 'Authentication';

  @override
  String get aiCredentialName => 'Header or query parameter name';

  @override
  String get aiCredentialPrefix => 'Credential prefix (optional)';

  @override
  String get aiApiKey => 'API key';

  @override
  String get aiApiKeyNewHint =>
      'You may leave this empty and add the key later.';

  @override
  String get aiApiKeyExistingHint =>
      'Leave empty to keep the current key. A changed destination requires a new key.';

  @override
  String get aiRequestOptions => 'Advanced request options (JSON)';

  @override
  String get aiRequestOptionsHint =>
      'Generic JSON requires requestTemplate. Protocol options include path, responsePath, body, fields, audioDataEncoding, and includePrompt. This metadata is exported with the profile; never place a key here.';

  @override
  String get aiRequiredField => 'This field is required';

  @override
  String get aiRequestOptionsMustBeObject =>
      'Advanced request options must be a JSON object';

  @override
  String get aiJsonProtocolNeedsTemplate =>
      'Generic JSON requires requestTemplate';

  @override
  String get aiInvalidJson => 'Invalid JSON';

  @override
  String get aiInvalidBaseUrl => 'Enter a valid HTTP(S) API address';

  @override
  String aiSettingsFailed(String error) {
    return 'AI settings operation failed: $error';
  }

  @override
  String get aiProtocolAudioTranscriptions => 'Audio transcription multipart';

  @override
  String get aiProtocolChatAudio => 'Chat input_audio';

  @override
  String get aiProtocolChatText => 'Chat text extraction';

  @override
  String get aiProtocolGenericJson => 'Generic JSON HTTP';

  @override
  String get aiAuthNone => 'No authentication';

  @override
  String get aiAuthBearer => 'Authorization Bearer';

  @override
  String get aiAuthHeader => 'Custom header';

  @override
  String get aiAuthQuery => 'Query parameter';

  @override
  String get aiWorkbenchTitle => 'AI-assisted recognition';

  @override
  String get aiWorkbenchUnavailable =>
      'Recognition is unavailable while this record is read-only or busy.';

  @override
  String get aiReadyStatus => 'Tap the microphone to capture one check-in.';

  @override
  String aiRecordingStatus(String elapsed) {
    return 'Recording $elapsed';
  }

  @override
  String get aiLiveTranscriptTitle => 'Live recognized fields';

  @override
  String get aiLiveStructuredWaiting =>
      'Building enough context for a complete check-in. Recognized fields will appear here.';

  @override
  String get aiLiveStructuredUpdating =>
      'Organizing fields from everything recognized so far…';

  @override
  String aiLiveTranscriptionRetrying(String error) {
    return 'Live recognition temporarily failed. The complete content will still be retried after recording stops: $error';
  }

  @override
  String get aiRecognizingStatus => 'Recognizing and preparing suggestions…';

  @override
  String get aiStartRecording => 'Record';

  @override
  String get aiStopAndRecognize => 'Recognize';

  @override
  String get aiMicrophonePermissionDenied =>
      'Microphone permission was not granted.';

  @override
  String aiRecordingFailed(String error) {
    return 'Recording failed: $error';
  }

  @override
  String aiRecognitionFailed(String error) {
    return 'Recognition failed: $error';
  }

  @override
  String get aiReviewTitle => 'Review AI suggestions';

  @override
  String get aiTranscriptTitle => 'Transcript';

  @override
  String get aiCopyTranscript => 'Copy transcript';

  @override
  String get aiTranscriptCopied => 'Transcript copied.';

  @override
  String get aiNoStructuredCandidates =>
      'No structured fields were returned. The transcript is still available above.';

  @override
  String get aiCandidateRecord => 'Suggested record';

  @override
  String aiCandidateNumber(int number) {
    return 'Candidate $number';
  }

  @override
  String get aiCandidateHint =>
      'Empty fields are selected automatically. Replacing existing text always requires your explicit selection.';

  @override
  String get aiApplySelected => 'Apply selected';

  @override
  String aiCandidatesApplied(int count) {
    return 'Applied $count suggested field(s).';
  }

  @override
  String get aiCandidatesStale =>
      'These suggestions are no longer safe to apply because the record changed.';

  @override
  String aiApplyFailed(String error) {
    return 'Could not apply AI suggestions: $error';
  }

  @override
  String aiWillReplaceValue(String value) {
    return 'Will replace: $value';
  }

  @override
  String get aiWillFillEmpty => 'Will fill an empty field';

  @override
  String get aiReplacementNeedsConfirmation => 'Select to confirm replacement';

  @override
  String get aiCandidateUnchanged => 'Already matches';

  @override
  String get aiCandidateStale => 'The field changed after recording began';

  @override
  String get aiCandidateBeingEdited => 'The field is currently being edited';

  @override
  String get aiCandidateLocked => 'Another collaborator is editing this field';

  @override
  String get aiCandidateReadOnly => 'This record is read-only';

  @override
  String get aiCandidateBusy => 'The record is busy';

  @override
  String get aiCandidateInvalid => 'Unsupported or invalid suggestion';

  @override
  String get textAssistantTitle => 'Text assistant';

  @override
  String get textAssistantDescription =>
      'Use a simple text-model setup for structured fields, inline suggestions, and dictionary maintenance.';

  @override
  String get textAssistantPrivacyTitle =>
      'Processed by your selected model service';

  @override
  String get textAssistantPrivacyMessage =>
      'When needed, current field text or aggregated historical terms are sent to the selected service. Complete records, remarks, and times are not sent. The API key is used only for request authentication and stored securely on this device.';

  @override
  String get textAssistantEnabled => 'Enable text assistant';

  @override
  String get textAssistantNotConfigured => 'Text assistant is not configured';

  @override
  String get textAssistantInlineSuggestions =>
      'Show AI formatting suggestions while typing';

  @override
  String get textAssistantInlineSuggestionsHint =>
      'Shows one fast suggestion for device, antenna, QTH, height, and power after typing pauses for about 300 ms.';

  @override
  String get textAssistantTest => 'Test connection';

  @override
  String get textAssistantConfigure => 'Configure text assistant';

  @override
  String get textAssistantEdit => 'Edit configuration';

  @override
  String get textAssistantConfigureTitle => 'Configure text assistant';

  @override
  String get textAssistantProvider => 'Provider type';

  @override
  String get textAssistantProviderOpenAi => 'OpenAI (Responses API)';

  @override
  String get textAssistantProviderAnthropic => 'Anthropic';

  @override
  String get textAssistantProviderCompatible =>
      'OpenAI-compatible (legacy Chat Completions)';

  @override
  String get textAssistantTestSucceeded =>
      'The text assistant connection works.';

  @override
  String get textAssistantSuggestionLabel => 'AI formatting suggestion';

  @override
  String get aiDictionaryRecognize => 'Recognize from history';

  @override
  String get aiDictionaryOptimize => 'Optimize dictionaries with AI';

  @override
  String get aiDictionaryNeedsAssistant =>
      'Configure and enable the text assistant in Settings first.';

  @override
  String get aiDictionaryNoSuggestions =>
      'No dictionary changes were suggested.';

  @override
  String aiDictionaryApplied(int count) {
    return 'Applied $count dictionary suggestion(s).';
  }

  @override
  String aiDictionaryFailed(String error) {
    return 'Dictionary AI operation failed: $error';
  }

  @override
  String get aiDictionaryOptimizing => 'Optimizing dictionaries';

  @override
  String get aiDictionaryRecognizing => 'Recognizing historical terms';

  @override
  String get aiDictionaryPreparing => 'Preparing local data…';

  @override
  String aiDictionaryProgress(int completed, int total) {
    return 'Completed $completed / $total';
  }

  @override
  String get aiDictionaryReviewTitle => 'Review dictionary suggestions';

  @override
  String aiDictionaryReviewHint(int recordCount) {
    return 'Generated from $recordCount historical record(s) and the current dictionaries. Only selected changes will be written.';
  }

  @override
  String get aiDictionaryActionAdd => 'Add';

  @override
  String get aiDictionaryActionRename => 'Rename';

  @override
  String get aiDictionaryActionMerge => 'Merge';

  @override
  String aiDictionaryUsedCount(int count) {
    return 'Used $count time(s) in history';
  }

  @override
  String get aiDictionaryMergeWarning =>
      'Merging hides the source term and is not selected by default. Historical records are unchanged.';

  @override
  String get aiDictionaryApplySelected => 'Apply selected suggestions';
}

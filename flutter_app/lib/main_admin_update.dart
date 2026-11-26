part of 'main.dart';

// Updating NeoAgent from the admin pages. The banner, the settings and the
// follow-the-restart logic are shared; this supplies the server calls and the
// wording. The server runs the same flow as `neoagent update`.

NeoUpdateController _adminUpdateController(
  BackendClient client,
  String baseUrl,
) => NeoUpdateController(
  NeoUpdateApi(
    status: () => client.fetchAdminUpdate(baseUrl),
    check: () => client.checkAdminUpdate(baseUrl),
    start: () => client.startAdminUpdate(baseUrl),
    setChannel: (channel) => client.setAdminUpdateChannel(baseUrl, channel),
    failureOf: (error) => error is BackendException
        ? (status: error.statusCode, message: error.message)
        : null,
  ),
);

NeoUpdateStrings _adminUpdateStrings() => NeoUpdateStrings(
  title: appStrings.updates,
  description: appStrings.adminUpdatesHint,
  versionLabel: 'Version',
  channelLabel: appStrings.releaseChannel,
  channelHint: appStrings.adminUpdateChannelHint,
  stable: appStrings.stable,
  beta: appStrings.beta,
  checkNow: appStrings.adminUpdateCheckNow,
  neverChecked: appStrings.adminUpdateNeverChecked,
  checkedAt: (time) => appStrings.adminUpdateCheckedAgo(_relativeTime(time)),
  upToDate: appStrings.adminUpdateUpToDate,
  checkFailed: appStrings.adminUpdateCheckFailed,
  details: appStrings.adminUpdateDetails,
  blocked: (reason) => (
    title: reason == 'container' ? 'Docker' : appStrings.updates,
    hint: switch (reason) {
      'container' => appStrings.adminUpdateContainerHint,
      'managed' => appStrings.adminUpdateManagedHint,
      _ => appStrings.adminUpdateNotGitHint,
    },
  ),
  readyTitle: appStrings.adminUpdateReadyTitle,
  readySubtitle: appStrings.adminUpdateReadySubtitle,
  whatsNew: appStrings.adminUpdateWhatsNew,
  updateNow: appStrings.updateNow,
  confirmTitle: appStrings.adminUpdateConfirmTitle,
  confirmMessage: appStrings.adminUpdateConfirmMessage,
  cancel: appStrings.cancel,
  updatingTitle: appStrings.adminUpdatingTitle,
  updatingToTitle: appStrings.adminUpdatingToTitle,
  reconnecting: appStrings.adminUpdateReconnecting,
  handsOff: appStrings.adminUpdateHandsOff,
  doneTitle: appStrings.adminUpdateDoneTitle,
  doneReloading: appStrings.adminUpdateDoneReloading,
  reload: appStrings.adminUpdateReload,
  failedTitle: appStrings.adminUpdateFailedTitle,
  close: appStrings.close,
  retry: appStrings.retry,
);

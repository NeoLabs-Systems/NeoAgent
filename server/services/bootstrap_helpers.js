'use strict';

const HEADLESS_BROWSER_SETTING_KEY = 'headless_browser';

function getErrorMessage(error) {
  if (error instanceof Error && error.message) {
    return error.message;
  }

  return String(error);
}

function isEnabledSetting(value) {
  return value !== 'false' && value !== false && value !== '0';
}

function restoreBrowserHeadlessPreference(browserController, database) {
  const userCount =
    database.prepare('SELECT COUNT(*) AS count FROM users').get()?.count || 0;
  const headlessSetting =
    userCount === 1
      ? database
          .prepare(
            'SELECT value FROM user_settings WHERE user_id = (SELECT id FROM users LIMIT 1) AND key = ?',
          )
          .get(HEADLESS_BROWSER_SETTING_KEY)
      : null;

  if (!headlessSetting) {
    return { restored: false, userCount };
  }

  browserController.headless = isEnabledSetting(headlessSetting.value);
  return {
    restored: true,
    userCount,
    headless: browserController.headless,
  };
}

function runBackgroundTask(errorPrefix, task, logger = console.error) {
  return Promise.resolve()
    .then(task)
    .catch((error) => {
      logger(errorPrefix, getErrorMessage(error));
    });
}

module.exports = {
  getErrorMessage,
  isEnabledSetting,
  restoreBrowserHeadlessPreference,
  runBackgroundTask,
};

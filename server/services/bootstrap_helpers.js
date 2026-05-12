function getErrorMessage(error) {
  if (error instanceof Error && error.message) {
    return error.message;
  }

  return String(error);
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
  runBackgroundTask,
};

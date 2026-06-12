'use strict';

module.exports = [
  require('./schedule'),
  require('./manual'),
  require('./webhook'),
  require('./gmail_message_received'),
  require('./outlook_email_received'),
  require('./slack_message_received'),
  require('./teams_message_received'),
  require('./weather_event'),
  require('./whatsapp_personal_message_received'),
];

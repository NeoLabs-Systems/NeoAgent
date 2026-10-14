'use strict';

const { membershipAdapter } = require('./messaging_membership');

module.exports = membershipAdapter({
  type: 'messaging_member_joined',
  label: 'Member Joined',
  eventName: 'member_joined',
  verb: 'joined',
});

'use strict';

const { membershipAdapter } = require('./messaging_membership');

module.exports = membershipAdapter({
  type: 'messaging_member_left',
  label: 'Member Left',
  eventName: 'member_left',
  verb: 'left',
});

'use strict';

const { normalizeTrimmedText } = require('../security');

module.exports = {
  type: 'discord_member_joined',
  label: 'Discord Member Joined',
  async validateConfig(config = {}) {
    const guildId = normalizeTrimmedText(config.guildId || config.guild_id, 40);
    if (!/^\d{17,20}$/.test(guildId)) {
      throw new Error('A Discord server ID is required.');
    }
    return { guildId };
  },
  summarize(config = {}) {
    return `Discord member joined · server: ${config.guildId}`;
  },
};

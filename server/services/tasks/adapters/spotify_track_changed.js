'use strict';

const { connectionConfig, summaryParts } = require('./shared');

module.exports = {
  type: 'spotify_track_changed',
  label: 'Spotify Track Changed',
  providerKey: 'spotify',
  appKey: 'spotify',
  configHint: '{ connectionId }; fires when a different track starts playing',
  async validateConfig(config = {}, context = {}) {
    return connectionConfig(config, context, 'spotify', 'spotify');
  },
  summarize(config = {}) {
    return summaryParts('Spotify track changed', [config.accountEmail]);
  },
  poll: {
    intervalMinutes: 1,
    cursor: 'list',
    async fetchRows({ tool, config }) {
      const playback = await tool('spotify_get_current_playback');
      const item = playback?.item;
      if (!playback?.is_playing || !item?.id) return [];
      return [{
        fingerprint: `spotify:${config.connectionId}:${item.id}`,
        timestamp: new Date().toISOString(),
        context: {
          triggerEvent: {
            provider: 'spotify',
            event: 'track_changed',
            trackId: item.id,
            title: item.name || '',
            artists: Array.isArray(item.artists) ? item.artists.map((artist) => artist.name).filter(Boolean) : [],
            album: item.album?.name || null,
            device: playback.device?.name || null,
            url: item.external_urls?.spotify || null,
          },
        },
      }];
    },
  },
};

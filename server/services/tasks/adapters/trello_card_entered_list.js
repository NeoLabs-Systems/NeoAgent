'use strict';

const { connectionConfig, listFrom, requiredText, summaryParts, timeCursor } = require('./shared');

const ENTRY_ACTIONS = 'createCard,copyCard,updateCard:idList,moveCardToBoard,convertToCardFromCheckItem';

// The list's activity says how a card got there, so a card moved in counts
// the same as one created there.
function enteredList(action, listId) {
  const data = action.data || {};
  return data.listAfter?.id === listId || (action.type !== 'updateCard' && data.list?.id === listId);
}

module.exports = {
  type: 'trello_card_entered_list',
  label: 'Trello Card Added to List',
  providerKey: 'trello',
  appKey: 'trello',
  configHint: '{ connectionId, listId }; fires for cards created in or moved into the list',
  async validateConfig(config = {}, context = {}) {
    return {
      ...connectionConfig(config, context, 'trello', 'trello'),
      listId: requiredText(config.listId || config.list_id, 100, 'Trello list ID is required.'),
    };
  },
  summarize(config = {}) {
    return summaryParts('Trello cards entering list', [config.listId]);
  },
  poll: {
    intervalMinutes: 5,
    cursor: 'ordered',
    baseline: 'now',
    async fetchRows({ tool, config }) {
      const result = await tool('trello_list_actions', {
        list_id: config.listId,
        filter: ENTRY_ACTIONS,
        limit: 50,
      });
      return listFrom(result)
        .filter((action) => action && enteredList(action, config.listId))
        .map((action) => ({
          fingerprint: timeCursor(action.date, action.id),
          timestamp: action.date,
          context: {
            triggerEvent: {
              provider: 'trello',
              event: 'card_entered_list',
              how: action.type === 'updateCard' ? 'moved' : 'created',
              cardId: action.data?.card?.id || null,
              cardName: action.data?.card?.name || '',
              listId: config.listId,
              listName: action.data?.listAfter?.name || action.data?.list?.name || null,
              fromList: action.data?.listBefore?.name || null,
              boardName: action.data?.board?.name || null,
              by: action.memberCreator?.fullName || action.memberCreator?.username || null,
            },
          },
        }))
        .filter((row) => row.fingerprint)
        .sort((left, right) => left.fingerprint.localeCompare(right.fingerprint));
    },
  },
};

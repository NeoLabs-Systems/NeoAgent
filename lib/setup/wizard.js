'use strict';

const { SETUP_WIZARD_SECTIONS } = require('./contract');

const VALID_ACTIONS = new Set(['next', 'back', 'skip', 'cancel']);

function normalizeStartIndex(sections, startSectionId) {
  const index = sections.findIndex((section) => section.id === startSectionId);
  return index >= 0 ? index : 0;
}

async function runSetupWizard({
  sections = SETUP_WIZARD_SECTIONS,
  startSectionId = null,
  completedSections = [],
  runSection,
  onTransition = async () => {},
} = {}) {
  if (typeof runSection !== 'function') {
    throw new TypeError('runSetupWizard requires a section runner.');
  }
  const completed = new Set(completedSections);
  const skipped = new Set();
  let index = normalizeStartIndex(sections, startSectionId);

  while (index < sections.length) {
    const section = sections[index];
    const outcome = await runSection(section, {
      canGoBack: index > 0,
      completedSections: [...completed],
      skippedSections: [...skipped],
    });
    const action = String(outcome?.action || 'next');
    if (!VALID_ACTIONS.has(action)) {
      throw new Error(`Invalid setup wizard action: ${action}.`);
    }
    if (action === 'cancel') {
      const error = new Error('Setup was cancelled before any changes were saved.');
      error.code = 'SETUP_CANCELLED';
      throw error;
    }
    if (action === 'back') {
      if (index > 0) index -= 1;
      await onTransition({
        sectionId: sections[index].id,
        completedSections: [...completed],
        skippedSections: [...skipped],
      });
      continue;
    }

    if (section.id !== 'review') {
      if (action === 'skip') {
        if (outcome?.completed === true) completed.add(section.id);
        else completed.delete(section.id);
        skipped.add(section.id);
      } else if (outcome?.completed === false) {
        completed.delete(section.id);
        skipped.add(section.id);
      } else {
        completed.add(section.id);
        skipped.delete(section.id);
      }
    }
    index += 1;
    await onTransition({
      sectionId: sections[index]?.id || 'configured',
      completedSections: [...completed],
      skippedSections: [...skipped],
    });
  }

  return {
    completedSections: [...completed],
    skippedSections: [...skipped],
  };
}

module.exports = {
  runSetupWizard,
};

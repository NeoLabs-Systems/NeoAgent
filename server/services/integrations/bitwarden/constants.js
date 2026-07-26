'use strict';

const BITWARDEN_PROVIDER_KEY = 'bitwarden';

const BITWARDEN_APP = {
  id: 'password_manager',
  label: 'Password manager',
  description: 'Use selected Bitwarden items without exposing their secret values to the AI.',
};

module.exports = {
  BITWARDEN_APP,
  BITWARDEN_PROVIDER_KEY,
};

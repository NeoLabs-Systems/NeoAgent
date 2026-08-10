'use strict';

const crypto = require('node:crypto');
const { isoCBOR } = require('@simplewebauthn/server/helpers');

const FLAG_USER_PRESENT = 0x01;
const FLAG_USER_VERIFIED = 0x04;
const FLAG_ATTESTED_CREDENTIAL_DATA = 0x40;
const AAGUID = Buffer.alloc(16, 0);

function base64url(bytes) {
  return Buffer.from(bytes).toString('base64url');
}

function sha256(bytes) {
  return crypto.createHash('sha256').update(Buffer.from(bytes)).digest();
}

function coseEs256PublicKey(publicKeyJwk) {
  return Buffer.from(isoCBOR.encode(new Map([
    [1, 2],
    [3, -7],
    [-1, 1],
    [-2, Buffer.from(publicKeyJwk.x, 'base64url')],
    [-3, Buffer.from(publicKeyJwk.y, 'base64url')],
  ])));
}

function buildAuthenticatorData({ rpId, flags, signCount, attestedCredentialData }) {
  const header = Buffer.alloc(37);
  sha256(Buffer.from(rpId, 'utf8')).copy(header, 0);
  header.writeUInt8(flags, 32);
  header.writeUInt32BE(signCount, 33);
  return attestedCredentialData ? Buffer.concat([header, attestedCredentialData]) : header;
}

function buildClientDataJSON({ type, challenge, origin }) {
  return Buffer.from(JSON.stringify({ type, challenge, origin, crossOrigin: false }), 'utf8');
}

/**
 * Minimal software authenticator that produces the same "none" attestation and
 * ES256 assertions a real security key would, so the WebAuthn routes can be
 * exercised without hardware.
 */
function createVirtualAuthenticator({ userVerified = true } = {}) {
  const { privateKey, publicKey } = crypto.generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
  const credentialId = crypto.randomBytes(32);
  const cosePublicKey = coseEs256PublicKey(publicKey.export({ format: 'jwk' }));
  let signCount = 0;

  function flags(includeAttestedData) {
    let value = FLAG_USER_PRESENT;
    if (userVerified) value |= FLAG_USER_VERIFIED;
    if (includeAttestedData) value |= FLAG_ATTESTED_CREDENTIAL_DATA;
    return value;
  }

  return {
    credentialId: base64url(credentialId),

    register({ options, origin }) {
      const credentialIdLength = Buffer.alloc(2);
      credentialIdLength.writeUInt16BE(credentialId.length, 0);
      const authData = buildAuthenticatorData({
        rpId: options.rp.id,
        flags: flags(true),
        signCount,
        attestedCredentialData: Buffer.concat([AAGUID, credentialIdLength, credentialId, cosePublicKey]),
      });
      const attestationObject = Buffer.from(isoCBOR.encode(new Map([
        ['fmt', 'none'],
        ['attStmt', new Map()],
        ['authData', new Uint8Array(authData)],
      ])));

      return {
        id: base64url(credentialId),
        rawId: base64url(credentialId),
        type: 'public-key',
        clientExtensionResults: {},
        response: {
          clientDataJSON: base64url(buildClientDataJSON({
            type: 'webauthn.create',
            challenge: options.challenge,
            origin,
          })),
          attestationObject: base64url(attestationObject),
          transports: ['usb'],
        },
      };
    },

    authenticate({ options, origin, userHandle = null }) {
      signCount += 1;
      const authData = buildAuthenticatorData({
        rpId: options.rpId,
        flags: flags(false),
        signCount,
      });
      const clientDataJSON = buildClientDataJSON({
        type: 'webauthn.get',
        challenge: options.challenge,
        origin,
      });
      const signature = crypto.sign(
        'sha256',
        Buffer.concat([authData, sha256(clientDataJSON)]),
        privateKey,
      );

      return {
        id: base64url(credentialId),
        rawId: base64url(credentialId),
        type: 'public-key',
        clientExtensionResults: {},
        response: {
          clientDataJSON: base64url(clientDataJSON),
          authenticatorData: base64url(authData),
          signature: base64url(signature),
          userHandle: userHandle == null ? null : base64url(Buffer.from(String(userHandle), 'utf8')),
        },
      };
    },
  };
}

module.exports = { createVirtualAuthenticator };

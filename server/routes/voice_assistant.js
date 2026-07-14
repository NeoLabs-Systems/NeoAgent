const express = require('express');

const { requireAuth } = require('../middleware/auth');
const { sanitizeError } = require('../utils/security');
const { transcribeVoiceInput } = require('../services/voice/providers');
const { writeTempAudioFile, removeTempFile } = require('../services/voice/liveAudio');

const router = express.Router();

router.use(requireAuth);

router.post('/transcribe', async (req, res) => {
  try {
    const audioBase64 = String(req.body?.audioBase64 || '').trim();
    const mimeType = String(req.body?.mimeType || 'audio/pcm;rate=16000;channels=1').trim();

    if (!audioBase64) {
      return res.status(400).json({ error: 'audioBase64 is required.' });
    }

    const approxBytes = (audioBase64.length * 3) / 4;
    if (approxBytes > 25 * 1024 * 1024) {
      return res.status(400).json({ error: 'Audio exceeds maximum size of 25MB.' });
    }

    const audioBytes = Buffer.from(audioBase64, 'base64');
    const { filePath, mimeType: fileMimeType } = await writeTempAudioFile(audioBytes, mimeType);
    let transcript = '';
    try {
      transcript = await transcribeVoiceInput(filePath, {
        mimeType: fileMimeType,
        userId: req.session.userId,
        timeoutMs: 30000,
      });
    } finally {
      await removeTempFile(filePath);
    }

    return res.json({ transcript: String(transcript || '').trim() });
  } catch (err) {
    const message = sanitizeError(err);
    return res.status(500).json({ error: message });
  }
});

module.exports = router;

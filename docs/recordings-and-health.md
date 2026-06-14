# Recordings and health

Recordings and health data are optional features of the NeoAgent clients. Both
store their processed data on the NeoAgent backend.

## Recordings

The web client can capture microphone and screen audio. The Android client can
record microphone audio through a foreground service.

Recordings upload in chunks and move through recording, processing, completed,
failed, or cancelled states. When Deepgram is configured, NeoAgent transcribes
the audio and stores timestamped segments that can be searched from the
operator interface or by the agent.

Optional recording insights can produce summaries, action items, and event
suggestions after transcription.

The agent can list recordings, inspect a session, and search transcripts. It
can also extract transcripts and metadata from supported public social-video
URLs when the required host tool is installed.

## Health Connect

The Android app can read Health Connect records after the user grants Android
permissions. Supported data includes steps, heart rate, sleep, exercise, and
weight.

The app uploads granted records to the user's NeoAgent backend. Stored metrics
appear in **Health** and are available to the owning agent through the health
tool.

Health Connect access can be revoked in Android settings. Revoking access stops
future reads but does not remove records already uploaded to NeoAgent; delete
stored server data separately when required.

## Privacy

Audio, transcripts, and health records are sensitive personal data. Protect the
server account, use HTTPS for remote clients, restrict agents and integrations,
and include these data stores in backup and deletion procedures.

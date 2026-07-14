# Health

Health data is an optional feature of the NeoAgent clients. It stores
processed data on the NeoAgent backend.

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

Health records are sensitive personal data. Protect the server account, use
HTTPS for remote clients, restrict agents and integrations, and include this
data store in backup and deletion procedures.

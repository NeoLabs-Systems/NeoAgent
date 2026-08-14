package com.neoagent.flutter_app.telecom

import android.content.Context
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.telecom.Connection
import android.telecom.ConnectionService
import android.telecom.ConnectionRequest
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager
import android.telecom.DisconnectCause

class NeoAgentConnectionService : ConnectionService() {
    override fun onCreateOutgoingConnection(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?
    ): Connection {
        return createConnection(request, isIncoming = false)
    }

    override fun onCreateOutgoingConnectionFailed(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?
    ) {
        super.onCreateOutgoingConnectionFailed(connectionManagerPhoneAccount, request)
    }

    override fun onCreateIncomingConnection(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?
    ): Connection {
        return createConnection(request, isIncoming = true)
    }

    override fun onCreateIncomingConnectionFailed(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?
    ) {
        super.onCreateIncomingConnectionFailed(connectionManagerPhoneAccount, request)
    }

    companion object {
        const val EXTRA_FLUTTER_INITIATED = "is_flutter_initiated"

        @Volatile
        private var currentConnection: NeoAgentConnection? = null

        @Synchronized
        fun getAndClearCurrentConnection(): NeoAgentConnection? {
            val conn = currentConnection
            currentConnection = null
            return conn
        }
        
        @Synchronized
        fun swapConnection(newConnection: NeoAgentConnection) {
            currentConnection?.let {
                try {
                    it.setDisconnected(DisconnectCause(DisconnectCause.LOCAL))
                    it.destroy()
                } catch (e: Exception) {
                    // Ignore
                }
            }
            currentConnection = newConnection
        }
    }

    private fun createConnection(request: ConnectionRequest?, isIncoming: Boolean): Connection {
        val connection = NeoAgentConnection(applicationContext)
        swapConnection(connection)
        
        // Custom flag from Flutter to know if it started the call
        val isFlutterInitiated = request?.extras?.getBoolean(EXTRA_FLUTTER_INITIATED) ?: false
        connection.isFlutterInitiated = isFlutterInitiated

        connection.connectionProperties = Connection.PROPERTY_SELF_MANAGED
        connection.setInitializing()

        if (isIncoming) {
            connection.setRinging()
        } else {
            connection.setDialing()
            // There is no remote party to ring: the voice session is live as soon as
            // Telecom hands us the connection. Without this the call sits in DIALING
            // forever, so audio focus is never granted and STATE_ACTIVE never fires.
            Handler(Looper.getMainLooper()).post {
                if (connection.state == Connection.STATE_DIALING) {
                    connection.setActive()
                }
            }
        }

        return connection
    }
}

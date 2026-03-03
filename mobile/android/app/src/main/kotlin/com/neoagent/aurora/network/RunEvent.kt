package com.neoagent.aurora.network

/** Typed events emitted by the NeoAgent WebSocket server → engine.js. */
sealed class RunEvent {

    /** A new agent run has been kicked off. */
    data class Start(
        val runId: String,
        val title: String,
        val model: String,
        val triggerType: String?,
        val triggerSource: String?,
    ) : RunEvent()

    /** The AI is processing / generating – no tool call yet. */
    data class Thinking(
        val runId: String,
        val iteration: Int,
    ) : RunEvent()

    /** Partial text is streaming in from the model. */
    data class Stream(
        val runId: String,
        val content: String,
        val iteration: Int,
    ) : RunEvent()

    /** A tool call is about to execute. */
    data class ToolStart(
        val runId: String,
        val tool: String,
        val input: String,
        val iteration: Int,
    ) : RunEvent()

    /** A tool call has finished. */
    data class ToolEnd(
        val runId: String,
        val tool: String,
        val result: String?,
        val error: String?,
        val durationMs: Long,
        val iteration: Int,
    ) : RunEvent()

    /** The run finished successfully. */
    data class Complete(
        val runId: String,
        val content: String,
        val totalTokens: Int,
        val iterations: Int,
    ) : RunEvent()

    /** The run failed. */
    data class Error(
        val runId: String,
        val error: String,
    ) : RunEvent()

    /** An interim progress message from inside a tool. */
    data class Interim(
        val runId: String,
        val message: String,
    ) : RunEvent()
}

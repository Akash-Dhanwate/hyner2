package com.hyner.hyner

import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong

/** One active file operation and one waiting operation; never an unbounded PDF queue. */
internal class FileWorkQueue(private val postToMain: (() -> Unit) -> Unit) {
    companion object {
        // One process-wide worker also bounds memory across activity recreation.
        // It sleeps only while working and releases its thread after being idle.
        private val executor = ThreadPoolExecutor(
            1, 1, 30L, TimeUnit.SECONDS, ArrayBlockingQueue<Runnable>(1),
            { task -> Thread(task, "Hyner-file-io") }, ThreadPoolExecutor.AbortPolicy(),
        ).apply { allowCoreThreadTimeOut(true) }
    }
    private val ownedTasks = ConcurrentHashMap<Long, Runnable>()
    private val closed = AtomicBoolean(false)
    private val sequence = AtomicLong()
    private val pending = ConcurrentHashMap<Long, () -> Unit>()

    fun <T> submit(action: () -> T, success: (T) -> Unit, failure: (Throwable) -> Unit) {
        val id = sequence.incrementAndGet()
        val finished = AtomicBoolean(false)
        fun deliver(outcome: Result<T>) {
            postToMain {
                if (finished.compareAndSet(false, true)) {
                    pending.remove(id)
                    ownedTasks.remove(id)
                    if (closed.get()) failure(IllegalStateException("The activity closed."))
                    else outcome.fold(success, failure)
                }
            }
        }
        val cancel = { deliver(Result.failure(IllegalStateException("The activity closed."))) }
        pending[id] = cancel
        if (closed.get()) {
            cancel()
            return
        }
        try {
            val task = Runnable {
                try {
                    if (closed.get()) cancel()
                    else deliver(runCatching(action))
                } finally { ownedTasks.remove(id) }
            }
            ownedTasks[id] = task
            executor.execute(task)
        } catch (error: RejectedExecutionException) {
            deliver(Result.failure(error))
        }
    }

    fun close() {
        if (!closed.compareAndSet(false, true)) return
        // Remove queued tasks before immediate main-thread cancellations clear tracking.
        // Never remove a replacement activity's work from the shared executor.
        ownedTasks.values.toList().forEach { executor.remove(it) }
        ownedTasks.clear()
        pending.values.toList().forEach { it() }
        // An already-open write finishes safely; the shared worker times out idle.
    }
}

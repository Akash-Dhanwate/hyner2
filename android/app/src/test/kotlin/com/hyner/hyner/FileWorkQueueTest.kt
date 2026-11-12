package com.hyner.hyner

import org.junit.Assert.*
import org.junit.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

class FileWorkQueueTest {
    @Test fun workRunsOffCallerAndResultsUseDispatcher() {
        val callbacks = LinkedBlockingQueue<() -> Unit>()
        val queue = FileWorkQueue { callbacks.add(it) }
        val caller = Thread.currentThread()
        var delivered = false
        queue.submit(
            action = { assertNotSame(caller, Thread.currentThread()); 42 },
            success = { assertSame(caller, Thread.currentThread()); assertEquals(42, it); delivered = true },
            failure = { throw AssertionError(it) },
        )
        try {
            val callback = callbacks.poll(5, TimeUnit.SECONDS)
            assertNotNull(callback)
            assertFalse(delivered)
            callback!!.invoke()
            assertTrue(delivered)
        } finally { queue.close() }
    }

    @Test fun closeCompletesEachPendingResultOnceAndDoesNotStartQueuedIo() {
        val callbacks = LinkedBlockingQueue<() -> Unit>()
        val queue = FileWorkQueue { callbacks.add(it) }
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        val ended = CountDownLatch(1)
        val completions = AtomicInteger()
        val queuedRuns = AtomicInteger()
        queue.submit(action = { entered.countDown(); release.await(); ended.countDown(); 1 },
            success = { fail("Closed activity must not receive success") }, failure = { completions.incrementAndGet() })
        assertTrue(entered.await(5, TimeUnit.SECONDS))
        queue.submit(action = { queuedRuns.incrementAndGet() }, success = { fail("Queued work ran") }, failure = { completions.incrementAndGet() })
        queue.close()
        repeat(2) { callbacks.poll(5, TimeUnit.SECONDS)!!.invoke() }
        assertEquals(2, completions.get())
        release.countDown()
        assertTrue(ended.await(5, TimeUnit.SECONDS))
        callbacks.poll(5, TimeUnit.SECONDS)!!.invoke() // Late active-job completion is ignored.
        assertEquals(2, completions.get())
        assertEquals(0, queuedRuns.get())
        queue.close()
    }

    @Test fun queueRejectsOverflowInsteadOfRetainingUnboundedBuffers() {
        val callbacks = LinkedBlockingQueue<() -> Unit>()
        val queue = FileWorkQueue { callbacks.add(it) }
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        var rejected = false
        queue.submit(action = { entered.countDown(); release.await() }, success = {}, failure = {})
        assertTrue(entered.await(5, TimeUnit.SECONDS))
        queue.submit(action = { 2 }, success = {}, failure = {})
        queue.submit(action = { fail("Overflow job must not run") }, success = {}, failure = { rejected = true })
        try {
            callbacks.poll(5, TimeUnit.SECONDS)!!.invoke()
            assertTrue(rejected)
        } finally { queue.close(); release.countDown() }
    }
    @Test fun closingOldOwnerKeepsReplacementActivityJobAndSerializesIo() {
        val callbacks = LinkedBlockingQueue<() -> Unit>()
        val old = FileWorkQueue { callbacks.add(it) }
        val replacement = FileWorkQueue { callbacks.add(it) }
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        val newRan = CountDownLatch(1)
        val oldFailures = AtomicInteger()
        val newSuccesses = AtomicInteger()
        old.submit(action = { entered.countDown(); release.await(); 1 }, success = { fail("Old owner closed") }, failure = { oldFailures.incrementAndGet() })
        assertTrue(entered.await(5, TimeUnit.SECONDS))
        replacement.submit(action = { newRan.countDown(); 2 }, success = { newSuccesses.incrementAndGet() }, failure = { throw AssertionError(it) })
        old.close()
        assertEquals(1, newRan.count)
        release.countDown()
        assertTrue(newRan.await(5, TimeUnit.SECONDS))
        repeat(3) { callbacks.poll(5, TimeUnit.SECONDS)!!.invoke() }
        assertEquals(1, oldFailures.get())
        assertEquals(1, newSuccesses.get())
        replacement.close()
    }
    @Test fun immediateCancellationDispatcherStillRemovesOldQueuedBuffers() {
        val old = FileWorkQueue { it() }
        val replacement = FileWorkQueue { it() }
        val entered = CountDownLatch(1)
        val release = CountDownLatch(1)
        val newFinished = CountDownLatch(1)
        val queuedRuns = AtomicInteger()
        val errors = AtomicInteger()
        try {
            old.submit(action = { entered.countDown(); release.await() }, success = {}, failure = {})
            assertTrue(entered.await(5, TimeUnit.SECONDS))
            old.submit(action = { queuedRuns.incrementAndGet() }, success = {}, failure = {})
            old.close() // Production's runOnUiThread dispatch is immediate on the UI thread.
            replacement.submit(action = { 1 }, success = { newFinished.countDown() }, failure = { errors.incrementAndGet(); newFinished.countDown() })
            release.countDown()
            assertTrue(newFinished.await(5, TimeUnit.SECONDS))
            assertEquals(0, errors.get())
            assertEquals(0, queuedRuns.get())
        } finally { old.close(); replacement.close(); release.countDown() }
    }
}

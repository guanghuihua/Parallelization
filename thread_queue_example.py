import queue
import threading
import time


def worker(name, task_queue, results, lock):
    """Pull a task from the queue, simulate work, and record the duration."""
    while True:
        try:
            task = task_queue.get(timeout=0.5)
        except queue.Empty:
            return

        start = time.perf_counter()
        # Simulate work that takes longer for larger inputs.
        time.sleep(0.05 + task * 0.01)
        elapsed = time.perf_counter() - start

        with lock:
            results.append((name, task, elapsed))

        task_queue.task_done()


def main():
    tasks = queue.Queue()
    for n in range(10):
        tasks.put(n)

    results = []
    results_lock = threading.Lock()
    threads = [
        threading.Thread(
            target=worker, args=(f"worker-{i}", tasks, results, results_lock)
        )
        for i in range(4)
    ]

    for t in threads:
        t.start()

    tasks.join()

    for t in threads:
        t.join()

    for name, task, elapsed in sorted(results, key=lambda x: x[1]):
        print(f"{name} processed task {task} in {elapsed:.3f}s")


if __name__ == "__main__":
    main()

module asyncore.core;

private import std.conv;
private import std.c.stdlib;
private import std.stdint;
public import deimos.uv;

string asyncore_strerror(uv_err_t err) {
  return to!string(uv_strerror(err));
}

/*
 * Objects of this class must be created before any other functions.
 * All functions besides Loop.run() are non-blocking.
 */
class Loop
{
  public:
    immutable static uv_run_mode RUN_DEFAULT_MODE = uv_run_mode.UV_RUN_DEFAULT;
    immutable static uv_run_mode RUN_ONCE_MODE    = uv_run_mode.UV_RUN_ONCE;
    immutable static uv_run_mode RUN_NOWAIT_MODE  = uv_run_mode.UV_RUN_NOWAIT;

    this() {
      _loopPtr = uv_loop_new();
    }

    ~this() {
      uv_loop_delete(_loopPtr);
    }

    /*
     * This function runs the event loop. It will act differently depending on the
     * specified mode:
     *  - RUN_DEFAULT_MODE: Runs the event loop until the reference count drops to
     *    zero. Always returns zero.
     *  - RUN_ONCE_MODE: Poll for new events once. Note that this function blocks if
     *    there are no pending events. Returns zero when done (no active handles
     *    or requests left), or non-zero if more events are expected (meaning you
     *    should run the event loop again sometime in the future).
     *  - RUN_NOWAIT_MODE: Poll for new events once but don't block if there are no
     *    pending events.
     */
    int run(uv_run_mode mode=Loop.RUN_DEFAULT_MODE) {
      return uv_run(_loopPtr, mode);
    }

    void stop() {
      uv_stop(_loopPtr);
    }

    uv_loop_t * getUvLoop() {
      return _loopPtr;
    }

  protected:
    uv_loop_t *_loopPtr;
}

class DefaultLoop
{
  public:
    // See Loop.run() description.
    static int run(uv_run_mode mode=Loop.RUN_DEFAULT_MODE) {
      uv_loop_t *loopPtr = uv_default_loop();
      return uv_run(loopPtr, mode);
    }

    static void stop() {
      uv_loop_t *loopPtr = uv_default_loop();
      uv_stop(loopPtr);
    }

    static uv_loop_t * getUvLoop() {
      return uv_default_loop();
    }

  private:
    this() {}
}

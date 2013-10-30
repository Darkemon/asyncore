module asyncore.core;

private import std.conv;
private import std.c.stdlib;
private import std.stdint;
public import deimos.uv;

string asyncore_strerror(uv_err_t err) {
  return to!string(uv_strerror(err));
}

class DefaultLoop 
{
  public:
    @system
    static void run() {
      uv_loop_t *loopPtr = uv_default_loop();
      uv_run(loopPtr, uv_run_mode.UV_RUN_DEFAULT);
    }

    @system
    static void stop() {
      uv_loop_t *loopPtr = uv_default_loop();
      uv_stop(loopPtr);
    }

  private:
    this() {}
}

class Loop
{
  public:
    uv_loop_t * getUvLoop() {
      return _loopPtr;
    }

  private:
    uv_loop_t *_loopPtr;
}

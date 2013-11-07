/**
 * Asynchronous signal.
 *
 * License: GNU GPL v2 (http://www.gnu.org/)
 * Author:  Artyom Krasotin
 *
 */

module asyncore.signal;

private import asyncore.core;
private import asyncore.events.eventemitter;
private import std.c.stdlib : malloc, free;

/*
 * UNIX signal handling on a per-event loop basis. The implementation is not
 * ultra efficient so don't go creating a million event loops with a million
 * signal watchers.
 *
 * Note to Linux users: SIGRT0 and SIGRT1 (signals 32 and 33) are used by the
 * NPTL pthreads library to manage threads. Installing watchers for those
 * signals will lead to unpredictable behavior and is strongly discouraged.
 * Future versions of libuv may simply reject them.
 *
 * Some signal support is available on Windows:
 *
 *   SIGINT is normally delivered when the user presses CTRL+C. However, like
 *   on Unix, it is not generated when terminal raw mode is enabled.
 *
 *   SIGBREAK is delivered when the user pressed CTRL+BREAK.
 *
 *   SIGHUP is generated when the user closes the console window. On SIGHUP the
 *   program is given approximately 10 seconds to perform cleanup. After that
 *   Windows will unconditionally terminate it.
 *
 *   SIGWINCH is raised whenever libuv detects that the console has been
 *   resized. SIGWINCH is emulated by libuv when the program uses an uv_tty_t
 *   handle to write to the console. SIGWINCH may not always be delivered in a
 *   timely manner; libuv will only detect size changes when the cursor is
 *   being moved. When a readable uv_tty_handle is used in raw mode, resizing
 *   the console buffer will also trigger a SIGWINCH signal.
 *
 * Watchers for other signals can be successfully created, but these signals
 * are never generated. These signals are: SIGILL, SIGABRT, SIGFPE, SIGSEGV,
 * SIGTERM and SIGKILL.
 *
 * Note that calls to raise() or abort() to programmatically raise a signal are
 * not detected by libuv; these will not trigger a signal watcher.
 */

class Signal : EventEmitter {

  public:

// ================================
//      Constructor & Destructor
// ================================

    this(Loop loop = null)
    {
      if (loop is null)
        _loopPtr = DefaultLoop.getUvLoop();
      else
        _loopPtr = loop.getUvLoop();

      _signalPtr = cast(uv_signal_t*)malloc(uv_signal_t.sizeof);
      _signalPtr.data = cast(void*)this;

      // For more performance.
      _eventSignal = new SignalEvent(SignalEvent.SIGNAL);

      if (uv_signal_init(_loopPtr, _signalPtr) != 0)
      {
        uv_err_t error = uv_last_error(_loopPtr);
        throw new Exception(asyncore_strerror(error));
      }
    }

    ~this()
    {
      unwatch();
      uv_close(cast(uv_handle_t*)_signalPtr, &close_cb);
    }


// ================================
//      Public methods
// ================================

  void watch(int signum)
  {
    if (uv_signal_start(_signalPtr, &signal_cb, signum) != 0)
      _emitError();
  }

  void unwatch() {
    if (uv_signal_stop(_signalPtr) != 0)
      _emitError();
  }

  private:
    uv_loop_t   *_loopPtr;
    uv_signal_t *_signalPtr;
    SignalEvent  _eventSignal;

// ================================
//      Private methods
// ================================

    extern (C) static void signal_cb(uv_signal_t* handle, int signum)
    {
      Signal self = cast(Signal)handle.data;
      // It's faster than building SignalEvent object on each timeout event.
      self._eventSignal._signum = signum;
      self.emit(self._eventSignal);
    }

    extern (C) static void close_cb(uv_handle_t* handle)
    {
      free(handle);
    }

    void _emitError() {
      uv_err_t error = uv_last_error(_loopPtr);
      auto e = new SignalEvent(SignalEvent.ERROR, asyncore_strerror(error));
      emit(e);
    }
}


class SignalEvent : Event
{
  public:
    static immutable int SIGNAL = 0;
    static immutable int ERROR  = 1;

    @property const string message() { return _msg; }
    @property int signum() { return _signum; }

    this(int eventId, string msg=null) { 
      super(eventId);
      _msg = msg;
    }

  private:
    string _msg;
    int    _signum = -1;
}

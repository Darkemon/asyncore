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
    {

    }
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

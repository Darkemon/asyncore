module asyncore.timer;

private import asyncore.core;
private import asyncore.events.eventemitter : EventEmitter, Event;
private import std.c.stdlib : malloc, free;

class Timer : EventEmitter {

  public:

// ================================
//      Properties
// ================================

    @property uint64_t repeat() const { 
      return uv_timer_get_repeat(_timerPtr);
    }

    /*
     * Set the repeat value in milliseconds. Note that if the repeat value is set
     * from a timer callback (listener) it does not immediately take effect. 
     * If the timer was non-repeating before, it will have been stopped.
     * If it was repeating, then the old repeat value will have been used 
     * to schedule the next timeout.
     */
    @property void repeat(uint64_t repeat) {
      uv_timer_set_repeat(_timerPtr, repeat);
    }


// ================================
//      Constructor & Destructor
// ================================

    this(Loop loop = null)
    {
      if (loop is null)
        _loopPtr = uv_default_loop();
      else
        _loopPtr = loop.getUvLoop();

      _timerPtr = cast(uv_timer_t*)malloc(uv_timer_t.sizeof);
      _timerPtr.data = cast(void*)this;

      // For more performance.
      _eventTimeout = new TimerEvent(TimerEvent.TIMEOUT);

      int ret = uv_timer_init(_loopPtr, _timerPtr);
    }

    ~this()
    {
      if (isActive())
        stop();

      uv_close(cast(uv_handle_t*)_timerPtr, null); // stop timer immediately
      free(_timerPtr);
    }


// ================================
//      Public methods
// ================================

    /*
     * Start the timer. `timeout` and `repeat` are in milliseconds.
     *
     * If timeout is zero, the callback fires on the next tick of the event loop.
     *
     * If repeat is non-zero, the callback fires first after timeout milliseconds
     * and then repeatedly after repeat milliseconds.
     */
    void start(uint64_t timeout, uint64_t repeat = 0) {
      if (uv_timer_start(_timerPtr, &timer_cb, timeout, repeat) != 0)
        _emitError();
    }

    void stop() {
      if (uv_timer_stop(_timerPtr) != 0) {
        _emitError();
      }
    }

    /*
     * Stop the timer, and if it is repeating restart it using the repeat value
     * as the timeout. If the timer has never been started before it emits error event.
     */
    void again() {
      int ret = uv_timer_again(_timerPtr);
      if (ret != 0) {
        if (ret == -1) {
          uv_err_t error = uv_last_error(_loopPtr);
          if (error.code == uv_err_code.UV_EINVAL) {
            _emitError("the timer has never been started before again()");
            return;
          }
        }
        _emitError();
      }
    }

    /* Returns true if timer has been started, false otherwise. */
    bool isActive() const {
      return cast(bool)uv_is_active(cast(uv_handle_t*)_timerPtr);
    }


  private:
    uv_loop_t  *_loopPtr;
    uv_timer_t *_timerPtr;
    TimerEvent  _eventTimeout;


// ================================
//      Private methods
// ================================

    extern (C) static void timer_cb(uv_timer_t* handle, int status)
    {
      Timer self = cast(Timer)handle.data;

      if (status != 0) {
        self._emitError();
      }
      else {
        // It's faster than building TimerEvent object on each timeout event.
        self.emit(self._eventTimeout);
      }
    }

    void _emitError(string msg=null) {
      TimerEvent e;
      if (msg)
        e = new TimerEvent(TimerEvent.ERROR, msg);
      else {
        uv_err_t error = uv_last_error(_loopPtr);
        e = new TimerEvent(TimerEvent.ERROR, asyncore_strerror(error));
      }
      emit(e);
    }
}


class TimerEvent : Event
{
  public:
    static immutable int TIMEOUT = 0;
    static immutable int ERROR   = 1;

    @property const string message() { return _msg; }

    this(int eventId, string msg=null) { 
      super(eventId);
      _msg  = msg;
    }

  private:
    string _msg;
}

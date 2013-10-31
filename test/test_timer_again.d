import asyncore.core;
import asyncore.timer;

import std.stdio;

void main()
{
  uint64_t start_time;
  int  repeatTimer1_timeout_called = 0;
  int  repeatTimer2_timeout_called = 0;
  bool repeatTimer2_repeat_allowed = false;
  bool dummyErr = false;
  auto dummyTimer   = new Timer();
  auto repeatTimer1 = new Timer();
  auto repeatTimer2 = new Timer();

  start_time = uv_now(uv_default_loop());
  assert(0 < start_time);

  /* Verify that it is not possible to again() a never-started timer. */
  dummyTimer.on(TimerEvent.ERROR, (in Event e) 
  {
    dummyErr = true;
    destroy(dummyTimer);
  });
  dummyTimer.again();

  /* Start timer repeatTimer1. */
  repeatTimer1.on(TimerEvent.TIMEOUT, (in Event e)
  {
    assert(repeatTimer1.repeat == 50);

    writefln("repeatTimer1 timeout occured after %d ms\n",
      (uv_now(uv_default_loop()) - start_time));

    repeatTimer1_timeout_called++;

    repeatTimer2.again();

    if (uv_now(uv_default_loop()) >= start_time + 500) {
      destroy(repeatTimer1);
      /* We're not calling uv_timer_again on repeat_2 any more, so after this */
      /* timer_2_cb is expected. */
      repeatTimer2_repeat_allowed = true;
      return;
    }
  });

  repeatTimer1.on(TimerEvent.ERROR, (in Event e)
  {
    TimerEvent event = cast(TimerEvent)e;
    writefln(event.message);
    assert(false);
  });

  repeatTimer1.start(50, 0);
  assert(repeatTimer1.repeat == 0);
  
  /* Actually make repeatTimer1 repeating. */
  repeatTimer1.repeat = 50;
  assert(repeatTimer1.repeat == 50);

  /*
   * Start another repeating timer. It'll be again()ed by the repeatTimer1 so
   * it should not time out until repeatTimer1 stops.
   */
  repeatTimer2.on(TimerEvent.TIMEOUT, (in Event e)
  {
    assert(repeatTimer2_repeat_allowed);

    writefln("repeatTimer2 timeout occured after %d ms\n",
      (uv_now(uv_default_loop()) - start_time));

    repeatTimer2_timeout_called++;

    if (repeatTimer2.repeat == 0) {
      assert(!repeatTimer2.isActive());
      destroy(repeatTimer2);
      return;
    }

    writefln("repeat time of repeatTimer2 %d ms\n",
      repeatTimer2.repeat);
    assert(repeatTimer2.repeat == 100);

    /* This shouldn't take effect immediately. */
    repeatTimer2.repeat = 0;
  });

  repeatTimer2.on(TimerEvent.ERROR, (in Event e)
  {
    TimerEvent event = cast(TimerEvent)e;
    writefln(event.message);
    assert(false);
  });

  repeatTimer2.start(100, 100);
  assert(repeatTimer2.repeat == 100);

  DefaultLoop.run();

  assert(dummyErr == true);
  assert(repeatTimer1_timeout_called == 10);
  assert(repeatTimer2_timeout_called == 2);

  writefln("Test took %d ms (expected ~700 ms)\n",
       (uv_now(uv_default_loop()) - start_time));
  assert(700 <= uv_now(uv_default_loop()) - start_time);
}

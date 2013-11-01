import asyncore.core;
import asyncore.timer;

import std.stdio;

void main()
{
  int once_cb_called         = 0;
  int once_close_cb_called   = 0;
  int repeat_cb_called       = 0;
  int repeat_close_cb_called = 0;
  int order_cb_called        = 0;
  uint64_t start_time;
  Timer tiny_timer;
  Timer huge_timer1;
  Timer huge_timer2;  

  void once_cb(in Event e)
  {
    writefln("ONCE_CB %d\n", once_cb_called);
    TimerEvent event = cast(TimerEvent)e;
    
    assert(!event.source.isActive());

    once_cb_called++;

    destroy(event.source);

    /* Just call this randomly for the code coverage. */
    uv_update_time(uv_default_loop());
  }

  void repeat_cb(in Event e)
  {
    writefln("REPEAT_CB\n");
    TimerEvent event = cast(TimerEvent)e;

    assert(event.source.isActive());

    repeat_cb_called++;

    if (repeat_cb_called == 5) {
      destroy(event.source);
    }
  }

  void never_cb(in Event e) {
    throw new Exception("never_cb should never be called");
  }

  void tiny_timer_cb(in Event e)
  {
    TimerEvent event = cast(TimerEvent)e;
    //assert(event.source == tiny_timer); // TODO: opEquals in Timer
    destroy(tiny_timer);
    destroy(huge_timer1);
    destroy(huge_timer2);
  }

  void huge_repeat_cb(in Event e)
  {
    static int ncalls;

    TimerEvent event = cast(TimerEvent)e;

    if (ncalls == 0) {
      //assert(event.source == &huge_timer1); // TODO: opEquals in Timer
    }
    else {
      //assert(event.source == &tiny_timer); // TODO: opEquals in Timer
    }

    if (++ncalls == 10) {
      destroy(tiny_timer);
      destroy(huge_timer1);
    }
  }

// ================================
//      Tests
// ================================

  {
    writefln("Test: timer");

    Timer[10] once_timers;
    auto repeat = new Timer();
    auto never  = new Timer();
    uint i;

    start_time = uv_now(uv_default_loop());
    assert(0 < start_time);

    /* Let 10 timers time out in 500 ms total. */
    for (i = 0; i < once_timers.length; i++) {
      auto t = new Timer();
      t.on(TimerEvent.TIMEOUT, &once_cb);
      t.start(i * 50);
      once_timers[i] = t;
    }

    /* The 11th timer is a repeating timer that runs 4 times */
    repeat.on(TimerEvent.TIMEOUT, &repeat_cb);
    repeat.start(100, 100);

    /* The 12th timer should not do anything. */
    never.on(TimerEvent.TIMEOUT, &never_cb);
    never.start(100, 100);
    never.stop();
    destroy(never);

    DefaultLoop.run();

    assert(once_cb_called == 10);
    writefln("repeat_cb_called %d\n", repeat_cb_called);
    assert(repeat_cb_called == 5);

    assert(500 <= uv_now(uv_default_loop()) - start_time);
  }

// FIXME: add setTimeout, clearTimeout.
  //{
  //  writefln("Test: timer_start_twice");
  //  auto once = new Timer();

  //  once_cb_called = 0;

  //  once.on(TimerEvent.TIMEOUT, &never_cb)
  //  r = uv_timer_start(&once, never_cb, 86400 * 1000, 0);
  //  ASSERT(r == 0);
  //  r = uv_timer_start(&once, once_cb, 10, 0);
  //  ASSERT(r == 0);
  //  r = uv_run(uv_default_loop(), UV_RUN_DEFAULT);
  //  ASSERT(r == 0);

  //  ASSERT(once_cb_called == 1);

  //  MAKE_VALGRIND_HAPPY();
  //  return 0;
  //}

  {
    writefln("Test: timer_init");
    auto timer = new Timer();

    assert(timer.repeat == 0);
    assert(!timer.isActive());
  }

  {
    writefln("Test: timer_order");
    int first  = 0;
    int second = 1;
    auto timer_a = new Timer();
    auto timer_b = new Timer();

    void order_cb_a(in Event e) {
      assert(order_cb_called++ == first);
    }


    void order_cb_b(in Event e) {
      assert(order_cb_called++ == second);
    }

    timer_a.on(TimerEvent.TIMEOUT, &order_cb_a);
    timer_b.on(TimerEvent.TIMEOUT, &order_cb_b);

    /* Test for starting handle_a then handle_b */
    timer_a.start(0);
    timer_b.start(0);
    assert(0 == DefaultLoop.run());

    assert(order_cb_called == 2);

    timer_a.stop();
    timer_b.stop();

    /* Test for starting handle_b then handle_a */
    order_cb_called = 0;
    first  = 1;
    second = 0;
    timer_b.start(0);
    timer_a.start(0);
    assert(0 == DefaultLoop.run());

    assert(order_cb_called == 2);
  }

  {
    writefln("Test: timer_huge_timeout");
    tiny_timer  = new Timer();
    huge_timer1 = new Timer();
    huge_timer2 = new Timer();  

    tiny_timer.on(TimerEvent.TIMEOUT, &tiny_timer_cb);
    huge_timer1.on(TimerEvent.TIMEOUT, &tiny_timer_cb);
    huge_timer2.on(TimerEvent.TIMEOUT, &tiny_timer_cb);

    tiny_timer.start(1);
    huge_timer1.start(0xffff_ffff_ffff_ffffL);
    huge_timer2.start(cast(uint64_t)-1);

    assert(0 == DefaultLoop.run());
  }

  {
    writefln("Test: timer_huge_repeat");
    tiny_timer  = new Timer();
    huge_timer1 = new Timer();

    tiny_timer.on(TimerEvent.TIMEOUT, &huge_repeat_cb);
    huge_timer1.on(TimerEvent.TIMEOUT, &huge_repeat_cb);

    tiny_timer.start(2, 2);
    huge_timer1.start(1, cast(uint64_t)-1);

    assert(0 == DefaultLoop.run());
  }

  {
    writefln("Test: timer_run_once");
    int timer_run_once_timer_cb_called;
    auto timer = new Timer;
    timer.on(TimerEvent.TIMEOUT, (in Event e)
    {
      timer_run_once_timer_cb_called++;
    });

    timer.start(0);
    DefaultLoop.run(Loop.RUN_ONCE_MODE);
    assert(1 == timer_run_once_timer_cb_called);

    timer.start(1);
    DefaultLoop.run(Loop.RUN_ONCE_MODE);
    assert(2 == timer_run_once_timer_cb_called);

    destroy(timer);

    assert(0 == DefaultLoop.run(Loop.RUN_ONCE_MODE));
  }
}

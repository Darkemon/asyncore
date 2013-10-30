import asyncore.core;
import asyncore.timer;

import std.stdio;

void main()
{
  // Segmentation fault occurs in following case. Why!?
  //Timer t;
  //t.on(t.on(TimerEvent.TIMEOUT, (in Event event) {
  //  TimerEvent e = cast(TimerEvent)event;
  //  writefln("timeout!");
  //});

  int NUM_TIMERS   = 1000000;
  int timeout      = 0;
  int timeoutCalls = 0;
  uint64_t before, after;
  Timer[] timers;

  void timeoutListener(in Event event) {
    timeoutCalls++;
  };

  for (int i = 0; i < NUM_TIMERS; i++) {
    if (i % 1000 == 0)
      timeout++;

    auto t = new Timer();
    t.on(TimerEvent.TIMEOUT, &timeoutListener);
    t.start(timeout);
    timers ~= t;
  }

  before = uv_hrtime();
  DefaultLoop.run();
  after = uv_hrtime();

  assert(timeoutCalls == NUM_TIMERS);

  writefln("%.2f seconds\n", (after - before) / 1e9);
}

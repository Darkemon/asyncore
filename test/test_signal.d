import asyncore.core;
import asyncore.signal;
import asyncore.timer;

import std.stdio;
import core.sys.posix.signal;

static int[2] timer_ncalls;
static int[4] signal_ncalls;

enum { CLOSE, STOP };

class MyTimer : Timer {
  public:
    uint ncalls;
    int  signum;
    int  id;

    this(int idN) { 
      super();
      id = idN;
    }
}

class MySignal : Signal {
  public:
    int  stop_or_close;
    uint ncalls;
    int  signum;
    int  id;

    this(int idN) {
      super();
      id = idN;
    }
}

void main()
{
  immutable int NSIGNALS = 10;

  void start_timer(MyTimer timer, int signum)
  {
    timer_ncalls[timer.id] = 0;
    timer.signum = signum;

    timer.on(TimerEvent.TIMEOUT, (in Event e)
    {
      auto ev = cast(TimerEvent)e;
      auto t = cast(MyTimer)ev.source;
      raise(t.signum);

      if (++timer_ncalls[t.id] == NSIGNALS)
        destroy(t);
    });

    timer.start(5, 5);
  }

  void start_watcher(MySignal signal, int signum)
  {
    signal_ncalls[signal.id] = 0;
    signal.signum = signum;
    signal.stop_or_close = CLOSE;

    signal.on(SignalEvent.SIGNAL, (in Event e)
    {
      auto ev = cast(SignalEvent)e;
      auto s = cast(MySignal)ev.source;
      assert(ev.signum == s.signum);

      if (++signal_ncalls[s.id] == NSIGNALS)
      {
        if (s.stop_or_close == STOP)
          s.unwatch();
        else if (s.stop_or_close == CLOSE)
          destroy(s);
        else
          assert(false);
      }
    });

    signal.watch(signum);
  }

// ================================
//      Tests
// ================================

  {
    write("Test: we_get_signal ... ");

    auto timer  = new MyTimer(0);
    auto signal = new MySignal(0);

    start_timer(timer, SIGCHLD);
    start_watcher(signal, SIGCHLD);
    signal.stop_or_close = STOP; /* stop, don't close the signal handle */
    assert(0 == DefaultLoop.run());
    assert(timer_ncalls[0] == NSIGNALS);
    assert(signal_ncalls[0] == NSIGNALS);

    timer = new MyTimer(0);

    start_timer(timer, SIGCHLD);
    assert(0 == DefaultLoop.run());
    assert(timer_ncalls[0] == NSIGNALS);
    assert(signal_ncalls[0] == NSIGNALS);

    signal_ncalls[0] = 0;
    signal.stop_or_close = CLOSE; /* now close it when it's done */
    signal.watch(SIGCHLD);

    timer = new MyTimer(0);

    start_timer(timer, SIGCHLD);
    assert(0 == DefaultLoop.run());
    assert(timer_ncalls[0] == NSIGNALS);
    assert(signal_ncalls[0] == NSIGNALS);

    writefln("OK");
  }

  {
    write("Test: we_get_signals ... ");
    uint i;

    MyTimer[2]  timers;
    MySignal[4] signals;

    for (i=0; i<4; i++)
      signals[i] = new MySignal(i);

    for (i=0; i<2; i++)
      timers[i] = new MyTimer(i);
    

    start_watcher(signals[0], SIGUSR1);
    start_watcher(signals[1], SIGUSR1);
    start_watcher(signals[2], SIGUSR2);
    start_watcher(signals[3], SIGUSR2);
    start_timer(timers[0], SIGUSR1);
    start_timer(timers[1], SIGUSR2);
    assert(0 == DefaultLoop.run());

    for (i=0; i<4; i++)
      assert(signal_ncalls[i] == NSIGNALS);

    for (i=0; i<2; i++)
      assert(timer_ncalls[i] == NSIGNALS);

    writefln("OK");
  }
}

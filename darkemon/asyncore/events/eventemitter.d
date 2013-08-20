/**
 * Event machine like EventDispatcher in ActionScript 3.0
 * and EventEmitter in NodeJS.
 * 
 * License: GNU GPL v2 (http://www.gnu.org/)
 * Author:  Artyom Krasotin
 *
 */

module darkemon.asyncore.events.eventemitter;

private import std.algorithm;

class Event {
  public:
    this(int eventId) {
      _id = eventId;
    }

    @property pure nothrow 
    int id() const { return _id; }

  private:
    int _id;
}

interface IEventEmitter {
  alias void delegate(in Event event) listener_t;

  alias on = addListener;
  void addListener(int eventId, in listener_t listener);
  void removeListener(int eventId, in listener_t listener);
  void removeAllListeners(int eventId);
  void emit(in Event event);
}

class EventEmitter : IEventEmitter 
{
  public:
    nothrow
    void addListener(int eventId, in listener_t listener)
    {
      if (!(eventId in _listeners))
        _listeners[eventId] = [listener];
      else
        _listeners[eventId] ~= [listener];
    }

    void removeListener(int eventId, in listener_t listener)
    {
      if (eventId in _listeners)
      {
        auto listenerList = _listeners[eventId];
        for (int i=0; i < listenerList.length;)
        {
          if (listenerList[i] && listenerList[i] == listener)
            listenerList = listenerList.remove(i);
          else
            ++i;
        }
        
        if (listenerList.length == 0)
          _listeners[eventId] = null;
        else
          _listeners[eventId] = listenerList;

        _listeners.rehash();
      }
    }

    void removeAllListeners(int eventId)
    {
      if (eventId in _listeners)
      {
        _listeners.remove(eventId);
        _listeners.rehash();
      }
    }

    
    void removeAllListeners()
    {
      _listeners.clear();
    }

    void emit(in Event event)
    {
      int eventId = event.id;
      if (eventId in _listeners) {
        auto listenerList = _listeners[eventId];
        foreach (listener; listenerList)
        {
          if (listener)
            listener(event);
        }
      }
    }

  private:
    listener_t[][int] _listeners;
}



unittest {
  import std.stdio;

  bool test1 = false, test2 = false, test3 = false, test4 = false;

  class MyEvent : Event {
    public:
      static immutable int EVENT_1 = 1;
      static immutable int EVENT_2 = 2;

      this(int eventId) {
        super(eventId);
      }
  }

  void eventListener1(in Event event) {
    MyEvent e = cast(MyEvent)event;

    switch (e.id)
    {
      case MyEvent.EVENT_1:
        writefln("  eventListener1: got event MyEvent.EVENT_1");
        test1 = true;
        break;
      case MyEvent.EVENT_2:
        writefln("  eventListener1: got event MyEvent.EVENT_2");
        test2 = true;
        break;
      default:;
    }
  }

  void eventListener2(in Event event) {
    MyEvent e = cast(MyEvent)event;

    switch (e.id)
    {
      case MyEvent.EVENT_1:
        writefln("  eventListener2: got event MyEvent.EVENT_1");
        test3 = true;
        break;
      default:;
    }
  }

  void eventListener3(in Event event) {
    MyEvent e = cast(MyEvent)event;

    switch (e.id)
    {
      case MyEvent.EVENT_1:
        writefln("  eventListener3: got event MyEvent.EVENT_1");
        test4 = true;
        break;
      default:;
    }
  }

  auto evEmitter = new EventEmitter;
  auto e1        = new MyEvent(MyEvent.EVENT_1);
  auto e2        = new MyEvent(MyEvent.EVENT_2);

  writefln("# add listener 'eventListener1' on event MyEvent.EVENT_1");
  evEmitter.on(MyEvent.EVENT_1, &eventListener1);
  writefln("# add listener 'eventListener1' on event MyEvent.EVENT_2");
  evEmitter.addListener(MyEvent.EVENT_2, &eventListener1);
  writefln("# add listener 'eventListener2' on event MyEvent.EVENT_1");
  evEmitter.addListener(MyEvent.EVENT_1, &eventListener2);
  writefln("# add listener 'eventListener3' on event MyEvent.EVENT_1");
  evEmitter.addListener(MyEvent.EVENT_1, &eventListener3);  

  writefln("");
  writefln("# emit MyEvent.EVENT_1");
  evEmitter.emit(e1);
  writefln("");
  writefln("# emit MyEvent.EVENT_2");
  evEmitter.emit(e2);

  assert(test1 == true);
  assert(test2 == true);
  assert(test3 == true);
  assert(test4 == true);

  test1 = test2 = test3 = test4 = false;
  writefln("");
  writefln("# remove listener 'eventListener2' for event MyEvent.EVENT_1");
  evEmitter.removeListener(MyEvent.EVENT_1, &eventListener2);

  writefln("");
  writefln("# emit MyEvent.EVENT_1");
  evEmitter.emit(e1);
  writefln("");
  writefln("# emit MyEvent.EVENT_2");
  evEmitter.emit(e2);

  assert(test1 == true);
  assert(test2 == true);
  assert(test3 == false);
  assert(test4 == true);

  test1 = test2 = test3 = test4 = false;
  writefln("");
  writefln("# remove all listeners for event MyEvent.EVENT_1");
  evEmitter.removeAllListeners(MyEvent.EVENT_1);

  writefln("");
  writefln("# emit MyEvent.EVENT_1");
  evEmitter.emit(e1);
  writefln("");
  writefln("# emit MyEvent.EVENT_2");
  evEmitter.emit(e2);

  assert(test1 == false);
  assert(test2 == true);
  assert(test3 == false);
  assert(test4 == false);

  test1 = test2 = test3 = test4 = false;
  writefln("");
  writefln("# remove all listeners");
  evEmitter.removeAllListeners();

  writefln("");
  writefln("# emit MyEvent.EVENT_1");
  evEmitter.emit(e1);
  writefln("");
  writefln("# emit MyEvent.EVENT_2");
  evEmitter.emit(e2);

  assert(test1 == false);
  assert(test2 == false);
  assert(test3 == false);
  assert(test4 == false);

  writefln("\n===== SUCCESS! =====\n");
}


unittest {
  import std.stdio;

  class KickEvent : Event 
  {
    static immutable int KICK = 0;

    this(int eventId) {
      super(eventId);
    }
  }

  class BadGuy
  {
    public:
      void ass(in Event e) {
        assert(_isAlive == true);

        writefln("bad guy: \"oh my ass, i'm dying...\"");
        _isAlive = false;
      }

    private:
      bool _isAlive = true;
  }

  class SuperHero : EventEmitter
  {
    public:
      void doKick() {
        auto e = new KickEvent(KickEvent.KICK);
        emit(e);
      }
  }

  auto badGuy = new BadGuy;
  auto hero   = new SuperHero;

  hero.on(KickEvent.KICK, &badGuy.ass);

  writefln("SuperHero kicks a bad guy!");
  hero.doKick();

  // This does not work, we can't trace when listener is destroyed.

  //writefln("... and bad guy is died ...");
  //destroy(badGuy);
  //writefln("BUT our hero kicks a bad guy again!");
  //hero.doKick();
  //writefln("... and nothing");
}

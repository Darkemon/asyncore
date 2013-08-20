module darkemon.asyncore.select;

public  import core.sys.linux.epoll;
public  import core.stdc.errno;
private import core.sys.posix.unistd;

class EpollException : Exception
{
  public:
    enum : int {
      Create,
      Ctl,
      Wait
    }

    this(int type, int errno, string file = __FILE__, 
      size_t line = __LINE__, Throwable next = null ) @safe pure nothrow
    {
      _type  = type,
      _errno = errno;
      super(_getMsg(), file, line, next);
    }

    @property int type() const {
      return _type;
    }
    
    @property int errno() const {
      return _errno;
    }

  private:
    int _type;
    int _errno;  

    @safe
    string _getMsg() nothrow pure
    {
      final switch (_errno) {
        string msg = null;
        case EBADF:
          if (_type == EpollException.Create)
            msg = "epfd or fd is not a valid file descriptor";
          else if (_type == EpollException.Wait)
            msg = "epfd is not a valid file descriptor";
          break;

        case EEXIST:
          if (_type == EpollException.Create)
            msg = "op was EPOLL_CTL_ADD, and the supplied file descriptor fd "
              "is already registered with this epoll instance";
          break;

        case EINVAL:
          if (_type == EpollException.Create)
            msg = "size is not positive";
          else if (_type == EpollException.Ctl)
            msg = "epfd is not an epoll file descriptor, or fd is the same as "
              "epfd, or the requested operation op is not supported by this "
              "interface";
          else if (_type == EpollException.Wait)
            msg = "epfd is not an epoll file descriptor, or maxevents is less "
              "than or equal to zero";
          break;

        case EMFILE:
          if (_type == EpollException.Create)
            msg = "the per-user limit on the number of epoll instances imposed "
              "by /proc/sys/fs/epoll/max_user_instances was encountered";
          break;

        case ENFILE:
          if (_type == EpollException.Create)
            msg = "the system limit on the total number of open files has "
              "been reached";
          break;

        case ENOMEM:
          if (_type == EpollException.Create)
            msg = "there was insufficient memory to create the kernel object";
          else if (_type == EpollException.Ctl)
            msg = "there was insufficient memory to handle the requested op "
              "control operation";
          break;

        case ENOENT:
          if (_type == EpollException.Create)
            msg = "op was EPOLL_CTL_MOD or EPOLL_CTL_DEL, and fd is not "
              "registered with this epoll instance";
          break;

        case ENOSPC:
          if (_type == EpollException.Create)
            msg = "the limit imposed by /proc/sys/fs/epoll/max_user_watches "
              "was encountered while trying to register (EPOLL_CTL_ADD) a new "
              "file descriptor on an epoll instance";
          break;

        case EPERM:
          if (_type == EpollException.Create)
            msg = "the target file fd does not support epoll";
          break;

        case EFAULT:
          if (_type == EpollException.Create)
            msg = "the memory area pointed to by events is not accessible "
              "with write permissions";
          break;

        case EINTR:
          if (_type == EpollException.Create)
            msg = "the call was interrupted by a signal handler before either "
              "any of the requested events occurred or the timeout expired";
            break;
      }         

      if (!msg)
        msg = "unknown error";

      return msg;
    }
}

class Epoll {
  public:
    /** 
      * @param int maxevents
      *
      * @param int size
      *   It informed the kernel of the number of file descriptors that the 
      *   caller expected to add to the epoll instance. Since Linux 2.6.8, 
      *   the size argument is ignored, but must be greater than zero.
      */
    this(int maxevents = 1024, int size = 1)
    {
      _maxevents = maxevents;
      _events = new epoll_event[_maxevents];
      _epollFd = epoll_create(size);

      if (_epollFd < 0)
        throw new EpollException(EpollException.Create, errno());
    }

    ~this() {
      close(_epollFd);
      destroy(_events);
    }

    @property int maxevents() const {
      return _maxevents;
    }

    void register(int fd, int eventmask)
    {
      _event.events  = eventmask;
      _event.data.fd = fd;

      if (epoll_ctl(_epollFd, EPOLL_CTL_ADD, fd, &_event) < 0)
        throw new EpollException(EpollException.Ctl, errno());
    }

    void unregister(int fd)
    {
      if (epoll_ctl(_epollFd, EPOLL_CTL_DEL, fd, null) < 0)
        throw new EpollException(EpollException.Ctl, errno());
    }

    void modify(int fd, int eventmask)
    {
      _event.events  = eventmask;
      _event.data.fd = fd;

      if (epoll_ctl(_epollFd, EPOLL_CTL_MOD, fd, &_event) < 0)
        throw new EpollException(EpollException.Ctl, errno());
    }

    const(epoll_event)[] poll(int timeout = -1) {
      int nEvents = epoll_wait(_epollFd, _events.ptr, _maxevents, timeout);

      if (nEvents < 0)
        throw new EpollException(EpollException.Wait, errno());

      return _events[0..nEvents];
    }

  private:
    int           _epollFd;
    int           _maxevents;
    epoll_event[] _events;
    epoll_event   _event;
}

unittest {
  import std.socket;
  import std.stdio;

  Epoll  epoll    = new Epoll;
  Socket listener = new TcpSocket;
  Socket[int] connections;
  int nEvents = 0;

  listener.blocking = false;
  listener.bind(new InternetAddress("127.0.0.1", 8111));
  listener.listen(10);

  writefln("listening on port 8111");

  epoll.register(cast(int)listener.handle, EPOLLIN|EPOLLET);

  while (true) {
    auto events = epoll.poll(1);

    foreach (e; events)
    {
      if (e.data.fd == cast(int)listener.handle)
      {
        Socket s;

        while (true) {
          try {
            s = listener.accept();
          }
          catch (Exception e) {
            //writefln("error accepting: %s", e.toString());
            if (s)
              s.close();
            break;
          }

          if (nEvents < epoll.maxevents)
          {
            writefln("connection from %s established", 
              s.remoteAddress().toString());

            s.blocking = false;

            epoll.register(cast(int)s.handle, EPOLLIN|EPOLLOUT|EPOLLET);
            connections[cast(int)s.handle] = s;
            s = null;
            ++nEvents;
          } 
          else
          {
            writefln("rejected connection from %s; too many connections", 
              s.remoteAddress().toString());
            s.close();
          }
        }
      }
      else
      {
        if (e.events & EPOLLIN) {
          char[1024] buf;
          int read = connections[e.data.fd].receive(buf);
          if (read == 0)
            goto SOCK_DOWN;
          else if (read > 0)
            writefln("received %d bytes from %s: \"%s\"", read, 
              connections[e.data.fd].remoteAddress().toString(), 
              buf[0 .. read]);
        }
        else if (e.events & EPOLLOUT) {
        }
        else if (e.events & EPOLLERR) {
        }
        else if (e.events & EPOLLHUP) {
SOCK_DOWN:          
          writefln("connection from %s closed", 
            connections[e.data.fd].remoteAddress().toString());
          epoll.unregister(e.data.fd);
          connections[e.data.fd].close();
          connections.remove(e.data.fd);
          --nEvents;
        }
      }
    }
  }

  writefln("close listener");
  listener.close();
}
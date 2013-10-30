module asyncore.net.socket;

private import std.string;
private import asyncore.core;
private import asyncore.events.eventemitter : EventEmitter, Event;

import std.stdio;

class TcpSocket : EventEmitter 
{
  public:
    this()
		{
      _init();
		}

		~this()
		{
			removeAllListeners();

      if (_isConnected)
        uv_close(_socketPtr, null); // stops polling and closes socket immediately

      asyncore_set_handle_data(_socketPtr, null);
      asyncore_free(_socketPtr);

      _uninit();
		}

		/**
		 * Opens the connection for a given socket. If port and host are given, 
		 * then the socket will be opened as a TCP socket, if host is omitted, 
		 * localhost will be assumed.
		 */
		void connect(uint port, string host = "127.0.0.1")
    {
		  // C code may uses this pointer in any time, therefore we save reference
      // to this pointer, so GC did not collect it. 
      _dstHost = toStringz(host);

      _dstAddrPtr = asyncore_new_uv_ip4_addr(_dstHost, port);
      _connectPtr = asyncore_new_connect();

      int r;
      
      r = uv_tcp_init(_loopPtr, _socketPtr);
      if (r != 0) {
        _uninit();
        _emitError();
        return;
      }

      asyncore_set_request_data(_connectPtr, cast(void*)this); // keep pointer to this
      r = asyncore_tcp_connect(_connectPtr, _socketPtr, _dstAddrPtr, 
        &_onConnect);
      if (r != 0) {
        _uninit();
        _emitError();
      }
		}

		void write(char[] data)
    {
      uv_write_t_ptr writeReqPtr = asyncore_new_write();
      asyncore_set_request_data(writeReqPtr, cast(void*)this); // keep pointer to this

      // TODO: queue data in user memory

      write_req_t writeRequest;
      writeRequest.req      = writeReqPtr;
      writeRequest.buf.base = data.ptr;
      writeRequest.buf.len  = data.length;

      // XXX: need hold char[] data?

      if (uv_write(writeRequest.req, _socketPtr, &(writeRequest.buf), 1, 
                   &_onWrite))
      {
        asyncore_set_request_data(writeReqPtr, null);
        asyncore_free(writeReqPtr);
        writeRequest.buf.base = null;
        _emitError();
        uv_close(_socketPtr, &_onClose);
      }
      else {
        _writeReqs[cast(ssize_t)writeReqPtr] = writeRequest;
      }
    }

		void end(string data) {
      // TODO: make write
      // TODO: make shutdown
    }

		void end() {
      // TODO: make shutdown
    }

		void destroy() {
      emit(new SocketEvent(SocketEvent.CLOSE));
      uv_close(_socketPtr, &_onClose);  
    }

  private:
		uv_loop_t_ptr        _loopPtr;
		uv_tcp_t_ptr         _socketPtr;   // must free on destroy
		uv_connect_t_ptr     _connectPtr;  // must free on destroy
    sockaddr_in_ptr      _dstAddrPtr;  // IPv4, must free on destroy
    immutable(char)     *_dstHost;     // for memory safe, under GC
    bool                 _isConnected = false;
    write_req_t[ssize_t] _writeReqs;   // associative array, where: key - pointer
                                       // uv_write_t_ptr, value - struct 
                                       // write_req_t

		void _init() {
		  _loopPtr   = uv_default_loop();
      _socketPtr = asyncore_new_tcp();
		}

    void _uninit() {
      _isConnected = false;

      if (_writeReqs.length != 0) {
        foreach(wrReq; _writeReqs.byValue()) {
          asyncore_free(wrReq.req);
        }
        _writeReqs.clear();
      }

      if (_connectPtr) {
        asyncore_set_request_data(_connectPtr, null);
        asyncore_free(_connectPtr);
        _connectPtr = null;
      }

      if (_dstAddrPtr) {
        asyncore_free(_dstAddrPtr);
        _dstAddrPtr = null;
      }
    }

    void _emitError() {
      uv_err_t error = uv_last_error(uv_default_loop());
      auto e = new SocketEvent(SocketEvent.ERROR, asyncore_strerror(error));
      emit(e);
    }

    extern (C) 
    {
      static void _onConnect(uv_connect_t_ptr connPtr, int status)
      {
        TcpSocket self = cast(TcpSocket)asyncore_get_request_data(connPtr);

        // Keep pointer to owner class.
        asyncore_set_handle_data(self._socketPtr, cast(void*)self);

        if (status != 0) {
          self._emitError();
          uv_close(self._socketPtr, &self._onClose);      
          return;
        }

        self._isConnected = true;
        self.emit(new SocketEvent(SocketEvent.CONNECT));

        // Start reading.
        int r = uv_read_start(self._socketPtr, &asyncore_alloc_callback, 
          &self._onRead);

        if (r != 0) {
          self._emitError();
          uv_close(self._socketPtr, &self._onClose);      
          return;  
        }
      }

      static void _onClose(uv_handle_t_ptr handle)
      {
        TcpSocket self = cast(TcpSocket)asyncore_get_handle_data(handle);
        self._uninit();
      }

      static void _onRead(uv_stream_t_ptr handle, ssize_t nread, uv_buf_t buf)
      {
        TcpSocket self = cast(TcpSocket)asyncore_get_handle_data(handle);

        if (nread < 0) {
          if (buf.base)
            buf.free();

          if (nread == UV_EOF)
            self.emit(new SocketEvent(SocketEvent.CLOSE));
          else
            self._emitError();

          uv_close(self._socketPtr, &self._onClose);
          return;
        }

        if (nread == 0) {
          /* Everything OK, but nothing read. */
          buf.free();
          return;
        }

        auto e = new SocketEvent(SocketEvent.DATA, null, buf.base[0..nread]);
        self.emit(e);
        buf.free();
      }

      static void _onWrite(uv_write_t_ptr req, int status)
      {
        TcpSocket self = cast(TcpSocket)asyncore_get_request_data(req);

        self._writeReqs.remove(cast(ssize_t)req);
        asyncore_set_request_data(req, null);
        asyncore_free(req);

        if (status != 0) {
          self._emitError();
          uv_close(self._socketPtr, &self._onClose);
        }
      }
    }
}



class SocketEvent : Event
{
  public:
    static immutable int CONNECT = 0;
    static immutable int DATA    = 1;
    static immutable int ERROR   = 2;
    static immutable int CLOSE   = 3;

    this(int eventId, string msg=null, char[] data=null) { 
      super(eventId);
      _msg  = msg;
      _data = data;
    }

    @property const string message() { return _msg; }
    @property const(char)[] data() { return _data; }

  private:
    string _msg;
    char[] _data;
}

module deimos.uv_private.unix;

import deimos.uv;

import core.stdc.stdint;
import core.sys.posix.pthread;
import core.sys.posix.semaphore;
import core.sys.posix.netinet.in_;
import core.sys.posix.termios;


extern(C):

version(OSX) {
	alias semaphore_t UV_PLATFORM_SEM_T;
} else  {
	alias sem_t UV_PLATFORM_SEM_T;
}

alias void function (uv_loop_t* loop, uv__io_t* w, uint events) uv__io_cb;

struct uv__io_t {
	uv__io_cb cb;
	void* pending_queue[2];
	void* watcher_queue[2];
	uint pevents; /* Pending event mask i.e. mask at next tick. */
	uint events;  /* Current event mask. */
	int fd;
	//mixin UV_IO_PRIVATE_FIELDS;UV_IO_PRIVATE_PLATFORM_FIELDS;
	version(BSD) {
		int rcount;
		int wcount;
	} else version(OSX) {
		int rcount;
		int wcount;
	}

};

alias void function(uv_loop_t* loop, uv__async* w, uint nevents) uv__async_cb;

struct uv__async {
	uv__async_cb cb;
	uv__io_t io_watcher;
	int wfd;
};

struct uv__work {
	void function (uv__work *w) work;
	void function (uv__work *w, int status) done;
	uv_loop_t* loop;
	void* wq[2];
};


/* Note: May be cast to struct iovec. See writev(2). */
struct uv_buf_t {
	char* base;
	size_t len;
};

alias int uv_file;
alias int uv_os_sock_t;

alias PTHREAD_ONCE_INIT UV_ONCE_INIT;

alias pthread_once_t uv_once_t;
alias pthread_t uv_thread_t;
alias pthread_mutex_t uv_mutex_t;
alias pthread_rwlock_t uv_rwlock_t;
alias UV_PLATFORM_SEM_T uv_sem_t;
alias pthread_cond_t uv_cond_t;


version(OSX) { /* defined(__APPLE__) && defined(__MACH__) */
	struct uv_barrier_t{
	uint n;
	uint count;
	uv_mutex_t mutex;
	uv_sem_t turnstile1;
	uv_sem_t turnstile2;
	};
}else{ 
	alias pthread_barrier_t uv_barrier_t;
} 

/* Platform-specific definitions for uv_spawn support. */
alias gid_t uv_gid_t;
alias uid_t uv_uid_t;

/* Platform-specific definitions for uv_dlopen support. */
//TODO? #define UV_DYNAMIC /* empty */

struct uv_lib_t {
	void* handle;
	char* errmsg;
};

template UV_LOOP_PRIVATE_FIELDS() {
	ulong flags;
	int backend_fd;                                                        
	void* pending_queue[2];
	void* watcher_queue[2];
	uv__io_t** watchers;                                                      
	uint nwatchers;
	uint nfds;                                                         
	void* wq[2];                                                              
	uv_mutex_t wq_mutex;                                                      
	uv_async_t wq_async;
	uv_handle_t* closing_handles;
	void* process_handles[1][2];
	void* prepare_handles[2];
	void* check_handles[2];
	void* idle_handles[2];
	void* async_handles[2];
	uv__async async_watcher;
	/* RB_HEAD(uv__timers, uv_timer_s) */
	struct uv__timers_t {
		uv_timer_t* rbh_root;
	};
	uv__timers_t timer_handles;           
	uint64_t time;                                                             
	int signal_pipefd[2];
	uv__io_t signal_io_watcher;
	uv_signal_t child_watcher;
	int emfile_fd;                                                         
	uint64_t timer_counter;
	//mixin UV_PLATFORM_LOOP_FIELDS;
	version(linux) {
		uv__io_t inotify_read_watcher;
		void* inotify_watchers;
		int inotify_fd;
	} else version(OSX) {
		uv_thread_t cf_thread;
		void* cf_cb;
		void* cf_loop;
		uv_mutex_t cf_mutex;
		uv_sem_t cf_sem;
		void* cf_signals[2];            
	} else version(SUN) {
		uv__io_t fs_event_watcher; 
		int fs_fd;
	}

}

template UV_REQ_TYPE_PRIVATE(){}

template UV_REQ_PRIVATE_FIELDS(){}

template UV_PRIVATE_REQ_TYPES(){}

template UV_WRITE_PRIVATE_FIELDS() {
	void* queue[2];
	int write_index;
	uv_buf_t* bufs;
	int bufcnt;                                                               
	int error;                                                                 
	uv_buf_t bufsml[4];
}

template UV_CONNECT_PRIVATE_FIELDS() {
	void* queue[2];
}

template UV_SHUTDOWN_PRIVATE_FIELDS() {}

template UV_UDP_SEND_PRIVATE_FIELDS() {
	void* queue[2];
	sockaddr_in6 addr;
	int bufcnt;                                                               
	uv_buf_t* bufs;
	ssize_t status;
	uv_udp_send_cb send_cb;
	uv_buf_t bufsml[4];
}

template UV_HANDLE_PRIVATE_FIELDS() {
	int flags;
	uv_handle_t* next_closing;
}

template UV_STREAM_PRIVATE_FIELDS() {
	uv_connect_t *connect_req;
	uv_shutdown_t *shutdown_req;
	uv__io_t io_watcher;
	void* write_queue[2];
	void* write_completed_queue[2];
	uv_connection_cb connection_cb;
	int delayed_error;
	int accepted_fd;
	//UV_STREAM_PRIVATE_PLATFORM_FIELDS;
	version(OSX) {
		void* select;
	}
}

template UV_TCP_PRIVATE_FIELDS(){}

template UV_UDP_PRIVATE_FIELDS() {
	uv_alloc_cb alloc_cb;
	uv_udp_recv_cb recv_cb;
	uv__io_t io_watcher;
	void* write_queue[2];
	void* write_completed_queue[2];
}

template UV_PIPE_PRIVATE_FIELDS() {
	const char* pipe_fname; /* strdup'ed */
}

template UV_POLL_PRIVATE_FIELDS() {
	uv__io_t io_watcher;
}

template UV_PREPARE_PRIVATE_FIELDS() {
	uv_prepare_cb prepare_cb;
	void* queue[2];
}

template UV_CHECK_PRIVATE_FIELDS() {
	uv_check_cb check_cb;
	void* queue[2];
}

template UV_IDLE_PRIVATE_FIELDS() {
	uv_idle_cb idle_cb;
	void* queue[2];
}

template UV_ASYNC_PRIVATE_FIELDS() {
	uv_async_cb async_cb;
	void* queue[2];
	int pending;
}

template UV_TIMER_PRIVATE_FIELDS() {
	/* RB_ENTRY(uv_timer_s) tree_entry; */
	struct tree_entry_t{
		uv_timer_t* rbe_left;
		uv_timer_t* rbe_right;
		uv_timer_t* rbe_parent;
		int rbe_color;
	};
	tree_entry_t tree_entry;
	uv_timer_cb timer_cb;
	uint64_t timeout;
	uint64_t repeat;
	uint64_t start_id;
}

template UV_GETADDRINFO_PRIVATE_FIELDS() {
	uv__work work_req;
	uv_getaddrinfo_cb cb;
	addrinfo* hints;
	char* hostname;
	char* service;
	addrinfo* res;
	int retcode;
}

template UV_PROCESS_PRIVATE_FIELDS() {
	void* queue[2];
	int errorno;
}

template UV_FS_PRIVATE_FIELDS() {
	const char *new_path;
	uv_file file;
	int flags;
	mode_t mode;
	void* buf;
	size_t len;
	off_t off;
	uid_t uid;
	gid_t gid;
	double atime;
	double mtime;
	uv__work work_req;
}

template UV_WORK_PRIVATE_FIELDS() {
	uv__work work_req;
}

template UV_TTY_PRIVATE_FIELDS() {
	core.sys.posix.termios.termios orig_termios;
	int mode;
}

template UV_SIGNAL_PRIVATE_FIELDS() {
	/* RB_ENTRY(uv_signal_s) tree_entry; */
	struct tree_entry_t{  
		uv_signal_t* rbe_left;
		uv_signal_t* rbe_right;
		uv_signal_t* rbe_parent;
		int rbe_color;
	};
	tree_entry_t tree_entry;
	/* Use two counters here so we don have to fiddle with atomics. */
	uint caught_signals;
	uint dispatched_signals;
}

template UV_FS_EVENT_PRIVATE_FIELDS() {
	uv_fs_event_cb cb;
	//mixin UV_PLATFORM_FS_EVENT_FIELDS;
	version(linux) {
		void* watchers[2];
		int wd;
	} else version(BSD) {
		uv__io_t event_watcher;
	} else version(OSX) {
		uv__io_t event_watcher;
		char* realpath;
		int realpath_len;
		int cf_flags;
		void* cf_eventstream;
		uv_async_t* cf_cb;
		void* cf_events[2];
		uv_sem_t cf_sem;
		uv_mutex_t cf_mutex;
	} else version(SUN) {
		file_obj_t fo;
		int fd;   
	}
}

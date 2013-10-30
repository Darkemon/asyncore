module deimos.uv_private.linux;

import core.sys.posix.semaphore;
import deimos.uv_private.unix;


template UV_PLATFORM_LOOP_FIELDS() {
	uv__io_t inotify_read_watcher;
	void* inotify_watchers;
	int inotify_fd;
};

template UV_PLATFORM_FS_EVENT_FIELDS() {
	void* watchers[2];
	int wd;
};


alias sem_t UV_PLATFORM_SEM_T;
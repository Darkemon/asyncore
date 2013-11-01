test:
	mkdir -p out/test
	dmd -ofout/test/benchmark_million_timers -Iout/di out/asyncore.a test/benchmark_million_timers.d

	dmd -ofout/test/test_timer_again -Iout/di out/asyncore.a test/test_timer_again.d
	dmd -ofout/test/test_timer -Iout/di out/asyncore.a test/test_timer.d

asyncore: uv
	mkdir -p out/di/asyncore
	mkdir -p out/di/asyncore/events
	mkdir -p out/di/asyncore/net

	dmd -lib -ofout/asyncore.a -Hdout/di/asyncore -Iout/di \
            src/asyncore/*.d \
            src/asyncore/events/* \
            out/uv.a

	mv out/di/asyncore/eventemitter.di out/di/asyncore/events

uv:
	(cd deps/libuv; make)
	mkdir -p out/di/deimos
	mkdir -p out/di/deimos/uv_private
	
	dmd -lib -ofout/uv.a -Hdout/di/deimos \
            src/deimos/uv_private/linux.d \
            src/deimos/uv_private/unix.d \
            src/deimos/*.d \
            deps/libuv/libuv.a

	mv out/di/deimos/linux.di out/di/deimos/uv_private
	mv out/di/deimos/unix.di out/di/deimos/uv_private
	

clean:
	rm -rf out
	(cd deps/libuv; make clean)

.PHONY: test asyncore

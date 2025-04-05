module main

import os
import net.http
import actioncable
import time
import x.json2

fn capture_signal(signals chan os.Signal) fn (os.Signal) {
	return fn [signals] (signal os.Signal) {
		go fn [signals, signal] () {
			signals <- signal
		}()
	}
}

fn signal_listen(signals chan os.Signal, done chan bool) {
	for {
		signal := <-signals
		default_logger.info('receive signal: ${signal}')

		done <- true
	}
}

fn main() {
	docker := DockerClient.new()

	mut headers := http.new_header()
	headers.add_custom('X-Proxy-Name', 'dev')!
	headers.add_custom('X-Proxy-Key', '5b39056b3ee1109708d7e0ab')!

	done := chan bool{}

	// Buffered the signal channel, allowing the main thread not to block when sending it over the channel in another thread
	signals := chan os.Signal{}
	os.signal_opt(os.Signal.int, capture_signal(signals))!
	go signal_listen(signals, done)

	mut consumer := actioncable.Consumer.new('ws://localhost:3000/cable', headers)!

	consumer.on("open", fn [mut consumer] ()! {
		consumer.subscribe("TotoChannel", json2.null)!
	})

	go fn [mut consumer, done] ()! {
		h := go consumer.start()
		h.wait()!
		done <- true
	}()

	for {
		select {
			ev := <-consumer.pump {
				println("ev: ${ev}")
			}

			status := <-done {
				default_logger.info('receive done signal, closing connection')

				consumer.close()!
				default_logger.info('exiting ...')
				exit(0)
			}
		}
	}
}

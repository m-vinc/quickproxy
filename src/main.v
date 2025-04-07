module main

import os
import net.http
import actioncable
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
	_ := DockerClient.new()

	mut headers := http.new_header()
	// This is not a real credentials you foool
	headers.add_custom('X-Proxy-Name', 'dev')!
	headers.add_custom('X-Proxy-Key', '5b39056b3ee1109708d7e0ab')!

	done := chan bool{}

	signals := chan os.Signal{}
	os.signal_opt(os.Signal.int, capture_signal(signals))!
	go signal_listen(signals, done)

	mut consumer := actioncable.Consumer.new('ws://localhost:3000/cable', headers)!

	consumer.subscribe('TotoChannel', actioncable.SubscribeParams{
		on_confirmed: fn (mut sub actioncable.Subscription, msg &actioncable.Message) {
			sub.perform('toto', actioncable.Data(map[string]json2.Any{})) or {
				println('error performing')
			}
		}
		on_message: fn (mut sub actioncable.Subscription, msg &actioncable.Message) {
			println('${msg}')
		}
	})!

	go fn [mut consumer, done] () ! {
		h := go consumer.start()
		h.wait()!
		done <- true
	}()

	for {
		select {
			_ := <-done {
				default_logger.info('receive done signal, closing connection')

				consumer.close()!
				default_logger.info('exiting ...')
				exit(0)
			}
		}
	}
}

module actioncable

import net.http
import net.websocket
import time

fn Connection.new(url string, header http.Header) !&Connection {
	mut conn := &Connection{
		client:  websocket.new_client(url, websocket.ClientOpt{
			read_timeout:  5 * time.second
			write_timeout: 5 * time.second
		})!
		monitor: chan bool{}
	}

	conn.client.header = header

	conn.client.on_message(fn [mut conn] (mut ws websocket.Client, msg &websocket.Message) ! {
		conn.client.logger.info('receive message -> ${msg.opcode} - ${msg.payload.bytestr()}')

		match msg.opcode {
			.continuation {}
			.text_frame {
				for callback in conn.on_text_message_callbacks {
					callback(mut ws, msg)
				}
			}
			.binary_frame {}
			.close {}
			.ping {}
			.pong {}
		}

		if msg.payload.len == 0 {
			return
		}
	})

	return conn
}

type TextMessageFn = fn (mut ws websocket.Client, msg &websocket.Message)

@[heap]
struct Connection {
mut:
	client                    &websocket.Client
	reconnect                 bool = true
	monitor                   chan bool
	on_text_message_callbacks []TextMessageFn
}

fn (mut conn Connection) listen() ! {
	if !conn.reconnect {
		return
	}

	go fn [mut conn] () ! {
		conn.client.connect()!
		conn.client.listen()!
		conn.monitor <- true
	}()
}

fn (mut conn Connection) monitor() ! {
	conn.listen()!

	conn.client.logger.info('Start monitoring process')
	for {
		select {
			_ := <-conn.monitor {
				conn.client.logger.info('can we try to re-connect ?')
				if !conn.need_reconnect() {
					return
				}
			}
			500 * time.millisecond {
				if conn.need_reconnect() {
					conn.client.logger.info('need reconnect')
					conn.listen()!
				}
			}
		}
	}
}

fn (mut conn Connection) alive() bool {
	rlock conn.client.client_state {
		return conn.client.client_state.state == websocket.State.open
	}
}

fn (mut conn Connection) need_reconnect() bool {
	rlock conn.client.client_state {
		return conn.client.client_state.state == websocket.State.closed && conn.reconnect
	}
}

fn (mut conn Connection) close() ! {
	rlock conn.client.client_state {
		conn.reconnect = false
		if conn.client.client_state.state != websocket.State.open {
			return
		}
	}

	conn.client.close(1000, 'closed by us')!
}

fn (mut conn Connection) write_string(s string) ! {
	conn.client.write_string(s)!
}

fn (mut conn Connection) on_text_message(f TextMessageFn) {
	conn.on_text_message_callbacks << f
}

fn (mut conn Connection) on_open(f fn (mut ws websocket.Client) !) {
	conn.client.on_open(f)
}

fn (mut conn Connection) on_close(f fn (mut ws websocket.Client, code int, reason string) !) {
	conn.client.on_close(f)
}

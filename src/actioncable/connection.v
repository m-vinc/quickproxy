module actioncable

import net.http
import net.websocket
import x.json2
import strconv
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

	conn.client.on_open(fn [mut conn] (mut ws websocket.Client) ! {
		conn.client.logger.info('conn.Client.on_open websocket connected to the server and ready to send messages...')
	})

	conn.client.on_error(fn [mut conn] (mut ws websocket.Client, err string) ! {
		conn.client.logger.info('on_error error: ${err}')
		conn.monitor <- true
	})

	// // use on_close_ref if you want to send any reference object
	conn.client.on_close(fn [mut conn] (mut ws websocket.Client, code int, reason string) ! {
		conn.client.logger.info('on_close the connection to the server successfully closed (${code} - ${reason})')
	})

	// on new messages from other clients, display them in blue text
	conn.client.on_message(fn [mut conn] (mut ws websocket.Client, msg &websocket.Message) ! {
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

type TextMessageFn = fn(mut ws websocket.Client, msg &websocket.Message)

@[heap]
struct Connection {
mut:
	client        &websocket.Client
	monitor       chan bool
	on_text_message_callbacks []TextMessageFn
}

// fn (mut conn Connection) on_text_message(ws &websocket.Client, msg &websocket.Message) ! {
// 	payload := json2.decode[Payload](msg.payload.bytestr()) or { return err }
//
// 	match payload.type {
// 		welcome { conn.h_welcome(ws, payload)! }
// 		disconnect { conn.client.pong()! }
// 		ping { conn.h_ping(ws, payload)! }
// 		confirmation { conn.client.pong()! }
// 		rejection { conn.client.pong()! }
// 		unauthorized { conn.client.pong()! }
// 		invalid_request { conn.client.pong()! }
// 		server_restart { conn.client.pong()! }
// 		remote { conn.client.pong()! }
// 		else { conn.client.logger.info('receive unknown payload type: ${payload.type} - ${msg.payload.bytestr()}') }
// 	}
//
// 	return
// }

fn (mut conn Connection) h_welcome(ws &websocket.Client, payload Payload) ! {
	conn.client.logger.info('receive welcome !')
	return
}

fn (mut conn Connection) h_ping(ws &websocket.Client, payload Payload) ! {
	if payload.message == none {
		return
	}

	ts_string := payload.message or { return error('ping message is not present') }
	ts := strconv.atoi(ts_string)!

	conn.client.logger.info('receive ping ${ts} !')
	return
}

fn (mut conn Connection) listen() ! {
	conn.client.connect()!

	go fn [mut conn] () ! {
		conn.client.listen()!
		conn.monitor <- true
	}()
}

fn (mut conn Connection) monitor() ! {
	conn.listen()!

	conn.client.logger.info('Start monitoring process')
	for {
		select {
			m := <-conn.monitor {
				conn.client.logger.info('can we try to re-connect ?')
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

fn (mut conn Connection) need_reconnect() bool {
	rlock conn.client.client_state {
		return conn.client.client_state.state == websocket.State.closed
	}
}

fn (mut conn Connection) close() ! {
	rlock conn.client.client_state {
		if conn.client.client_state.state != websocket.State.open {
			return
		}
	}

	conn.client.close(1000, 'closed by us')!
}

fn (mut conn Connection) write_string(s string)! {
	conn.client.write_string(s)!
}

fn (mut conn Connection) on_text_message(f TextMessageFn) {
	conn.on_text_message_callbacks << f
}


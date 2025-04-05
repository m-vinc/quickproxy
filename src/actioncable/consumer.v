module actioncable

import net.http
import net.websocket
import x.json2
import log

pub fn Consumer.new(url string, header http.Header) !&Consumer {
	shared subscriptions := []&Subscription{}

	mut consumer := &Consumer{
		connection: Connection.new(url, header)!,
		subscriptions: subscriptions,
	}

	consumer.connection.on_text_message(fn [mut consumer] (mut ws websocket.Client, msg &websocket.Message) {
		payload := json2.decode[Payload](msg.payload.bytestr()) or { return }

		consumer.logger.info("receive text message: ${msg.payload.bytestr()}")

		match payload.type {
			welcome { consumer.logger.info('receive welcome from server ~') }
			// disconnect { conn.client.pong()! }
			ping { }
			confirmation { consumer.on_confirm_subscription(payload) or { return } }
			// rejection { conn.client.pong()! }
			// unauthorized { conn.client.pong()! }
			// invalid_request { conn.client.pong()! }
			// server_restart { conn.client.pong()! }
			// remote { conn.client.pong()! }
			else { consumer.logger.info('receive unknown payload type: ${payload.type} - ${msg.payload.bytestr()}') }
		}
	})

	return consumer
}

pub struct Event {
	type string
}

pub struct Consumer {

mut:
	connection    &Connection
	subscriptions shared []&Subscription
pub mut:
	logger &log.Logger = default_logger
}

pub fn (mut consumer Consumer) start() ! {
	consumer.connection.monitor()!
}

pub fn (mut consumer Consumer) subscribe(channel string, data json2.Any) ! {
	lock consumer.subscriptions {
		for sub in consumer.subscriptions {
			if sub.channel == channel {
				return
			}
		}

		mut sub := Subscription.new(consumer, channel, data)!
		consumer.subscriptions << sub

		subscribe_command := sub.subscribe_command()
		consumer.connection.write_string(subscribe_command)!
	}
}

pub fn (mut consumer Consumer) unsubscribe(channel string, data json2.Any) ! {
	lock consumer.subscriptions {
		for i, sub in consumer.subscriptions {
			if sub.channel == channel {
				consumer.connection.write_string(sub.unsubscribe_command())!

				consumer.subscriptions.delete(i)
				break
			}
		}
	}
}

pub fn (mut consumer Consumer) close() ! {
	consumer.connection.close()!
}

fn (mut consumer Consumer) on_confirm_subscription(payload &Payload) ! {
	if payload.identifier != none {
		identifier := json2.decode[Identifier](payload.identifier) or { return }

		lock consumer.subscriptions {
			for mut sub in consumer.subscriptions {
				if sub.channel == identifier.channel {
					sub.confirmed = true
					consumer.logger.info("subscription to ${identifier.channel} confirmed")
					break
				}
			}
		}
	}
}

// Allow external hook from outside consumer
pub fn (mut consumer Consumer) on(event_name string, handler fn()!) {
	match event_name {
	"open" {
			consumer.connection.client.on_open(fn [mut consumer, handler] (mut ws websocket.Client) ! {
				handler()!
			})
		}
	else {}
	}
}

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

	consumer.connection.on_open(fn [mut consumer] (mut ws websocket.Client) ! {
		lock consumer.subscriptions {
			for sub in consumer.subscriptions {
				consumer.ensure_subscribe(sub)!
			}
		}
	})

	consumer.connection.on_close(fn [mut consumer] (mut ws websocket.Client, code int, reason string) ! {
		lock consumer.subscriptions {
			for _, mut sub in consumer.subscriptions {
				sub.confirmed = false
			}
		}
	})

	consumer.connection.on_text_message(fn [mut consumer] (mut ws websocket.Client, msg &websocket.Message) {
		payload := json2.decode[Payload](msg.payload.bytestr()) or { return }

		consumer.logger.info("receive text message: ${msg.payload.bytestr()}")

		match payload.type {
			welcome { consumer.logger.info('receive welcome from server ~') }
			// disconnect { conn.client.pong()! }
			ping { }
			confirmation { consumer.on_confirm_subscription(payload) or { return } }
			// rejection { conn.client.pong()! }
			unauthorized { consumer.close() or { consumer.logger.info("receiving an unauthorized, let the server close it") } }
			channel { consumer.on_channel_message(payload) or { return } }
			// invalid_request { conn.client.pong()! }
			// server_restart { conn.client.pong()! }
			// remote { conn.client.pong()! }
			else { consumer.logger.info('receive unknown payload type: ${payload.type} - ${msg.payload.bytestr()}') }
		}
	})

	return consumer
}

fn (mut consumer Consumer) on_channel_message(payload &Payload)! {
	if payload.identifier != none {
		identifier := json2.decode[Identifier](payload.identifier)!
		rlock consumer.subscriptions {
			for sub in consumer.subscriptions {
				if sub.channel == identifier.channel {
					for callback in sub.on_message_callbacks {
						callback(sub)!
					}
					break
				}
			}
		}
	}

	return error("channel_message has no identifier")
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

pub fn (mut consumer Consumer) ensure_subscribe(sub &Subscription) ! {
	rlock consumer.subscriptions {
			subscribe_command := sub.subscribe_command()
			// We only throw that data away and wait for a confirmation, no subscription_guarantor for now
			consumer.connection.write_string(subscribe_command)!
	}
}

pub fn (mut consumer Consumer) subscribe(channel string, data ?json2.Any) ! &Subscription {
	lock consumer.subscriptions {
		mut sub := ?&Subscription(none)
		for mut s in consumer.subscriptions {
			if s.channel == channel {
				sub = s
				break
			}
		}

		if sub == none {
			mut new_sub := Subscription.new(consumer, channel, data)!
			consumer.subscriptions << new_sub

			if consumer.connection.alive() {
				// We only throw that data away and wait for a confirmation, no subscription_guarantor for now
				subscribe_command := new_sub.subscribe_command()
				consumer.connection.write_string(subscribe_command)!
			}
			return new_sub
		} else {
			return sub
		}
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

pub fn (mut consumer Consumer) text(channel string, data ?json2.Any, f SubscriptionHandleFn) ! {
	lock consumer.subscriptions {
		mut current_sub := ?&Subscription(none)
		for mut sub in consumer.subscriptions {
			if sub.channel == channel {
				current_sub = sub
				break
			}
		}

		if current_sub != none {
			// Maybe we want to update the subscription data ?
		} else {
			mut sub := consumer.subscribe(channel, data)!
			sub.on_message_callbacks << f
		}
	}

	return
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

fn (mut consumer Consumer) write_string(data string) ! {
	return consumer.connection.write_string(data)
}

module actioncable

import x.json2

fn Subscription.new(consumer &Consumer, channel string, data ?json2.Any) !&Subscription {
	sub := &Subscription{
		consumer:   consumer
		channel:    channel
		identifier: json2.encode[Identifier](Identifier{ channel: channel })
		data:       data
	}

	return sub
}

@[heap]
pub struct Subscription {
	channel    string
	identifier string
	data       ?json2.Any
mut:
	confirmed bool
	consumer &Consumer
	on_message_callbacks []SubscriptionHandleFn
}

type SubscriptionHandleFn = fn(sub &Subscription)!

pub struct Identifier {
	channel string
}

fn (s Subscription) subscribe_command() string {
	return json2.encode[Command](Command{
		command:    'subscribe'
		identifier: s.identifier
		data:       s.data
	})
}

fn (s Subscription) unsubscribe_command() string {
	return json2.encode[Command](Command{
		command:    'unsubscribe'
		identifier: s.identifier
		data:       s.data
	})
}

pub fn (mut s Subscription) send(data string) ! {
	return s.consumer.write_string(data)
}

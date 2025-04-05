module actioncable

import x.json2


fn Subscription.new(consumer &Consumer, channel string, data json2.Any) !&Subscription {
	sub := &Subscription{
		consumer: consumer,
		channel: channel,
		identifier: json2.encode[Identifier](Identifier{channel: channel}),
		data: data,
	}

	return sub
}

@[heap]
struct Subscription {
	consumer &Consumer

	channel string
	identifier string
	data json2.Any
pub mut:
	confirmed bool
}

pub struct Identifier {
	channel string
}

fn (s Subscription) subscribe_command() string {
	return json2.encode[Command](Command{command: "subscribe", identifier: s.identifier, data: s.data})
}

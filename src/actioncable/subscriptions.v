module actioncable

import maps
import x.json2

fn Subscription.new(consumer &Consumer, channel string, params SubscribeParams) !&Subscription {
	sub := &Subscription{
		consumer:     consumer
		channel:      channel
		identifier:   json2.encode[Identifier](Identifier{ channel: channel })
		on_message:   params.on_message
		on_confirmed: params.on_confirmed
	}

	return sub
}

@[heap]
pub struct Subscription {
	channel    string
	identifier string
mut:
	consumer  &Consumer
	confirmed bool

	on_message   ?SubscriptionHandleFn
	on_confirmed ?SubscriptionHandleFn
}

pub struct SubscribeParams {
pub mut:
	on_confirmed ?SubscriptionHandleFn
	on_message   ?SubscriptionHandleFn
}

type SubscriptionHandleFn = fn (mut sub Subscription, msg &Message)

pub struct Identifier {
	channel string
}

fn (s Subscription) subscribe_command() string {
	return json2.encode[Command](Command{
		command:    'subscribe'
		identifier: s.identifier
	})
}

fn (s Subscription) unsubscribe_command() string {
	return json2.encode[Command](Command{
		command:    'unsubscribe'
		identifier: s.identifier
	})
}

pub fn (mut s Subscription) perform(method string, data Data) ! {
	mut perform_data := map[string]json2.Any{}
	perform_data['action'] = method

	encoded_message := json2.encode[map[string]json2.Any](maps.merge(perform_data, data))

	raw_message := json2.encode[Command](Command{
		command:    'message'
		identifier: s.identifier
		data:       encoded_message
	})

	return s.consumer.write_string(raw_message)
}

pub fn (mut s Subscription) send(data string) ! {
	return s.consumer.write_string(data)
}

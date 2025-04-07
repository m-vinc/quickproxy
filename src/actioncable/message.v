module actioncable

import x.json2

pub struct Command {
	command    string
	identifier string
	data       string
}

pub struct Message {
	type       ?string @[omitempty]
	identifier ?string

	// Allow end-users decoding it as they want.
	message ?string
}

pub type Data = map[string]json2.Any

const welcome = 'welcome'
const disconnect = 'disconnect'
const ping = 'ping'
const confirmation = 'confirm_subscription'
const rejection = 'rejection'
const unauthorized = 'unauthorized'
const invalid_request = 'invalid_request'
const server_restart = 'server_restart'
const remote = 'remote'
const channel = 'channel'

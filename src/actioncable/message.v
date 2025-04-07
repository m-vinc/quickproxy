module actioncable

import x.json2

pub struct Command {
	command    string
	identifier string
	data       ?json2.Any @[omitempty]
}

pub struct Payload {
	type       string
	identifier ?string
	message    ?string
}

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

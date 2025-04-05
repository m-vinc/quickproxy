module main

struct DockerClient {}

fn DockerClient.new() DockerClient {
	return DockerClient{}
}

fn (dc DockerClient) toto() bool {
	return true
}

package exp.rtg;

import exp.rtg.Transport;

using tink.CoreApi;

class Guest<Command, Message> {
	final transport:GuestTransport<Command, Message>;

	public final disconnected:Future<Noise>;
	public final errors:Signal<Error>;
	public final messageReceived:Signal<Message>;

	public function new(transport) {
		this.transport = transport;

		disconnected = transport.events.select(e -> switch e {
			case Disconnected: Some(Noise);
			case _: None;
		}).nextTime();

		messageReceived = transport.events.select(e -> switch e {
			case MessageReceived(m): Some(m);
			case _: None;
		});

		errors = transport.events.select(e -> switch e {
			case Errored(e): Some(e);
			case _: None;
		});
	}

	public inline function connect() {
		return transport.connect();
	}

	public inline function send(command:Command):Promise<Noise> {
		return transport.sendToHost(command);
	}
}

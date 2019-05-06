package exp.rtg.transport;

import exp.rtg.Transport;
import tink.websocket.Server;
import tink.websocket.Client;

using tink.CoreApi;

@:genericBuild(exp.rtg.Macro.buildStringTransport(exp.rtg.transport.WebSocketTransport.WebSocketHostTransportBase))
class WebSocketHostTransport<Command, Message> {}

class WebSocketHostTransportBase<Command, Message> extends StringTransport<Command, Message> implements HostTransport<Command, Message> {
	public final events:Signal<HostEvent<Command>>;
	
	final server:Server;
	final clients:Map<Int, ConnectedClient> = new Map();
	
	var counter = 0;
	
	public function new(server) {
		this.server = server;
		
		final trigger = Signal.trigger();
		events = trigger;
		
		server.errors.handle(e -> trigger.trigger(Errored(e)));
		
		server.clientConnected.handle(client -> {
			final id = counter++;
			clients[id] = client;
			
			trigger.trigger(GuestConnected(id));
			
			client.send(Text(stringifyDownlink(Connected(id))));
			
			client.messageReceived.handle(function(m) switch m {
				case Text(parseUplink(_) => Success(env)): 
					switch env {
						case Command(command): trigger.trigger(CommandReceived(id, command));
					}
				case _:
			});
			
			client.closed.handle(_ -> trigger.trigger(GuestDisonnected(id)));
		});
	}
	
	public function sendToGuest(id:Int, message:Message):Promise<Noise> {
		return switch clients[id] {
			case null: new Error(NotFound, 'Client $id is not connected');
			case client:
				client.send(Text(stringifyDownlink(Message(message)))); Noise;
		}
	}
	
	public function broadcast(message:Message):Promise<Noise> {
		final json = stringifyDownlink(Message(message));
		for(client in clients) client.send(Text(json));
		return Noise;
	}
	
	
}

@:genericBuild(exp.rtg.Macro.buildStringTransport(exp.rtg.transport.WebSocketTransport.WebSocketGuestTransportBase))
class WebSocketGuestTransport<Command, Message> {}

class WebSocketGuestTransportBase<Command, Message> extends StringTransport<Command, Message> implements GuestTransport<Command, Message> {
	public final events:Signal<GuestEvent<Message>>;
	
	final getClient:Void->Client;
	final trigger:SignalTrigger<GuestEvent<Message>>;
	
	var client:Client;
	var binding:CallbackLink;
	
	public function new(getClient) {
		this.getClient = getClient;
		events = trigger = Signal.trigger();
	}
	
	public function connect():Promise<Noise> {
		return new Promise((resolve, reject) -> {
			client = getClient();
			binding = client.messageReceived.handle(function(m) switch m {
				case Text(parseDownlink(_) => Success(env)): 
					switch env {
						case Connected(_): resolve(Noise);
						case Message(message): trigger.trigger(MessageReceived(message));
					}
				case _:
			});
		});
	}
	
	public function disconnect():Promise<Noise> {
		binding.dissolve();
		client.close();
		return Noise;
	}
	
	public function sendToHost(command:Command):Promise<Noise> {
		client.send(Text(stringifyUplink(Command(command))));
		return Noise;
	}
}

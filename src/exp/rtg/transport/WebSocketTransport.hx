package exp.rtg.transport;

import exp.rtg.Transport;
import tink.websocket.Server;
import tink.websocket.Client;
import tink.Json.*;

using tink.CoreApi;

class WebSocketHostTransport<Command, Message> implements HostTransport<Command, Message> {
	public final events:Signal<HostEvent<Command>>;
	
	final server:Server;
	final clients:Map<Int, ConnectedClient> = new Map();
	
	var counter = 0;
	
	public function new(server) {
		this.server = server;
		
		var trigger = Signal.trigger();
		events = trigger;
		
		server.clientConnected.handle(client -> {
			var id = counter++;
			clients[id] = client;
			
			trigger.trigger(PlayerConnected(id));
			
			client.send(Text(stringify(DownlinkEnvelope.Connected(id))));
			
			client.messageReceived.handle(function(m) switch m {
				case Text(parse((_:UplinkEnvelope)) => Success(env)): 
					switch env {
						case Command(command): trigger.trigger(CommandReceived(id, haxe.Unserializer.run(command)));
					}
				case _:
			});
			
			client.closed.handle(_ -> trigger.trigger(PlayerDisonnected(id)));
		});
	}
	
	public function sendToPlayer(id:Int, message:Message):Promise<Noise> {
		return switch clients[id] {
			case null: new Error(NotFound, 'Client $id is not connected');
			case client:
				var serialized = haxe.Serializer.run(message);
				var envelope = DownlinkEnvelope.Message(serialized);
				var json = stringify(envelope);
				client.send(Text(json)); Noise;
		}
	}
	
	public function broadcast(message:Message):Promise<Noise> {
		var serialized = haxe.Serializer.run(message);
		var envelope = DownlinkEnvelope.Message(serialized);
		var json = stringify(envelope);
		for(client in clients) client.send(Text(json));
		return Noise;
	}
	
	
}

class WebSocketPlayerTransport<Command, Message> implements PlayerTransport<Command, Message> {
	public final events:Signal<PlayerEvent<Message>>;
	
	final getClient:Void->Client;
	final trigger:SignalTrigger<PlayerEvent<Message>>;
	
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
				case Text(parse((_:DownlinkEnvelope)) => Success(env)): 
					switch env {
						case Connected(_): resolve(Noise);
						case Message(message): trigger.trigger(MessageReceived(haxe.Unserializer.run(message)));
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
		var serialized = haxe.Serializer.run(command);
		var envelope = UplinkEnvelope.Command(serialized);
		var json = stringify(envelope);
		client.send(Text(json));
		return Noise;
	}
}


enum UplinkEnvelope {  // TODO: Type-parametrize and serialize with tink_json
	Command(command:String);
}

enum DownlinkEnvelope {
	Connected(id:Int);  // TODO: Type-parametrize and serialize with tink_json
	Message(message:String);
}
package exp.rtg.transport;

import exp.rtg.Transport;
import tink.websocket.Server;
import tink.websocket.Client;

using tink.CoreApi;

class WebSocketHostTransport implements HostTransport {
	public final events:Signal<HostEvent>;
	
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
			
			client.send(Binary(serialize(Metadata(Connected(id)))));
			
			client.messageReceived.handle(function(m) switch m {
				case Binary(unserialize(_) => Success(env)): 
					switch env {
						case Metadata(_): // unused
						case Data(data): trigger.trigger(DataReceived(id, data));
					}
				case _:
			});
			
			client.closed.handle(_ -> trigger.trigger(GuestDisonnected(id)));
		});
	}
	
	public function sendToGuest(id:Int, data:Chunk):Promise<Noise> {
		return switch clients[id] {
			case null:
				new Error(NotFound, 'Client $id is not connected');
			case client:
				client.send(Binary(serialize(Data(deata))));
				Noise;
		}
	}
	
	public function broadcast(data:Chunk):Promise<Noise> {
		final serialized = serialize(Data(data));
		for(client in clients) client.send(Binary(serialized));
		return Noise;
	}
	
	inline function serialize(v:DownlinkEnvelope<DownlinkMeta>):Chunk
		return tink.Json.stringify(v);
	
	inline function unserialize(v:Chunk):Outcome<UplinkEnvelope<Noise>>
		return tink.Json.parse((v:UplinkEnvelope<Noise>));
	
}

class WebSocketGuestTransport implements GuestTransport {
	public final events:Signal<GuestEvent>;
	
	final getClient:Void->Client;
	final trigger:SignalTrigger<GuestEvent>;
	
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
				case Binary(unserialize(_) => Success(env)): 
					switch env {
						case Metadata(Connected(_)):
							trigger.trigger(Connected);
							resolve(Noise);
						case Data(data):
							trigger.trigger(DataReceived(deata));
					}
				case _:
			});
		});
	}
	
	public function disconnect():Promise<Noise> {
		binding.dissolve();
		client.close();
		trigger.trigger(Disconnected);
		return Noise;
	}
	
	public function sendToHost(data:Chunk):Promise<Noise> {
		client.send(Binary(serialize(Data(data))));
		return Noise;
	}
	
	inline function serialize(v:UpEnvelope<DownlinkMeta>):Chunk
		return tink.Json.stringify(v);
	
	inline function unserialize(v:Chunk):Outcome<DownlinkEnvelope<Noise>>
		return tink.Json.parse((v:DownlinkEnvelope<Noise>));
}


private enum DownlinkMeta {
	Connected(id:Int);
}
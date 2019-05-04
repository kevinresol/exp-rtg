package exp.rtg.transport;

import haxe.Constraints;
import exp.rtg.Transport;
import tink.Json.*;

using tink.CoreApi;

class WebRtcHostTransport<Command, Message> implements HostTransport<Command, Message> {
	public final events:Signal<HostEvent<Command>>;
	
	public final id:Future<String>;
	
	final peer:Peer;
	final connections:Map<Int, Connection> = new Map();
	
	var count = 0;
	
	public function new(?opt) {
		peer = new Peer(opt);
		id = Future.async(cb -> peer.on('open', cb));
		
		final trigger = Signal.trigger();
		events = trigger;
		
		peer.on('connection', (conn:Connection) -> {
			final id = count++;
			connections[id] = conn;
			
			trigger.trigger(PlayerConnected(id));
			conn.send(stringify(DownlinkEnvelope.Connected(id)));
			
			conn.on('data', (data:String) -> {
				switch parse((data:UplinkEnvelope)) {
					case Success(Command(command)): trigger.trigger(CommandReceived(id, haxe.Unserializer.run(command)));
					case Failure(_): 
				}
			});
			
			conn.on('close', trigger.trigger.bind(PlayerDisonnected(id)));
		});
	}
	
	public function sendToPlayer(id:Int, message:Message):Promise<Noise> {
		return switch connections[id] {
			case null: new Error(NotFound, 'Client $id is not connected');
			case conn:
				var serialized = haxe.Serializer.run(message);
				var envelope = DownlinkEnvelope.Message(serialized);
				var json = stringify(envelope);
				conn.send(json); Noise;
		}
	}
	
	public function broadcast(message:Message):Promise<Noise> {
		var serialized = haxe.Serializer.run(message);
		var envelope = DownlinkEnvelope.Message(serialized);
		var json = stringify(envelope);
		for(conn in connections) conn.send(json);
		return Noise;
	}
	
	
}

class WebRtcPlayerTransport<Command, Message> implements PlayerTransport<Command, Message> {
	public final events:Signal<PlayerEvent<Message>>;
	
	final trigger:SignalTrigger<PlayerEvent<Message>>;
	final peer:Future<Peer>;
	final hostId:String;
	var conn:Connection;
	
	public function new(opt, hostId:String) {
		var peer = new Peer(opt);
		this.peer = Future.async(cb -> peer.on('open', cb.bind(peer)));
		this.hostId = hostId;
		events = trigger = Signal.trigger();
	}
	
	public function connect():Promise<Noise> {
		return new Promise((resolve, reject) -> {
			peer.handle(peer -> {
				conn = peer.connect(hostId);
				conn.on('open', resolve.bind(Noise));
				conn.on('data', (data:String) -> {
					switch parse((data:DownlinkEnvelope)) {
						case Success(Connected(_)): resolve(Noise);
						case Success(Message(message)): trigger.trigger(MessageReceived(haxe.Unserializer.run(message)));
						case Failure(_):
					}
				});
			});
		});
	}
	
	public function disconnect():Promise<Noise> {
		return new Error(NotImplemented, 'Not implemented');
	}
	
	public function sendToHost(command:Command):Promise<Noise> {
		var serialized = haxe.Serializer.run(command);
		var envelope = UplinkEnvelope.Command(serialized);
		var json = stringify(envelope);
		conn.send(json);
		return Noise;
	}
}


private enum UplinkEnvelope {  // TODO: Type-parametrize and serialize with tink_json
	Command(command:String);
}

private enum DownlinkEnvelope {
	Connected(id:Int);  // TODO: Type-parametrize and serialize with tink_json
	Message(message:String);
}

@:native('Peer')
private extern class Peer {
	function new(?opt:{});
	function connect(id:String):Connection;
	function on(event:String, f:Function):Void;
}

private extern class Connection {
	function on(event:String, f:Function):Void;
	function send(msg:String):Void;
}
package exp.rtg.transport;

import haxe.Constraints;
import exp.rtg.Transport;
import tink.Json.*;

using tink.CoreApi;

/**
 * Add this to html:
 * <script src="https://unpkg.com/peerjs@1.0.0/dist/peerjs.min.js"></script>
 */
class WebRtcHostTransport<Command, Message> implements HostTransport<Command, Message> {
	public final events:Signal<HostEvent<Command>>;
	
	public final id:Future<String>;
	
	final peer:Peer;
	final connections:Map<Int, DataConnection> = new Map();
	
	var count = 0;
	
	public function new(?opt) {
		peer = new Peer(opt);
		id = Future.async(cb -> peer.on('open', cb));
		
		final trigger = Signal.trigger();
		events = trigger;
		
		peer.on('error', e -> trigger.trigger(Errored(Error.ofJsError(e))));
		
		peer.on('connection', (conn:DataConnection) -> {
			final id = count++;
			connections[id] = conn;
			
			trigger.trigger(GuestConnected(id));
			conn.send(stringify(DownlinkEnvelope.Connected(id)));
			
			conn.on('data', (data:String) -> {
				switch parse((data:UplinkEnvelope)) {
					case Success(Command(command)): trigger.trigger(CommandReceived(id, haxe.Unserializer.run(command)));
					case Failure(_): 
				}
			});
			
			conn.on('close', trigger.trigger.bind(GuestDisonnected(id)));
		});
	}
	
	public function sendToGuest(id:Int, message:Message):Promise<Noise> {
		return switch connections[id] {
			case null:
				new Error(NotFound, 'Client $id is not connected');
			case conn:
				final serialized = haxe.Serializer.run(message);
				final envelope = DownlinkEnvelope.Message(serialized);
				final json = stringify(envelope);
				conn.send(json);
				Noise;
		}
	}
	
	public function broadcast(message:Message):Promise<Noise> {
		final serialized = haxe.Serializer.run(message);
		final envelope = DownlinkEnvelope.Message(serialized);
		final json = stringify(envelope);
		for(conn in connections) conn.send(json);
		return Noise;
	}
	
	
}

class WebRtcGuestTransport<Command, Message> implements GuestTransport<Command, Message> {
	public final events:Signal<GuestEvent<Message>>;
	
	final trigger:SignalTrigger<GuestEvent<Message>>;
	final opt:{};
	final hostId:String;
	var conn:DataConnection;
	
	public function new(opt, hostId:String) {
		this.opt = opt;
		this.hostId = hostId;
		events = trigger = Signal.trigger();
	}
	
	public function connect():Promise<Noise> {
		return new Promise((resolve, reject) -> {
			final peer = new Peer(opt, hostId);
			peer.on('open', () -> {
				conn = peer.connect(hostId);
				conn.on('error', e -> trigger.trigger(Errored(Error.ofJsError(e))));
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
		conn.close();
		return Noise;
	}
	
	public function sendToHost(command:Command):Promise<Noise> {
		final serialized = haxe.Serializer.run(command);
		final envelope = UplinkEnvelope.Command(serialized);
		final json = stringify(envelope);
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
	function connect(id:String):DataConnection;
	function on(event:String, f:Function):Void;
}

private extern class DataConnection {
	function on(event:String, f:Function):Void;
	function send(msg:String):Void;
	function close():Void;
}
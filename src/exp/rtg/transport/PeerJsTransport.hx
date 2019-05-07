package exp.rtg.transport;

import haxe.Constraints;
import exp.rtg.Transport;

using tink.CoreApi;

/**
 * Add this to html:
 * <script src="https://unpkg.com/peerjs@1.0.0/dist/peerjs.min.js"></script>
 */
 
@:genericBuild(exp.rtg.Macro.buildStringTransport(exp.rtg.transport.PeerJsTransport.PeerJsHostTransportBase))
class PeerJsHostTransport<Command, Message> {}

class PeerJsHostTransportBase<Command, Message> extends StringTransport<Noise, DownlinkMeta, Command, Message> implements HostTransport<Command, Message> {
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
			conn.send(stringifyDownlink(Meta(Connected(id))));
			
			conn.on('data', (data:String) -> {
				switch parseUplink(data) {
					case Success(Meta(_)): // unused
					case Success(Command(command)): trigger.trigger(CommandReceived(id, command));
					case Failure(e): trace(e);
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
				conn.send(stringifyDownlink(Message(message)));
				Noise;
		}
	}
	
	public function broadcast(message:Message):Promise<Noise> {
		final json = stringifyDownlink(Message(message));
		for(conn in connections) conn.send(json);
		return Noise;
	}
}

@:genericBuild(exp.rtg.Macro.buildStringTransport(exp.rtg.transport.PeerJsTransport.PeerJsGuestTransportBase))
class PeerJsGuestTransport<Command, Message> {}

class PeerJsGuestTransportBase<Command, Message> extends StringTransport<Noise, DownlinkMeta, Command, Message> implements GuestTransport<Command, Message> {
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
			final peer = new Peer(opt);
			peer.on('open', () -> {
				conn = peer.connect(hostId);
				conn.on('error', e -> trigger.trigger(Errored(Error.ofJsError(e))));
				conn.on('open', resolve.bind(Noise));
				conn.on('data', (data:String) -> {
					switch parseDownlink(data) {
						case Success(Meta(Connected(_))): resolve(Noise);
						case Success(Message(message)): trigger.trigger(MessageReceived(message));
						case Failure(e): trace(e);
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
		conn.send(stringifyUplink(Command(command)));
		return Noise;
	}
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

private enum DownlinkMeta {
	Connected(id:Int);
}
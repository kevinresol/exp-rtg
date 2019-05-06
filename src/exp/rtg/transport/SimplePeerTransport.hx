package exp.rtg.transport;

import tink.state.State;
import haxe.Constraints;
import exp.rtg.Transport;
import tink.state.*;

using tink.CoreApi;

/**
 * Add this to html:
 * <script src="https://cdnjs.cloudflare.com/ajax/libs/simple-peer/9.3.0/simplepeer.min.js"></script>
 */
 
@:genericBuild(exp.rtg.Macro.buildStringTransport(exp.rtg.transport.SimplePeerTransport.SimplePeerHostTransportBase))
class SimplePeerHostTransport<Command, Message> {}

class SimplePeerHostTransportBase<Command, Message> extends StringTransport<Command, Message> implements HostTransport<Command, Message> {
	public final events:Signal<HostEvent<Command>>;
	
	public final current:Observable<{id:Int, peer:Peer, signal:{}}>;
	
	final peers:Map<Int, Peer> = new Map();
	
	var count = 0;
	
	public function new(getSignal:Int->Signaling) {
		
		final state = new State(null);
		current = state;
		
		final trigger = Signal.trigger();
		events = trigger;
		
		function next() {
			final peer = new Peer({initiator: true});
			final id = count++;
			var signaling = getSignal(id);
			var first = true;
			peer.on('signal', function(data) {
				if(first) {
					signaling.received.nextTime().handle(next); // create new listening peer once received the first signal from remote peer
					peer.once('connect', signaling.received.handle(peer.signal).dissolve);
					state.set({id: id, peer: peer, signal: data});
					first = false;
				} else {
					signaling.send(data);
				}
			});
			
			peer.once('connect', () -> {
				signaling.destroy();
				signaling = null;
				
				peers[id] = peer;
				
				trigger.trigger(GuestConnected(id));
				peer.send(stringifyDownlink(Connected(id)));
				
				peer.on('data', (data:Dynamic) -> {
					switch parseUplink(data.toString()) {
						case Success(Command(command)): trigger.trigger(CommandReceived(id, command));
						case Failure(_): 
					}
				});
				
				peer.once('close', () -> {
					trigger.trigger(GuestDisonnected(id));
					peers.remove(id);
					peer.destroy();
				});
			});
		}
		
		next();
	}
	
	public function sendToGuest(id:Int, message:Message):Promise<Noise> {
		return switch peers[id] {
			case null:
				new Error(NotFound, 'Client $id is not connected');
			case peer:
				peer.send(stringifyDownlink(Message(message)));
				Noise;
		}
	}
	
	public function broadcast(message:Message):Promise<Noise> {
		var json = stringifyDownlink(Message(message));
		for(peer in peers) peer.send(json);
		return Noise;
	}
	
	
}

@:genericBuild(exp.rtg.Macro.buildStringTransport(exp.rtg.transport.SimplePeerTransport.SimplePeerGuestTransportBase))
class SimplePeerGuestTransport<Command, Message> {}

class SimplePeerGuestTransportBase<Command, Message> extends StringTransport<Command, Message> implements GuestTransport<Command, Message> {
	public final events:Signal<GuestEvent<Message>>;
	
	final trigger:SignalTrigger<GuestEvent<Message>>;
	final init:{};
	final signaling:Signaling;
	var peer:Peer;
	
	public function new(init, signaling) {
		this.init = init;
		this.signaling = signaling;
		events = trigger = Signal.trigger();
	}
	
	public function connect():Promise<Noise> {
		return new Promise((resolve, reject) -> {
			peer = new Peer();
			peer.on('signal', data -> {
				signaling.send(data);
				signaling.received.handle(peer.signal);
			});
			peer.on('error', e -> reject(Error.ofJsError(e)));
			peer.once('connect', () -> {
				signaling.destroy();
				peer.on('data', (data:Dynamic) -> {
					switch parseDownlink(data.toString()) {
						case Success(Connected(_)): resolve(Noise);
						case Success(Message(message)): trigger.trigger(MessageReceived(message));
						case Failure(e): trace(e.data);
					}
				});
			});
			peer.once('close', peer.destroy);
			peer.signal(init);
		});
	}
	
	public function disconnect():Promise<Noise> {
		peer.destroy();
		return Noise;
	}
	
	public function sendToHost(command:Command):Promise<Noise> {
		peer.send(stringifyUplink(Command(command)));
		return Noise;
	}
}

interface Signaling {
	final received:Signal<{}>;
	function send(data:{}):Void;	
	function destroy():Void;	
}

class MqttSignaling implements Signaling {
	public final received:Signal<{}>;
	
	final client:mqtt.Client;
	final topic:String;
	
	var binding:CallbackLink;
	
	public function new(client, subscribe, publish) {
		this.client = client;
		this.topic = publish;
		
		received = Signal.generate(trigger -> binding = client.messageReceived.handle(message -> trigger(haxe.Json.parse(message.content))));
		client.connect().handle(o -> {
			client.subscribe(subscribe);
		});
	}
	
	public function send(data:{}):Void {
		client.publish(topic, haxe.Json.stringify(data));
	}
	
	public function destroy():Void {
		binding.dissolve();
		// received.clear();
	}
	
}

@:native('SimplePeer')
private extern class Peer {
	function new(?opt:{});
	function signal(data:{}):Void;
	function on(event:String, f:Function):Dynamic;
	function once(event:String, f:Function):Void;
	function send(data:String):Void;
	function destroy():Void;
}
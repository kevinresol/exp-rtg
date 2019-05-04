package exp.rtg;

import tink.state.ObservableArray;
import exp.rtg.Transport;

using Lambda;
using tink.CoreApi;

class Host<Command, Message> {
	
	public final players:Players<Command, Message>;
	public final transport:HostTransport<Command, Message>;
	
	public function new(transport) {
		players = new Players(transport);
		
		this.transport = transport;
	}
	
	public function broadcast(message:Message):Promise<Noise> {
		return transport.broadcast(message);
	}
}

class Players<Command, Message> extends ObservableArray<ConnectedPlayer<Command, Message>> {
	public final connected:Signal<ConnectedPlayer<Command, Message>>;
	public final disconnected:Signal<ConnectedPlayer<Command, Message>>;
	
	final _connected:SignalTrigger<ConnectedPlayer<Command, Message>>;
	final _disconnected:SignalTrigger<ConnectedPlayer<Command, Message>>;
	final transport:HostTransport<Command, Message>;
	
	public function new(transport) {
		super();
		
		this.transport = transport;
		
		connected = _connected = Signal.trigger();
		disconnected = _disconnected = Signal.trigger();
		
		transport.events.handle(function(e) switch e {
			case PlayerConnected(id): connect(id);
			case PlayerDisonnected(id): disconnect(id);
			case CommandReceived(id, command):
		});
		
		changes.handle(change -> switch change {
			case Remove(index, values): for(v in values) _disconnected.trigger(v);
			case Insert(index, values): for(v in values) _connected.trigger(v);
			case _:
		});
	}
	
	public function connect(id:Int) {
		push(new ConnectedPlayer(id, transport));
	}
	
	public function disconnect(id:Int) {
		var i = length;
		while(i-- > 0) {
			var player = items[i];
			if(player.id == id) splice(i, 1);
		}
	}
}


@:allow(rtg)
class ConnectedPlayer<Command, Message> {
	public final id:Int;
	public final disconnected:Future<Noise>;
	public final commandReceived:Signal<Command>;
	
	final transport:HostTransport<Command, Message>;
	
	public function new(id, transport) {
		this.id = id;
		this.transport = transport;
		this.disconnected = transport.events.select(event -> switch event {
			case PlayerDisonnected(id) if(this.id == id): Some(Noise);
			case _: None;
		}).nextTime();
		this.commandReceived = transport.events.select(event -> switch event {
			case CommandReceived(id, command) if(this.id == id): Some(command);
			case _: None;
		});
	}
	
	public inline function send(message:Message):Promise<Noise> {
		return transport.sendToPlayer(id, message);
	}
	
}
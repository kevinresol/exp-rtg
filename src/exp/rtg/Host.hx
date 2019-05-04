package exp.rtg;

import tink.state.ObservableArray;
import exp.rtg.Transport;

using Lambda;
using tink.CoreApi;

class Host<Command, Message> {
	
	public final guests:Guests<Command, Message>;
	public final transport:HostTransport<Command, Message>;
	
	public function new(transport) {
		guests = new Guests(transport);
		
		this.transport = transport;
	}
	
	public function broadcast(message:Message):Promise<Noise> {
		return transport.broadcast(message);
	}
}

class Guests<Command, Message> extends ObservableArray<ConnectedGuest<Command, Message>> {
	public final connected:Signal<ConnectedGuest<Command, Message>>;
	public final disconnected:Signal<ConnectedGuest<Command, Message>>;
	
	final _connected:SignalTrigger<ConnectedGuest<Command, Message>>;
	final _disconnected:SignalTrigger<ConnectedGuest<Command, Message>>;
	final transport:HostTransport<Command, Message>;
	
	public function new(transport) {
		super();
		
		this.transport = transport;
		
		connected = _connected = Signal.trigger();
		disconnected = _disconnected = Signal.trigger();
		
		transport.events.handle(function(e) switch e {
			case GuestConnected(id): connect(id);
			case GuestDisonnected(id): disconnect(id);
			case _:
		});
		
		changes.handle(change -> switch change {
			case Remove(index, values): for(v in values) _disconnected.trigger(v);
			case Insert(index, values): for(v in values) _connected.trigger(v);
			case _:
		});
	}
	
	public function connect(id:Int) {
		push(new ConnectedGuest(id, transport));
	}
	
	public function disconnect(id:Int) {
		var i = length;
		while(i-- > 0) {
			var guest = items[i];
			if(guest.id == id) splice(i, 1);
		}
	}
}


@:allow(rtg)
class ConnectedGuest<Command, Message> {
	public final id:Int;
	public final disconnected:Future<Noise>;
	public final commandReceived:Signal<Command>;
	
	final transport:HostTransport<Command, Message>;
	
	public function new(id, transport) {
		this.id = id;
		this.transport = transport;
		this.disconnected = transport.events.select(event -> switch event {
			case GuestDisonnected(id) if(this.id == id): Some(Noise);
			case _: None;
		}).nextTime();
		this.commandReceived = transport.events.select(event -> switch event {
			case CommandReceived(id, command) if(this.id == id): Some(command);
			case _: None;
		});
	}
	
	public inline function send(message:Message):Promise<Noise> {
		return transport.sendToGuest(id, message);
	}
	
}
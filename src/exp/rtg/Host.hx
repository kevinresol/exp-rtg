package exp.rtg;

import tink.state.ObservableArray;
import exp.rtg.Transport;

using Lambda;
using tink.CoreApi;

class Host {
	
	public final guests:Guests;
	public final transport:HostTransport;
	
	public function new(transport) {
		guests = new Guests(transport);
		
		this.transport = transport;
	}
	
	public function broadcast(data:Chunk):Promise<Noise> {
		return transport.broadcast(data);
	}
}

class Guests extends ObservableArray<ConnectedGuest> {
	public final connected:Signal<ConnectedGuest>;
	public final disconnected:Signal<ConnectedGuest>;
	
	final _connected:SignalTrigger<ConnectedGuest>;
	final _disconnected:SignalTrigger<ConnectedGuest>;
	final transport:HostTransport;
	
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
class ConnectedGuest {
	public final id:Int;
	public final disconnected:Future<Noise>;
	public final dataReceived:Signal<Chunk>;
	
	final transport:HostTransport;
	
	public function new(id, transport) {
		this.id = id;
		this.transport = transport;
		this.disconnected = transport.events.select(event -> switch event {
			case GuestDisonnected(id) if(this.id == id): Some(Noise);
			case _: None;
		}).nextTime();
		this.dataReceived = transport.events.select(event -> switch event {
			case DataReceived(id, data) if(this.id == id): Some(data);
			case _: None;
		});
	}
	
	public inline function send(data:Chunk):Promise<Noise> {
		return transport.sendToGuest(id, data);
	}
	
}
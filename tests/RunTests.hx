package ;

import tink.unit.*;
import tink.testrunner.*;
import tink.state.*;
import tink.Chunk;
import exp.rtg.*;
import exp.rtg.Transport;

using tink.CoreApi;
using Lambda;

@:asserts
class RunTests {

	static function main() {
		Runner.run(TestBatch.make([
			new RunTests(),
		])).handle(Runner.exit);
	}
	
	function new() {}
	
	public function test() {
	
		var hostTransport = new MockHostTransport();
		var host = new Host(hostTransport);
		
		var game = new Game();
		
		var connected = false;
		
		host.guests.connected.handle(guest -> {
			connected = true;
			var gameGuest = game.createGuest(guest.id);
			guest.dataReceived.handle(data -> switch tink.Json.parse((data:Command)) {
				case Success(SetSpeed(v)): gameGuest.speed.set(v);
				case Failure(e): trace(e);
			});
			guest.disconnected.handle(_ -> game.removeGuest(guest.id));
		});
		
		asserts.assert(host.guests.length == 0);
		var guestTransport = new MockGuestTransport(hostTransport);
		guestTransport.connect()
			.next(_ -> {
				asserts.assert(connected);
				asserts.assert(host.guests.length == 1);
				asserts.assert(game.guests.length == 1);
				asserts.assert(game.guests[0].pos == 0);
				guestTransport.sendToHost(tink.Json.stringify(SetSpeed(1)));
				game.update();
				asserts.assert(game.guests[0].pos == 1);
				guestTransport.disconnect();
			})
			.next(_ -> {
				asserts.assert(host.guests.length == 0);
				asserts.assert(game.guests.length == 0);
				Noise;
			})
			.handle(asserts.handle);
		
		
		return asserts;
	}
	
}

class MockHostTransport implements HostTransport {
	public final events:Signal<HostEvent>;
	public final eventsTrigger:SignalTrigger<HostEvent>;
	public final guests:Array<MockGuestTransport>;
	
	var count:Int = 0;
	
	public function new() {
		guests = [];
		events = eventsTrigger = Signal.trigger();
		
		events.handle(function(e) switch e {
			case GuestConnected(id):
				guests.push(MockGuestTransport.list[id]);
			case GuestDisonnected(id):
				for(i in 0...guests.length) {
					var guest = guests[i];
					if(guest.id == id) {
						guests.splice(i, 1);
						guest.eventsTrigger.trigger(Disconnected);
					}
				}
			case _ :
		});
	}
	
	public function sendToGuest(id:Int, data:Chunk):Promise<Noise> {
		return switch guests.find(guest -> guest.id == id) {
			case null:
				new Error(NotFound, 'Guest $id not found');
			case guest:
				guest.eventsTrigger.trigger(DataReceived(data));
				Noise;
		}
	}
	
	public function broadcast(data:Chunk):Promise<Noise> {
		for(guest in guests) guest.eventsTrigger.trigger(DataReceived(data));
		return Noise;
	}
}

class MockGuestTransport implements GuestTransport {
	public static var list:Array<MockGuestTransport> = [];
	static var count:Int = 0;
	
	public final events:Signal<GuestEvent>;
	public final eventsTrigger:SignalTrigger<GuestEvent>;
	public var id(default, null):Int;
	final host:MockHostTransport;
	
	var connected = false;
	
	public function new(host) {
		this.host = host;
		
		id = count++;
		list[id] = this;
		
		events = eventsTrigger = Signal.trigger();
	}
	public function connect():Promise<Noise> {
		if(connected) return new Error('Already connected');
		connected = true;
		host.eventsTrigger.trigger(GuestConnected(id));
		return Noise;
	}
	public function disconnect():Promise<Noise> {
		if(!connected) return new Error('Not connected');
		connected = false;
		host.eventsTrigger.trigger(GuestDisonnected(id));
		return Noise;
		
	}
	public function sendToHost(data:Chunk):Promise<Noise> {
		if(!connected) return new Error('Not connected');
		host.eventsTrigger.trigger(DataReceived(id, data));
		return Noise;
	}
}

enum Command {
	SetSpeed(v:Int);
}

enum Message {
	
}

class GameGuest {
	public final id:Int;
	public final speed:State<Int> = new State(0);
	public var pos:Int = 0;
	
	public function new(id) {
		this.id = id;
	}
}

class Game {
	
	public final guests:Array<GameGuest> = [];
	
	public function new() {
		
	}
	
	public function update() {
		for(guest in guests) guest.pos += guest.speed.value;
	}
	
	public function createGuest(id:Int) {
		var guest = new GameGuest(id);
		guests.push(guest);
		return guest;
	}
	
	public function removeGuest(id:Int) {
		var i = guests.length;
		while(i-- > 0) {
			var guest = guests[i];
			if(guest.id == id) guests.splice(i, 1);
		}
	}
}
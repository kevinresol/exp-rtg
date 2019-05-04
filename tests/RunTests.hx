package ;

import tink.unit.*;
import tink.testrunner.*;
import tink.state.*;
import rtg.*;
import rtg.Transport;

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
		var host = new Host<Command, Message>(hostTransport);
		
		var game = new Game();
		
		var connected = false;
		
		host.players.connected.handle(player -> {
			connected = true;
			var gamePlayer = game.createPlayer(player.id);
			player.commandReceived.handle(command -> switch command {
				case SetSpeed(v): gamePlayer.speed.set(v);
			});
			player.disconnected.handle(_ -> game.removePlayer(player.id));
		});
		
		asserts.assert(host.players.length == 0);
		var playerTransport = new MockPlayerTransport(hostTransport);
		playerTransport.connect()
			.next(_ -> {
				asserts.assert(connected);
				asserts.assert(host.players.length == 1);
				asserts.assert(game.players.length == 1);
				asserts.assert(game.players[0].pos == 0);
				playerTransport.sendToHost(SetSpeed(1));
				game.update();
				asserts.assert(game.players[0].pos == 1);
				playerTransport.disconnect();
			})
			.next(_ -> {
				asserts.assert(host.players.length == 0);
				asserts.assert(game.players.length == 0);
				Noise;
			})
			.handle(asserts.handle);
		
		
		return asserts;
	}
	
}

class MockHostTransport implements HostTransport<Command, Message> {
	public final events:Signal<HostEvent<Command>>;
	public final eventsTrigger:SignalTrigger<HostEvent<Command>>;
	public final players:Array<MockPlayerTransport>;
	
	var count:Int = 0;
	
	public function new() {
		players = [];
		events = eventsTrigger = Signal.trigger();
		
		events.handle(function(e) switch e {
			case PlayerConnected(id):
				players.push(MockPlayerTransport.list[id]);
			case PlayerDisonnected(id):
				for(i in 0...players.length) {
					var player = players[i];
					if(player.id == id) {
						players.splice(i, 1);
						player.eventsTrigger.trigger(Disonnected);
					}
				}
			case CommandReceived(id, command):
		});
	}
	
	public function sendToPlayer(id:Int, message:Message):Promise<Noise> {
		return switch players.find(player -> player.id == id) {
			case null:
				new Error(NotFound, 'Player $id not found');
			case player:
				player.eventsTrigger.trigger(MessageReceived(message));
				Noise;
		}
	}
	
	public function broadcast(message:Message):Promise<Noise> {
		for(player in players) player.eventsTrigger.trigger(MessageReceived(message));
		return Noise;
	}
}

class MockPlayerTransport implements PlayerTransport<Command, Message> {
	public static var list:Array<MockPlayerTransport> = [];
	static var count:Int = 0;
	
	public final events:Signal<PlayerEvent<Message>>;
	public final eventsTrigger:SignalTrigger<PlayerEvent<Message>>;
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
		host.eventsTrigger.trigger(PlayerConnected(id));
		return Noise;
	}
	public function disconnect():Promise<Noise> {
		if(!connected) return new Error('Not connected');
		connected = false;
		host.eventsTrigger.trigger(PlayerDisonnected(id));
		id = null;
		return Noise;
		
	}
	public function sendToHost(command:Command):Promise<Noise> {
		if(!connected) return new Error('Not connected');
		host.eventsTrigger.trigger(CommandReceived(id, command));
		return Noise;
	}
}

enum Command {
	SetSpeed(v:Int);
}

enum Message {
	
}

class GamePlayer {
	public final id:Int;
	public final speed:State<Int> = new State(0);
	public var pos:Int = 0;
	
	public function new(id) {
		this.id = id;
	}
}

class Game {
	
	public final players:Array<GamePlayer> = [];
	
	public function new() {
		
	}
	
	public function update() {
		for(player in players) player.pos += player.speed.value;
	}
	
	public function createPlayer(id:Int) {
		var player = new GamePlayer(id);
		players.push(player);
		return player;
	}
	
	public function removePlayer(id:Int) {
		var i = players.length;
		while(i-- > 0) {
			var player = players[i];
			if(player.id == id) players.splice(i, 1);
		}
	}
}
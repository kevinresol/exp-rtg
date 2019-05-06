package;

import exp.rtg.*;
import exp.rtg.transport.WebSocketTransport;
import tink.state.*;
import tink.websocket.servers.*;
import Command;

class Playground {
	static function main() {
		var host = new Host<Command, Message>(new WebSocketHostTransport<Command, Message>(new NodeWsServer({port: 8134})));
		
		var game = new Game();
		
		host.guests.connected.handle(guest -> {
			var gameGuest = game.createGuest(guest.id);
			trace('guest ${guest.id} connected');
			guest.commandReceived.handle(command -> switch command {
				case ChangeDirection(dir): gameGuest.direction.set(dir);
			});
			guest.disconnected.handle(_ -> game.removeGuest(guest.id));
		});
		
		new haxe.Timer(16).run = function() {
			game.update(16/1000);
			for(guest in game.guests) trace(guest.id, guest.x, guest.y);
		}
	}
}


class GameGuest {
	public final id:Int;
	public final direction:State<Direction> = new State(North);
	public var x:Float = 0;
	public var y:Float = 0;
	
	public function new(id) {
		this.id = id;
	}
}

class Game {
	
	public final guests:Array<GameGuest> = [];
	
	public function new() {
		
	}
	
	public function update(dt:Float) {
		for(guest in guests) {
			switch guest.direction.value {
				case North: guest.y -= dt;
				case South: guest.y += dt;
				case East: guest.x += dt;
				case West: guest.x -= dt;
			}
		}
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
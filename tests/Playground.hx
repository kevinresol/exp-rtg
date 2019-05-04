package;

import rtg.*;
import rtg.transport.WebSocketTransport;
import tink.state.*;
import tink.websocket.servers.*;
import Command;

class Playground {
	static function main() {
		var host = new Host<Command, Message>(new WebSocketHostTransport(new NodeWsServer({port: 8134})));
		
		var game = new Game();
		
		host.players.connected.handle(player -> {
			var gamePlayer = game.createPlayer(player.id);
			trace('player ${player.id} connected');
			player.commandReceived.handle(command -> switch command {
				case ChangeDirection(dir): gamePlayer.direction.set(dir);
			});
			player.disconnected.handle(_ -> game.removePlayer(player.id));
		});
		
		new haxe.Timer(16).run = function() {
			game.update(16/1000);
			for(player in game.players) trace(player.id, player.x, player.y);
		}
	}
}


class GamePlayer {
	public final id:Int;
	public final direction:State<Direction> = new State(North);
	public var x:Float = 0;
	public var y:Float = 0;
	
	public function new(id) {
		this.id = id;
	}
}

class Game {
	
	public final players:Array<GamePlayer> = [];
	
	public function new() {
		
	}
	
	public function update(dt:Float) {
		for(player in players) {
			switch player.direction.value {
				case North: player.y -= dt;
				case South: player.y += dt;
				case East: player.x += dt;
				case West: player.x -= dt;
			}
		}
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
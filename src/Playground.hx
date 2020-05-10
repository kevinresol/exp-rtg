package;

import js.html.DivElement;
import js.Browser.*;
import tink.Url;
import why.duplex.peerjs.*;
import exp.rtg.*;

class Playground {
	static function main() {
		var url:Url = window.location.href;
		switch url.query.toMap()['id'] {
			case null:
				runHost();
			case v:
				runGuest(v);
		}
	}

	static function runHost() {
		var id = 'why-duplex-${Std.random(1 << 28)}';
		Host.create(PeerJsServer.bind.bind({id: id, key: 'lwjd5qra8257b9'}), v -> true).handle(function(o) switch o {
			case Success(host):
				trace('host running. id = $id');
				trace(location.href + '?id=$id');
				host.rooms.created.handle(function(room) {
					var game = new Game();
					trace('room ${room.id} created');
					room.guests.connected.handle(function(guest) {
						trace('guest ${guest.id} connected');
						var player = game.addPlayer();
						guest.data.handle(function(chunk) {
							switch chunk[0] {
								case 0:
									player.dx = 20;
									player.dy = 0;
								case 1:
									player.dx = -20;
									player.dy = 0;
								case 2:
									player.dx = 0;
									player.dy = 20;
								case 3:
									player.dx = 0;
									player.dy = -20;
								case _:
							}
						});
					});
				});

				host.rooms.create('default');
			case Failure(e):
				trace(e);
		});
	}

	static function runGuest(id:String) {
		Guest.connect(PeerJsClient.connect.bind({id: id, key: 'lwjd5qra8257b9'})).handle(function(o) switch o {
			case Success(guest):
				trace('connected to host');
				guest.joinRoom(0).handle(function(o) switch o {
					case Success(seat):
						trace('joined room');
						seat.data.handle(function(o) trace(o.toString()));

						function addButton(text:String, value:Int) {
							var button = document.createButtonElement();
							button.innerText = text;
							var bytes = haxe.io.Bytes.alloc(1);
							bytes.set(0, value);
							button.onclick = function() seat.send(bytes);
							document.body.appendChild(button);
						}

						addButton('right', 0);
						addButton('left', 1);
						addButton('down', 2);
						addButton('up', 3);

					case Failure(e):
						trace(e);
				});
			case Failure(e):
				trace(e);
		});
	}
}

class Game {
	final players:Array<Player> = [];

	public function new() {
		var t = -1.;
		function run(now:Float) {
			var dt = now - t;
			if (t > 0)
				update(dt / 1000);
			t = now;
			window.requestAnimationFrame(run);
		}
		window.requestAnimationFrame(run);
	}

	public function addPlayer():Player {
		var player = new Player();
		players.push(player);
		return player;
	}

	function update(dt:Float) {
		for (player in players) {
			player.x += dt * player.dx;
			player.y += dt * player.dy;
		}
	}
}

class Player {
	public var x(default, set):Float = 0;
	public var y(default, set):Float = 0;
	public var dx:Float = 20;
	public var dy:Float = 0;

	var div:DivElement;

	public function new() {
		div = document.createDivElement();
		div.style.position = 'absolute';
		div.style.width = '10px';
		div.style.height = '10px';
		div.style.backgroundColor = 'red';
		document.body.appendChild(div);
	}

	function set_x(v) {
		this.x = v;
		div.style.left = v + 'px';
		return v;
	}

	function set_y(v) {
		this.y = v;
		div.style.top = v + 'px';
		return v;
	}
}

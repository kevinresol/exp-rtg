package;

import why.qrcode.printer.DataUrlPrinter;
import why.qrcode.encoder.JsEncoder;
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
				var url = location.href + '?id=$id';
				
				new JsEncoder(L).encode(url)
					.next(data -> new DataUrlPrinter().print(data))
					.next(v -> {
						var a = document.createAnchorElement();
						a.href = url;
						a.target = '_blank';
						
						var img = document.createImageElement();
						img.src = v;
						img.style.position = 'absolute';
						img.style.opacity = '0.3';
						
						a.appendChild(img);
						document.body.appendChild(a);
					})
					.handle(o -> trace(o));
				
				host.rooms.created.handle(function(room) {
					var game = new Game();
					trace('room ${room.id} created');
					room.guests.connected.handle(function(guest) {
						trace('guest ${guest.id} connected');
						var player = game.addPlayer();
						
						player.dead.handle(function(_) game.removePlayer(player));
						
						guest.data.map(chunk -> tink.Json.parse((chunk:Command))).handle(function(o) switch o {
							case Success(Turn(turn)):
								player.dir = switch [player.dir, turn] {
									case [Up, Left]: Left;
									case [Down, Left]: Right;
									case [Left, Left]: Down;
									case [Right, Left]: Up;
									case [Up, Right]: Right;
									case [Down, Right]: Left;
									case [Left, Right]: Up;
									case [Right, Right]: Down;
								}
								
							case Failure(e):
								trace(e);
						});
						
						guest.disconnected.handle(function(o) {
							trace('guest ${guest.id} disconnected, error: ${Std.string(o)}');
							game.removePlayer(player);
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
						
						var container = document.createDivElement();
						container.style.display = 'flex';
						container.style.width = '100vw';
						container.style.height = '100vh';
						document.body.appendChild(container);

						function addButton(text:String, value:Turn) {
							var button = document.createButtonElement();
							button.style.flex = '1';
							button.innerText = text;
							button.onclick = function() seat.send(tink.Json.stringify(Command.Turn(value)));
							container.appendChild(button);
						}

						addButton('Left', Left);
						addButton('Right', Right);

					case Failure(e):
						trace(e);
				});
			case Failure(e):
				trace(e);
		});
	}
}


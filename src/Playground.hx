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
						guest.data.map(chunk -> tink.Json.parse((chunk:Command))).handle(function(o) switch o {
							case Success(SetDirection(dir)):
								player.dir = dir;
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

						function addButton(text:String, value:Direction) {
							var button = document.createButtonElement();
							button.innerText = text;
							button.onclick = function() seat.send(tink.Json.stringify(Command.SetDirection(value)));
							document.body.appendChild(button);
						}

						addButton('Right', Right);
						addButton('Left', Left);
						addButton('Down', Down);
						addButton('Up', Up);

					case Failure(e):
						trace(e);
				});
			case Failure(e):
				trace(e);
		});
	}
}


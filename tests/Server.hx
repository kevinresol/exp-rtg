package;

import exp.rtg.*;
import why.duplex.websocket.*;

class Server {
	static function main() {
		return Host.create(WebSocketServer.bind.bind({port: 8585}), v -> v == 'chat')
			.handle(function(o) switch o {
				case Success(host):
					trace('host is up');
					host.rooms.created.handle(function(room) {
						trace('room created ${room.id}');
						room.guests.connected.handle(function(guest) {
							trace('room ${room.id}: guest ${guest.id} connected');
						});
						room.guests.disconnected.handle(function(guest) {
							trace('room ${room.id}: guest ${guest.id} disconnected');
						});
					});
				case Failure(e):
					trace(e);
			});
	}
}
package;

import tink.unit.*;
import tink.testrunner.*;
import exp.rtg.*;
import why.duplex.websocket.*;

using tink.CoreApi;

@:asserts
class RunTests {
	static function main() {
		Runner.run(TestBatch.make([new RunTests(),])).handle(Runner.exit);
	}

	function new() {}

	var host:Host;

	@:setup
	public function setup() {
		return Host.create(WebSocketServer.bind.bind({port: 8585}), v -> v == 'chat').next(host -> {
			this.host = host;
			Noise;
		});
	}

	public function createRoom() {
		var type = 'chat';

		host.rooms.created.handle(function(room) {
			asserts.assert(room.type == type);
		});

		Guest.connect(WebSocketClient.connect.bind('ws://localhost:8585'))
			.next(guest -> guest.createRoom('chat'))
			.next(id -> asserts.assert(id != null))
			.handle(asserts.handle);

		return asserts;
	}

	public function joinRoom() {
		var type = 'chat';
		var message = 'Joined!';
		var roomId = new tink.state.State(null);
		var count = 0;

		host.rooms.created.handle(function(room) {
			room.guests.connected.handle(function(guest) {
				count++;
				guest.data.handle(function(chunk) {
					asserts.assert(chunk.toString() == message + guest.id);
				});
			});
		});

		function join(guest:Guest, id) {
			return guest.joinRoom(id).next(seat -> seat.send(message + seat.id));
		}

		Guest.connect(WebSocketClient.connect.bind('ws://localhost:8585')).next(guest -> {
			guest.createRoom(type).next(id -> {
				roomId.set(id);
				join(guest, id);
			});
		}).eager();

		roomId.bind({direct: false}, id -> Guest.connect(WebSocketClient.connect.bind('ws://localhost:8585')).next(join.bind(_, id)).eager());
		roomId.bind({direct: false}, id -> Guest.connect(WebSocketClient.connect.bind('ws://localhost:8585')).next(join.bind(_, id)).eager());
		roomId.bind({direct: false}, id -> Guest.connect(WebSocketClient.connect.bind('ws://localhost:8585')).next(join.bind(_, id)).eager());

		haxe.Timer.delay(function() {
			asserts.assert(count == 4);
			asserts.done();
		}, 100);

		return asserts;
	}
}

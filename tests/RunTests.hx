package;

import tink.unit.*;
import tink.testrunner.*;
import exp.rtg.*;
import why.duplex.websocket.*;

using tink.CoreApi;
using RunTests.HostTools;

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

		Promise.inParallel([
			host.waitForRoomCreation().next(room -> asserts.assert(room.type == type)).noise(),
			Guest.connect(WebSocketClient.connect.bind('ws://localhost:8585'))
				.next(guest -> guest.createRoom('chat'))
				.next(id -> asserts.assert(id != null))
				.noise(),
		]).handle(asserts.handle);

		return asserts;
	}

	public function joinRoom() {
		var type = 'chat';
		var message = 'Joined! ';
		var roomId = Future.trigger();
		Promise.inParallel([
			host.waitForRoomCreation().next(room -> {
				new Promise(function(resolve, reject) {
					var count = 0;
					room.guests.connected.handle(function(guest) {
						guest.waitForData().handle(function(o) switch o {
							case Success(chunk):
								asserts.assert(chunk.toString() == message + guest.id);
								if (++count == 4)
									resolve(Noise);
							case Failure(e):
								reject(e);
						});
					});
				});
			}).noise(),
			Guest.connect(WebSocketClient.connect.bind('ws://localhost:8585')).next(guest -> {
				guest.createRoom(type).next(id -> {
					roomId.trigger(id);

					function join(guest:Guest) {
						return guest.joinRoom(id).next(seat -> seat.send(message + seat.id));
					}

					Promise.inParallel([
						join(guest),
						Promise.inParallel([
							for (i in 0...3)
								Guest.connect(WebSocketClient.connect.bind('ws://localhost:8585')).next(join)
						]),
					]);
				});
			}).noise(),
		]).handle(asserts.handle);

		return asserts;
	}
}

class HostTools {
	static final TIMED_OUT = new Error('Timed out');

	public static function waitForRoomCreation(host:Host, timeout = 1000):Promise<Host.Room> {
		return host.rooms.created.nextTime().map(Success).first(Future.delay(timeout, Failure(TIMED_OUT)));
	}

	public static function waitForData(guest:Host.RoomGuest, timeout = 1000):Promise<tink.Chunk> {
		return guest.data.nextTime().map(Success).first(Future.delay(timeout, Failure(TIMED_OUT)));
	}
}

package exp.rtg;

import exp.rtg.message.*;
import why.duplex.*;

using tink.CoreApi;

class Guest {
	public final disconnected:Future<Option<Error>>;

	final data:Signal<Outcome<Downlink, Error>>;

	final client:Client;

	public static function connect(createClient:() -> Promise<Client>):Promise<Guest> {
		return createClient().next(Guest.new);
	}

	function new(client:Client) {
		this.client = client;
		disconnected = client.disconnected;
		data = client.data.map(v -> tink.Json.parse((v : Downlink)));
	}

	public function createRoom(type:String):Promise<Int> {
		return send(Metadata(CreateRoom(type))).next(_ -> {
			data.select(v -> switch v {
				case Success(Metadata(RoomCreated(id, t))) if (t == type):
					Some(Success(id));
				case Success(Metadata(RoomCreateFailed(t, reason))) if (t == type):
					Some(Failure(new Error(reason.getName())));
				case _:
					None;
			}).nextTime().first(Future.delay(10000, Failure(new Error('Timed out when creating room of type "$type"'))));
		});
	}

	public function joinRoom(id:Int):Promise<Seat> {
		return send(Metadata(JoinRoom(id))).next(_ -> {
			data.select(v -> switch v {
				case Success(Metadata(RoomJoined(i, as, type))) if (i == id):
					Some(Success(new Seat(as, {id: id, type: type}, this)));
				case Success(Metadata(RoomJoinFailed(i, reason))) if (i == id):
					Some(Failure(new Error(reason.getName())));
				case _:
					None;
			}).nextTime().first(Future.delay(10000, Failure(new Error('Timed out when joining room "$id"'))));
		});
	}

	public function rejoinRoom(id:Int, gid:Int):Promise<Seat> {
		return send(Metadata(RejoinRoom(id, gid))).next(_ -> {
			data.select(v -> switch v {
				case Success(Metadata(RoomRejoined(i, as, type))) if (i == id && as == gid):
					Some(Success(new Seat(as, {id: id, type: type}, this)));
				case Success(Metadata(RoomRejoinFailed(i, as, reason))) if (i == id && as == gid):
					Some(Failure(new Error(reason.getName())));
				case _:
					None;
			}).nextTime().first(Future.delay(10000, Failure(new Error('Timed out when rejoining room "$id" as "$gid"'))));
		});
	}

	public inline function send(message:Uplink):Promise<Noise> {
		return client.send(tink.Json.stringify(message));
	}

	public inline function disconnect():Future<Noise> {
		return client.disconnect();
	}
}

typedef RoomInfo = {
	final id:Int;
	final type:String;
	// final closed:Future<Noise>; // TODO;
}

interface SeatObject<Incoming, Outgoing> {
	final id:Int;
	final room:RoomInfo;
	final data:Signal<Incoming>;
	function send(data:Outgoing):Promise<Noise>;
	function leave():Future<Noise>;
}

@:access(exp.rtg)
class Seat implements SeatObject<Chunk, Chunk> {
	public final id:Int;
	public final room:{
		final id:Int;
		final type:String;
		// final closed:Future<Noise>; // TODO;
	}
	public final data:Signal<Chunk>;

	final guest:Guest;

	public function new(id, room, guest) {
		this.id = id;
		this.room = room;
		this.guest = guest;

		data = guest.data.select(o -> switch o {
			case Success(Data(id, data)) if (id == room.id): Some(data);
			case _: None;
		});
	}

	public function wrap<In, Out>(serialize:Out->Chunk, unserialize:Chunk->Outcome<In, Error>):SeatObject<Outcome<In, Error>, Out> {
		return new WrappedSeat(this, serialize, unserialize);
	}

	public function send(data:Chunk):Promise<Noise> {
		return guest.send(Data(room.id, data));
	}

	public function leave():Future<Noise> {
		throw 'TODO';
	}
}

class WrappedSeat<In, Out> implements SeatObject<Outcome<In, Error>, Out> {
	public final id:Int;
	public final room:RoomInfo;
	public final data:Signal<Outcome<In, Error>>;

	final serialize:Out->Chunk;
	final seat:Seat;

	public function new(seat:Seat, serialize:Out->Chunk, unserialize:Chunk->Outcome<In, Error>) {
		this.seat = seat;
		this.id = seat.id;
		this.room = seat.room;
		this.serialize = serialize;
		this.data = seat.data.map(unserialize);
	}

	public function send(data:Out):Promise<Noise> {
		return seat.send(serialize(data));
	}

	public function leave():Future<Noise> {
		return seat.leave();
	}
}

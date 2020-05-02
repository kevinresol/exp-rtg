package exp.rtg;

import exp.rtg.message.*;
import why.duplex.*;

using tink.CoreApi;

class Guest {
	
	public final disconnected:Future<Option<Error>>;
	final data:Signal<Outcome<Downlink, Error>>;
	
	final client:Client;
	
	public static function connect(createClient:()->Promise<Client>):Promise<Guest> {
		return createClient().next(Guest.new);
	}

	function new(client:Client) {
		this.client = client;
		disconnected = client.disconnected;
		data = client.data.map(v -> tink.Json.parse((v:Downlink)));
	}
	
	public function createRoom(type:String):Promise<Int> {
		return send(Metadata(CreateRoom(type)))
			.next(_ -> {
				data
					.select(v -> switch v {
						case Success(Metadata(RoomCreated(id, t))) if(t == type):
							Some(Success(id));
						case Success(Metadata(RoomCreateFailed(t, reason))) if(t == type):
							Some(Failure(new Error(reason.getName())));
						case _:
							None;
					})
					.nextTime()
					.first(Future.delay(10000, Failure(new Error('Timed out when creating room of type "$type"'))));
			});
	}
	
	public function joinRoom(id:Int):Promise<Seat> {
		return send(Metadata(JoinRoom(id)))
			.next(_ -> {
				data
					.select(v -> switch v {
						case Success(Metadata(RoomJoined(i, as, type))) if(i == id):
							Some(Success(new Seat(as, {id: id, type: type}, this)));
						case Success(Metadata(RoomJoinFailed(i, reason))) if(i == id):
							Some(Failure(new Error(reason.getName())));
						case _:
							None;
					})
					.nextTime()
					.first(Future.delay(10000, Failure(new Error('Timed out when joining room "$id"'))));
			});
	}
	
	public function rejoinRoom(id:Int, gid:Int):Promise<Seat> {
		return send(Metadata(RejoinRoom(id, gid)))
			.next(_ -> {
				data
					.select(v -> switch v {
						case Success(Metadata(RoomRejoined(i, as, type))) if(i == id && as == gid):
							Some(Success(new Seat(as, {id: id, type: type}, this)));
						case Success(Metadata(RoomRejoinFailed(i, as, reason))) if(i == id && as == gid):
							Some(Failure(new Error(reason.getName())));
						case _:
							None;
					})
					.nextTime()
					.first(Future.delay(10000, Failure(new Error('Timed out when rejoining room "$id" as "$gid"'))));
			});
	}
	
	public inline function send(message:Uplink):Promise<Noise> {
		return client.send(tink.Json.stringify(message));
	}
	
	public inline function disconnect():Future<Noise> {
		return client.disconnect();
	}
}



@:access(exp.rtg)
class Seat {
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
			case Success(Data(id, data)) if(this.id == id): Some(data);
			case _: None;
		});
	}
	
	public function send(data:Chunk):Promise<Noise> {
		return guest.send(Data(room.id, data));
	}
	
	public function leave():Future<Noise> {
		throw 'TODO';
	}
}


// final disconnected:Future<Option<Error>>;
// final data:Signal<Chunk>;
// function send(data:Chunk):Promise<Noise>;
// function disconnect():Future<Noise>;
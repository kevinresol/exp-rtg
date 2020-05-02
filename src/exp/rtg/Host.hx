package exp.rtg;

import why.duplex.*;
import exp.rtg.message.*;
import tink.state.*;

using tink.CoreApi;

@:access(exp.rtg)
class Host {
	
	public final rooms:Rooms;
	
	public static function create(createServer:()->Promise<Server>, roomTypeSupported):Promise<Host> {
		return createServer().next(Host.new.bind(roomTypeSupported));
	}
	
	function new(roomTypeSupported:String->Bool, server:Server) {
		rooms = new Rooms();
		server.connected.handle(client -> {
			var guest = new HostGuest(client);
			guest.data.handle(function(command) {
				switch command {
					case Success(Metadata(CreateRoom(type))):
						if(roomTypeSupported(type)) {
							var room = new Room(type);
							rooms.add(room);
							guest.send(Metadata(RoomCreated(room.id, type)));
						} else {
							guest.send(Metadata(RoomCreateFailed(type, UnsupportedType)));
						}
						
					case Success(Metadata(JoinRoom(id))):
						switch rooms.get(id) {
							case null:
								guest.send(Metadata(RoomJoinFailed(id, NotExist)));
							case room:
								var roomGuest = new RoomGuest(guest, room);
								room.guests.add(roomGuest);
								roomGuest.disconnected.handle(_ -> room.guests.remove(roomGuest.id));
								guest.send(Metadata(RoomJoined(id, roomGuest.id, room.type)));
						}
						
					case Success(Metadata(RejoinRoom(id, as))):
						switch rooms.get(id) {
							case null:
								guest.send(Metadata(RoomRejoinFailed(id, as, NotExist)));
							case room:
								switch room.pendingRejoin[as] {
									case null:
										guest.send(Metadata(RoomRejoinFailed(id, as, NotExist)));
									case slot:
										slot.trigger(Success(new RoomGuest(guest, room, as)));
										guest.send(Metadata(RoomRejoined(id, as, room.type)));
								}
						}
						
					case Success(Metadata(LeaveRoom(id))):
						switch rooms.get(id) {
							case null:
								guest.send(Metadata(RoomLeaveFailed(id, NotExist)));
							case room:
								if(room.guests.remove(id)) {
									guest.send(Metadata(RoomLeft(id)));
								} else {
									guest.send(Metadata(RoomLeaveFailed(id, NotJoined)));
								}
						}
						
					case Success(Metadata(CloseRoom(id))):
						switch rooms.get(id) {
							case null:
								guest.send(Metadata(RoomCloseFailed(id, NotExist)));
							case room:
								room.close();
								// broadcast performed by room
						}
						
					case Success(Data(id, data)):
						// handled in room
						
					case Failure(e):
						// invalid uplink
				}
			});
		});
	}
	
	public function destroy() {
		
	}
}

@:access(exp.rtg)
private class Room {
	static var ids = 0;
	
	public final id:Int;
	public final type:String;
	public final guests:RoomGuests;
	
	final pendingRejoin:Map<Int, PromiseTrigger<RoomGuest>>;
	var guestIds = 0;
	
	public function new(type) {
		this.id = ids++;
		this.type = type;
		this.guests = new RoomGuests();
		this.pendingRejoin = new Map();
	}
	
	public inline function broadcast(data:Chunk) {
		_broadcast(Data(id, data));
	}
	
	public function close() {
		_broadcast(Metadata(RoomClosed(id)));
		destroy();
	}
	
	public function waitForRejoin(guest:RoomGuest, expiry:Future<Noise>):Promise<RoomGuest> {
		var trigger = Promise.trigger();
		pendingRejoin[guest.id] = trigger;
		return trigger;
	}
	
	
	function _broadcast(message:Downlink) {
		var serialized = tink.Json.stringify(message);
		for(guest in guests) guest.guest.client.send(serialized); // bypass serializations
	}
	
	inline function nextGuestId() {
		return guestIds++;
	}
	
	inline function destroy() {
		// TODO: cleanup
	}
}

@:access(tink.state)
class Rooms {
	public final created:Signal<Room>;
	
	final map:ObservableMap<Int, Room> = new ObservableMap([]);
	
	public function new() {
		created = new Signal(cb -> {
			map.changes.handle(change -> switch change {
				case {from: None, to: Some(v)}: cb.invoke(v);
				case _:
			});
		});
	}
	
	inline function get(id:Int):Room {
		return map.get(id);
	}
		
	inline function add(room:Room) {
		map.set(room.id, room);
	}
	
	inline function remove(id:Int) {
		map.remove(id);
	}
}

@:access(tink.state)
class RoomGuests {
	public final connected:Signal<RoomGuest>;
	public final disconnected:Signal<RoomGuest>;
	
	final array:ObservableArray<RoomGuest> = new ObservableArray();
	
	public function new() {
		connected = new Signal(cb -> {
			array.changes.handle(change -> switch change {
				case Insert(index, values): for(v in values) cb.invoke(v);
				case _:
			});
		});
		disconnected = new Signal(cb -> {
			array.changes.handle(change -> switch change {
				case Remove(index, values): for(v in values) cb.invoke(v);
				case _:
			});
		});
	}
	
	public inline function iterator()
		return array.values();
	
	public inline function add(guest:RoomGuest) {
		array.push(guest);
	}
		
	public function remove(id:Int):Bool {
		for(guest in array.values()) {
			if(guest.id == id) {
				array.remove(guest);
				return true;
			}
		}
		return false;
	}
}

class HostGuest {
	public final disconnected:Future<Option<Error>>;
	public final data:Signal<Outcome<Uplink, Error>>;
	
	final client:Client;
	
	public function new(client:Client) {
		this.client = client;
		disconnected = client.disconnected;
		data = client.data.map(v -> tink.Json.parse((v:Uplink)));
	}
	
	public function send(message:Downlink):Promise<Noise> {
		return client.send(tink.Json.stringify(message));
	}
	
	public function disconnect():Future<Noise> {
		return client.disconnect();
	}
}

@:access(exp.rtg)
class RoomGuest {
	public final id:Int;
	public final disconnected:Future<Option<Error>>;
	public final data:Signal<Chunk>;
	
	final room:Room;
	final guest:HostGuest;
	
	public function new(guest:HostGuest, room:Room, ?id:Int) {
		this.room = room;
		this.guest = guest;
		this.id = id == null ? room.nextGuestId() : id;
		disconnected = guest.disconnected;
		data = guest.data.select(v -> switch v {
			case Success(Data(id, data)) if(id == room.id): Some(data);
			case _: None;
		});
	}
	
	public function send(data:Chunk):Promise<Noise> {
		return guest.send(Data(room.id, data));
	}
	
	public function disconnect():Future<Noise> {
		return guest.disconnect();
	}
}
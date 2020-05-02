package exp.rtg.message;

enum Downlink {
	Metadata(v:DownlinkMeta);
	Data(roomId:Int, v:Chunk);
}

enum DownlinkMeta {
	RoomCreated(id:Int, type:String);
	RoomJoined(id:Int, gid:Int, type:String);
	RoomRejoined(id:Int, gid:Int, type:String);
	RoomLeft(id:Int);
	RoomClosed(id:Int);
	
	RoomCreateFailed(type:String, reason:RoomCreateFailReason);
	RoomJoinFailed(id:Int, reason:RoomJoinFailReason);
	RoomRejoinFailed(id:Int, gid:Int, reason:RoomRejoinFailReason);
	RoomLeaveFailed(id:Int, reason:RoomLeaveFailReason);
	RoomCloseFailed(id:Int, reason:RoomCloseFailReason);
}

enum RoomCreateFailReason {
	UnsupportedType;
}

enum RoomJoinFailReason {
	NotExist;
}

enum RoomRejoinFailReason {
	NotExist;
}

enum RoomLeaveFailReason {
	NotExist;
	NotJoined;
}

enum RoomCloseFailReason {
	NotExist;
	NotHost;
}
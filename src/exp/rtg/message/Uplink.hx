package exp.rtg.message;


enum Uplink {
	Metadata(v:UplinkMeta);
	Data(roomId:Int, v:Chunk);
}

enum UplinkMeta {
	CreateRoom(type:String);
	JoinRoom(id:Int);
	RejoinRoom(id:Int, gid:Int);
	LeaveRoom(id:Int);
	CloseRoom(id:Int);
}
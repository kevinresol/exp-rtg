package exp.rtg;

using tink.CoreApi;

interface HostTransport<Command, Message> {
	final events:Signal<HostEvent<Command>>;
	function sendToGuest(id:Int, message:Message):Promise<Noise>;
	function broadcast(message:Message):Promise<Noise>;
}

interface GuestTransport<Command, Message> {
	final events:Signal<GuestEvent<Message>>;
	function connect():Promise<Noise>;
	function disconnect():Promise<Noise>;
	function sendToHost(command:Command):Promise<Noise>;
}


enum HostEvent<Command> {
	GuestConnected(id:Int);
	GuestDisonnected(id:Int);
	CommandReceived(id:Int, command:Command);
	Errored(error:Error);
}

enum GuestEvent<Message> {
	Connected;
	Disconnected;
	MessageReceived(message:Message);
	Errored(error:Error);
}

class StringTransport<UplinkMeta, DownlinkMeta, Command, Message> {
	function stringifyDownlink(down:DownlinkEnvelope<DownlinkMeta, Message>):String throw 'abstract';
	function stringifyUplink(up:UplinkEnvelope<UplinkMeta, Command>):String throw 'abstract';
	function parseDownlink(s:String):Outcome<DownlinkEnvelope<DownlinkMeta, Message>, Error> throw 'abstract';
	function parseUplink(s:String):Outcome<UplinkEnvelope<UplinkMeta, Command>, Error> throw 'abstract';
}


enum UplinkEnvelope<Meta, Command> {
	Meta(meta:Meta);
	Command(command:Command);
}

enum DownlinkEnvelope<Meta, Message> {
	Meta(meta:Meta);
	Message(message:Message);
}
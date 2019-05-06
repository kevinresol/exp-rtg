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
	Disonnected;
	MessageReceived(message:Message);
	Errored(error:Error);
}

class StringTransport<Command, Message> {
	function stringifyDownlink(down:DownlinkEnvelope<Message>):String throw 'abstract';
	function stringifyUplink(up:UplinkEnvelope<Command>):String throw 'abstract';
	function parseDownlink(s:String):Outcome<DownlinkEnvelope<Message>, Error> throw 'abstract';
	function parseUplink(s:String):Outcome<UplinkEnvelope<Command>, Error> throw 'abstract';
}


enum UplinkEnvelope<Command> {
	Command(command:Command);
}

enum DownlinkEnvelope<Message> {
	Connected(id:Int);
	Message(message:Message);
}
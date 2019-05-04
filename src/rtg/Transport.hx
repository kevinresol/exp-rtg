package rtg;

using tink.CoreApi;

interface HostTransport<Command, Message> {
	final events:Signal<HostEvent<Command>>;
	function sendToPlayer(id:Int, message:Message):Promise<Noise>;
	function broadcast(message:Message):Promise<Noise>;
}

interface PlayerTransport<Command, Message> {
	final events:Signal<PlayerEvent<Message>>;
	function connect():Promise<Noise>;
	function disconnect():Promise<Noise>;
	function sendToHost(command:Command):Promise<Noise>;
}


enum HostEvent<Command> {
	PlayerConnected(id:Int);
	PlayerDisonnected(id:Int);
	CommandReceived(id:Int, command:Command);
}

enum PlayerEvent<Message> {
	Connected;
	Disonnected;
	MessageReceived(message:Message);
}
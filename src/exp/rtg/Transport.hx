package exp.rtg;

import tink.Chunk;
using tink.CoreApi;

interface HostTransport {
	final events:Signal<HostEvent>;
	function sendToGuest(id:Int, data:Chunk):Promise<Noise>;
	function broadcast(data:Chunk):Promise<Noise>;
}

interface GuestTransport {
	final events:Signal<GuestEvent>;
	function connect():Promise<Noise>;
	function disconnect():Promise<Noise>;
	function sendToHost(data:Chunk):Promise<Noise>;
}


enum HostEvent {
	GuestConnected(id:Int);
	GuestDisonnected(id:Int);
	DataReceived(id:Int, data:Chunk);
	Errored(error:Error);
}

enum GuestEvent {
	Connected;
	Disconnected;
	DataReceived(data:Chunk);
	Errored(error:Error);
}


enum UplinkEnvelope<Meta> {
	Metadata(meta:Meta);
	Data(v:Chunk);
}

enum DownlinkEnvelope<Meta> {
	Metadata(meta:Meta);
	Data(v:Chunk);
}
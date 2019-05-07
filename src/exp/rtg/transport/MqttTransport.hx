package exp.rtg.transport;

import mqtt.Client;
import exp.rtg.Transport;

using tink.CoreApi;
using StringTools;

@:genericBuild(exp.rtg.Macro.buildStringTransport(exp.rtg.transport.MqttTransport.MqttHostTransportBase))
class MqttHostTransport<Command, Message> {}

class MqttHostTransportBase<Command, Message> extends StringTransport<UplinkMeta, DownlinkMeta, Command, Message> implements HostTransport<Command, Message> {
	public final events:Signal<HostEvent<Command>>;
	
	final client:Client;
	final topic:TopicHandler;
	
	final clients:Array<Int> = [];
	
	var count = 0;
	
	public function new(client, topicPrefix) {
		this.client = client;
		this.topic = new TopicHandler(topicPrefix);
		
		events = Signal.generate(trigger -> {
			client.messageReceived.handle(function(message) {
				switch [topic.parse(message.topic), parseUplink(message.content)] {
					case [Success(Uplink(Lobby)), Success(Meta(Join(hash)))]:
						final id = count++;
						client.publish(topic.build(Downlink(Lobby)), stringifyDownlink(Meta(Allocated(hash, id))));
						trigger(GuestConnected(id));
					case [Success(Uplink(Peer(id))), Success(Command(command))]:
						trigger(CommandReceived(id, command));
					case [topic, content]:
						// trace(topic, content);
				}
			});
		});
		
		client.connect()
			.next(_ -> client.subscribe(topic.build(Uplink(All))))
			.handle(o -> trace(o));
	}
	
	public function sendToGuest(id:Int, message:Message):Promise<Noise> {
		return client.publish(topic.build(Downlink(Peer(id))), stringifyDownlink(Message(message)));
	}
	
	public function broadcast(message:Message):Promise<Noise> {
		var content = stringifyDownlink(Message(message));
		return Promise.inParallel([for(id in clients) client.publish(topic.build(Downlink(Peer(id))), content)]);
	}
}

@:genericBuild(exp.rtg.Macro.buildStringTransport(exp.rtg.transport.MqttTransport.MqttGuestTransportBase))
class MqttGuestTransport<Command, Message> {}

class MqttGuestTransportBase<Command, Message> extends StringTransport<UplinkMeta, DownlinkMeta, Command, Message> implements GuestTransport<Command, Message> {
	public final events:Signal<GuestEvent<Message>>;
	
	final trigger:SignalTrigger<GuestEvent<Message>>;
	final client:Client;
	final topic:TopicHandler;
	var id:Int = null;
	
	public function new(client, topicPrefix) {
		this.client = client;
		this.topic = new TopicHandler(topicPrefix);
		trigger = Signal.trigger();
		events = trigger;
	}
	
	public function connect():Promise<Noise> {
		return new Promise((resolve, reject) -> {
			var hash = 'random_' + Std.random(1<<24);
			client.messageReceived.handle(message -> switch [topic.parse(message.topic), parseDownlink(message.content)] {
				case [Success(Downlink(Lobby)), Success(Meta(Allocated(_hash, id)))] if(_hash == hash):
					this.id = id;
					client.unsubscribe(topic.build(Downlink(Lobby)));
					client.subscribe(topic.build(Downlink(Peer(id))));
					trigger.trigger(Connected);
					resolve(Noise);
				case [Success(Downlink(Peer(_))), Success(Message(message))]:
					trigger.trigger(MessageReceived(message));
				case _:
					// 
			});
			client.connect()
				.next(_ -> {
					client.subscribe(topic.build(Downlink(Lobby)));
					client.publish(topic.build(Uplink(Lobby)), stringifyUplink(Meta(Join(hash))));
				})
				.handle(o -> switch o {
					case Success(_): // ok
					case Failure(e): reject(e);
				});
		});
	}
	
	public function disconnect():Promise<Noise> {
		return client.close();
	}
	
	public function sendToHost(command:Command):Promise<Noise> {
		return client.publish(topic.build(Uplink(Peer(id))), stringifyUplink(Command(command)));
	}
}

class TopicHandler {
	final prefix:String;
	static final UNRECOGNIZED_ERROR = new Error(BadRequest, 'Unrecognized topic');
	
	public function new(prefix) {
		this.prefix = prefix;
	}
	
	public function parse(v:String) {
		if(!v.startsWith(prefix)) return Failure(UNRECOGNIZED_ERROR);
		return switch v.substr(prefix.length + 1).split('/') {
			case ['downlink', 'lobby']: Success(Downlink(Lobby));
			case ['uplink', 'lobby']: Success(Uplink(Lobby));
			case ['downlink', 'peer', Std.parseInt(_) => id] if(id != null): Success(Downlink(Peer(id)));
			case ['uplink', 'peer', Std.parseInt(_) => id] if(id != null): Success(Uplink(Peer(id)));
			case _: Failure(UNRECOGNIZED_ERROR);
		}
	}
	
	public function build(topic:Topic) {
		return prefix + switch topic {
			case Downlink(All): '/downlink/#';
			case Uplink(All): '/uplink/#';
			case Downlink(Lobby): '/downlink/lobby';
			case Uplink(Lobby): '/uplink/lobby';
			case Downlink(Peer(id)): '/downlink/peer/$id';
			case Uplink(Peer(id)): '/uplink/peer/$id';
		}
	}
}

private enum Topic {
	Downlink(channel:Channel);
	Uplink(channel:Channel);
}

private enum Channel {
	All;
	Lobby;
	Peer(id:Int);
}

private enum UplinkMeta {
	Join(hash:String);
}

private enum DownlinkMeta {
	Allocated(hash:String, id:Int);
}


import rtg.transport.WebSocketTransport;
import tink.websocket.clients.*;
import Command;

using tink.CoreApi;

class Client {
	static function main() {
		var transport = new WebSocketPlayerTransport(() -> new tink.websocket.Client(new JsConnector('ws://localhost:8134')));
		
		transport.connect()
			.handle(o -> {
				if(o.isSuccess()) {
					js.Browser.document.body.onkeypress = function(e) switch e.keyCode {
						case 119: transport.sendToHost(ChangeDirection(North)); // w
						case 100: transport.sendToHost(ChangeDirection(East)); // d
						case 115: transport.sendToHost(ChangeDirection(South)); // s
						case 97: transport.sendToHost(ChangeDirection(West)); // a
					}
				}
			});
	}
}
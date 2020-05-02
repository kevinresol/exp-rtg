package;

import exp.rtg.*;
import why.duplex.websocket.*;

using tink.CoreApi;

class Client {
	static function main() {
		Guest.connect(WebSocketClient.connect.bind('ws://localhost:8585'))
			.next(guest -> guest.createRoom('chat').next(guest.joinRoom))
			.handle(function(o) switch o {
				case Success(seat):
					
				case Failure(e):
			});
	}
}
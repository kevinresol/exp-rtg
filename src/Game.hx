package;

import haxe.Timer;
import js.Browser.*;
import js.html.DivElement;

class Game {
	final players:Array<Player> = [];

	public function new() {
		var timer = new Timer(100);
		timer.run = step;
	}

	public function removePlayer(v:Player) {
		v.destroy();
		players.remove(v);
	}
	
	public function addPlayer():Player {
		var player = new Player();
		players.push(player);
		return player;
	}

	function step() {
		for (player in players) {
			player.step();
		}
	}
}

class Player {
	public var dir:Direction = Right;
	public var list:List<Block> = new List();

	public function new() {
		list.add(new Block(0, 0));
		list.add(new Block(1, 0));
		list.add(new Block(2, 0));
		list.add(new Block(3, 0));
		list.add(new Block(4, 0));
	}
	
	public function step() {
		var head = list.last();
		var tail = list.pop();
		
		switch dir {
			case Up: 
				tail.set(head.x, head.y - 1);
			case Down: 
				tail.set(head.x, head.y + 1);
			case Left: 
				tail.set(head.x - 1, head.y);
			case Right: 
				tail.set(head.x + 1, head.y);
		}
		
		// move tail to head
		list.add(tail);
	}
	
	public inline function destroy() {
		for(v in list) v.destroy();
	}
}

class Block {
	public var y(default, null):Int;
	public var x(default, null):Int;

	var div:DivElement;

	public function new(x, y) {
		div = document.createDivElement();
		div.style.position = 'absolute';
		div.style.width = '10px';
		div.style.height = '10px';
		div.style.backgroundColor = 'red';
		document.body.appendChild(div);
		set(x, y);
	}
	
	public function set(x, y) {
		this.x = x;
		this.y = y;
		div.style.left = (x * 10) + 'px';
		div.style.top = (y * 10) + 'px';
	}
	
	public inline function destroy() {
		document.body.removeChild(div);
		div = null;
	}
}

package;

import haxe.Timer;
import js.Browser.*;
import js.html.DivElement;

using tink.CoreApi;

class Game {
	
	public static inline final W:Int = 60;
	public static inline final H:Int = 50;
	
	final players:Array<Player> = [];
	final cells:Array<Array<Int>> = [for(_ in 0...W) [for(_ in 0...H) -1]];
	
	var food:Block;

	public function new() {
		var timer = new Timer(100);
		timer.run = step;
		
		var div = document.createDivElement();
		div.style.width = (W * 10) + 'px';
		div.style.height = (H * 10) + 'px';
		div.style.border = 'solid 1px black';
		document.body.appendChild(div);
		refresh();
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
	
	function refresh() {
		if(food != null) food.destroy();
		food = new Block(Std.random(W), Std.random(H), 'green');
	}

	function step() {
		for(i in 0...W) for(j in 0...H) cells[i][j] = -1;
		var eaten = false;
		for (player in players) {
			
			if(player.step(food))
				eaten = true;
			
			for(block in player.list)
				cells[block.x][block.y] = player.id;
		}
		for (player in players) {
			var head = player.head();
			var occupied = cells[head.x][head.y];
			if(occupied != -1 && occupied != player.id)
				player.die();
		}
		if(eaten) refresh();
	}
}



class Player {
	static var ids = 0;
	
	public final id:Int = ids ++;
	public var dir:Direction = Right;
	public var list:List<Block> = new List();
	public final dead:Future<Noise>;
	public var destroyed:Bool = false;
	
	final _dead:FutureTrigger<Noise>;

	public function new() {
		list.add(new Block(0, 0));
		list.add(new Block(1, 0));
		list.add(new Block(2, 0));
		list.add(new Block(3, 0));
		list.add(new Block(4, 0));
		
		dead = _dead = Future.trigger();
	}
	
	public function head() {
		return list.last();
	}
	
	public function step(food:Block) {
		trace(list.length);
		
		var head = list.last();
		var tail = list.pop();
		
		var x = head.x;
		var y = head.y;
		
		switch dir {
			case Up: 
				y = head.y - 1;
			case Down: 
				y = head.y + 1;
			case Left: 
				x = head.x - 1;
			case Right: 
				x = head.x + 1;
		}
		
		return if(x == food.x && y == food.y) {
			list.add(new Block(x, y));
			list.push(tail); // put back tail
			true;
		} else {
			// move tail to head
			tail.set(x, y);
			list.add(tail);
			false;
		}
		
	}
	
	public inline function destroy() {
		if(!destroyed) {
			destroyed = true;
			for(v in list) v.destroy();
		}
	}
	
	public function die() {
		_dead.trigger(Noise);
	}
}

class Block {
	public var y(default, null):Int;
	public var x(default, null):Int;

	var div:DivElement;

	public function new(x, y, color = 'red') {
		div = document.createDivElement();
		div.style.position = 'absolute';
		div.style.width = '10px';
		div.style.height = '10px';
		div.style.backgroundColor = color;
		document.body.appendChild(div);
		set(x, y);
	}
	
	public function set(x, y) {
		if(x < 0) x = Game.W - 1;
		if(x >= Game.W) x = 0;
		if(y < 0) y = Game.H - 1;
		if(y >= Game.H) y = 0;
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


enum Direction {
	North;
	South;
	East;
	West;
}

enum Command {
	ChangeDirection(dir:Direction);
}
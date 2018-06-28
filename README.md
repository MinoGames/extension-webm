## WEBM:

Information about webm:
* http://www.webmproject.org/

## Setup/Installing:

You need HAXE and OPENFL. http://openfl.org/

```
haxelib install openfl-webm
```

## Simple Example:

```haxe
var io:WebmIo = new WebmIoFile("c:/projects/test.webm");
var player:WebmPlayer = new WebmPlayer(io);
player.addEventListener('play', function(e) {
	trace('play!');
});
player.addEventListener('end', function(e) {
	trace('end!');
});
player.addEventListener('stop', function(e) {
	trace('stop!');
});
player.play();

addChild(player);
```

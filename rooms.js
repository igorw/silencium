function debug(message) {
	$('#debug').append($('<p>').text(message));
	$('#debug-container').scrollTop($('#debug-container').scrollTop() + 300);
}

$(document).ready(function () {
	WebSocket.__swfLocation = "web-socket-js/WebSocketMain.swf";
	
	var ws = new WebSocket("ws://localhost:4001"),
			server = new ServerEventDispatcher(ws);
	
	// debug
	
	server.bind('alert', function (event) {
		alert(event.message);
	});
	
	server.bind('debug', function (event) {
		debug(event.message);
	});
	
	// open (ws)
	
	server.bind('open', function (event) {
		debug('websocket connected');
	});
	
	// close (ws)
	
	server.bind('close', function (event) {
		debug('Error: Websocket closed');
	});
	
	// rooms
	
	server.bind('rooms', function (event) {
		$('#rooms').empty();
		$.each(event.rooms, function (key, room) {
			var li = $('<li>').append($('<a>').attr('href', 'game.html#' + room.port).text(room.name + ' (' + room.users + ')'));
			$('#rooms').append(li);
		});
	});
});

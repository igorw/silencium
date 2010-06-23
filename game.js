function debug(message) {
	$('#debug').append('<p>' + message + '</p>');
	$('#debug-container').scrollTop($('#debug-container').scrollTop() + 300);
}

function error(message) {
	$('#error').html('<p>' + message + '</p>');
}

function clear_errors() {
	$('#error').empty();
}

$(document).ready(function() {
	ws = new WebSocket("ws://localhost:3001");
	server = new ServerEventDispatcher(ws);
	
	// init
	
	$('#guess-container').hide();
	
	// debug
	
	server.bind('alert', function(event) {
		alert(event.message);
	});
	
	server.bind('debug', function(event) {
		debug(event.message);
	});
	
	// connect
	
	server.bind('connect', function(event) {
	});
	
	// close (ws)
	
	server.bind('close', function(event) {
		debug("Error: Websocket closed");
	});
	
	// join
	
	$('#join-container form').submit(function() {
		server.trigger('join', {
			username: $('#join-username').val()
		});
		return false;
	});
	
	server.bind('join', function(event) {
		if (event.accepted) {
			clear_errors();
			$('#join-container').hide();
			$('#guess-container').show();
		} else {
			error("Could not join: [" + event.message + "]");
		}
	});
});

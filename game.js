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

function chat_message(username, message) {
	var now = new Date();
	$('.chat-box > tbody:last').append('<tr>' +
			'<td>' + now.getHours() + ':' + now.getMinutes() + ':' + now.getSeconds() + '</td>' +
			'<td>' + username + '</td>' +
			'<td>' + message + '</td>' +
		'</tr>');
}

$(document).ready(function() {
	ws = new WebSocket("ws://localhost:3001");
	server = new ServerEventDispatcher(ws);
	
	// init
	
	$('#guess-container').hide();
	$('#users-container').hide();
	$('#fatal-error').hide();
	
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
		$('#game-container').hide();
		$('#fatal-error').show();
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
		if (!event.accepted) {
			error("Could not join: [" + event.message + "]");
			return;	
		}
		
		clear_errors();
		$('#join-container').hide();
		$('#guess-container').show();
		$('#users-container').show();
		
		server.trigger('users');
	});
	
	// guess
	
	$('#guess-container form').submit(function() {
		server.trigger('guess', {
			word: $('#guess-word').val()
		});
		$('#guess-word').val('');
		return false;
	});
	
	server.bind('guess', function(event) {
		chat_message(event.username, event.word);
	});
	
	// users
	
	server.bind('users', function(event) {
		var items = event.users;
		items.sort();
		
		$('#users').empty();
		$.each(items, function(key, username) {
			$('#users').append('<li>' + username + '</li>');
		});
	});
});

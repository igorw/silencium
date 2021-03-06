String.prototype.leftPad = function (l, c) {
	return new Array(l - this.length + 1).join(c || '0') + this;
};

function debug(message) {
	$('#debug').append($('<p>').text(message));
	$('#debug-container').scrollTop($('#debug-container').scrollTop() + 300);
}

function error(message) {
	$('#error').html($('<p>').text(message));
}

function clear_errors() {
	$('#error').empty();
}

function chat_message(username, message, class_name) {
	if (!class_name) {
		class_name = '';
	}
	
	var now = new Date();
	$('.chat-box > tbody:last').append(
		$('<tr>').
			append($('<td>').text(
				now.getHours().toString().leftPad(2) + ':' +
				now.getMinutes().toString().leftPad(2) + ':'+
				now.getSeconds().toString().leftPad(2)
			)).
			append($('<td>').text(username)).
			append($('<td>').text(message)
		).addClass(class_name)
	);
	
	if ($('.chat-box tr').size() > 8) {
		$('.chat-box tr').first().remove();
	}
}

$(document).ready(function () {
	WebSocket.__swfLocation = "web-socket-js/WebSocketMain.swf";
	
	// fragment is the port
	var port = location.hash.length ? location.hash.substring(1) : 3000,
			ws = new WebSocket("ws://localhost:" + port),
			server = new ServerEventDispatcher(ws),
			
			username = '',
			giver = false,
			time_remaining = 0;
	
	// init
	
	$('.container').hide();
	$('.exception').hide();
	$('.guest').show();
	
	$('#debug-container').hide();
	$('#debug-button').click(function () {
		$('#debug-button-container').hide();
		$('#debug-container').show();
		return false;
	});
	$('#debug-close-button').click(function () {
		$('#debug-container').hide();
		$('#debug-button-container').show();
		return false;
	});
	
	// debug
	
	server.bind('alert', function (event) {
		alert(event.message);
	});
	
	server.bind('debug', function (event) {
		debug(event.message);
	});
	
	// connect
	
	server.bind('connect', function (event) {
		debug('websocket connected');
	});
	
	// close (ws)
	
	server.bind('close', function (event) {
		$('#game-container').hide();
		$('.exception').hide();
		$('#fatal-error').show();
		debug('Error: Websocket closed');
	});
	
	// join
	
	$('#join-form').submit(function () {
		server.trigger('join', {
			username: $('#join-username').val()
		});
		return false;
	});
	
	server.bind('join', function (event) {
		if (!event.accepted) {
			error("Could not join: [" + event.message + "]");
			return;	
		}
		
		clear_errors();
		$('.container').hide();
		$('.player').show();
		
		username = event.username;
		debug('username: ' + event.username);
	});
	
	// guess
	
	$('#guess-form').submit(function () {
		server.trigger('guess', {
			word: $('#guess-word').val()
		});
		$('#guess-word').val('');
		return false;
	});
	
	server.bind('guess', function (event) {
		var class_name = event.correct ? 'correct-guess' : '';
		chat_message(event.username, event.word, class_name);
	});
	
	// give
	
	$('#give-form').submit(function () {
		server.trigger('give', {
			hint: $('#give-hint').val()
		});
		$('#give-hint').val('');
		return false;
	});
	
	server.bind('give', function (event) {
		chat_message(event.username, event.hint, 'giver');
	});
	
	server.bind('system_message', function (event) {
		chat_message('', event.message, 'system');
	});
	
	// users
	
	server.bind('users', function (event) {
		$('#users').empty();
		$.each(event.users, function (key, user) {
			var li = $('<li>').text(user.name + ' (' + user.score + ')');
			if (user.giver) {
				li.addClass('giver');
			}
			if (user.name === username) {
				li.addClass('myself');
			}
			$('#users').append(li);
		});
	});
	
	// new card
	
	server.bind('new_card', function (event) {
		$('#give-card').empty();
		$('#give-card').append($('<li class="word">').text(event.word));
		$.each(event.taboo_words, function (key, taboo_word) {
			$('#give-card').append($('<li class="taboo-word">').text(taboo_word));
		});
	});
	
	// pause
	
	server.bind('pause', function (event) {
		$('#game-container').hide();
		$('#pause').show();
	});
	
	// unpause
	
	server.bind('unpause', function (event) {
		$('.exception').hide();
		$('#game-container').show();
	});
	
	// become giver
	
	server.bind('become_giver', function (event) {
		// if we are are already giver
		// do nothing
		if (giver) {
			return;
		}
		
		giver = true;
		
		$('.container').hide();
		$('.giver').show();
		
		$('#give-word').text('');
	});
	
	// become player
	
	server.bind('become_player', function (event) {
		giver = false;
		
		$('.container').hide();
		$('.player').show();
		
		$('#guess-word').text('');
	});
	
	// game over
	
	server.bind('game_over', function (event) {
		$('#game-container').hide();
		$('.exception').hide();
		$('#game-over').show();
		
		$('#scoreboard').empty();
		$.each(event.users, function (key, user) {
			var li = $('<li>').text(user.name + ' (' + user.score + ')');
			if (user.name === username) {
				li.addClass('myself');
			}
			$('#scoreboard').append(li);
		});
	});
	
	// reset
	
	server.bind('reset', function (event) {
		$('.container').hide();
		$('.exception').hide();
		$('#game-container').show();
		$('.guest').show();
		
		clear_errors();
		$('.chat-box tr').remove();
	});
	
	// time sync
	
	server.bind('time_sync', function (event) {
		time_remaining = event.time_remaining;
		$('#time_remaining').text(time_remaining);
	});
});

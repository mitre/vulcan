$(document).ready(function() {
	var messages = $('#messages');
	function init() {
		messages.scrollTop($('#messages')[0].scrollHeight);
	}
	window.setTimeout(init, 50);
});

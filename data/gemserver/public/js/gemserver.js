/**
 * Rubygems Gemserver
 * $Id$
 * 
 * Authors:
 * - Michael Granger <ged@FaerieMUD.org>
 * 
 */

// Limit reloads to every 2s
const RELOAD_DELAY = 1000;

var UploadCounter = 0;
var ReloadTimeout = null;

// function on_upload_dragenter( event ) {
// 	console.debug( "DragEnter event: %o", event );
// 	$('#dropzone').addClass('targeted');
// }
// 
// function on_upload_dragleave( event ) {
// 	console.debug( "DragLeave event: %o", event );
// 	if ( UploadCounter == 0 )
// 		$('#dropzone').removeClass('targeted');
// }
// 
// function on_upload_docenter( event ) {
// 	console.debug( "DocEnter event: %o", event );
// 	$('#upload').addClass('targeted');
// }
// 
// function on_upload_docleave( event ) {
// 	console.debug( "DocLeave event: %o", event );
// 	if ( UploadCounter == 0 )
// 		$('#upload').removeClass('targeted');
// }
// 
// function on_upload_drop( event ) {
// 	console.debug( "Drop event: %o", event );
// 	$('#upload').addClass('uploading');
// }

/* Provide console simulation for firebug-less environments */
if (!("console" in window) || !("firebug" in console)) {
    var names = ["log", "debug", "info", "warn", "error", "assert", "dir", "dirxml",
    "group", "groupEnd", "time", "timeEnd", "count", "trace", "profile", "profileEnd"];

    window.console = {};
    for (var i = 0; i < names.length; ++i)
        window.console[names[i]] = function() {};
}


function hook_fileupload() {
	console.debug( "hooking fileupload" );

    $('#uploadform form').fileUploadUI({
        uploadTable: $('.uploaded-files'),
        downloadTable: $('.download-files'),
        buildUploadRow: function (files, index) {
            var file = files[index];
            return $(
                '<tr>' +
                '<td>' + file.name + '</td>' +
                '<td class="file-upload-progress"><div></div></td>' +
                '<td class="file-upload-cancel">' +
                '<div class="ui-state-default ui-corner-all ui-state-hover" title="Cancel">' +
                '<span class="ui-icon ui-icon-cancel">Cancel</span>' +
                '</div>' +
                '</td>' +
                '</tr>'
            );
        },
        buildDownloadRow: function (file) {
            return $(
                '<tr><td>' + file.name + '</td></tr>'
            );
        }

    });
}


function handle_ajax_error( event, xhr, opts, err ) {
	console.error( "AJAX error: %o", err );
	$('#error-notice').
		html( "<div><h2>Error</h2><p>" + err.message() + "</p></div>" ).
		dialog({ title: "AJAX Error" });	
}

$(document).ready( function() {
	hook_fileupload();
	$('#error-notice').ajaxError( handle_ajax_error );
});


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


/* Provide console simulation for firebug-less environments */
if (!("console" in window) || !("firebug" in console)) {
    var names = ["log", "debug", "info", "warn", "error", "assert", "dir", "dirxml",
    "group", "groupEnd", "time", "timeEnd", "count", "trace", "profile", "profileEnd"];

    window.console = {};
    for (var i = 0; i < names.length; ++i)
        window.console[names[i]] = function() {};
}


function on_upload_dragenter() {
	console.debug( "DragEnter event." );
	$('#dropzone').addClass('targeted');
}

function on_upload_dragleave() {
	console.debug( "DragLeave event." );
	if ( UploadCounter == 0 )
		$('#dropzone').removeClass('targeted');
}

function on_upload_docenter() {
	console.debug( "DocEnter event." );
	$('#upload').addClass('targeted');
}

function on_upload_docleave() {
	console.debug( "DocLeave event." );
	if ( UploadCounter == 0 )
		$('#upload').removeClass('targeted');
}

function on_upload_drop() {
	console.debug( "Drop event." );
	$('#upload').addClass('uploading');
}


/**
 * Update the progressbar identified by {index} with {progress}.
 *
 * @param {Integer} index     the index of the progress bar to update.
 * @param {Integer} progress  the percentage the bar should be set to as an Integer 0-100.
 */
function update_progressbar( index, filename, progress ) {
	var pb = $( "#upload-progress #progress-bar" + index );
	console.debug( "Updating progress bar: %o", pb );
	
	pb.find( '.progress-bar-progress' ).
		css( 'width', progress.toString(10) + '%' );
	pb.find( '.progress-bar-percent' ).text( progress.toString(10) + '%' );
}


/**
 * Update the speed shown on the progressbar identified by {index} with {speed}.
 *
 * @param {Integer} index  the index of the progress bar to update.
 * @param {Integer} speed  the speed (in bytes/s) of the upload
 */
function update_progressbar_speed( index, filename, speed ) {
	var pb = $( "#upload-progress #progress-bar" + index );
	console.debug( "Updating progress bar speed: %o (%s)", pb, speed );
	
	pb.find( '.progress-bar-speed' ).text( speed.toString(10) + ' Kb/s' );
}


/**
 * Callback for 'upload_started' event.
 * 
 * @param {Integer} i     index of uploaded file
 * @param {File}    file  the File object that is being uploaded
 * @param {Integer} len   the total number of files dropped
 */
function on_upload_started( i, file, len ) {
	console.debug( "Upload started for %s (%d of %d dropped)", file.name, i+1, len );
	
	var pb_id = 'progress-bar' + i.toString(10);
	var pb_div = $('<div id="' + pb_id + '" class="progress-bar">');
	$(pb_div).append( '<div class="progress-bar-progress">&nbsp;</div>' );
	$(pb_div).append( '<span class="progress-bar-filename">' + file.name + '</span>' );
	$(pb_div).append( '<span class="progress-bar-percent">0%</span>' );
	$(pb_div).append( '<span class="progress-bar-speed">0 Kb/s</span>' );

	UploadCounter++;
	console.debug( "Appending progressbar: %o", pb_div );
	$('#upload-progress').append( pb_div );

	update_progressbar( i, file.name, 0 );
}

/**
 * Callback for the 'upload_finished' event.
 * 
 * @param {Integer} i         index of uploaded file
 * @param {File}    file      the File object that was uploaded
 * @param {Object}  response  the data returned from the upload request (in JSON format)
 * @param {Time}    time      the Time the upload finished
 */
function on_upload_finished( i, file, response, time ) {
	console.debug( "Finished uploading %s in %s: %o", file.name, time, response );
	update_progressbar( i, file.name, 100 );

	UploadCounter--;
	console.debug( "%d uploads remain.", UploadCounter );

	$( '#progress-bar' + i ).fadeOut( function() {$(this).remove();} );

	if ( ReloadTimeout )
		window.clearTimeout( ReloadTimeout );

	ReloadTimeout = window.setTimeout( function() {
		$( '#main' ).load( '/gems' );
		ReloadTimeout = null;
	}, RELOAD_DELAY );

	if ( UploadCounter == 0 )
		$('#upload').removeClass( 'uploading' );
}


/**
 * Event callback for the 'progress_updated' event.
 * 
 * @param {Integer} i         index of the file being uploaded
 * @param {File} file         the File object of the file being uploaded
 * @param {Integer} progress  the percentage progress as an integer
 */
function on_progress_updated( i, file, progress ) {
	console.debug( "Progress on %s: %d%", file.name, progress );
	update_progressbar( i, file.name, progress );
}

function on_speed_updated( i, file, speed ) {
	console.debug( "Speed update for %s: %s", file.name, speed );
	update_progressbar_speed( i, file.name, speed );
}

function on_upload_error( err, file ) {
    switch( err ) {
        case 'BrowserNotSupported':
			console.error( "Browser doesn't support HTML5 drag-and-drop" );
            alert('browser does not support html5 drag and drop');
            break;
        case 'TooManyFiles':
			console.error( "User dropped more than the maximum number of files." );
        	alert('too many files');
            // user uploaded more than 'maxfiles'
            break;
        case 'FileTooLarge':
			console.error( "File '%s' is too large.", file.name );
        	alert("file '" + file.name + "' too large");
            // program encountered a file whose size is greater than 'maxfilesize'
            // FileTooLarge also has access to the file which was too large
            // use file.name to reference the filename of the culprit file
            break;
        default:
			console.error( "Unknown error: %o", err );
			alert( "Unknown error: " + err );
            break;
    }
}

function hook_fileupload() {
	console.debug( "hooking fileupload" );
	$('#dropzone').filedrop({
	    url:  				'/upload', // upload handler, handles each file separately
	    paramname: 			'gem',     // POST parameter name used on serverside to reference file
	    data: {},

	    maxfiles: 			25,
	    maxfilesize: 		20,        // max file size in MBs

	    error: 				on_upload_error,

	    dragEnter: 			on_upload_dragenter,
	    dragLeave: 			on_upload_dragleave,

	    docEnter: 			on_upload_docenter,
	    docLeave: 			on_upload_docleave,

	    drop: 				on_upload_drop,

	    uploadStarted: 		on_upload_started,
	    uploadFinished: 	on_upload_finished,

	    progressUpdated: 	on_progress_updated,
	    speedUpdated: 		on_speed_updated
	});
}


function handle_ajax_error( event, xhr, opts, err ) {
	console.error( "AJAX error: %o", err );
	$('#error-notice').
		html( "<div><h2>Error</h2><p>" + err.message() + "</p></div>" ).
		overlay({
			top: 260,
			mask: {
				color: 'rgb(55,0,0)',
				loadSpeed: 200,
				opacity: 0.5
			},
			closeOnClick: false,
			load: true
		});	
}

$(document).ready( function() {
	hook_fileupload();
	$('#error-notice').ajaxError( handle_ajax_error );
});


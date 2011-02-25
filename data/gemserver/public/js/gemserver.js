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

var EnterCounter = { doc: 0, drag: 0 };
var UploadCounter = 0;
var ReloadTimeout = null;

const Templates = {
	upload_row: null
};

/* Provide console simulation for firebug/webinspector-less environments */
if (!("console" in window) || !("groupEnd" in console)) {
    var names = ["log", "debug", "info", "warn", "error", "assert", "dir", "dirxml",
    "group", "groupEnd", "time", "timeEnd", "count", "trace", "profile", "profileEnd"];

    window.console = {};
    for (var i = 0; i < names.length; ++i)
        window.console[names[i]] = function() {};
}

function on_upload_docenter( event ) {
	EnterCounter.doc += 1;
	console.debug( "DocEnter event (%d): %o", EnterCounter.doc, event );
	$('#dropzone').addClass('dragging');
}

function on_upload_docleave( event ) {
	EnterCounter.doc -= 1;
	console.debug( "DocLeave event (%d): %o", EnterCounter.doc, event );
	if ( EnterCounter.doc == 0 )
		$('#upload').removeClass('dragging');
}

function on_upload_dragenter( event ) {
	EnterCounter.drag += 1;
	console.debug( "DragEnter event (%d): %o", EnterCounter.drag, event );
	$('#dropzone').addClass('targeted');
}

function on_upload_dragleave( event ) {
	EnterCounter.drag -= 1;
	console.debug( "DragLeave event (%d): %o", EnterCounter.drag, event );
	if ( EnterCounter.drag == 0 )
		$('#dropzone').removeClass('targeted');
}

function on_upload_drop( event ) {
	console.debug( "Drop event: %o", event );
	$('#upload').addClass('uploading');
}

function build_upload_row( files, index ) {
	var file = files[ index ];
	var tmpl = Templates.upload_row.clone();
	console.debug( "Building an upload row for file %d of %d: %s",
		index + 1, files.length, file.name );

	tmpl.find( '.filename' ).html( file.name );
	console.debug( "Returning row: %o", tmpl );

	return tmpl;
}

function hasDragAndDrop() {
	return 'draggable' in document.createElement('span');
}
function hasFileAPI() {
	return typeof FileReader != 'undefined';
}


/**
 * Callback for 'beforeSend' event.
 */
function on_before_send( event, files, index, xhr, handler, callBack ) {
	var file = files[ index ];

	if ( UploadCounter === 0 )
		console.group( "Upload (%d files)", files.length );

	console.debug( "Upload started for %s (%d of %d dropped)", file.name, index+1, files.length );
	UploadCounter++;

	$('#upload').addClass( 'uploading' );

    return callBack();
}


/**
 * Callback for the 'onComplete' event.
 */
function on_complete( event, files, index, xhr, handler ) {
	var file = files[ index ];

	console.debug( "Finished uploading %s", file.name );
	UploadCounter--;

	handler.progressbar.fadeOut( function() {$(this).remove();} );
	if ( UploadCounter === 0 ) {
		console.groupEnd();
		$( '#main' ).load( '/gems' );
		$('#upload').removeClass( 'uploading' );
	}
}


function hook_fileupload() {
	console.debug( "hooking fileupload" );

    $('#upload form').fileUploadUI({
		uploadTable: $('#upload table.uploads'),
		buildUploadRow: build_upload_row,
		dropZone: $('#dropzone'),
        progressSelector: '.upload-row td.progress',
        cancelSelector: '.upload-row td.cancel',
		onDocumentDragEnter: on_upload_docenter,
		onDocumentDragLeave: on_upload_docleave,
		onDragEnter: on_upload_dragenter,
		onDragLeave: on_upload_dragleave,
		beforeSend: on_before_send,
		onComplete: on_complete
    });

}

function set_upload_instructions() {
	if ( hasDragAndDrop() && hasFileAPI() ) {
		console.debug( "  has drag-and-drop and the File API" );
		$('#upload p').
			html( "Select one or more gems to upload, or drag and drop them into this window.");
	}
}

function handle_ajax_error( event, xhr, opts, err ) {
	console.error( "AJAX error: %o", err );
	$('#error-notice').
		html( "<div><h2>Error</h2><p>" + err.message() + "</p></div>" ).
		dialog({ title: "AJAX Error" });	
}

function extract_templates() {
	Templates.upload_row = $('#upload table.uploads tr.upload-row').remove();
	// Templates.upload_row = $('#upload table.uploads tr.upload-row').clone();
}

$(document).ready( function() {
	extract_templates();
	hook_fileupload();
	set_upload_instructions();
	$('#error-notice').ajaxError( handle_ajax_error );
});


$(function() {	  
	  var tabs = $( "#container" ).tabs();
		tabs.find( ".ui-tabs-nav" ).sortable({
		axis: "x",
		stop: function() {
		tabs.tabs( "refresh" );
		}
	 }); 
	 
	 
	 //  drag and drop function here
	 
	    $("#left-pane li").draggable({
			containment: '#gbox',
			cursor: 'move',
			helper: 'clone',
			scroll: false,
			connectToSortable: '#right-pane',
			appendTo: '#right-pane',
			start: function () {},
			stop: function (event, ui) {}
		}).mousedown(function () {});
		
	
		$("#right-pane").sortable({
			sort: function () {},
			placeholder: 'ui-state-highlight',
			receive: function () {},
			update: function (event, ui) {}
			
		});
		
		$("#right-pane").droppable({
			accept: "#left-pane li",
			accept: ":not(.ui-sortable-helper)",
			drop: function (event, ui) {
				if ($(ui.draggable).find('.ui-icon-refresh').length == 0)
				{ 
					$(ui.draggable).append("<div class='ui-icon-refresh' > X </div>");
				}
			}
		});
	
		
		$("#left-pane").droppable({
			accept: "#right-pane li",
			drop: function (event, ui) {}
		});
		
		$(document).on( "click", ".ui-icon-refresh", function( event ) {
			$(this).parent().remove();
		});

	//  drag function here
	$( "#addToListDiv" ).sortable();
	$( "#addToListDiv" ).disableSelection();
	$('.addToInput').keyup(function(e){
		$(this).next().show();
		e.stopPropagation();		
	});
	
	
	
	$(document).on( "click", "html", function( event ) {
		$('.addToFormDiv,.ms-drop').hide();
				
	});
	$('.addToFormDiv').click(function(e){
		$(this).show();
		e.stopPropagation();		
	});
	  
	  $windowsHeight = $(window).height();
	 // setInterval(function() {
	 
	  divHeight = ($windowsHeight)-350;
	   $("#addToListDiv").css('height',divHeight);
	  //},50000);
	  
	  
	 $(document).on( "click", ".openWindow", function( event ) {
		$(this).removeClass('openWindow');
		$(this).addClass('closedWindow');
		$(this).parent().next().show();
	 });
	 $(document).on( "click", ".closedWindow", function( event ) {
		$(this).removeClass('closedWindow');
		$(this).addClass('openWindow');
		$(this).parent().next().hide();
	 });
	  
	 $(".multipleSelectBox").multipleSelect({
            filter: false
     });
	  
	  
	  
	
	
  });
 
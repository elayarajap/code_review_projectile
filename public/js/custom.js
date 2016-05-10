$(function() {	  
	  var tabs = $( "#container" ).tabs();
		tabs.find( ".ui-tabs-nav" ).sortable({
		axis: "x",
		stop: function() {
		tabs.tabs( "refresh" );
		}
	 }); 

	
	$(".multipleSelectBox").multipleSelect({
            filter: false
    });
	  
	  
	  
	$( "#addToListDivInner" ).sortable();
	$( "#addToListDivInner" ).disableSelection();


	alert(5);
});
 

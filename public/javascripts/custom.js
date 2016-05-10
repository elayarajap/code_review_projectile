
  $(function() {
	  
	  var tabs = $( "#container" ).tabs();
		tabs.find( ".ui-tabs-nav" ).sortable({

  		axis: "x",
  		stop: function() {
  		tabs.tabs( "refresh" );
  		}
  	}); 

    $( "#addToListDivInner" ).sortable();
    $( "#addToListDivInner" ).disableSelection();

    var windowsHeight = $(window).height();
    
    
      var divHeight = windowsHeight -450;
      
      $("#addToListDiv").css('min-height',divHeight);

      
	
  });


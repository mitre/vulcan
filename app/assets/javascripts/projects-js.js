/**
* Theme: Minton Admin Template
* Author: Coderthemes
* Form wizard page
*/

function load_wizard() {
  var FormWizard = function() {};

  FormWizard.prototype.createBasic = function($form_container) {
      $form_container.children("div").steps({
          headerTag: "h3",
          bodyTag: "section",
          transitionEffect: "slideLeft",
          onFinishing: function (event, currentIndex) { 
              //NOTE: Here you can do form validation and return true or false based on your validation logic
              console.log("Form has been validated!");
              return true; 
          }, 
          onFinished: function (event, currentIndex) {
             //NOTE: Submit the form, if all validation passed.
              console.log("Form can be submitted using submit method. E.g. $('#basic-form').submit()"); 
              $("#basic-form").submit();

          }
      });
      return $form_container;
  },
  FormWizard.prototype.init = function() {
      //basic form
      this.createBasic($("#basic-form"));
  },
  //init
  $.FormWizard = new FormWizard, $.FormWizard.Constructor = FormWizard
  $.FormWizard.init();
}

// Add event listener for opening and closing details
// $('#project-controls-datatable tbody').on('click', 'td.pc-app-id', function () {
//   alert("here")
//   var tr = $(this).closest('tr');
//   var row = table.row( tr );
// 
//   if ( row.child.isShown() ) {
//     row.child.hide();
//     tr.removeClass('shown');
//   }
//   else {
//    if ( table.row( '.shown' ).length ) {
//       $('.table_row', table.row( '.shown' ).node()).click();
//    }
//    row.child( details_panel(row.data()) ).show();
//    tr.addClass('shown');
//   }
// });

// function details_panel ( d ) {
//     // 'd' is the original data object for the row
//   var details_panel = '';
//   details_panel +=
//   '<ul class="nav nav-tabs">'+
//     '<li class="active"><a data-toggle="tab" href="#fdetails">Finding Details</a></li>'+
//     '<li><a data-toggle="tab" href="#details" >Details</a></li>'+
//     '<li><a data-toggle="tab" href="#inspec_code">Inspec Code</a></li>'+
//   '</ul>'+
//   '<div class="tab-content">'+
//     '<div id="fdetails" class="tab-pane active">'+
//       '<table cellpadding="5" cellspacing="0" border="0" style="padding-left:50px;">'+
//         '<tr>'+
//             '<td>'+d.finding_details.replace(/(?:\r\n|\r|\n)/g, '<br>')+'</td>'+
//         '</tr>'+
//       '</table>'+
//     '</div>'+
//     '<div id="details" class="tab-pane">'+
//       '<table cellpadding="5" cellspacing="0" border="0" style="padding-left:50px;">';
// 
// 
//     //Mandatory feilds
//     details_panel += '<tr>'+ '<td>Control:</td>'+ '<td>'+d['vuln_num']    +'</td>'+ '</tr>';
//     details_panel += '<tr>'+ '<td>Title:</td>'  + '<td>'+d['rule_title']  +'</td>'+ '</tr>';
//     details_panel += '<tr>'+ '<td>Desc:</td>'   + '<td>'+d['vuln_discuss']+'</td>'+ '</tr>';
// 
//     var  DATA_NOT_FOUND_MESSAGE = 'N/A'
//     // Optional Tags
//     if (d['severity']      != DATA_NOT_FOUND_MESSAGE) { details_panel += '<tr>'+ '<td>Severity:</td>'  + '<td>'+d['severity']     +'</td>'+ '</tr>'; }
//     if (d['impact']        != DATA_NOT_FOUND_MESSAGE) { details_panel += '<tr>'+ '<td>Impact:</td>'    + '<td>'+d['impact']       +'</td>'+ '</tr>'; }
//     if (d['nist']          != DATA_NOT_FOUND_MESSAGE) { details_panel += '<tr>'+ '<td>Nist Ref:</td>'  + '<td>'+d['nist']         +'</td>'+ '</tr>'; }
//     if (d['rationale']     != DATA_NOT_FOUND_MESSAGE) { details_panel += '<tr>'+ '<td>Rationale:</td>' + '<td>'+d['rationale']    +'</td>'+ '</tr>'; }
//     if (d['cis_family']    != DATA_NOT_FOUND_MESSAGE) { details_panel += '<tr>'+ '<td>CIS family:</td>'+ '<td>'+d['cis_family']   +'</td>'+ '</tr>'; }
//     if (d['cis_rid']       != DATA_NOT_FOUND_MESSAGE) { details_panel += '<tr>'+ '<td>CIS rid:</td>'   + '<td>'+d['cis_rid']      +'</td>'+ '</tr>'; }
//     if (d['cis_level']     != DATA_NOT_FOUND_MESSAGE) { details_panel += '<tr>'+ '<td>CIS level:</td>' + '<td>'+d['cis_level']    +'</td>'+ '</tr>'; }
//     if (d['check_content'] != DATA_NOT_FOUND_MESSAGE) { details_panel += '<tr class="overflow-wrap">'+ '<td>Check Text:</td>'+ '<td>'+d['check_content']+'</td>'+ '</tr>'; }
//     if (d['fix_text']      != DATA_NOT_FOUND_MESSAGE) { details_panel += '<tr>'+ '<td>Fix Text:</td>'  + '<td>'+d['fix_text']     +'</td>'+ '</tr>'; }
// 
//     details_panel +=
//       '</table>'+
//     '</div>'+
//     '<div id="inspec_code" class="tab-pane">'+
//       '<table cellpadding="5" cellspacing="0" border="0" style="padding-left:50px;">'+
//         '<tr>'+
//             '<td><pre id="precode" class="line-numbers"><code id="code" class="language-ruby">'+d.code+'</code></pre></td>'+
//         '</tr>'+
//       '</table>'+
//     '</div>' +
//   '</div>';
// 
//     return details_panel;
// }
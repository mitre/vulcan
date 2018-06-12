/**
* Theme: Minton Admin Template
* Author: Coderthemes
* Form wizard page
*/

function load_wizard(form_id) {
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
              $($form_container).submit();

          }
      });
      return $form_container;
  },
  FormWizard.prototype.init = function(form_id) {
      //basic form
      this.createBasic($(form_id));
  },
  //init
  $.FormWizard = new FormWizard, $.FormWizard.Constructor = FormWizard
  $.FormWizard.init(form_id);
}
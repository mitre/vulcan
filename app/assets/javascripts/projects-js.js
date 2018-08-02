/**
* Theme: Minton Admin Template
* Author: Coderthemes
* Form wizard page
*/

function load_wizard(form_id, on_step_changing_function) {
  var FormWizard = function() {};

  FormWizard.prototype.createBasic = function($form_container) {
      $form_container.children("div").steps({
          headerTag: "h3",
          bodyTag: "section",
          transitionEffect: "slideLeft",
          onFinished: function (event, currentIndex) {
             //NOTE: Submit the form, if all validation passed.
              console.log("Form can be submitted using submit method. E.g. $('#basic-form').submit()"); 
              $($form_container).submit();

          },
          onStepChanging: function(event, currentIndex, newIndex) {
            return on_step_changing_function(event, currentIndex, newIndex)
          },
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

function createMorrisChart(id, data) {
  console.log(data);
  data = JSON.parse(data)
  console.log(data['results']);
  var colors = ['#63AC56', '#DB4B42', '#429CF6', '#B1E6FB', '#E9B655']
  new Morris.Donut({element: id, data: data['results'], resize: true, colors: colors})
}
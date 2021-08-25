
<script>
// This mixin is for generating bootstrap alerts
export default {
  methods: {
    // Take in a `response` directly from an AJAX call and see if it
    // contains data that we can make into either an alert or notice.
    //
    // `response['data']['notice']` and `response['data']['alert']` are
    // valid for generating alerts.
    alertOrNotifyResponse: function(response) {
      let classes = 'alert alert-dismissable fade show ';
      let textContent = '';
      if (response['data'] && response['data']['notice']) {
        classes += ' alert-success';
        textContent = response['data']['notice'];
      }
      else if (response['data'] && response['data']['alert']) {
        classes += 'alert-danger';
        textContent = response['data']['alert'];
      } else {
        // The response did not contain data we can use for an alert or notice.
        return;
      }

      let element = document.createElement('p');
      element.className = classes;
      element.textContent = textContent;
      element.setAttribute('role', 'alert');
      document.getElementById('alerts')?.appendChild(element);
      setTimeout(function() { element.remove() }, 5000);
    }
  }
}
</script>

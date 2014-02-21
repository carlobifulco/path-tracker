(function() {
  var get_data,
    _this = this;

  $("#get_data").click(function() {
    return get_data();
  });

  get_data = function(e) {
    var ini;
    if (e == null) e = false;
    ini = $("#ini").val();
    console.log(ini);
    return $.get("/log/" + ini, function(data) {
      console.log("getting");
      console.log(data);
      window.data = data;
      return $("#log_html").html(data);
    });
  };

  window.get_data = get_data;

  $(document).ready(function() {
    console.log("here I am");
    return KeyboardJS.bind.key("enter", get_data);
  });

}).call(this);

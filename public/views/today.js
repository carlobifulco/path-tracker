(function() {
  var render, render_template, show_sparklines,
    _this = this;

  render = function(data, html) {
    var hb, results;
    if (typeof data === "string") {
      data = JSON.parse(data);
      console.log(data);
    }
    hb = Handlebars.compile(html);
    results = hb(data);
    return results;
  };

  window.render = render;

  render_template = function(id, data) {
    return $("#" + id + "_html").html(render(data, ($("#" + id + "_template")[0]).innerHTML));
  };

  window.render_template = render_template;

  show_sparklines = function(func) {
    var _this = this;
    if (func == null) func = false;
    return $.get("/get_entry", function(data) {
      data = JSON.parse(data);
      window.data = data;
      render_template("sparkline", data);
      $('.inlinesparkline').sparkline("html", {
        type: "bullet",
        width: '30px'
      });
      $(".show_entry").click(function(e) {
        console.log(e.currentTarget.id);
        return show(e.currentTarget.id);
      });
      if (func) return func();
    });
  };

  window.show_sparklines = show_sparklines;

  $(document).ready(function() {
    console.log("here I am");
    return show_sparklines();
  });

}).call(this);

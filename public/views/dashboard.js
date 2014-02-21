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
    return $.get("/get_dashboard", function(data) {
      var key, _fn, _i, _len, _ref;
      data = JSON.parse(data);
      window.data = data;
      _ref = _.keys(data);
      _fn = function(key) {
        render_template("sparkline", data);
        return $('.inlinesparkline').sparkline("html", {
          type: "line",
          width: '300px',
          height: "35px"
        });
      };
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        key = _ref[_i];
        _fn(key);
      }
      if (func) return func();
    });
  };

  window.show_sparklines = show_sparklines;

  $(document).ready(function() {
    console.log("here I am");
    return show_sparklines();
  });

}).call(this);

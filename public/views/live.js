(function() {
  var decorate, entry_click, get_activities, has_a_distribution_preference, has_a_location, has_a_specialty, icons, render, render_template, serialize, show, show_cardinal, show_regular, show_sparklines, update, update_yaml,
    _this = this;

  update_yaml = function() {
    var _this = this;
    return $.get("/get_yaml", function(data) {
      data = JSON.parse(data);
      console.log("getting");
      console.log(data);
      return window.yaml = data;
    });
  };

  window.update_yaml = update_yaml;

  if (!window.yaml) update_yaml();

  icons = function() {
    var i, _fn, _fn2, _fn3, _i, _j, _k, _l, _len, _len2, _len3, _len4, _ref, _ref2, _ref3, _ref4, _results;
    _ref = yaml.b_psv;
    _fn = function(i) {
      return $("#" + i).prepend($('<i class="icon-forward"></i>'));
    };
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      i = _ref[_i];
      _fn(i);
    }
    _ref2 = yaml.c_ppmc;
    _fn2 = function(i) {
      return $("#" + i).prepend($('<i class="icon-play"></i>'));
    };
    for (_j = 0, _len2 = _ref2.length; _j < _len2; _j++) {
      i = _ref2[_j];
      _fn2(i);
    }
    _ref3 = yaml.d_core;
    _fn3 = function(i) {
      return $("#" + i).prepend($('<i class="icon-home"></i>'));
    };
    for (_k = 0, _len3 = _ref3.length; _k < _len3; _k++) {
      i = _ref3[_k];
      _fn3(i);
    }
    _ref4 = yaml.a_hr;
    _results = [];
    for (_l = 0, _len4 = _ref4.length; _l < _len4; _l++) {
      i = _ref4[_l];
      _results.push((function(i) {
        return $("#" + i).prepend($('<i class="icon-picture"></i>'));
      })(i));
    }
    return _results;
  };

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

  decorate = function() {
    var ini, _fn, _fn2, _fn3, _i, _len, _ref;
    _ref = _.keys(data["paths_acts_points"]);
    _fn = function(ini) {
      var a;
      a = has_a_specialty(get_activities(ini));
      if (a) return $("#" + ini).parent().parent().addClass("error");
    };
    _fn2 = function(ini) {
      var a;
      a = has_a_location(get_activities(ini));
      if (a) return $("#" + ini).parent().parent().addClass("warning");
    };
    _fn3 = function(ini) {
      var a;
      a = has_a_distribution_preference(get_activities(ini));
      if (a) return $("#" + ini).parent().parent().addClass("success");
    };
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      ini = _ref[_i];
      _fn(ini);
      _fn2(ini);
      _fn3(ini);
    }
    return icons();
  };

  window.decorate = decorate;

  get_activities = function(ini) {
    return _.keys(data["paths_acts_points"][ini]);
  };

  window.get_activities = get_activities;

  has_a_specialty = function(arr) {
    var match, specialties;
    specialties = _.keys(yaml["distribution-specialty"]);
    match = _.intersection(arr, specialties);
    if (match.length === 1) {
      return match[0];
    } else {
      return false;
    }
  };

  window.has_a_specialty = has_a_specialty;

  has_a_location = function(arr) {
    var locations, match;
    locations = _.keys(yaml["distribution-location"]);
    match = _.intersection(arr, locations);
    if (match.length === 1) {
      return match[0];
    } else {
      return false;
    }
  };

  window.has_a_location = has_a_location;

  has_a_distribution_preference = function(arr) {
    var match, specialties;
    specialties = _.keys(yaml["distribution-preference"]);
    match = _.intersection(arr, specialties);
    if (match.length === 1) {
      return match[0];
    } else {
      return false;
    }
  };

  window.has_a_distribution_preference = has_a_distribution_preference;

  show_sparklines = function(func) {
    var _this = this;
    if (func == null) func = false;
    return $.get("/get_live", function(data) {
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
      if (func) func();
      if (func) $("#serialize").show();
      if (func) {
        $("#serialize").click(function() {
          return serialize();
        });
      }
      decorate();
      return render_template("status", data);
    });
  };

  window.show_sparklines = show_sparklines;

  show_cardinal = function() {
    return $.get("/activities_cardinal", function(data) {
      window.cardinal_data = JSON.parse(data);
      return render_template("cardinal", data);
    });
  };

  window.show_cardinal = show_cardinal;

  show_regular = function() {
    return $.get("/activities_regular", function(data) {
      data = JSON.parse(data);
      render_template("regular", data);
      return entry_click();
    });
  };

  window.show_regular = show_regular;

  update = function(id, n) {
    var activity;
    activity = $("#" + id);
    console.log(activity);
    if (activity.attr("type") === "checkbox") activity.attr("checked", true);
    if (activity.attr("type") === "text") return activity.val(n);
  };

  window.update = update;

  show = function(id) {
    var _this = this;
    $("#status_html").hide();
    window.id = id;
    render_template("id", {
      id: id
    });
    show_cardinal();
    show_regular();
    $.get("/path/activities/points", function(data) {
      var activities, i, _i, _len, _ref, _results;
      data = JSON.parse(data);
      activities = data["path"]["" + id];
      _ref = _.keys(activities);
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        i = _ref[_i];
        _results.push(update(i, activities[i].n));
      }
      return _results;
    });
    return show_sparklines(function() {
      return $("#" + id).css("color", "red");
    });
  };

  serialize = function() {
    var data;
    data = $("#entry").serializeArray();
    console.log(data);
    window.data = data;
    return $.post("/tomorrow", $("#entry").serializeArray(), function(e) {
      if (JSON.parse(e)["ok"]) {
        alert("Data updated");
        return show_sparklines(function() {
          return $("#" + ($("#path_name").val())).css("color", "red");
        });
      }
    });
  };

  window.serialize = serialize;

  entry_click = function() {
    return $('[type=text]').click(function(e) {
      console.log(e);
      console.log("e scrElement: " + e.srcElement.value);
      return e.srcElement.value = Number(e.srcElement.value) + Number(prompt("Add:"));
    });
  };

  window.entry_click = entry_click;

  window.show = show;

  $(document).ready(function() {
    console.log("here I am");
    return show_sparklines();
  });

}).call(this);

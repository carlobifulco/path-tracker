(function() {
  var get_all, get_checked, get_unchecked, parse_html, post_data, render,
    __indexOf = Array.prototype.indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; },
    _this = this;

  render = function(r) {
    var hb, results, template;
    window.r = r;
    console.log(r);
    template = ($("#template")[0]).innerHTML;
    hb = Handlebars.compile(template);
    results = hb(r);
    $("#placeholder").html(results);
    $("#placeholder").show();
    return $("#ajax_button").show();
  };

  get_checked = function(id) {
    var checked_boxes, i, _i, _len, _results;
    checked_boxes = $("#" + id + " input[type='checkbox']:checked");
    _results = [];
    for (_i = 0, _len = checked_boxes.length; _i < _len; _i++) {
      i = checked_boxes[_i];
      _results.push($(i).attr("name"));
    }
    return _results;
  };

  window.get_checked = get_checked;

  get_all = function(id) {
    var all_boxes, i, _i, _len, _results;
    all_boxes = $("#" + id + " input[type='checkbox']");
    _results = [];
    for (_i = 0, _len = all_boxes.length; _i < _len; _i++) {
      i = all_boxes[_i];
      _results.push($(i).attr("name"));
    }
    return _results;
  };

  window.get_all = get_all;

  get_unchecked = function(id) {
    var i, _i, _len, _ref, _results;
    _ref = get_all(id);
    _results = [];
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      i = _ref[_i];
      if (__indexOf.call(get_checked(id), i) < 0) _results.push(i);
    }
    return _results;
  };

  window.get_unchecked = get_unchecked;

  parse_html = function() {
    var data, left_over_previous_day_slides, total_ESD, total_GI, total_SO, total_blocks, total_cytology;
    total_blocks = $("#total_blocks")[0].value;
    total_GI = $("#total_GI")[0].value;
    total_SO = $("#total_SO")[0].value;
    total_ESD = $("#total_ESD")[0].value;
    total_cytology = $("#total_cytology")[0].value;
    left_over_previous_day_slides = $("#left_over_previous_day_slides")[0].value;
    data = {
      path_present: _.union(get_checked("working"), get_unchecked("absent")),
      path_absent: _.union(get_checked("absent"), get_unchecked("working")),
      total_blocks: total_blocks,
      total_GI: total_GI,
      total_SO: total_SO,
      total_ESD: total_ESD,
      total_cytology: total_cytology,
      left_over_previous_day_slides: left_over_previous_day_slides
    };
    return data;
  };

  window.parse_html = parse_html;

  post_data = function() {
    var data;
    data = parse_html();
    window.data = data;
    return $.post("/setup", data, function(e) {
      if (JSON.parse(e)) {
        $.get("/get_setup", function(e) {
          return render(JSON.parse(e));
        });
        alert("Data Updated");
        return console.log(e);
      }
    });
  };

  window.post_data = post_data;

  $(document).ready(function() {
    $("#placeholder").hide();
    $.get("/get_setup", function(e) {
      return render(JSON.parse(e));
    });
    window.t = $("#template");
    window.p = $("#placeholder");
    window.render = render;
    return $("#ajax_button").click(function(e) {
      return post_data();
    });
  });

}).call(this);

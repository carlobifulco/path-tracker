// Generated by CoffeeScript 1.3.3
(function() {
  var get_all, get_checked, get_unchecked, post_data, render,
    __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; },
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
      if (__indexOf.call(get_checked(id), i) < 0) {
        _results.push(i);
      }
    }
    return _results;
  };

  window.get_unchecked = get_unchecked;

  post_data = function() {
    var blocks_east, blocks_hr, blocks_west, data;
    blocks_east = $("#blocks_east")[0].value;
    blocks_west = $("#blocks_west")[0].value;
    blocks_hr = $("#blocks_hr")[0].value;
    data = {
      path_present: _.union(get_checked("working"), get_unchecked("absent")),
      path_absent: _.union(get_checked("absent"), get_unchecked("working")),
      blocks_east: blocks_east,
      blocks_west: blocks_west,
      blocks_hr: blocks_hr
    };
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

  $(document).ready(function() {
    $("#placeholder").hide();
    $.get("/get_setup", function(e) {
      return render(JSON.parse(e));
    });
    window.t = $("#template");
    window.p = $("#placeholder");
    window.render = render;
    $("#ajax_button").click(function(e) {
      return post_data();
    });
    return window.post_data = post_data;
  });

}).call(this);
(function () {
  var __slice = [].slice;

  this.namespace = function(target, name, block) {
    var item, top, _i, _len, _ref, _ref1, _ref2;

    if (arguments.length < 3) {
      if (typeof exports !== "undefined") {
        _ref = [exports].concat(__slice.call(arguments));
        target = _ref[0];
        name = _ref[1];
        block = _ref[2];
      } else {
        _ref1 = [window].concat(__slice.call(arguments));
        target = _ref1[0];
        name = _ref1[1];
        block = _ref1[2];
      }
    }

    top = target;
    _ref2 = name.split(".");
    for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
      item = _ref2[_i];
      target = target[item] || (target[item] = {});
    }

    return block(target, top);
  };
}).call(this);

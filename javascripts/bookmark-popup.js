// Generated by CoffeeScript 1.8.0
(function() {
  this.BookmarksPopup = (function() {
    function BookmarksPopup(bookmarks, options, flowtipOptions) {
      this.bookmarks = bookmarks;
      this.options = options != null ? options : {};
      this.flowtipOptions = flowtipOptions != null ? flowtipOptions : {};
      this.parentPopup = this.options.parentPopup;
      this.parentRegion = this.options.parentRegion;
      this.folderId = this.options.folderId;
    }

    BookmarksPopup.prototype.render = function($target) {
      var bookmark, bookmarkItem, flowtipOptions, _i, _len, _ref;
      this.$target = $target;
      this.$el = document.createElement("ul");
      this.$el.className = "bookmarks-list";
      _ref = this.bookmarks;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        bookmark = _ref[_i];
        bookmarkItem = new BookmarkItem(bookmark);
        bookmarkItem.delegate = this;
        bookmarkItem.render(this.$el);
      }
      flowtipOptions = this.parentPopup ? {
        region: this.parentRegion || "right",
        topDisabled: true,
        leftDisabled: false,
        rightDisabled: false,
        bottomDisabled: true,
        rootAlign: "edge",
        leftRootAlignOffset: 0,
        rightRootAlignOffset: -0.1,
        targetAlign: "edge",
        leftTargetAlignOffset: 0,
        rightTargetAlignOffset: -0.1
      } : {
        region: "bottom",
        topDisabled: true,
        leftDisabled: true,
        rightDisabled: true,
        bottomDisabled: false,
        rootAlign: "edge",
        rootAlignOffset: 0,
        targetAlign: "edge",
        targetAlignOffset: 0
      };
      this.flowtip = new FlowTip(_.extend({
        className: "bookmarks-popup",
        hasTail: false,
        rotationOffset: 0,
        edgeOffset: 10,
        targetOffset: 2,
        maxHeight: "" + (this.maxHeight()) + "px"
      }, flowtipOptions, this.flowtipOptions));
      this.flowtip.setTooltipContent(this.$el);
      this.flowtip.setTarget(this.$target);
      this.flowtip.show();
      return this.flowtip.content.addEventListener("scroll", (function(_this) {
        return function() {
          return _this.hidePopupIfPresent();
        };
      })(this), false);
    };

    BookmarksPopup.prototype.hide = function() {
      this.hidePopupIfPresent();
      this.flowtip.hide();
      return this.flowtip.destroy();
    };

    BookmarksPopup.prototype.hidePopupIfPresent = function() {
      if (this.popup) {
        this.popup.hide();
        return this.popup = null;
      }
    };

    BookmarksPopup.prototype.openFolder = function(bookmarkItem) {
      return chrome.bookmarks.getChildren(bookmarkItem.bookmarkId, (function(_this) {
        return function(bookmarks) {
          _this.hidePopupIfPresent();
          _this.popup = new BookmarksPopup(bookmarks, {
            parentPopup: _this,
            parentRegion: _this.parentPopup ? _this.flowtip._region : void 0,
            folderId: bookmarkItem.bookmarkId
          });
          return _this.popup.render(bookmarkItem.$link);
        };
      })(this));
    };

    BookmarksPopup.prototype.maxHeight = function() {
      if (this.parentPopup) {
        return document.body.clientHeight - 20;
      } else {
        return document.body.clientHeight - 41;
      }
    };

    BookmarksPopup.prototype.BookmarkItemDidMouseOver = function(bookmarkItem) {
      var _ref;
      if (bookmarkItem.isFolder()) {
        if (this.popup) {
          if (this.popup.folderId !== bookmarkItem.bookmarkId) {
            this.hidePopupIfPresent();
          }
        } else {
          this.openFolder(bookmarkItem);
        }
      } else {
        this.hidePopupIfPresent();
      }
      return (_ref = this.parentPopup) != null ? typeof _ref.BookmarksPopupDidMouseOverItem === "function" ? _ref.BookmarksPopupDidMouseOverItem(bookmarkItem) : void 0 : void 0;
    };

    BookmarksPopup.prototype.BookmarkItemDidMouseOut = function(bookmarkItem) {
      if (bookmarkItem.isFolder()) {
        if (!this.mouseoutTimeout) {
          return this.mouseoutTimeout = _.delay((function(_this) {
            return function() {
              _this.hidePopupIfPresent();
              return _this.mouseoutTimeout = null;
            };
          })(this), 100);
        }
      }
    };

    BookmarksPopup.prototype.BookmarkItemWillClick = function(bookmarkItem) {
      if (this.popup && this.popup.folderId !== bookmarkItem.bookmarkId) {
        return this.hidePopupIfPresent();
      }
    };

    BookmarksPopup.prototype.BookmarkItemDidClick = function(bookmarkItem) {
      var _ref;
      return (_ref = this.parentPopup) != null ? typeof _ref.BookmarksPopupDidClickItem === "function" ? _ref.BookmarksPopupDidClickItem(bookmarkItem) : void 0 : void 0;
    };

    BookmarksPopup.prototype.BookmarksPopupDidMouseOverItem = function(bookmarkItem) {
      if (this.mouseoutTimeout) {
        clearTimeout(this.mouseoutTimeout);
        this.mouseoutTimeout = null;
      }
      return {
        BookmarksPopupDidClickItem: function(bookmarkItem) {
          if (this.parentPopup) {
            return this.hidePopupIfPresent();
          } else {
            return this.hide();
          }
        }
      };
    };

    return BookmarksPopup;

  })();

}).call(this);

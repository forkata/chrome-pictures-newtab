namespace "ChromePicturesNewTab", (exports) ->
  class exports.BookmarksList

    constructor: (@bookmarks, @options = {}) ->
      @delegate = @options.delegate

    render: (@viewport) ->
      @el = document.createElement("ul")
      @el.className = "bookmarks-list clearfix"
      @viewport.appendChild(@el)
      @renderBookmarks()

    renderBookmarks: ->
      for bookmark in @bookmarks
        bookmarkItem = new ChromePicturesNewTab.BookmarkItem(bookmark)
        bookmarkItem.delegate = this
        bookmarkItem.render(@el)

    hidePopupIfPresent: ->
      if @popup
        @popup.hide()
        @popup = null

    openFolder: (bookmarkItem) ->
      chrome.bookmarks.getChildren bookmarkItem.bookmarkId, (bookmarks) =>
        @hidePopupIfPresent()
        @popup = new ChromePicturesNewTab.BookmarksPopup bookmarks, @popupOptions(bookmarkItem)
        @popup.render(bookmarkItem.link)

      $(bookmarkItem.el).addClass("folder-opened")
      @delegate?.BookmarksListDidOpenFolder?(this)

    popupOptions: (bookmarkItem) ->
      {
        bookmarkItem: bookmarkItem
        folderId: bookmarkItem.bookmarkId
        delegate: this
      }

    BookmarksPopupDidHideWithBookmarkItem: (bookmarkItem) ->
      $(bookmarkItem.el).removeClass("folder-opened")

    BookmarkItemDidClick: (bookmarkItem) ->
      @openFolder(bookmarkItem) if bookmarkItem.isFolder()

    BookmarkItemDidMouseOver: (bookmarkItem) ->
      @hidePopupIfPresent() unless bookmarkItem.isFolder()
      @delegate?.BookmarksListDidMouseOverItem?(this, bookmarkItem)

    BookmarkItemWillClick: (bookmarkItem) ->
      @hidePopupIfPresent()

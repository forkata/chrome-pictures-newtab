class @BookmarksList

  constructor: (@bookmarks, @options = {}) ->
    @delegate = @options.delegate

  render: (@$viewport) ->
    @$el = document.createElement("ul")
    @$el.className = "bookmarks-list clearfix"

    for bookmark in @bookmarks
      bookmarkItem = new BookmarkItem(bookmark)
      bookmarkItem.delegate = this
      bookmarkItem.render(@$el)

    @$viewport.appendChild(@$el)

  hidePopupIfPresent: ->
    if @popup
      @popup.hide()
      @popup = null

  openFolder: (bookmarkItem) ->
    chrome.bookmarks.getChildren bookmarkItem.bookmarkId, (bookmarks) =>
      @hidePopupIfPresent()
      @popup = new BookmarksPopup(bookmarks, { folderId: bookmarkItem.bookmarkId })
      @popup.render(bookmarkItem.$link)
    @delegate?.BookmarksListDidOpenFolder?(this)

  BookmarkItemDidClick: (bookmarkItem) ->
    @openFolder(bookmarkItem) if bookmarkItem.isFolder()

  BookmarkItemDidMouseOver: (bookmarkItem) ->
    @hidePopupIfPresent() unless bookmarkItem.isFolder()
    @delegate?.BookmarksListDidMouseOverItem?(this, bookmarkItem)

  BookmarkItemWillClick: (bookmarkItem) ->
    @hidePopupIfPresent()

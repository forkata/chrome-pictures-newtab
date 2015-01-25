namespace "ChromePicturesNewTab", (exports) ->
  class exports.BookmarksBar

    constructor: ->
      @bookmarksLoaded = new RSVP.Promise (resolve, reject) =>
        chrome.bookmarks.getChildren "1", (bookmarks) =>
          @bookmarks = bookmarks
          resolve(@bookmarks)

    render: (@viewport) ->
      @el = document.createElement("div")
      @el.id = "bookmarks-bar"

      @viewport.appendChild(@el)

      @bookmarksLoaded.then =>
        @mainBookmarksList = new ChromePicturesNewTab.BookmarksList(@bookmarks, { delegate: this })
        @mainBookmarksList.render(@el)

        @otherBookmarksList = new ChromePicturesNewTab.BookmarksList([{ id: "2", title: "Other Bookmarks" }], { delegate: this })
        @otherBookmarksList.render(@el)
        @otherBookmarksList.el.className += " other-bookmarks"

    hidePopupIfPresent: ->
      @otherBookmarksList.hidePopupIfPresent()
      @mainBookmarksList.hidePopupIfPresent()

    BookmarksListDidOpenFolder: (bookmarksList) ->
      if bookmarksList == @mainBookmarksList
        @otherBookmarksList.hidePopupIfPresent()
      else
        @mainBookmarksList.hidePopupIfPresent()

    BookmarksListDidMouseOverItem: (bookmarksList, bookmarkItem) ->
      if bookmarkItem.isFolder()
        if bookmarksList == @mainBookmarksList
          @otherBookmarksList.hidePopupIfPresent()
        else
          @mainBookmarksList.hidePopupIfPresent()
      else
        @hidePopupIfPresent()

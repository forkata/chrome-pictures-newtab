namespace "ChromePicturesNewTab", (exports) ->
  class exports.NewTabPage
    attrRegexp: new RegExp("^[^-]+-photo-(.+)")

    constructor: ($viewport) ->
      @$viewport = $viewport

      @$photo = $("#photo")
      @$photoFooter = $("#photo-footer")
      @$photoTitleLink = $("#photo-title-link")
      @$photoTitleOwnerLink = $("#photo-title-owner-link")
      @$photoRefreshLink = $("#photo-refresh-link")
      @$photoPinLink = $("#photo-pin-link")
      @$photoPinLinkText = $("#photo-pin-link span")

      @proxy = new ChromePicturesNewTab.BackgroundServiceProxy()

      @proxy.call("setViewportSize", @$viewport.width(), @$viewport.height())
      window.addEventListener "resize", =>
        @proxy.call("setViewportSize", @$viewport.width(), @$viewport.height())
      , false

      @ensureCachedPhoto("current").then (photo) =>
        nowTime = (new Date()).getTime()
        photoTime = parseInt(photo.timestamp) || Infinity
        diffTime = nowTime - photoTime
        timedOut = diffTime > 900000

        if timedOut && !photo.isPinned
          @advancePhoto()
        else
          @displayPhoto(photo)
          @ensureCachedPhoto("next")

      @bookmarksBar = new ChromePicturesNewTab.BookmarksBar()
      @bookmarksBar.render(@$viewport[0])

      @$photoRefreshLink.on "click", =>
        @withLoadingAnimation @$photoRefreshLink, =>
          @refreshPhoto()

      @$photoPinLink.on "click", =>
        @togglePinned()

      document.body.addEventListener "click", (event) =>
        unless $(event.target).closest(".bookmarks-popup").length
          @bookmarksBar?.hidePopupIfPresent()
      , false

      window.addEventListener "resize", =>
        @bookmarksBar?.hidePopupIfPresent()
      , false

    withLoadingAnimation: ($target, func) ->
      if !$target.hasClass("loading")
        $target.addClass("loading")
        func().then =>
          $target.removeClass("loading")

    togglePinned: ->
      @proxy.call("togglePinned").then =>
        @cachedPhoto("current").then (photo) =>
          @updatePinnedDisplay(photo)

    displayPhoto: (photo) ->
      console.log "Displaying photo", photo.title

      chrome.storage.local.get ["current-photo-timestamp"], (data) ->
        console.log "Checking photo timestamp", data["current-photo-timestamp"]
        if !data["current-photo-timestamp"]
          photoTime = (new Date()).getTime()
          console.log "Setting photo timestamp to #{photoTime}"
          data["current-photo-timestamp"] = photoTime
          chrome.storage.local.set data

      if ChromePicturesNewTab.Deployed
        @$photo.css "background-image", "url(#{photo.dataUri})"
      else
        @$photo.css "background-image", "url('#{photo.url}')"

      @$photoTitleLink.text(photo.title)
      @$photoTitleLink.attr("href", photo.webUrl)
      @$photoTitleOwnerLink.html("&copy; #{photo.ownerName}")
      @$photoTitleOwnerLink.attr("href", photo.ownerWebUrl)

      if (photo.bottomGrayscale / 255.0) * 100 < 50
        @$photoFooter.attr("data-color", "dark")
      else
        @$photoFooter.attr("data-color", "light")

      if (photo.topGrayscale / 255.0) * 100 < 50
        $(@bookmarksBar.el).attr("data-color", "dark")
      else
        $(@bookmarksBar.el).attr("data-color", "light")

      @updatePinnedDisplay(photo)
      null

    updatePinnedDisplay: (photo) ->
      @$photoPinLinkText.text if photo.isPinned
        "Unpin"
      else
        "Pin"

    refreshPhoto: ->
      @proxy.call("replaceNextPhoto").then =>
        @advancePhoto()

    advancePhoto: ->
      @proxy.call("replaceCurrentPhoto").then =>
        @cachedPhoto("current").then (photo) =>
          @proxy.call("replaceNextPhoto")
          @displayPhoto(photo)

    ensureCachedPhoto: (prefix) ->
      @proxy.call("ensureCachedPhoto", prefix).then =>
        @cachedPhoto(prefix)

    cachedPhoto: (prefix) ->
      new RSVP.Promise (resolve, reject) =>
        try
          chrome.storage.local.get [
            "#{prefix}-photo-dataUri"
            "#{prefix}-photo-topGrayscale"
            "#{prefix}-photo-bottomGrayscale"
            "#{prefix}-photo-url"
            "#{prefix}-photo-contentType"
            "#{prefix}-photo-title"
            "#{prefix}-photo-webUrl"
            "#{prefix}-photo-ownerName"
            "#{prefix}-photo-ownerWebUrl"
            "#{prefix}-photo-timestamp"
            "#{prefix}-photo-isPinned"
          ], (data) =>
            photo = @decodePhoto(data)
            if photo.dataUri?.length > 0
              console.log "Photo cache hit: #{prefix}"
              resolve(photo)
            else
              console.warn "Photo cache miss: #{prefix}"
              reject()
        catch err
          console.error "Photo cache error: #{prefix}", err
          reject(err)

    decodePhoto: (data) ->
      photo = {}
      _.each _.keys(data), (key) =>
        attrName = key.match(@attrRegexp)[1]
        photo[attrName] = data[key]
      photo

namespace "ChromePicturesNewTab", (exports) ->
  class exports.BackgroundServiceProxy
    call: (method, args...) ->
      new RSVP.Promise (resolve, reject) ->
        chrome.runtime.sendMessage {
          method: method
          args: args
        }, (response) ->
          if response.resolve
            resolve(response.resolve...)
          else
            reject(response?.reject...)

window.onload = ->
  new ChromePicturesNewTab.NewTabPage($(document.body))


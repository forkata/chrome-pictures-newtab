class ChromePicturesNewTab
  @FetchSize: 500

  constructor: ($viewport) ->
    @$viewport = $viewport

    @$photo = $("#photo")
    @$photoTitle = $("#photo-title")
    @$photoTitleLink = $("#photo-title-link")
    @$photoTitleOwnerLink = $("#photo-title-owner-link")

    @viewportWidth = @$viewport.width()
    @viewportHeight = @$viewport.height()
    window.addEventListener "resize", =>
      @viewportWidth = @$viewport.width()
      @viewportHeight = @$viewport.height()
    , false

    @cachedPhoto().then (photo) =>
      @$photo.css "background-image", "url('#{photo.url}')"
      # @$photo.css "background-image", "url(#{photo.dataUri})"

      @$photoTitleLink.text(photo.title)
      @$photoTitleLink.attr("href", photo.webUrl)
      @$photoTitleOwnerLink.html("&copy; #{photo.ownerName}")
      @$photoTitleOwnerLink.attr("href", photo.ownerWebUrl)

      @fetchPhoto().then (photo) =>
        @savePhoto(photo)
    , ->
      @fetchPhoto().then (photo) =>
        @savePhoto(photo)
        @$photo.css "background-image", "url('#{photo.getAttribute("url")}')"

  cachedPhoto: ->
    new RSVP.Promise (resolve, reject) ->
      try
        chrome.storage.local.get [
          "photoDataUri"
          "photoUrl"
          "photoContentType"
          "photoTitle"
          "photoWebUrl"
          "photoOwnerName"
          "photoOwnerWebUrl"

        ], (data) ->
          if data.photoDataUri?.length > 0
            console.log "Photo cache hit"
            resolve({
              dataUri: data.photoDataUri
              url: data.photoUrl
              contentType: data.photoContentType
              title: data.photoTitle
              webUrl: data.photoWebUrl
              ownerName: data.photoOwnerName
              ownerWebUrl: data.photoOwnerWebUrl
            })
          else
            console.warn "Photo cache miss"
            reject()
      catch err
        console.error "Photo cache error"
        reject(err)

  savePhoto: (photo) ->
    console.log "saving", photo
    new RSVP.Promise (resolve, reject) ->
      try
        chrome.storage.local.set({
          photoDataUri: photo.dataUri
          photoUrl: photo.url
          photoContentType: photo.contentType
          photoTitle: photo.title
          photoWebUrl: photo.webUrl
          photoOwnerName: photo.ownerName
          photoOwnerWebUrl: photo.ownerWebUrl
        }, ->
          console.log "Photo saved"
          resolve()
        )
      catch err
        console.error "Error saving photo", err
        reject(err)

  fetchPhoto: ->
    new RSVP.Promise (resolve, reject) =>
      @fetchPhotos().then (resp) =>
        photos = $(resp).find("photo").toArray()
        index = parseInt(Math.random() * photos.length * 10, 10) % photos.length
        photo = photos[index]
        title = photo.getAttribute("title")
        webUrl = @photoWebUrl(photo.getAttribute("owner"), photo.getAttribute("id"))
        ownerName = photo.getAttribute("ownername")
        ownerWebUrl = @ownerWebUrl(photo.getAttribute("owner"))

        console.log "Use photo at index #{index} of #{photos.length} photos", photo
        console.log " * title: #{title}"
        console.log " * webUrl: #{webUrl}"
        console.log " * ownerName: #{ownerName}"

        @fetchPhotoSizes(photo.getAttribute("id")).then (resp) =>
          largestSize = _.reduce($(resp).find("size").toArray(), (largest, size) =>
            largest = size unless largest

            largestWidth = largest.getAttribute("width")
            largestHeight = largest.getAttribute("height")
            sizeWidth = size.getAttribute("width")
            sizeHeight = size.getAttribute("height")

            if sizeWidth <= @viewportWidth || sizeHeight <= @viewportHeight
              largestArea = largestWidth * largestHeight
              sizeArea = sizeWidth * sizeHeight
              largest = size if sizeArea > largestArea

            largest
          null)

          url = largestSize.getAttribute("source")
          contentType = "image/#{url.match(/\.([^.]+)$/)[1]}"
          photo.setAttribute "url", url
          photo.setAttribute "content-type", contentType

          @urlToBase64(url, contentType).then (dataUri) =>
            resolve({
              dataUri: dataUri
              url: url
              contentType: contentType
              title: title
              webUrl: webUrl
              ownerName: ownerName
              ownerWebUrl: ownerWebUrl
            })
      .catch ->
        console.error "Error fetching photo", arguments
        reject.apply(null, arguments)

  fetchPhotos: ->
    @flickrApiRequest("flickr.photos.search", {
      per_page: ChromePicturesNewTab.FetchSize
      page: 1

      tags: "NASA"
      extras: "license,owner_name"
      license: "1,2,3,4,5,7"
    })

  fetchPhotoSizes: (id) ->
    @flickrApiRequest("flickr.photos.getSizes", {
      photo_id: id
    })

  flickrApiRequest: (method, params) ->
    new RSVP.Promise (resolve, reject) ->
      $.ajax({
        type: "GET"
        url: "https://api.flickr.com/services/rest"
        data: _.extend({
          method: method
          api_key: "7d05080a526b965ba4978c0656dfdaf3"
        }, params)
      }).done((resp, status, req) ->
        resolve resp, status, req
      ).fail((req, status, message) ->
        reject req, status, message
      )

  photoWebUrl: (userId, photoId) ->
    "https://www.flickr.com/photos/#{userId}/#{photoId}"

  ownerWebUrl: (userId) ->
    "https://www.flickr.com/photos/#{userId}"

  urlToBase64: (url, contentType) ->
    new RSVP.Promise (resolve) ->
      canvas = document.createElement('CANVAS')
      ctx = canvas.getContext('2d')
      img = new Image()
      img.crossOrigin = 'Anonymous'
      img.onload = ->
        canvas.height = img.height
        canvas.width = img.width
        ctx.drawImage(img, 0, 0)

        dataURL = canvas.toDataURL(contentType)
        resolve(dataURL)
        $(canvas).remove()
      img.src = url

window.onload = ->
  classicNewTab = new ChromePicturesNewTab $(document.body)

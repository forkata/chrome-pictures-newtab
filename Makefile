all: clean js css
	cp -r extension/* build/

pack: all
	zip -r build.zip build

js: build/newtab.js build/bookmark-item.js build/bookmark-popup.js build/bookmark-list.js build/bookmark-bar.js
	cp -r javascripts/vendor/* build/

build/newtab.js: javascripts/newtab.coffee
	coffee -o build -c javascripts/newtab.coffee

build/bookmark-item.js: javascripts/bookmark-item.coffee
	coffee -o build -c javascripts/bookmark-item.coffee

build/bookmark-popup.js: javascripts/bookmark-popup.coffee
	coffee -o build -c javascripts/bookmark-popup.coffee

build/bookmark-list.js: javascripts/bookmark-list.coffee
	coffee -o build -c javascripts/bookmark-list.coffee

build/bookmark-bar.js: javascripts/bookmark-bar.coffee
	coffee -o build -c javascripts/bookmark-bar.coffee

css: build/newtab.css build/bookmark.css
	cp -r stylesheets/vendor/* build/

build/newtab.css: stylesheets/newtab.sass
	sass stylesheets/newtab.sass build/newtab.css

build/bookmark.css: stylesheets/bookmark.sass
	sass stylesheets/bookmark.sass build/bookmark.css

clean:
	rm -fr build
	rm -fr build.zip
	mkdir build

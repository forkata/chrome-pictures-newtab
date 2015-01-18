all: js

js: javascripts/newtab.js javascripts/bookmark-item.js javascripts/bookmark-popup.js javascripts/bookmark-list.js javascripts/bookmark-bar.js

javascripts/newtab.js: javascripts/newtab.coffee
	coffee -o javascripts -c javascripts/newtab.coffee

javascripts/bookmark-item.js: javascripts/bookmark-item.coffee
	coffee -o javascripts -c javascripts/bookmark-item.coffee

javascripts/bookmark-popup.js: javascripts/bookmark-popup.coffee
	coffee -o javascripts -c javascripts/bookmark-popup.coffee

javascripts/bookmark-list.js: javascripts/bookmark-list.coffee
	coffee -o javascripts -c javascripts/bookmark-list.coffee

javascripts/bookmark-bar.js: javascripts/bookmark-bar.coffee
	coffee -o javascripts -c javascripts/bookmark-bar.coffee

clean:
	rm -f javascripts/newtab.js
	rm -f javascripts/bookmark-item.js
	rm -f javascripts/bookmark-popup.js
	rm -f javascripts/bookmark-list.js
	rm -f javascripts/bookmark-bar.js

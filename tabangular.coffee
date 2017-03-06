###*
# Tabangular.js v1.0.0
# License: http://www.apache.org/licenses/LICENSE-2.0
# Copyright (c) 2014 David Sheldrick
###

tabangular = angular.module "tabangular", []

# get a display: none; style in ther somewhere
tabangular.run ->
  head = angular.element document.head
  head.ready ->
    head.append "<style type='text/css'>.tabangular-hide {display: none;}</style>"

###########
# Helpers #
###########

removeFromArray = (arr, item) ->
  if (i = arr.indexOf item) isnt -1
    arr.splice i, 1
    true
  else
    false

lastItem = (arr) ->
  arr[arr.length-1]

#################
# Events system #
#################

attach = (ctx, handlersObj, event, callback) ->
  if not (cbs = handlersObj[event])?
    cbs = []
    handlersObj[event] = cbs

  cbs.push callback
  ctx.trigger "_attach", {event: event, callback: callback}
  
  # return detach fn
  ->
    i = cbs.indexOf callback
    if i isnt -1
      cbs.splice i, 1
      ctx.trigger "_detach", {event: event, callback: callback}
      true
    else
      false

class Evented
  constructor: ->
    @_handlers = {}
    @_onceHandlers = {}

  # both of these return 'off' fns to detach cb from ev
  on: (ev, cb) -> attach @, @_handlers, ev, cb
  one: (ev, cb) -> attach @, @_onceHandlers, ev, cb

  trigger: (ev, data) ->
    cb.call(@, data) for cb in ons if (ons = @_handlers[ev])?
    cb.call(@, data) for cb in ones if (ones = @_onceHandlers[ev])?
    ones?.length = 0
    return


########################
# Tabs service factory #
########################

tabTypeDefaults =
  scope: true

class TabsProvider
  constructor: ->
    @_tabTypes = {}
    @_templateLoadCallbacks = {}
    @_tabTypeFetcher = null

    @$get = [
      "$http", "$compile", "$controller", "$templateCache", "$q", "$injector"
      ($http, $compile, $controller, $templateCache, $q, $injector) =>
        new TabsService @, $http, $compile, $controller, $templateCache, $q, $injector
    ]

  ###*
  # registers a new tab type with the system
  # @param id the string id of the tab type
  # @param options the tab type options. Some combination of the following:
  #                   
  #     scope: boolean
  #        specifies whether or not to define a new scope for
  #        tabs of this type. defaults to true
  #     templateUrl: string
  #        specifies a url from which to load a template (or the id of a
  #        template already in the dom)
  #     template: string
  #        specifies the template to use in the tab. takes
  #        precedence over templateUrl
  #     controller: function or string
  #        specifies the controller to call against the scope.
  #        Should be a function or a string denoting the
  #        controller to use. See
  #        https://docs.angularjs.org/api/ng/service/$controller
  #        defaults to a noop function
  ###
  registerTabType: (id, options) ->
    if @_tabTypes[id]?
      throw new Error "duplicate tab type '#{id}'"
    else
      @_tabTypes[id] = options
      # TODO: validate that we have enough information to decide how to compile
      # tabs

  typeFetcherFactory: (@_typeFetcherFactory) ->

  _reifyFetcher: ($injector) ->
    if @_typeFetcherFactory?
      @_tabTypeFetcher = $injector.invoke @_typeFetcherFactory
      delete @_typeFetcherFactory
      if typeof @_tabTypeFetcher isnt 'function'
        throw new Error "Tab type fetcher must be a function"



  
class TabsService
  constructor: (@provider, @$http, @$compile, @$controller, @$templateCache,
                @$q, @$injector) ->

  _getTabType: (id) ->
    @provider._reifyFetcher @$injector

    if @provider._tabTypes[id]?
      promise = @$q.when(@provider._tabTypes[id])
    else if @provider._tabTypeFetcher?
      deferred = @$q.defer()
      @provider._tabTypeFetcher deferred, id
      @provider._tabTypes[id] = deferred.promise
      promise = deferred.promise
    else 
      promise = @$q.when(null)

    promise


  # takes template and ctrl and does angular magic to create a DOM node, puts it
  # in tab._elem and adds the tabangular-hide class
  _compileElem: (tab, templateString, ctrl) ->
    if ctrl?
      @$controller(ctrl, {$scope: tab._scope, Tab: tab})
    tab._elem = @$compile(templateString.trim())(tab._scope)
    if tab.focused 
      tab._elem.removeClass "tabangular-hide"
    else 
      tab._elem.addClass "tabangular-hide"
    
  _compileContent: (tab, parentScope, cb) ->

    if typeof (tab.type) is 'string'
      @_getTabType(tab.type).then(
        (type) => 
          if !type?
            throw new Error "Unrecognised tab type: " + tab.type
          else
            @__compileContent tab, parentScope, cb, type
        ,
        (reason) ->
          console.warn "Tab type not found: " + tab.type
          console.warn "Reason: " + reason
          type = {
            templateString: "Tab type '#{tab.type}' not found because #{reason}"
            scope: false
          }
          @__compileContent tab, parentScope, cb, type
        )
    else
      @__compileContent tab, parentScope, cb, tab.type

        

  __compileContent: (tab, parentScope, cb, type) ->
    type = angular.extend {}, tabTypeDefaults, type
    tab._scope = if type.scope then parentScope.$new() else parentScope
    # maybe TODO: isolates and weird binding junk like directives

    # does the actual compilation once we found the template
    doCompile = (templateString) =>
      @_compileElem tab, templateString, type.controller
      cb()

    # find the template
    if type.template?
      doCompile type.template

    else if (url = type.templateUrl)?
      # look in template cache first
      if (cached = @$templateCache.get url)?
        doCompile cached
      else
        # check if this template is already being loaded, and if so, just get
        # in line for a callback
        if (waiting = @provider._templateLoadCallbacks[url])?
          waiting.push doCompile
        else
          # create the queue and trigger the load.
          @provider._templateLoadCallbacks[url] = [doCompile]
          @$http.get(url).then(
            (response) =>
              template = response.data
              @$templateCache.put url, template
              done(template) for done in @provider._templateLoadCallbacks[url]
              delete @provider._templateLoadCallbacks[url]
            ,
            (error) =>
              delete @provider._templateLoadCallbacks[url]
              tab.trigger "load_fail", error
              throw new Error "Unable to load template from " + url
          )
    else
      throw new Error "no template supplied"

  newArea: (options) ->
    area = new TabArea @, options

    window.addEventListener "beforeunload", ->
      area._persist()

    area


class Tab extends Evented
  constructor: (@area, @type, @options) ->
    super()
    @loading = true
    @loadingDeferred = false
    @closed = false
    @focused = false
    @_elem = null
    @_scope = null
    @enableAutoClose()
    @on "_attach", (data) =>
      if data.event is "loaded" and not @loading
        data.callback()

  deferLoading: ->
    @loadingDeferred = true
    @

  doneLoading: ->
    if @loading
      @loading = false
      @area._scope.$root.$$phase or @area._scope.$apply()
      if not @closed
        @trigger 'loaded'
    @

  close: (silent) ->
    if @closed
      throw new Error "Tab already closed"
    else if silent or @autoClose 
      removeFromArray @area._tabs, @
      removeFromArray @area._focusStack, @

      @closed = true

      @area._persist()
      if not @loading
        @_elem.remove()

        if @_scope isnt @area._scope
          @_scope.$destroy()

        @_elem = @_scope = null

        

        @trigger "closed"

        if @focused
          (lastItem(@area._focusStack) or lastItem(@area._tabs))?.focus()

          @focused = false
    else 
      @trigger "close"
    @

  enableAutoClose: ->
    @autoClose = true
    @

  disableAutoClose: ->
    @autoClose = false
    @

  focus: ->
    if @loading
      @on "loaded", => @focus()
    else if @closed
      throw new Error "Cannot focus closed tab"
    else if not @focused
      if (len = @area._focusStack.length) isnt 0
        current = @area._focusStack[len-1]
        current._elem.addClass "tabangular-hide"
        current.focused = false
        
      
      @focused = true

      @_elem?.removeClass "tabangular-hide"
      removeFromArray @area._focusStack, @
      @area._focusStack.push @
      @area._persist()

      @trigger "focused"
    @

  move: (toArea, idx) ->
    removeFromArray @area._tabs, @

    if toArea isnt @area
      removeFromArray @area._focusStack, @
      @area._persist()
      toArea._contentPane.append @_elem
      if @focused
        (lastItem(@area._focusStack) or lastItem(@area._tabs))?.focus()
      @area = toArea

    idx = Math.min Math.max(0, idx), @area._tabs.length

    @area._tabs.splice idx, 0, @
    if @focused or @area._tabs.length is 1
      @focused = false
      @focus()

    @area._persist()
    @


DEFAULT_TAB_AREA_OPTIONS =
  id: null
  persist: (json) ->
    if @id?
      window.localStorage["tabangular:" + @id] = json

  getExisting: (cb) ->
    if @id? and (json = window.localStorage["tabangular:" + @id])?
      cb(json)

  transformOptions: (options) -> options

  parseOptions: (options) -> options


class TabArea extends Evented
  constructor: (@_service, @options={}) ->
    super()
    @options = angular.extend {}, DEFAULT_TAB_AREA_OPTIONS, @options

    # handle existing tabs
    @_existingReady = false
    @_existingTabs = []

    # calls to @handleExisting get placed here if @_existingReady is false
    @_existingReadyQueue = []

    # initiate loading of existing tabs
    @options.getExisting? (json) =>
      json = json?.trim() or "[]" # allow empty string
      @_existingReady = true
      @_existingTabs = JSON.parse(json).map (tab) =>
        tab.options = @options.parseOptions tab.options
        tab
      cb() for cb in @_existingReadyQueue
      @_existingReadyQueue = []

    # actual state
    @_tabs = []
    @_focusStack = []

    # postpone loading of tabs until dom is ready
    @_readyQueue = []
    @_contentPane = null
    @_scope = null


    @on "_attach", (data) =>
      if data.event is "loaded" and @_contentPane?
        data.callback()

  # saves the junk to the place
  _persist: ->
    @options.persist? JSON.stringify @_tabs.map (tab) =>
        type: tab.type
        options: @options.transformOptions tab.options
        focused: !!tab.focused

  # calls cb on existing tabs like {type, options, active}. if cb returns
  # true, automatically reloads tab by calling @load(type, options)
  handleExisting: (cb) ->
    cb = cb or -> true
    if not @_existingReady
      @_existingReadyQueue.push => @handleExisting cb
    else
      for tab in @_existingTabs
        if cb tab
          loaded = @load tab.type, tab.options
          loaded.focus() if tab.focused
      @_persist()
    @

  _registerContentPane: (scope, elem) ->
    @_contentPane = elem
    @_scope = scope
    
    cb() for cb in @_readyQueue
    @_readyQueue = []
    @trigger "loaded"

  _createTab: (tabType, options) ->
    tab = new Tab @, tabType, options 
    @_tabs.push tab
    tab

  load: (tabType, options={}) ->
    tab = @_createTab tabType, options
    if @_contentPane?
      @_load tab
    else
      @_readyQueue.push => @_load tab
    @_persist()

    tab

  _load: (tab) ->
    @_service._compileContent tab, @_scope, =>
      @_contentPane.append tab._elem
      tab.trigger "dom_ready"
      if not tab.loadingDeferred
        tab.doneLoading()

  open: (tabType, options) ->
    @load(tabType, options).focus()

  list: ->
    @_tabs



tabangular.provider 'Tabs', TabsProvider


tabangular.directive 'tabContent', ->
  scope: false
  restrict: 'A'
  link: ($scope, $elem, $attrs) ->
    area = $scope.$eval $attrs.tabContent
    if not (area instanceof TabArea)
      throw new Error "'#{$attrs.tabContent}' is not a tab area" 
    else
      area._registerContentPane $scope, $elem
    return





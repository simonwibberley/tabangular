# License: http://www.apache.org/licenses/LICENSE-2.0
# Copyright (c) 2014 David Sheldrick

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
    cb(data) for cb in ons if (ons = @_handlers[ev])?
    cb(data) for cb in ones if (ones = @_onceHandlers[ev])?
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
      ($http, $compile, $controller, $templateCache, $q) =>
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
  #     templateURL: string
  #        specifies a url from which to load a template
  #     templateString: string
  #        specifies the template to use in the tab. takes
  #        precedence over templateURL
  #     templateID: string
  #        specifies the DOM element ID of the template to use.
  #        takes precedence over templateURL and templateString
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
      @_tabTypes[id] = tabTypeDefaults options
      # TODO: validate that we have enough information to decide how to compile
      # tabs
  
  tabTypeDefaults: (options) -> 
    angular.extend {}, tabTypeDefaults, options

  setTabTypeFetcher: (@_tabTypeFetcher) ->



  
class TabsService
  constructor: (@provider, @$http, @$compile, @$controller, @$templateCache,
                @$q, @$injector) ->

  _getTabType: (id) ->
    
    if @provider._tabTypes[id]?
      promise = @$q.when(@provider._tabTypes[id])
    else if @provider._tabTypeFetcher?
      deferred = @$q.defer()
      injectables = {deferred: deferred, typeID: id}
      @$injector.inject @provider._tabTypeFetcher, null, injectables
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
    tab._elem.addClass "tabangular-hide"


  _compileContent: (tab, parentScope, cb) ->

    if typeof (tab.type) is 'string'
      @_getTabType(tab.type).then((type) => 
        if !type?
          throw new Error "Unrecognised tab type: " + tab.type
        else
          @__compileContent tab, parentScope, cb, type)
        

  __compileContent: (tab, parentScope, cb, type) ->
    tab._scope = if type.scope then parentScope.$new() else parentScope
    # maybe TODO: isolates and weird binding junk like directives

    # does the actual compilation once we found the template
    doCompile = (templateString) =>
      @_compileElem tab, templateString, type.controller
      cb()

    # find the template
    if type.templateID?
      doCompile document.getElementById(type.templateID).innerHTML
    else if type.templateString?
      doCompile type.templateString
    else if (url = type.templateURL)?
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
    new TabArea @, options





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


  deferLoading: ->
    @loadingDeferred = true

  doneLoading: ->
    @loading = false
    @area._scope.$root.$$phase or @area._scope.$apply()
    if not @closed
      @trigger 'loaded'

  close: (silent) ->
    if @closed
      throw new Error "Tab already closed"
    else if not silent
      @trigger "close"
    else
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
          if (len = @area._focusStack.length) isnt 0
            @area._focusStack[len-1].focus()
          else if @area._tabs.length isnt 0
            @area._tabs[0].focus()

          @focused = false
    @

  enableAutoClose: ->
    if !@_offAutoClose?
      @_offAutoClose = @on "close", => @close true

  disableAutoClose: ->
    @_offAutoClose?()
    delete @_offAutoClose

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

      @_elem.removeClass "tabangular-hide"
      removeFromArray @area._focusStack, @
      @area._focusStack.push @
      @area._persist()

      @trigger "focused"
    @



DEFAULT_TAB_AREA_OPTIONS =
  id: null
  persist: (json) ->
    if @id?
      window.localStorage["tabangular:" + @id] = json

  getExisting: (cb) ->
    if @id? and (json = window.localStorage["tabangular:" + @id])?
      cb(json)


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
      @_existingReady = true
      @_existingTabs = JSON.parse json
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
    @options.persist? JSON.stringify @_tabs.map (tab) ->
      type: tab.type
      options: tab.options
      active: !!tab.focused

  # calls cb on existing tabs like {type, options, active}. if cb returns
  # true, automatically reloads tab by calling @load(type, options)
  handleExisting: (cb) ->
    if not @_existingReady
      @_existingReadyQueue.push => @handleExisting cb
    else
      for tab in @_existingTabs
        if cb tab
          loaded = @load tab.type, tab.options
          loaded.focus() if tab.active
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





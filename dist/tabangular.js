
/** License: http://www.apache.org/licenses/LICENSE-2.0
  * Copyright (c) 2014 David Sheldrick
 */

(function() {
  var DEFAULT_TAB_AREA_OPTIONS, Evented, Tab, TabArea, TabsProvider, TabsService, attach, removeFromArray, tabTypeDefaults, tabangular,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  tabangular = angular.module("tabangular", []);

  tabangular.run(function() {
    var head;
    head = angular.element(document.head);
    return head.ready(function() {
      return head.append("<style type='text/css'>.tabangular-hide {display: none;}</style>");
    });
  });

  removeFromArray = function(arr, item) {
    var i;
    if ((i = arr.indexOf(item)) !== -1) {
      arr.splice(i, 1);
      return true;
    } else {
      return false;
    }
  };

  attach = function(ctx, handlersObj, event, callback) {
    var cbs;
    if ((cbs = handlersObj[event]) == null) {
      cbs = [];
      handlersObj[event] = cbs;
    }
    cbs.push(callback);
    ctx.trigger("_attach", {
      event: event,
      callback: callback
    });
    return function() {
      var i;
      i = cbs.indexOf(callback);
      if (i !== -1) {
        cbs.splice(i, 1);
        ctx.trigger("_detach", {
          event: event,
          callback: callback
        });
        return true;
      } else {
        return false;
      }
    };
  };

  Evented = (function() {
    function Evented() {
      this._handlers = {};
      this._onceHandlers = {};
    }

    Evented.prototype.on = function(ev, cb) {
      return attach(this, this._handlers, ev, cb);
    };

    Evented.prototype.one = function(ev, cb) {
      return attach(this, this._onceHandlers, ev, cb);
    };

    Evented.prototype.trigger = function(ev, data) {
      var cb, ones, ons, _i, _j, _len, _len1;
      if ((ons = this._handlers[ev]) != null) {
        for (_i = 0, _len = ons.length; _i < _len; _i++) {
          cb = ons[_i];
          cb(data);
        }
      }
      if ((ones = this._onceHandlers[ev]) != null) {
        for (_j = 0, _len1 = ones.length; _j < _len1; _j++) {
          cb = ones[_j];
          cb(data);
        }
      }
      if (ones != null) {
        ones.length = 0;
      }
    };

    return Evented;

  })();

  tabTypeDefaults = {
    scope: true
  };

  TabsProvider = (function() {
    function TabsProvider() {
      this._tabTypes = {};
      this._templateLoadCallbacks = {};
      this._tabTypeFetcher = null;
      this.$get = [
        "$http", "$compile", "$controller", "$templateCache", "$q", "$injector", (function(_this) {
          return function($http, $compile, $controller, $templateCache, $q, $injector) {
            return new TabsService(_this, $http, $compile, $controller, $templateCache, $q, $injector);
          };
        })(this)
      ];
    }


    /**
     * registers a new tab type with the system
     * @param id the string id of the tab type
     * @param options the tab type options. Some combination of the following:
     *                   
     *     scope: boolean
     *        specifies whether or not to define a new scope for
     *        tabs of this type. defaults to true
     *     templateURL: string
     *        specifies a url from which to load a template
     *     templateString: string
     *        specifies the template to use in the tab. takes
     *        precedence over templateURL
     *     templateID: string
     *        specifies the DOM element ID of the template to use.
     *        takes precedence over templateURL and templateString
     *     controller: function or string
     *        specifies the controller to call against the scope.
     *        Should be a function or a string denoting the
     *        controller to use. See
     *        https://docs.angularjs.org/api/ng/service/$controller
     *        defaults to a noop function
     */

    TabsProvider.prototype.registerTabType = function(id, options) {
      if (this._tabTypes[id] != null) {
        throw new Error("duplicate tab type '" + id + "'");
      } else {
        return this._tabTypes[id] = options;
      }
    };

    TabsProvider.prototype.setTabTypeFetcher = function(_tabTypeFetcher) {
      this._tabTypeFetcher = _tabTypeFetcher;
    };

    return TabsProvider;

  })();

  TabsService = (function() {
    function TabsService(provider, $http, $compile, $controller, $templateCache, $q, $injector) {
      this.provider = provider;
      this.$http = $http;
      this.$compile = $compile;
      this.$controller = $controller;
      this.$templateCache = $templateCache;
      this.$q = $q;
      this.$injector = $injector;
    }

    TabsService.prototype._getTabType = function(id) {
      var deferred, injectables, promise;
      if (this.provider._tabTypes[id] != null) {
        promise = this.$q.when(this.provider._tabTypes[id]);
      } else if (this.provider._tabTypeFetcher != null) {
        deferred = this.$q.defer();
        injectables = {
          deferred: deferred,
          typeID: id
        };
        this.$injector.invoke(this.provider._tabTypeFetcher, null, injectables);
        this.provider._tabTypes[id] = deferred.promise;
        promise = deferred.promise;
      } else {
        promise = this.$q.when(null);
      }
      return promise;
    };

    TabsService.prototype._compileElem = function(tab, templateString, ctrl) {
      if (ctrl != null) {
        this.$controller(ctrl, {
          $scope: tab._scope,
          Tab: tab
        });
      }
      tab._elem = this.$compile(templateString.trim())(tab._scope);
      return tab._elem.addClass("tabangular-hide");
    };

    TabsService.prototype._compileContent = function(tab, parentScope, cb) {
      if (typeof tab.type === 'string') {
        return this._getTabType(tab.type).then((function(_this) {
          return function(type) {
            if (type == null) {
              throw new Error("Unrecognised tab type: " + tab.type);
            } else {
              return _this.__compileContent(tab, parentScope, cb, type);
            }
          };
        })(this));
      } else {
        return this.__compileContent(tab, parentScope, cb, tab.type);
      }
    };

    TabsService.prototype.__compileContent = function(tab, parentScope, cb, type) {
      var cached, doCompile, url, waiting;
      type = angular.extend({}, tabTypeDefaults, type);
      tab._scope = type.scope ? parentScope.$new() : parentScope;
      doCompile = (function(_this) {
        return function(templateString) {
          _this._compileElem(tab, templateString, type.controller);
          return cb();
        };
      })(this);
      if (type.templateID != null) {
        return doCompile(document.getElementById(type.templateID).innerHTML);
      } else if (type.templateString != null) {
        return doCompile(type.templateString);
      } else if ((url = type.templateURL) != null) {
        if ((cached = this.$templateCache.get(url)) != null) {
          return doCompile(cached);
        } else {
          if ((waiting = this.provider._templateLoadCallbacks[url]) != null) {
            return waiting.push(doCompile);
          } else {
            this.provider._templateLoadCallbacks[url] = [doCompile];
            return this.$http.get(url).then((function(_this) {
              return function(response) {
                var done, template, _i, _len, _ref;
                template = response.data;
                _this.$templateCache.put(url, template);
                _ref = _this.provider._templateLoadCallbacks[url];
                for (_i = 0, _len = _ref.length; _i < _len; _i++) {
                  done = _ref[_i];
                  done(template);
                }
                return delete _this.provider._templateLoadCallbacks[url];
              };
            })(this), (function(_this) {
              return function(error) {
                delete _this.provider._templateLoadCallbacks[url];
                tab.trigger("load_fail", error);
                throw new Error("Unable to load template from " + url);
              };
            })(this));
          }
        }
      } else {
        throw new Error("no template supplied");
      }
    };

    TabsService.prototype.newArea = function(options) {
      return new TabArea(this, options);
    };

    return TabsService;

  })();

  Tab = (function(_super) {
    __extends(Tab, _super);

    function Tab(area, type, options) {
      this.area = area;
      this.type = type;
      this.options = options;
      Tab.__super__.constructor.call(this);
      this.loading = true;
      this.loadingDeferred = false;
      this.closed = false;
      this.focused = false;
      this._elem = null;
      this._scope = null;
      this.enableAutoClose();
    }

    Tab.prototype.deferLoading = function() {
      return this.loadingDeferred = true;
    };

    Tab.prototype.doneLoading = function() {
      this.loading = false;
      this.area._scope.$root.$$phase || this.area._scope.$apply();
      if (!this.closed) {
        return this.trigger('loaded');
      }
    };

    Tab.prototype.close = function(silent) {
      var len;
      if (this.closed) {
        throw new Error("Tab already closed");
      } else if (!silent) {
        this.trigger("close");
      } else {
        removeFromArray(this.area._tabs, this);
        removeFromArray(this.area._focusStack, this);
        this.closed = true;
        this.area._persist();
        if (!this.loading) {
          this._elem.remove();
          if (this._scope !== this.area._scope) {
            this._scope.$destroy();
          }
          this._elem = this._scope = null;
          this.trigger("closed");
          if (this.focused) {
            if ((len = this.area._focusStack.length) !== 0) {
              this.area._focusStack[len - 1].focus();
            } else if (this.area._tabs.length !== 0) {
              this.area._tabs[0].focus();
            }
            this.focused = false;
          }
        }
      }
      return this;
    };

    Tab.prototype.enableAutoClose = function() {
      if (this._offAutoClose == null) {
        return this._offAutoClose = this.on("close", (function(_this) {
          return function() {
            return _this.close(true);
          };
        })(this));
      }
    };

    Tab.prototype.disableAutoClose = function() {
      if (typeof this._offAutoClose === "function") {
        this._offAutoClose();
      }
      return delete this._offAutoClose;
    };

    Tab.prototype.focus = function() {
      var current, len;
      if (this.loading) {
        this.on("loaded", (function(_this) {
          return function() {
            return _this.focus();
          };
        })(this));
      } else if (this.closed) {
        throw new Error("Cannot focus closed tab");
      } else if (!this.focused) {
        if ((len = this.area._focusStack.length) !== 0) {
          current = this.area._focusStack[len - 1];
          current._elem.addClass("tabangular-hide");
          current.focused = false;
        }
        this.focused = true;
        this._elem.removeClass("tabangular-hide");
        removeFromArray(this.area._focusStack, this);
        this.area._focusStack.push(this);
        this.area._persist();
        this.trigger("focused");
      }
      return this;
    };

    return Tab;

  })(Evented);

  DEFAULT_TAB_AREA_OPTIONS = {
    id: null,
    persist: function(json) {
      if (this.id != null) {
        return window.localStorage["tabangular:" + this.id] = json;
      }
    },
    getExisting: function(cb) {
      var json;
      if ((this.id != null) && ((json = window.localStorage["tabangular:" + this.id]) != null)) {
        return cb(json);
      }
    },
    transformOptions: function(options) {
      return options;
    },
    parseOptions: function(options) {
      return options;
    }
  };

  TabArea = (function(_super) {
    __extends(TabArea, _super);

    function TabArea(_service, options) {
      var _base;
      this._service = _service;
      this.options = options != null ? options : {};
      TabArea.__super__.constructor.call(this);
      this.options = angular.extend({}, DEFAULT_TAB_AREA_OPTIONS, this.options);
      this._existingReady = false;
      this._existingTabs = [];
      this._existingReadyQueue = [];
      if (typeof (_base = this.options).getExisting === "function") {
        _base.getExisting((function(_this) {
          return function(json) {
            var cb, _i, _len, _ref;
            _this._existingReady = true;
            _this._existingTabs = JSON.parse(json).map(function(tab) {
              return tab.options = _this.options.parseOptions(tab.options);
            });
            _ref = _this._existingReadyQueue;
            for (_i = 0, _len = _ref.length; _i < _len; _i++) {
              cb = _ref[_i];
              cb();
            }
            return _this._existingReadyQueue = [];
          };
        })(this));
      }
      this._tabs = [];
      this._focusStack = [];
      this._readyQueue = [];
      this._contentPane = null;
      this._scope = null;
      this.on("_attach", (function(_this) {
        return function(data) {
          if (data.event === "loaded" && (_this._contentPane != null)) {
            return data.callback();
          }
        };
      })(this));
    }

    TabArea.prototype._persist = function() {
      var _base;
      return typeof (_base = this.options).persist === "function" ? _base.persist(JSON.stringify(this._tabs.map((function(_this) {
        return function(tab) {
          return {
            type: tab.type,
            options: _this.options.transformOptions(tab.options),
            active: !!tab.focused
          };
        };
      })(this)))) : void 0;
    };

    TabArea.prototype.handleExisting = function(cb) {
      var loaded, tab, _i, _len, _ref;
      if (!this._existingReady) {
        this._existingReadyQueue.push((function(_this) {
          return function() {
            return _this.handleExisting(cb);
          };
        })(this));
      } else {
        _ref = this._existingTabs;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          tab = _ref[_i];
          if (cb(tab)) {
            loaded = this.load(tab.type, tab.options);
            if (tab.active) {
              loaded.focus();
            }
          }
        }
        this._persist();
      }
      return this;
    };

    TabArea.prototype._registerContentPane = function(scope, elem) {
      var cb, _i, _len, _ref;
      this._contentPane = elem;
      this._scope = scope;
      _ref = this._readyQueue;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        cb = _ref[_i];
        cb();
      }
      this._readyQueue = [];
      return this.trigger("loaded");
    };

    TabArea.prototype._createTab = function(tabType, options) {
      var tab;
      tab = new Tab(this, tabType, options);
      this._tabs.push(tab);
      return tab;
    };

    TabArea.prototype.load = function(tabType, options) {
      var tab;
      if (options == null) {
        options = {};
      }
      tab = this._createTab(tabType, options);
      if (this._contentPane != null) {
        this._load(tab);
      } else {
        this._readyQueue.push((function(_this) {
          return function() {
            return _this._load(tab);
          };
        })(this));
      }
      this._persist();
      return tab;
    };

    TabArea.prototype._load = function(tab) {
      return this._service._compileContent(tab, this._scope, (function(_this) {
        return function() {
          _this._contentPane.append(tab._elem);
          tab.trigger("dom_ready");
          if (!tab.loadingDeferred) {
            return tab.doneLoading();
          }
        };
      })(this));
    };

    TabArea.prototype.open = function(tabType, options) {
      return this.load(tabType, options).focus();
    };

    TabArea.prototype.list = function() {
      return this._tabs;
    };

    return TabArea;

  })(Evented);

  tabangular.provider('Tabs', TabsProvider);

  tabangular.directive('tabContent', function() {
    return {
      scope: false,
      restrict: 'A',
      link: function($scope, $elem, $attrs) {
        var area;
        area = $scope.$eval($attrs.tabContent);
        if (!(area instanceof TabArea)) {
          throw new Error("'" + $attrs.tabContent + "' is not a tab area");
        } else {
          area._registerContentPane($scope, $elem);
        }
      }
    };
  });

}).call(this);

//# sourceMappingURL=tabangular.js.map

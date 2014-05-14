# Tabangular.js

Dynamic persistent tabbed content for [Angular.JS](http://angularjs.org).

Useful for single-page interactive web apps which allow the user to organise content by tabs, e.g. a text editor.

## Data Model

Tabs...

- each have a unique content element which is shown only while the tab is in 'focus'.

- are 'typed'. A tab type specifies the template and (optionally) controller used to compile the tab's content element. By default, tabs get new scopes inheriting from their parent scope.

- are arranged by 'areas'. A tab area represents a flat array of tabs, of which only one can be focused at a time.

- can be moved to different areas, or to a different index within the same area.

- can be parameterised by providing an `options` object when they are created.

- provide a simple events system for communicating with their instantiators.

- are optionally persisted on a per-area basis.

## Building

You'll need to run `npm install` and then `sudo npm install grunt-cli -g` if you don't have grunt installed already.

Then it's just `grunt`, or `grunt && grunt watch` if developing.

## Usage

Load `tabangular.js` or `tabangular.min.js` into your page

```html
<script type="text/javascript" src="path/to/tabangular.js"></script>
```

Include `'tabangular'` in your module dependencies

```javascript
var textEditor = angular.module('textEditor', ['tabangular']);
```

Register named tab types at config time.

```javascript
textEditor.config(function (TabsProvider) {

  TabsProvider.registerTabType("editorTab", {
    // you can supply a url from which to fetch the template
    templateUrl: 'templates/editor.html',
    // controllers are resolved as usual
    controller: 'EditorCtrl'
  });

  TabsProvider.registerTabType("configTab", {
    // templateUrl looks in the $templateCache so you can supply the id of a
    // text/ng-template script element
    templateUrl: 'config-template',
    controller: function ($scope, Tab) { ... }
  });

  TabsProvider.registerTabType("hello", {
    // or just a string
    template: '<div>Hello world!</div>',
    // set scope to false to avoid creating a new scope for the tab
    scope: false
    // don't supply a controller if the tab doesn't need a controller
  });
});
```

Additionally, or alternatively, you can automatically resolve named tab types by providing a 'fetcher' function.

```javascript
textEditor.config(function (TabsProvider) {

  TabsProvider.typeFetcherFactory(function($http) {
    return function (deferred, typeID) {
      // deferred is a $q Deferred object which must be resolved with the tab type
      // typeID is the string ID of the tab type to resolve

      var templateURL = "tabs/" + typeID + "/template.html";

      // in this example, we load the controller from the server.
      var controllerURL = "tabs/" + typeID + "/controller.js";

      $http.get(controllerURL).success(function (result) {
        var ctrl = eval("(" + result.data + ")");

        // now the tab type can be resolved
        deferred.resolve({
          templateURL: templateURL,
          controller: ctrl
        });
      });
    };
  });

});
```

Create a tab area with the `Tabs` service

```javascript
textEditor.controller('WindowCtrl', function (Tabs) {
  $scope.docs = Tabs.newArea();
```

Then define functions and stuff for manipulating docs.

```javascript
  $scope.openDocument = function (filename) {
    $scope.docs.open('editorTab', {filename: filename});
  };

  $scope.newDocument = function () {
    $scope.docs.open('editorTab', {filename: 'untitled'})
  };

  $scope.configTab = null;
  $scope.config = function () {
    if ($scope.configTab) {
      // we only want one config tab open at a time
      $scope.configTab.focus();
    } else {
      $scope.configTab = $scope.docs.open('configTab'); // options are optional
      $scope.configTab.on("closed", function () {
        delete $scope.configTab;
      });
    }
  }
});
```

It is up to you to specify the HTML/css for the tabs themselves, along with the dom node in which the content elements should be placed.

```html
<body controller='WindowCtrl'>
  <!-- tabs go here -->
  <ul class='tabs-list'>
    <li ng-repeat='tab in docs.list()' ng-class="{active: tab.focused}">
      <a href="" ng-click="tab.focus()">{{tab.options.filename}}</a>
      <span ng-show="tab.loading">...</span>
      <a href="" ng-click="tab.close()">&times;</a>
    </li>
    <li class='new-document'>
      <a href="" ng-click="newDocument()">new +</a>
    </li>
  </ul>
  
  <div class="tabs-content" tab-content="docs">
    <!-- the tab-content value should evaluate to the relevant TabArea object -->
  </div>

  <button ng-click="config()">Configure the Editor</button>
</body>
```

Tab controllers can defer the 'loaded' event such that they don't get shown
until they want to be shown.

```javascript
function EditorCtrl ($scope, $http, Tab) {
  if (Tab.options.filename !== 'untitled') {
    Tab.deferLoading();
    $http.get(Tab.options.filename).then(function (response) {
      $scope.text = response.data;
      Tab.options.savedText = $scope.text;
      Tab.doneLoading();
    });
  } else {
    $scope.text = "";
    Tab.options.savedText = $scope.text;
  }
```

They can also intercept the `'close'` event, which gets fired when `Tab.close()` is called, but not when `Tab.close(true)` is called. 

```javascript
  Tab.disableAutoClose();
  Tab.on("close", function () {
    if ($scope.text === Tab.options.savedText
        || window.confirm("You have unsaved changes. Are you sure?")) {
      Tab.close(true); // force close
    }
  });

  $scope.save = function () {
    Tab.options.savedText = $scope.text;
    $http.post(whatever...);
  };
}
```

When providing a controller in the tab type, content templates should not use `ng-controller`, since the controller needs to be injected with the `Tab` pseudo-service by tabangular.

```html
<!-- templates/editor.html -->
<textarea ng-model='text'></textarea>
<button ng-click='save()'>Save</button>
```

However, if the tab doesn't need to know the fact that it's in a tab, `ng-controller` is fine.

```html
<!-- assume config tab type is simply {templateID: 'config.html'} -->

<script type='text/javascript'>
  function ConfigCtrl ($scope) {
    ... configuration logic
  }
</script>

<script type='text/ng-template' id='config.html'>
  <div ng-controller='ConfigCtrl'>
    ... configuration controls
  </div>
</script>
```

Persistence may be achieved by passing options to `Tabs.newArea`. There is a default `localStorage` persistence option which can be enabled by giving a string id to the tab area

```javascript
$scope.docs = Tabs.newArea({id: "myEditor"});
```

Alternatively, provide `persist` and `getExisting` functions to e.g. save state to a server.

```javascript
$scope.docs = Tabs.newArea({
  // persist is called whenever tabs are opened, closed, moved, and focused,
  // so if bandwidth is an issue for you, it is probably best to wrap the
  // post/put request somehow.
  persist: function (state) {
    // the state parameter is a string.
    $http.post('/tabs-state', {state: state});
  },
  // getExisting is called only once
  getExisting: function (cb) {
    $http.get('/tabs-state').success(function (result) {
      cb(result.data.state);
    });
  }
});
```



## API

### `TabsProvider` : provider

`TabsProvider` can be used to configure the `Tabs` service.

#### Methods

<a id="registerTabType"></a>
##### `registerTabType(id : string, options : object) : void`

Registers a tab type. `id` should be a unique string id, `options` should be an object with some combination of the following:

- `scope` :: `boolean`
  
  Specifies whether or not to define a new scope for tabs of this type. defaults to `true`

- `templateUrl` :: `string`

  Specifies a url from which to load a template, or the id of a template already in the dom (e.g. 'foo.html' for the template `<script type='text/ng-template' id='foo.html'>...</script>'`)

- `template` :: `string`

  Specifies the template to use in the tab. Takes precedence over `templateUrl`

- `controller` :: `function | string`
  
  Specifies the controller to call against the scope. Should be a function or a string denoting the controller to use (see [$controller](https://docs.angularjs.org/api/ng/service/$controller)).|

Examples:

```javascript
module.config(function (TabsProvider) {
  TabsProvider.registerTabType("myTabType", {
    templateUrl: "templates/my-tab-type.html",
    controller: "MyTabCtrl"
  });

  TabsProvider.registerTabType("myOtherTabType", {
    template: "<span>Hello {{name}}!</span>",
    controller: function ($scope, Tab) { $scope.name = Tab.options.name; }
  });
});
```

<a id="typeFetcherFactory"></a>
##### `typeFetcherFactory(factory : function) : void`

Registers a factory function for a tab type fetcher. The tab type fetcher resolves named tab types dynamically, if they haven't been previously registered. The factory function is invoked using Angular's dependency injector, to allow the use of services such at `$http` when resolving tab types. It should return the fetcher function which has the signature `(deferred : Deferred, typeID : string) : void`. The fetcher function is responsible for resolving the deferred object with the relevant tab type (see [`registerTabType`](#registerTabType) for the type options), or rejecting it when no such type can be found. See [$q](https://docs.angularjs.org/api/ng/service/$q) for the `Deferred` api.

Example which finds a template in Angular's template cache:

```javascript
module.config(function (TabsProvider) {
  TabsProvider.typeFetcherFactory(function ($templateCache) {
    return function (dfd, id) {
      var template = $templateCache.get(id + ".html");
      if (template) {
        dfd.resolve({
          template: template
          scope: false
        });
      } else {
        dfd.reject("Couldn't find template: " + id + ".html");
      }
    };
  });
});
```

### `Tabs` : service

The 'tabs' service allows the creation of new tab areas.

#### Methods

##### `newArea(options : object) : TabArea`

Creates a new tab area. `options` should be an object with some combination of the following:

- `id` :: `string`

  Activates the default localStorage persistence mechanism. Should be unique on a per-tab-area basis.

- `persist` :: `function (state : string) : void`

  Takes a string representation of the tab area's current state and puts it somewhere for safe keeping. Called when tabs are opened, closed, and focused. Also called upon the window's `beforeunload` event. By default it is a function which, if `id` has been defined, stores the state in `localStorage['tabangular:'+id]`

- `getExisting` :: `function (cb : function (state : string) : void) : void`

  Takes a callback which should be invoked with the stored state string at some point (or null if no state stored). Called once upon tab area construction. By default it is a function which, if `id` has been defined, looks up the state in `localStorage['tabangular:'+id]`

- `transformOptions` :: `function (options : object) : object`

  Takes the in-use version of a tab's options object and transforms it such that it is JSON stringifiable. By default it is the identity function.

- `parseOptions` :: `function (options : object) : object`

  The reverse of `transformOptions`. Takes the deserialised version of a tab's options object and transforms it such that it is identical to how it was before being serialised. By default it is the identity function.

## License

Copyright (c) 2014 David Sheldrick. All rights reserved.

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

### | (• ◡•)| (❍ᴥ❍ʋ)

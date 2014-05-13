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
    templateURL: 'templates/editor.html',
    // controllers are resolved as usual
    controller: 'EditorCtrl'
  });

  TabsProvider.registerTabType("configTab", {
    // you can supply the ID of a DOM node to use as a template
    templateID: 'config-template',
    controller: function ($scope, Tab) { ... }
  });

  TabsProvider.registerTabType("hello", {
    // or just a string
    templateString: '<div>Hello world!</div>',
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

### `TabsProvider` :: provider

`TabsProvider` can be used to configure the `Tabs` service.

#### Methods

<a id="registerTabType"></a>
##### `registerTabType(id : string, options : object) : void`

Registers a tab type. `id` should be a unique string id, `options` should be an object with some combination of the following:

|Key|Type|Description|
|---|----|-----------|  
|`scope`|boolean| specifies whether or not to define a new scope for tabs of this type. defaults to `true`|
|`templateURL`|string| specifies a url from which to load a template|
|`templateString`|string| specifies the template to use in the tab. takes precedence over templateURL|
|`templateID`|string| specifies the DOM element ID of the template to use. takes precedence over templateURL and templateString|
|`controller`|(optional) function or string| specifies the controller to call against the scope. Should be a function or a string denoting the controller to use (see [$controller](https://docs.angularjs.org/api/ng/service/$controller)).|

Example:

```javascript
module.config(function (TabsProvider) {
  TabsProvider.registerTabType("myTabType", {
    templateURL: "templates/my-tab-type.html",
    controller: "MyTabCtrl"
  })
});
```

##### `typeFetcherFactory(factory : function) : void`

Registers a factory function for a tab type fetcher. The tab type fetcher resolves named tab types dynamically, if they haven't been previously registered. The factory function is invoked using Angular's dependency injector, to allow the use of services such at `$http` when resolving tab types. It should return the fetcher function which has the signature `(deferred : Deferred, typeID : string) : void`. The fetcher function is responsible for resolving the deferred object with the relevant tab type (see [`registerTabType`](#registerTabType)), or rejecting it when no such type can be found. See [$q](https://docs.angularjs.org/api/ng/service/$q) for the `Deferred` api.

Example which finds the template :

```javascript
module.config(function (TabsProvider) {
  TabsProvider.typeFetcherFactory(function ($templateCache) {
    return function (dfd, id) {
      var template = $templateCache.get(id + ".html");
      if ()
    };

  });
});
```

## License

Copyright (c) 2014 David Sheldrick. All rights reserved.

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

### | (• ◡•)| (❍ᴥ❍ʋ)

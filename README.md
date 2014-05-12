# Tabangular.js

Dynamic persistent tabbed content for angular.js

## Tabs...

- are 'typed'. A tab type specifies the template and (optionally) controller used to compile the DOM element which represents the tab's content.

- each have a unique content element which is shown while the tab is in 'focus'. By default, tabs are given new scopes which inherit from their parent scope.

- are arranged by 'areas'. A tab area represents a flat array of tabs, of which only one can be focused at a time.

- can be moved to different areas, or to a different location in the same area.

- can be parameterised by providing an `options` object when they are created.

- provide a simple events system for communicating with their instantiators.

- are optionally persisted on a per-area basis. This is done by serializing an array of the open tabs along with their `options` objects.

## Usage

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

  TabsProvider.setTabTypeFetcher(function($http, deferred, typeID) {
    // the fetcher is injected with two parameters:
    //   deferred: a $q Deferred object which must be resolved with the tab type
    //   typeID: the string ID of the tab type to resolve

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
    if ($scope.configTab) // only want one of these to be open at a time
      $scope.configTab.focus();
    else
      $scope.configTab = $scope.docs.open('configTab'); // options are optional
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

Tab templates should not use ng-controller


```html
<!-- templates/editor.html -->
<textarea ng-model='text'></textarea>
<button ng-click='save()'>Save</button>
```

Persistence may be achieved by passing options to `Tabs.newArea`. There is a default `localStorage` persistence option which can be enabled by giving a string id to the tab area

```javascript
$scope.docs = Tabs.newArea({id: "myEditor"});
```

Alternatively, provide `persist` and `getExisting` functions to 

## API

Forthcoming

## Building

You'll need to run `npm install` and then `sudo npm install grunt-cli -g` if you don't have grunt installed already.

Then it's just `grunt`, or `grunt && grunt watch` if developing.

## License

Copyright (c) 2014 David Sheldrick. All rights reserved.

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

### | (• ◡•)| (❍ᴥ❍ʋ)

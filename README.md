# Tabangular.js

Dynamic persistent tabbed content for angular.js

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
    controller: 'EditorCtrl',
    // you can interrupt tab close events to prompt the user to save their work
    // or whatever by setting autoClose to false (it defaults to true)
    autoClose: false
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
      <a href="" ng-click="newDocument">new +</a>
    </li>
  </ul>
  
  <div class="tabs-content" tab-content="docs">
    <!-- content gets put in here -->
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

They can also intercept the 'close' event

```javascript
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

## API

Forthcoming

## Building

You'll need to run `npm install` and then `sudo npm install grunt -g` if you don't have grunt installed already.

Then it's just `grunt`, or `grunt && grunt watch` if developing.

## License

Copyright (c) 2014 David Sheldrick. All rights reserved.

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

### | (• ◡•)| (❍ᴥ❍ʋ)